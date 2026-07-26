# CLOSURE — visit-management

## Decisiones clave tomadas durante la implementación

### Modelo y dominio
- `Visit` usa AASM para el ciclo de vida. Los estados terminales del MVP son `checked_out` y `cancelled`; `rejected` y `expired` están preparados en constantes pero sin transiciones activas.
- `VisitStatusHistory` (renombrado desde el diseño como `visit_events`) cubre el historial funcional. No se creó un modelo separado; el existente cumple el contrato.
- `RECENT_CHECK_OUT_WINDOW = 24.hours` — constante en `Visit` que controla la ventana de visibilidad operativa para conserjes.

### Autorización y scopes
- `full_detail?` solo verifica `manage_visits` (no `view_visits`). Concierge tiene `VIEW_VISITS` por propiedad; incluirlo en `full_detail?` habría expuesto datos administrativos al perfil operativo.
- El scope diferencia `managed_property_ids` (tienen `MANAGE_VISITS`) de `operational_property_ids` (solo `VIEW_AUTHORIZED_VISITS`/`VIEW_VISITS`). Concierge recibe `.concierge_visible`; property_admin ve todos los estados.
- `cancel?` está bloqueado por policy antes de llegar a AASM para `checked_in`/`checked_out`, por lo que el error real es `Pundit::NotAuthorizedError`, no `AASM::InvalidTransition`.
- `check_in?` en pending sí llega a AASM porque la policy no restringe por estado (solo por capability y propiedad asignada).

### Controllers y rutas
- `Concierge::` namespace separado de `Admin::` (hereda de `AdminController` para reutilizar auth/locale/inertia_share).
- `authorize_visit_management!` usa `authorize Visit, :index?` para las acciones de soporte del formulario (`form_units`, `form_hosts`, `initial_status_preview`). Pundit resuelve la acción por nombre del método; sin `policy_class`, llamaría a `form_units?` que no existe.
- Los check-in/check-out de admin viven en sub-controllers separados (`Admin::Visits::CheckInsController`, `Admin::Visits::CheckOutsController`) para aislar el params de metadata operacional.

### Serializers
- `Admin::VisitDetailSerializer` hereda de `Admin::VisitSerializer` (list). AMS respeta la herencia de `attributes`.
- `Admin::VisitRestrictedSerializer` incluye `residential_property` (objeto embebido) para ser compatible con el tipo TypeScript `AdminVisitListItem` que lo requiere en la unión `AdminVisitShowItem`.
- Los handlers `onCheckIn`/`onCheckOut` en `admin/visits/index.vue` aceptan `AdminVisitListItem | AdminVisitShowItem` y castean a `AdminVisitListItem` internamente — necesario porque `VisitActionsDropdown` emite el tipo más amplio.

### i18n
- Todas las claves de usuario están en `es`, `en` y `pt`. La estructura frontend usa el prefijo `frontend.*` en los YAML; vue-i18n recibe solo el subárbol `frontend` como raíz de traducciones.
- Se agregó `visit_types.*` (guest/delivery/service/other) como único grupo nuevo; el resto ya existía en secciones anteriores del change.

### Tests
- Los tests de integración del ciclo de vida viven en `test/integration/visit_lifecycle_test.rb` y pasan directamente por los service objects, no por HTTP.
- 14.7 y 14.8 (QA manual) fueron verificados manualmente con `bin/dev`. El flujo de conserjería y administración funcionó correctamente en el navegador.
- 14.9 (cross-org/cross-property) ya cubierto en los tests de §5 y §6.

## Diferencias respecto al diseño original

| Aspecto | Diseño | Implementación |
|---|---|---|
| `visit_events` | Modelo nuevo propuesto | Se usó `VisitStatusHistory` existente |
| `check_out` concierge | Descrito como endpoint propio | Implementado como member action en `Concierge::VisitsController` |
| Serializer contextual (resident/owner) | Diseñado como `AdminVisitContextualDetail` | Tipos preparados en TS; serializer Ruby pendiente hasta §13 |
| `Concierge::VisitTimelineEntrySerializer` | Referenciado en stubs de serializer | Resuelto en el propio serializer summary con `VisitStatusHistory` directo |
