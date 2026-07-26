# Concierge Visit Access Flow Tasks

> Este change solo define OpenSpec. Las tareas siguientes describen una implementación futura y permanecen sin ejecutar.

## 1. Backend y scopes operativos de portería

* [x] 1.1 Definir contexto de una propiedad activa por sesión/pantalla de portería
* [x] 1.2 Reutilizar `VisitPolicy::Scope` y `Authorization::Resolver` con aislamiento por organización y propiedad
* [x] 1.3 Exigir `StaffAssignment` de conserjería activo y vigente
* [x] 1.4 Separar capabilities de visualización, ingreso y salida
* [x] 1.5 Definir scope `expected_today` para visitas `authorized` cuya programación/validez intersecta el día local
* [x] 1.6 Definir scope `currently_inside` para visitas `checked_in` sin salida
* [x] 1.7 Definir estado operacional efectivo para autorización vencida por `valid_until`, sin forzar transición persistida a `expired`

## 2. Búsqueda y listados de portería

* [x] 2.1 Definir búsqueda tenant-safe por documento del visitante
* [x] 2.2 Definir búsqueda por nombre normalizado del visitante
* [x] 2.3 Definir búsqueda por identificador/nombre visible de unidad
* [x] 2.4 Aplicar siempre scope de organización y propiedad antes de filtros de búsqueda
* [x] 2.5 Permitir resultado mínimo `cancelled` o vencido solo para explicar denegación de ingreso
* [x] 2.6 Excluir `cancelled` y `expired` de listas operativas normales
* [x] 2.7 Ordenar esperadas por horario y actualmente dentro por ingreso más antiguo
* [x] 2.8 Exponer contadores y estados vacíos de ambas listas

## 3. Check-in

* [x] 3.1 Reutilizar/extender el contrato `Visits::CheckIn`
* [x] 3.2 Exigir estado `authorized`, ventana temporal vigente y `register_visit_entry`
* [x] 3.3 Validar propiedad asignada mediante `VisitPolicy`
* [x] 3.4 Persistir `checked_in_at` y `checked_in_by_id` como `User`
* [x] 3.5 Transicionar atómicamente a `checked_in`
* [x] 3.6 Persistir metadata permitida de acceso, tipo, patente y observaciones
* [x] 3.7 Impedir doble check-in activo, incluyendo confirmaciones concurrentes
* [x] 3.8 Rechazar visitas `cancelled`, `expired`, vencidas o en cualquier estado distinto de `authorized`
* [x] 3.9 Definir evento opcional post-commit para notificación futura, sin implementar entrega

## 4. Check-out

* [x] 4.1 Reutilizar/extender el contrato `Visits::CheckOut`
* [x] 4.2 Exigir estado `checked_in` y `register_visit_exit`
* [x] 4.3 Validar propiedad asignada mediante `VisitPolicy`
* [x] 4.4 Persistir `checked_out_at` y `checked_out_by_id` como `User`
* [x] 4.5 Transicionar atómicamente a `checked_out`
* [x] 4.6 Validar que salida no preceda al ingreso
* [x] 4.7 Persistir metadata permitida de acceso, observaciones e incidencia
* [x] 4.8 Impedir salida duplicada

## 5. Serializers y props mínimos para conserjería

* [x] 5.1 Definir serializer de fila para esperadas hoy
* [x] 5.2 Definir serializer de fila para actualmente dentro
* [x] 5.3 Definir serializer de resultado mínimo de búsqueda no operable
* [x] 5.4 Reutilizar resumen restringido para confirmaciones de check-in/check-out
* [x] 5.5 Exponer `permissions`/`actions` calculadas en backend
* [x] 5.6 Exponer timestamps, actores resumidos, duración y timeline mínimo
* [x] 5.7 Verificar ausencia de perfil administrativo, roles, memberships y notas sensibles

## 6. UI de portería basada en mockups

* [x] 6.1 Diseñar pantalla de portería con contexto visible de propiedad
* [x] 6.2 Implementar búsqueda por documento, nombre y unidad
* [x] 6.3 Implementar listas Esperadas hoy y Actualmente dentro
* [x] 6.4 Mostrar badges de estado operacional efectivo
* [x] 6.5 Mostrar `Registrar ingreso` solo cuando backend entregue `check_in`
* [x] 6.6 Mostrar `Registrar salida` solo cuando backend entregue `check_out`
* [x] 6.7 Adaptar confirmación de ingreso desde `visit_checkin.png`
* [x] 6.8 Adaptar confirmación de salida desde `visit_checkout.png`
* [x] 6.9 Adaptar detalle mínimo/timeline desde `visit_details.png.png`
* [x] 6.10 Refrescar listas y contadores después de cada transición
* [x] 6.11 Mostrar “Solicitar nueva autorización” como instrucción, no como acción de autorización del conserje

## 7. Auditoría, historial y reportabilidad

* [x] 7.1 Verificar auditoría técnica de estado, timestamps y actores
* [x] 7.2 Registrar evento funcional `checked_in` con actor, from/to, momento y metadata
* [x] 7.3 Registrar evento funcional `checked_out` con actor, from/to, momento y metadata
* [x] 7.4 Garantizar rollback atómico entre visita e historial
* [x] 7.5 Exponer datos trazables para visitante, unidad, autorizador, actores de ingreso/salida y duración
* [x] 7.6 Definir consulta de visitas aún dentro sin construir reportes completos

## 8. Tests de autorización, estados y aislamiento

* [x] 8.1 Testear conserje con assignment activo en propiedad asignada
* [x] 8.2 Testear assignment inactivo, futuro y vencido
* [x] 8.3 Testear ausencia independiente de `view_authorized_visits`, `register_visit_entry` y `register_visit_exit`
* [x] 8.4 Testear búsqueda por documento, nombre y unidad
* [x] 8.5 Testear listas esperadas hoy y actualmente dentro
* [x] 8.6 Testear check-in exitoso y actor `User`
* [x] 8.7 Testear rechazo de visita cancelada, expirada, temporalmente vencida y no autorizada
* [x] 8.8 Testear doble check-in secuencial y concurrente
* [x] 8.9 Testear check-out exitoso y actor `User`
* [x] 8.10 Testear check-out desde estado inválido y salida duplicada
* [x] 8.11 Testear aislamiento cross-organization y cross-property en listas, búsqueda y mutaciones
* [x] 8.12 Testear payload mínimo y ausencia de datos administrativos
* [x] 8.13 Testear auditoría, historial y rollback
* [x] 8.14 Testear que visitas de `residential-visit-management` aparecen igual que otras visitas autorizadas
