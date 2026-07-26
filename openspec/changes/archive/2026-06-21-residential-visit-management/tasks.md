# Residential Visit Management Tasks

> Este change solo define OpenSpec. Las tareas siguientes describen una implementación futura y permanecen sin ejecutar.

## 1. API privada para residentes

* [x] 1.1 Definir el contrato versionado del endpoint privado autenticado para registrar una visita desde el contexto de una unidad
* [x] 1.2 Definir payload, respuesta, errores y semántica temporal sin aceptar organization, property, section, host, actores o status como valores confiables del cliente
* [x] 1.3 Mantener el endpoint separado de controllers, rutas y respuestas Inertia del administrador
* [x] 1.4 Documentar que el endpoint crea exclusivamente visitas autorizadas para residentes habilitados; un flujo `pending` requerirá otro contrato

## 2. Contexto y autorización del residente

* [x] 2.1 Resolver la organización activa, el `User` autenticado y su `Person` asociada
* [x] 2.2 Cargar `unit_id` mediante scopes tenant-safe
* [x] 2.3 Validar que la `Person` tenga `UnitOccupancy` o `UnitOwnership` activa y vigente en esa unidad
* [x] 2.4 Denegar relaciones inactivas, futuras, vencidas o eliminadas
* [x] 2.5 Exigir `create_visits` y `authorize_visits` en el contexto de la misma unidad
* [x] 2.6 Respetar `can_authorize_visits = true` cuando la autorización se deriva de `UnitOccupancy`
* [x] 2.7 Evitar escalamiento cross-unit, cross-property y cross-organization

## 3. Visitante como Person

* [x] 3.1 Resolver al visitante dentro de la organización por documento normalizado/digest usando el resolver canónico existente
* [x] 3.2 Reutilizar la `Person` existente cuando corresponde
* [x] 3.3 Crear una `Person` de visitante cuando no existe, con nombre, documento y teléfono válidos
* [x] 3.4 Evitar duplicados y cualquier reutilización cross-organization
* [x] 3.5 No introducir ni usar `visitor_profiles` como identidad primaria

## 4. Creación autorizada y trazabilidad

* [x] 4.1 Crear la visita asociada a la unidad validada y al visitante resuelto
* [x] 4.2 Asignar `host_person_id` desde la `Person` del `User` residente autenticado
* [x] 4.3 Derivar `residential_property_id` y `property_section_id` desde `unit_id`
* [x] 4.4 Crear la visita en estado `authorized` solo después de validar autorización efectiva
* [x] 4.5 Asegurar `created_by_id` y `authorized_by_id` como referencias al `User` autenticado
* [x] 4.6 Registrar `authorized_at` e historial funcional según el contrato vigente de `visit-management`
* [x] 4.7 Ejecutar resolución/creación de visitante, visita e historial en una transacción atómica

## 5. Visibilidad posterior para conserjería

* [x] 5.1 Confirmar que la visita `authorized` entra al scope operativo existente de conserjería
* [x] 5.2 Exigir `StaffAssignment` activo y vigente en la propiedad de la visita
* [x] 5.3 Exigir `view_authorized_visits` para esa propiedad
* [x] 5.4 Excluir conserjes asignados únicamente a otras propiedades
* [x] 5.5 Mantener a conserjería sin permisos de creación, edición o autorización por este flujo

## 6. Tests de autorización y aislamiento

* [x] 6.1 Testear creación exitosa por residente con ocupación activa y `can_authorize_visits = true`
* [x] 6.2 Testear creación exitosa por propietario activo cuando la regla vigente le concede `authorize_visits`
* [x] 6.3 Testear rechazo cuando el usuario no tiene relación con la unidad
* [x] 6.4 Testear rechazo de ocupación inactiva, futura, vencida o eliminada
* [x] 6.5 Testear rechazo de ocupante con `can_authorize_visits = false`
* [x] 6.6 Testear rechazo cross-organization
* [x] 6.7 Testear rechazo cross-property y cross-unit aunque el usuario tenga relación activa en otra unidad
* [x] 6.8 Testear creación y reutilización tenant-safe del visitante `Person`
* [x] 6.9 Testear `created_by_id`, `authorized_by_id`, `visitor_person_id` y `host_person_id`
* [x] 6.10 Testear derivación de propiedad y sección desde la unidad
* [x] 6.11 Testear visibilidad para conserjería asignada con `view_authorized_visits`
* [x] 6.12 Testear invisibilidad para conserjería de otra propiedad, con assignment inactivo o sin capability
* [x] 6.13 Testear rollback total ante errores de identidad, autorización o persistencia

## 7. QA de contrato

* [x] 7.1 Verificar que no se agregan vistas ni componentes Vue admin para residentes
* [x] 7.2 Verificar que no se implementa un portal móvil completo
* [x] 7.3 Verificar que `property_admin` y `concierge` siguen siendo roles por propiedad derivados de `StaffAssignment`
* [x] 7.4 Validar el change con `openspec validate residential-visit-management --type change --strict`
