# Visit Management Design

## Context

La plataforma ya cuenta con catastro residencial, personas, ownerships, occupancies, staff assignments y autorización basada en capabilities. Este cambio agrega el módulo MVP de visitas con dos experiencias deliberadamente separadas:

1. **Conserjería operativa:** consulta visitas operativas de propiedades asignadas y registra ingreso/salida.
2. **Gestión administrativa:** crea, autoriza, edita, cancela y consulta visitas dentro del alcance de `tenant_admin` o `property_admin`.

Decisiones base:

* `Person` es la identidad canónica de visitante y anfitrión.
* `User` es el actor autenticado de creación, autorización, check-in, check-out y cancelación.
* `property_admin` y `concierge` se derivan de `StaffAssignment` activo por propiedad; nunca son globales.
* `Authorization::Resolver`, Pundit y el backend son la fuente de verdad de scopes y acciones.
* El frontend renderiza `permissions`/`actions` entregadas por serializers; no infiere permisos solo por estado.
* El aislamiento por organización y propiedad es obligatorio.

## Goals

* Evolucionar `Visit` al contrato MVP y aplicar un ciclo de vida explícito.
* Separar conserjería operativa de gestión administrativa.
* Implementar creación, autorización, edición, cancelación, check-in y check-out según capability y scope.
* Registrar auditoría técnica e historial funcional visible.
* Exponer serializers e interfaces específicas para cada superficie.
* Mantener todos los textos visibles en i18n (`es`, `en`, `pt`).

## Non-Goals

* Visitas recurrentes o múltiples visitantes por visita.
* `visitor_profiles` como identidad primaria.
* Integración física con hardware o `access_events`.
* Gestión documental real; el tab Documentos queda preparado/placeholder.
* Notificaciones push/email.
* Portal móvil residente.
* Jobs automáticos de expiración.
* Flujos UI completos para `rejected` y `expired`.
* Gestión avanzada de flota/vehículos; el MVP solo conserva datos opcionales en metadata.

## Domain Model

### Visit

`Visit` guarda:

* `organization_id`, `residential_property_id`, `property_section_id`, `unit_id`;
* `visitor_person_id`, `host_person_id`;
* `created_by_id`, `authorized_by_id`, `checked_in_by_id`, `checked_out_by_id`, todos referidos a `User`;
* `visit_type`, `status`, `scheduled_at`, `valid_from`, `valid_until`;
* `checked_in_at`, `checked_out_at`, `notes`, `metadata`.

La unidad es la fuente de verdad territorial. `residential_property_id` y `property_section_id` se derivan desde `unit_id`; la sección puede ser nula.

### Person vs User

| Concepto | Modelo |
| --- | --- |
| Visitante | `Person` |
| Anfitrión | `Person` |
| Creador | `User` |
| Autorizador | `User` |
| Actor de check-in | `User` |
| Actor de check-out | `User` |
| Actor de cancelación/evento | `User` |

El anfitrión debe tener ownership u occupancy activa en la unidad. Visitante, anfitrión, unidad y visita deben pertenecer a la misma organización.

## Visit Lifecycle

Estados MVP:

* `pending`
* `authorized`
* `checked_in`
* `checked_out`
* `cancelled`

Estados preparados/post-MVP:

* `rejected`
* `expired`

Transiciones válidas:

| Desde | Acción | Hacia |
| --- | --- | --- |
| `pending` | authorize | `authorized` |
| `pending` | cancel | `cancelled` |
| `authorized` | check_in | `checked_in` |
| `authorized` | cancel | `cancelled` |
| `checked_in` | check_out | `checked_out` |

Reglas:

* check-in solo desde `authorized` y dentro de la ventana de validez;
* check-out solo desde `checked_in`;
* no se cancela desde `checked_in`, `checked_out` o `cancelled`;
* `checked_out` y `cancelled` son terminales en el MVP;
* el backend resuelve el estado inicial: `authorized` solo cuando el actor puede autorizar directamente; de lo contrario `pending`;
* el frontend no puede forzar un estado inicial no permitido.

## Authorization and Scopes

### Policy actions

| Acción | Regla principal |
| --- | --- |
| `index?` | `manage_visits` o `view_authorized_visits` |
| `show?` | detalle completo con `manage_visits`; restringido con `view_authorized_visits` |
| `create?` | `manage_visits` o `create_visits` en el contexto de unidad |
| `update?` | `manage_visits` y estado editable |
| `authorize?` | `authorize_visits` o `manage_visits`, solo desde `pending` |
| `cancel?` | `manage_visits` y estado `pending`/`authorized`; el flujo contextual de residentes puede usar su capability específica si se mantiene |
| `check_in?` | `register_visit_entry`, propiedad asignada y estado `authorized` |
| `check_out?` | `register_visit_exit`, propiedad asignada y estado `checked_in` |

### Policy scopes

| Actor | Scope |
| --- | --- |
| tenant_admin | todas las visitas de su organización |
| property_admin | visitas de propiedades con `StaffAssignment` activo |
| concierge | solo propiedades asignadas y estados `authorized`, `checked_in`, `checked_out` recientes |
| resident/owner autorizado | visitas de unidades relacionadas según ownership/occupancy y capabilities |
| sin relación | scope vacío |

Conserjería no crea, edita, autoriza ni cancela visitas en el MVP. Un admin tampoco hace check-in/check-out salvo que posea explícitamente las capabilities operativas.

## Backend-Computed Actions

Cada serializer de visita debe incluir un contrato estable:

```json
{
  "permissions": {
    "view": true,
    "edit": false,
    "cancel": false,
    "authorize": false,
    "check_in": true,
    "check_out": false
  },
  "actions": ["view", "check_in"]
}
```

El backend calcula estas acciones combinando estado, capability, scope, ventana temporal y reglas de transición. `actions` puede derivarse de `permissions`, pero ambos deben ser consistentes. El frontend solo renderiza lo recibido.

## Functional History

`audited` conserva auditoría técnica. El timeline, panel de actores y detalle usan un historial funcional independiente.

Se debe evolucionar `visit_status_histories` o crear un modelo equivalente (`visit_events`) con este contrato:

* `visit_id`
* `organization_id`
* `event_type`
* `from_status`
* `to_status`
* `actor_user_id`
* `occurred_at`
* `notes`
* `metadata`

Eventos mínimos:

* `created`
* `authorized`
* `checked_in`
* `checked_out`
* `cancelled`

Cada servicio de dominio registra el evento dentro de la misma transacción que muta la visita. El historial debe ser tenant-scoped, ordenable cronológicamente y serializable para timeline.

## Operational Metadata

Los datos operativos opcionales viven inicialmente en `visits.metadata` o en `metadata` del evento correspondiente.

Check-in:

```json
{
  "access_point": "Portería principal",
  "access_type": "pedestrian",
  "vehicle_plate": "ABC123",
  "notes": "Observación opcional"
}
```

Check-out:

```json
{
  "access_point": "Portería principal",
  "incident_type": "none",
  "notes": "Observación opcional"
}
```

Vehículo opcional asociado al registro:

```json
{
  "vehicle": {
    "plate": "ABC123",
    "brand_model": "Honda Civic",
    "color": "Gris"
  }
}
```

Si estos datos pasan a ser filtros, reglas de negocio o fuentes frecuentes de reportes, deberán promoverse a columnas o tablas propias mediante otro change.

## Serializers and Inertia Props

Serializers separados:

* **Operational list serializer:** payload mínimo para tabs de conserjería.
* **Admin list serializer:** columnas y filtros de gestión administrativa.
* **Full detail serializer:** información de visita, personas, actores, historial y metadata permitida.
* **Restricted detail serializer:** datos mínimos para control de acceso.
* **Operational summary serializer:** resumen para check-in/check-out.
* **Event/history serializer:** eventos funcionales del timeline.

Props esperadas:

* visitas paginadas;
* filtros y búsqueda actuales;
* propiedad/asignaciones disponibles según scope;
* contadores `authorized`, `checked_in`, `recent_checked_out`;
* `permissions` y `actions` por visita;
* catálogos traducidos;
* URLs/endpoints de acciones cuando el patrón del proyecto lo requiera.

## UI Surfaces

### 1. Concierge Authorized Visits

Página operativa para conserjería:

* muestra la propiedad asignada;
* tabs: Autorizadas, Ingresadas, Salidas recientes;
* búsqueda por visitante, unidad o anfitrión;
* filtros operativos;
* tabla paginada con visitante, unidad, anfitrión, estado, hora autorizada, último movimiento y acciones;
* todas las acciones están en `VisitActionsDropdown`;
* `authorized`: ver detalle, registrar ingreso;
* `checked_in`: ver detalle, registrar salida;
* `checked_out` reciente: ver detalle;
* nunca muestra `pending` o `cancelled`;
* nunca ofrece crear, editar, autorizar o cancelar.

### 2. Admin Visits Management

Página para `tenant_admin` y `property_admin`:

* selector de alcance cuando aplique: organización completa / propiedad asignada;
* filtros por propiedad, unidad, estado y rango de fechas;
* búsqueda por visitante, anfitrión o unidad;
* botón Nueva visita solo si `create?`/`manage_visits` lo permite;
* tabla con visitante, unidad, propiedad, anfitrión, estado, fecha, ingreso, salida y acciones;
* acciones de fila en `VisitActionsDropdown`;
* `pending`: ver, autorizar, editar, cancelar;
* `authorized`: ver, editar, cancelar;
* `checked_in`, `checked_out`, `cancelled`: ver;
* check-in/check-out aparecen únicamente si backend entrega capability operativa explícita.

### 3. Visit Create

Página o drawer administrativo con stepper:

1. Información general.
2. Detalles del visitante.
3. Fecha y horario.
4. Información adicional.
5. Notas y confirmación.

Campos:

* propiedad;
* unidad filtrada por propiedad;
* anfitrión filtrado por unidad;
* nombre, documento y teléfono del visitante;
* motivo;
* fecha, hora inicio y hora fin opcional;
* vehículo/patente opcional;
* notas.

`VisitAuthorizationSummary` refleja en tiempo real propiedad, unidad, anfitrión, visitante, motivo, horario, vehículo y una nota sobre el estado final estimado. No persiste datos ni decide el estado; el backend lo resuelve.

### 4. Visit Detail

Variantes:

* **Completa (`manage_visits`):** header con visitante/documento/estado, `Más acciones` dropdown, tabs Información/Documentos/Historial, datos de visita/visitante/anfitrión, propiedad, unidad, motivo, horario, vehículo, notas, actores y timeline.
* **Restringida (`view_authorized_visits`):** visitante, unidad, anfitrión, estado, horario autorizado, ingreso/salida, acciones operativas y timeline mínimo.

El tab Documentos puede mostrarse como preparado/placeholder, sin gestión documental real. Conserjería nunca recibe el perfil completo de personas ni datos administrativos no necesarios.

### 5. Check-in

Se abre desde `VisitActionsDropdown` solo si `permissions.check_in`:

* resumen del visitante, estado, unidad, anfitrión y horario autorizado;
* fecha/hora de ingreso;
* acceso/portería;
* tipo de acceso;
* patente/vehículo opcional;
* observaciones y mensaje informativo;
* Confirmar ingreso / Cancelar.

Al confirmar, `Visits::CheckIn` valida policy y transición, guarda actor/timestamp/metadata, registra evento funcional y refresca listado, contadores y detalle.

### 6. Check-out

Se abre desde `VisitActionsDropdown` solo si `permissions.check_out`:

* resumen del visitante, unidad, anfitrión e ingreso registrado;
* fecha/hora de salida;
* acceso/portería;
* observaciones;
* incidencia opcional;
* timeline operacional;
* Confirmar salida / Cancelar y `Más acciones` si existen secundarias.

Al confirmar, `Visits::CheckOut` valida policy y transición, guarda actor/timestamp/metadata, registra evento funcional y refresca listado, contadores y detalle.

## Interaction Rules

* Acciones de filas, tablas y detalle viven siempre en dropdowns; no hay botones inline de mutación.
* Botones primarios dentro de formularios/modales de confirmación sí están permitidos.
* Todos los textos visibles usan i18n en `es`, `en` y `pt`.
* Los estados se muestran traducidos, pero se transportan con valores canónicos.
* Errores de policy, transición y validación regresan desde backend y se muestran sin duplicar reglas de dominio en Vue.

## Visual References

Los mockups son referencia visual; este documento y el spec son la fuente de verdad funcional.

| Mockup | Superficie | Uso MVP |
| --- | --- | --- |
| [`visit_create.png`](mockups/visit_create.png) | Visit Create | stepper, composición y `VisitAuthorizationSummary` |
| [`visits_lists_property.png`](mockups/visits_lists_property.png) | Concierge Authorized Visits | tabs, propiedad asignada, tabla, búsqueda y dropdown |
| [`visits_organization.png`](mockups/visits_organization.png) | Admin Visits Management | alcance, filtros, tabla administrativa y paginación |
| [`visit_details.png.png`](mockups/visit_details.png.png) | Visit Detail | header, tabs, actores y timeline |
| [`visit_checkin.png`](mockups/visit_checkin.png) | Check-in | drawer/modal y metadata operacional |
| [`visit_checkout.png`](mockups/visit_checkout.png) | Check-out | drawer/modal, incidencia y timeline |

Vehículo, acceso/portería e incidencia sí pueden persistirse como metadata MVP. Documentos y notificaciones no agregan backend en este change.

## Validation and Testing Strategy

Las pruebas cubren:

* coherencia tenant/location y elegibilidad del anfitrión;
* estado inicial resuelto en backend;
* transiciones válidas e inválidas;
* historial funcional y metadata por evento;
* policies y scopes por capability;
* conserjería sin creación/edición/autorización/cancelación;
* serializers completos/restringidos y `permissions`;
* aislamiento cross-organization/cross-property;
* interfaces administrativas y operativas;
* i18n y estados de error.

## Legacy Schema Strategy

* `visits` permanece como tabla principal.
* `visit_status_histories` se evoluciona al contrato funcional o se reemplaza por `visit_events`.
* `visit_participants`, `visit_recurrences`, `visitor_profiles` y `access_events` no participan del MVP.
* Datos de desarrollo incompatibles se migran o limpian explícitamente.
