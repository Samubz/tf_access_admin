# Residential Visit Management

## Why

El módulo de visitas ya cubre la gestión administrativa y la operación de conserjería, pero el registro realizado directamente por un residente autenticado desde una aplicación privada necesita un contrato explícito y separado.

Este cambio define el flujo **3.3 Registro de visita desde residente vía API privada**. El residente entra al contexto de una de sus unidades, registra los datos mínimos del visitante y, cuando su relación con la unidad le concede autorización de visitas, crea una visita inmediatamente `authorized`. La visita queda disponible para la conserjería habilitada de esa propiedad.

## What Changes

* Agregar un flujo de creación de visitas exclusivo para una **API privada y autenticada de residentes**, separado de los endpoints, controllers Inertia y pantallas del administrador.
* Definir un contrato conceptual que recibe `unit_id`, nombre, documento y teléfono del visitante, además de la fecha/hora de visita.
* Resolver al residente desde el `User` autenticado y su `Person` dentro de la organización activa.
* Permitir el flujo únicamente para unidades donde esa `Person` tenga una relación activa mediante `UnitOccupancy` o `UnitOwnership`.
* Crear o reutilizar al visitante como `Person` canónico dentro de la organización, usando las reglas existentes de resolución y deduplicación.
* Crear la visita con:
  * `visitor_person_id` apuntando al visitante;
  * `host_person_id` apuntando a la `Person` asociada al `User` residente;
  * `created_by_id` apuntando al `User` autenticado;
  * `authorized_by_id` apuntando al mismo `User` cuando posee `authorize_visits` para la unidad;
  * `residential_property_id` y `property_section_id` derivados desde `unit_id`.
* Crear la visita directamente en estado `authorized` solamente cuando el residente está habilitado para autorizar visitas en esa unidad. Para una `UnitOccupancy`, esto exige `can_authorize_visits = true`; para una `UnitOwnership`, se conserva la regla efectiva de autorización definida por el dominio.
* Hacer visible la visita autorizada en el flujo operativo existente de conserjería cuando el conserje tenga un `StaffAssignment` activo para la propiedad y la capability `view_authorized_visits`.
* Mantener las restricciones de organización, propiedad, unidad, estado y capabilities ya definidas en `visit-management` y `operational-roles-and-permissions`.

Este flujo es adicional y distinto del flujo administrativo. No reutiliza una pantalla del administrador como interfaz del residente y no convierte la API privada en una superficie administrativa.

## Impact

**Capabilities relacionadas:**

* `residential-visit-management`: contrato del registro de visita desde residente mediante API privada.
* `visit-management`: reutiliza el modelo `Visit`, su ciclo de vida, la identidad basada en `Person`, los actores basados en `User` y el listado operativo de conserjería.
* `operational-roles-and-permissions`: reutiliza `create_visits`, `authorize_visits`, `view_authorized_visits` y los scopes por unidad y propiedad.
* `unified-person-profile`: reutiliza `Person` como identidad canónica y su resolución tenant-safe por documento.

**Dominio afectado conceptualmente:**

* `User`: actor autenticado que solicita, crea y, cuando corresponde, autoriza.
* `Person`: identidad del residente anfitrión y del visitante.
* `UnitOccupancy` / `UnitOwnership`: relación activa que delimita las unidades disponibles para el residente.
* `Unit`: fuente de `residential_property_id` y `property_section_id`.
* `Visit`: visita creada y autorizada.
* `StaffAssignment`: asignación activa que limita la visibilidad de conserjería a una propiedad.

**Trabajo futuro de implementación:**

* contrato de endpoint privado;
* autorización y resolución de contexto;
* resolución o creación del visitante;
* creación transaccional de la visita;
* tests de request, servicio, policy y aislamiento.

Este proposal no implementa esos componentes.

## Business Rules

* La solicitud requiere un `User` autenticado y una organización activa.
* El `User` debe resolver una `Person` dentro de esa misma organización.
* El residente solo puede registrar una visita para una unidad donde su `Person` tenga `UnitOccupancy` o `UnitOwnership` activa y vigente.
* Una relación inactiva, futura, vencida o eliminada no habilita el flujo.
* La relación con una unidad solo concede alcance sobre esa unidad; no concede alcance global sobre la propiedad ni sobre la organización.
* La creación y autorización se evalúan contra la unidad recibida, evitando reutilizar capabilities de otra unidad o propiedad.
* La visita queda `authorized` solo si el `User` posee la capability efectiva `authorize_visits` para esa unidad.
* Cuando la autorización depende de `UnitOccupancy`, la ocupación debe estar activa, vigente y tener `can_authorize_visits = true`.
* Si una relación activa permite crear pero no autorizar, este flujo no debe elevar privilegios ni crear una visita falsamente autorizada. El endpoint de registro autorizado debe rechazar la operación; un eventual flujo `pending` requerirá otro contrato explícito.
* `Person` sigue siendo la identidad canónica del visitante. No se introduce `visitor_profiles` como identidad primaria.
* `User` sigue siendo el actor autenticado. `created_by_id` y `authorized_by_id` nunca apuntan a `Person`.
* `visitor_person_id` apunta a la `Person` creada o reutilizada para el visitante.
* `host_person_id` apunta a la `Person` asociada al `User` residente en la organización activa.
* El visitante se busca o crea únicamente dentro de la organización actual; una coincidencia en otra organización no se reutiliza.
* `organization_id`, `residential_property_id` y `property_section_id` no son confiables desde el cliente. La organización proviene del contexto autenticado y propiedad/sección se derivan desde `unit_id`.
* No se permite crear visitas cross-organization, cross-property ni para una unidad fuera del alcance activo del residente.
* La visita creada debe reutilizar el historial funcional y la auditoría definidos por `visit-management`.
* Conserjería ve la visita solo cuando:
  * la visita está `authorized` y pertenece a su propiedad;
  * la `Person` del conserje tiene un `StaffAssignment` activo y vigente en esa propiedad;
  * el `User` posee `view_authorized_visits` para esa propiedad.
* Un conserje de otra propiedad no puede verla, aunque pertenezca a la misma organización.
* `property_admin` y `concierge` continúan siendo roles operativos derivados de `StaffAssignment` por propiedad; no se convierten en roles globales.

## Out of Scope

* Implementar código, migraciones, controllers, rutas, policies, serializers o servicios.
* Crear vistas o pantallas dentro del administrador para este flujo.
* Crear pantallas Vue admin para residentes.
* Implementar un portal móvil o aplicación self-service completa para residentes.
* Diseñar navegación, autenticación, recuperación de cuenta o gestión de perfil de la aplicación privada.
* Crear un flujo administrativo alternativo o modificar la UI administrativa existente.
* Crear visitas `pending` desde esta operación específica de registro autorizado.
* Notificaciones push, email, SMS o WhatsApp.
* Visitas recurrentes, múltiples visitantes, QR, credenciales o integración física de acceso.
* Introducir `visitor_profiles` como identidad primaria.
* Convertir `property_admin` o `concierge` en roles globales.
