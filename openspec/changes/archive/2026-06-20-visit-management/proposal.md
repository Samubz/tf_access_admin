## Why

La plataforma ya gestiona catastro (propiedades, secciones, unidades), propietarios, ocupantes, perfil unificado de persona y autorización operacional con capacidades preparadas para visitas (`create_visits`, `authorize_visits`, `register_visit_entry`, etc.), pero aún no existe un módulo funcional que permita crear, autorizar, consultar y registrar ingreso/salida de visitas.

Este cambio implementa el primer flujo operativo de alto valor después del catastro: la gestión de visitas residenciales. El módulo permitirá cubrir dos contextos principales:

1. **Operación de conserjería**, enfocada en visualizar visitas autorizadas de la propiedad asignada y registrar ingreso/salida.
2. **Gestión administrativa**, enfocada en consultar, crear, editar, cancelar y revisar visitas dentro del alcance autorizado.

El módulo de visitas es prerequisito natural para control de acceso, trazabilidad operacional, historial de estados, reportes y futuros eventos de acceso.

## What Changes

* Implementar el **módulo MVP de gestión de visitas** centrado en el modelo `Visit`, con estados AASM, servicios de dominio, políticas Pundit reales, serializers Inertia y UI diferenciada por rol.

* Normalizar el modelo de datos hacia un esquema MVP con **visitante y anfitrión como `Person`**, unidad/propiedad/sección denormalizadas para consulta, y trazabilidad de actores (`created_by`, `authorized_by`, `checked_in_by`, `checked_out_by`).

* Los campos `created_by_id`, `authorized_by_id`, `checked_in_by_id` y `checked_out_by_id` representan usuarios autenticados (`User`), mientras que `visitor_person_id` y `host_person_id` representan personas (`Person`).

* Completar la **`VisitPolicy`** existente, hoy contrato/placeholder con tests, integrándola con `Authorization::Resolver` y scopes por organización, propiedad y unidad.

* Exponer flujos UI separados para:

  * **Conserjería:** consulta operativa de visitas de la propiedad asignada, acciones de check-in/check-out y detalle restringido.
  * **Property admin / tenant admin:** gestión administrativa de visitas dentro de su alcance, incluyendo listado, filtros, creación, edición, cancelación y detalle completo.
  * **Residentes/propietarios autorizados:** creación o autorización de visitas solo cuando cumplan las reglas del dominio.

* La conserjería no podrá crear, editar, autorizar ni cancelar visitas en el flujo MVP. Su experiencia estará limitada a visitas operativas de la propiedad asignada: `authorized`, `checked_in` y `checked_out` recientes.

* Los roles administrativos podrán gestionar visitas dentro de su alcance:

  * `tenant_admin`: organización completa.
  * `property_admin`: propiedades asignadas.
  * Ningún rol administrativo registrará ingreso/salida salvo que también tenga capability operativa explícita.

* Implementar acciones por fila mediante un componente `VisitActionsDropdown`. No se deben usar botones inline para acciones como editar, autorizar, cancelar, registrar ingreso o registrar salida.

* Implementar pantallas principales:

  * Listado operativo de visitas autorizadas para conserjería.
  * Modal/drawer de check-in.
  * Modal/drawer de check-out.
  * Listado administrativo de gestión de visitas.
  * Formulario de nueva visita.
  * Vista de detalle de visita con tabs, actores e historial.

* Registrar **auditoría técnica** de mutaciones y transiciones de estado mediante `audited`.

* Registrar **historial funcional de estados** visible para usuario mediante `visit_status_histories` o un modelo equivalente de eventos funcionales. Este historial debe almacenar actor, estado anterior, estado nuevo, fecha/hora, notas y metadata operacional.

* Guardar metadata operacional MVP para check-in/check-out y vehículo opcional. Estos datos permanecerán en `metadata` mientras no sean requeridos como filtros, reglas o dimensiones frecuentes de reportes.

* Alinear o migrar el esquema legacy parcial (`visits`, `visit_participants`, `visit_status_histories`) hacia el contrato MVP.

* No introducir identidad separada de visitantes ni roles globales de `property_admin` / `concierge`.

* SCHEMA EVOLUTION: el esquema actual de desarrollo de `visits` usa nombres y relaciones distintas (`responsible_person`, `approved_by_person`, `visit_participants` con `visitor_profile_id`). Este change define la evolución hacia el contrato MVP; la implementación incluirá migraciones de columnas/estados si hay datos de desarrollo. Si existen datos de desarrollo, se deberán migrar o limpiar de forma explícita durante la implementación.

## Capabilities

### New Capabilities

* `visit-management`: Creación, autorización, consulta, check-in/check-out, cancelación y trazabilidad de visitas residenciales con aislamiento multi-tenant, autorización por capacidades operacionales y visitante/anfitrión modelados como `Person`.

### Modified Capabilities

* `operational-roles-and-permissions`: Se materializa el contrato de `VisitPolicy` definido previamente como placeholder, usando las capabilities existentes para visitas.

* `view_authorized_visits`: Permite a conserjería visualizar visitas operativas de la propiedad asignada. El ingreso y la salida requieren, respectivamente, `register_visit_entry` y `register_visit_exit`.

* `manage_visits`: Permite a usuarios administrativos consultar, crear, editar, cancelar y ver detalle completo de visitas dentro de su alcance.

## Impact

**Bounded context:** Visits, integrado con Organizations, Residential Properties, Property Sections, Units, Persons, Unit Ownerships, Unit Occupancies, Staff Assignments, Authentication & Authorization, Auditing.

**Modelos afectados:**

* `Visit`
  Existente. Evolucionar esquema, AASM, validaciones, auditoría, asociaciones y denormalización de contexto.

* `Person`
  Visitante y anfitrión. Identidad canónica organizacional.

* `User`
  Actor autenticado de acciones del sistema: `created_by`, `authorized_by`, `checked_in_by`, `checked_out_by`.

* `Unit`, `ResidentialProperty`, `PropertySection`
  Contexto territorial de la visita y denormalización para consulta.

* `UnitOwnership`, `UnitOccupancy`
  Elegibilidad del anfitrión y capacidades para crear o autorizar visitas.

* `StaffAssignment`
  Alcance de `property_admin`, `concierge`, `cleaning_staff` e `internal_staff`. No existen como roles globales.

* `visit_status_histories` o `visit_events`
  Historial funcional visible para usuario. Debe registrar eventos como creación, autorización, check-in, check-out y cancelación.

* `visit_participants`
  Fuera de alcance MVP o simplificado. El MVP considera un visitante principal por visita.

* `visit_recurrences`, `access_events`, `visitor_profiles`
  Fuera de alcance MVP.

**Backend nuevo o extendido:**

* Migraciones de evolución de `visits`.
* Modelo `Visit` con AASM y enums (`visit_type`, `status`).
* Servicios:

  * `Visits::Create`
  * `Visits::Authorize`
  * `Visits::CheckIn`
  * `Visits::CheckOut`
  * `Visits::Cancel`
  * `Visits::Reject` post-MVP, si aplica.
* `VisitPolicy` con implementación real y scopes diferenciados por capability.
* Scope operativo para conserjería:

  * propiedad asignada;
  * estados `authorized`, `checked_in` y `checked_out` recientes.
* Scope administrativo:

  * `tenant_admin`: organización completa;
  * `property_admin`: propiedades asignadas.
* Controllers Inertia administrativos y operativos.
* Serializers diferenciados:

  * listado operativo de conserjería;
  * listado administrativo;
  * detalle restringido;
  * detalle completo;
  * resumen para check-in/check-out;
  * historial funcional.
* Jobs opcionales de expiración automática quedan fuera de alcance MVP.

**Frontend (Inertia + Vue):**

* Pantalla operativa de conserjería para visitas autorizadas/operativas.
* Tabs operativos:

  * Autorizadas;
  * Ingresadas;
  * Salidas recientes.
* Búsqueda por visitante, unidad o anfitrión.
* Filtros operativos limitados al alcance de conserjería.
* Tabla con acciones por fila mediante dropdown.
* Modal/drawer de check-in con:

  * resumen del visitante;
  * fecha/hora de ingreso;
  * acceso/portería;
  * tipo de acceso;
  * patente o vehículo opcional;
  * observaciones.
* Modal/drawer de check-out con:

  * resumen del visitante;
  * fecha/hora de salida;
  * acceso/portería;
  * observaciones;
  * novedad/incidencia opcional;
  * línea de tiempo.
* Pantalla administrativa de gestión de visitas.
* Selector de alcance administrativo:

  * organización completa;
  * propiedad asignada.
* Filtros administrativos:

  * propiedad;
  * unidad;
  * estado;
  * rango de fechas;
  * búsqueda por visitante/anfitrión/unidad.
* Formulario de nueva visita con:

  * selección de propiedad;
  * selección de unidad;
  * selección de residente/anfitrión;
  * datos del visitante;
  * documento;
  * teléfono;
  * motivo;
  * fecha y horario;
  * vehículo opcional;
  * notas;
  * resumen lateral de autorización.
* Vista de detalle con:

  * header de visitante y estado;
  * dropdown de acciones;
  * tabs de Información, Documentos e Historial;
  * panel de información;
  * panel de actores;
  * historial de estados.

**Policies y tests:**

* Tests de `VisitPolicy`.
* Tests de scopes por organización, propiedad y unidad.
* Tests de servicios de dominio.
* Tests de transiciones AASM.
* Tests de aislamiento cross-organization y cross-property.
* Tests de elegibilidad de anfitrión vía ownership/occupancy.
* Tests de acciones disponibles según estado y capability.
* Tests de serializers por contexto: conserjería restringida vs administración completa.

## Fuera de alcance explícito (MVP)

* Visitas recurrentes (`visit_recurrences`).
* Múltiples visitantes por visita vía `visit_participants`.
* `visitor_profiles` como identidad primaria.
* Portal self-service móvil para residentes.
* Integración física de control de acceso / `access_events`.
* Notificaciones push/email al residente.
* Gestión avanzada de vehículos asociados a visitas.
* Jobs automáticos de expiración.
* Flujos UI para `rejected` y `expired`.

Para el MVP se implementarán transiciones UI y servicios para:

* `pending`
* `authorized`
* `checked_in`
* `checked_out`
* `cancelled`

Los estados `rejected` y `expired` pueden existir en el enum/AASM como estados preparados, pero sus flujos UI y jobs automáticos quedan fuera de alcance.

## Business Rules

* Toda visita pertenece a exactamente una organización, propiedad y unidad.

* `residential_property_id` y `property_section_id` se derivan desde la unidad seleccionada y no deben poder quedar inconsistentes con `unit_id`.

* `property_section_id` puede ser nulo si la unidad no pertenece a una sección.

* El visitante es siempre un `Person` de la organización, creado o reutilizado en el flujo.

* El anfitrión (`host_person_id`) debe ser un `Person` con relación activa con la unidad vía `UnitOwnership` o `UnitOccupancy`.

* Un propietario no residente puede figurar como anfitrión, pero no autoriza visitas salvo que las reglas de dominio lo habiliten explícitamente, por ejemplo mediante una ocupación activa con `can_authorize_visits = true`.

* La autorización de visitas solo puede realizarla:

  * un residente/ocupante activo con `can_authorize_visits = true`;
  * un `property_admin` dentro de su propiedad asignada;
  * un `tenant_admin` dentro de su organización.

* `property_admin` y `concierge` solo existen vía `StaffAssignment` activo por propiedad.

* `tenant_admin` tiene acceso organization-wide dentro de su organización.

* Ningún rol accede a visitas de otra organización.

* La conserjería solo puede ver visitas de propiedades donde tenga `StaffAssignment` activo con capability `view_authorized_visits`.

* La vista de conserjería solo muestra visitas en estados operativos:

  * `authorized`;
  * `checked_in`;
  * `checked_out` recientes.

* La vista de conserjería no muestra visitas:

  * `pending`;
  * `cancelled`;
  * `rejected`;
  * `expired`.

* La conserjería puede registrar check-in solo cuando la visita está en estado `authorized`.

* La conserjería puede registrar check-out solo cuando la visita está en estado `checked_in`.

* La conserjería no puede crear, editar, autorizar ni cancelar visitas en el flujo MVP.

* `property_admin` gestiona visitas solo en propiedades asignadas.

* `tenant_admin` gestiona visitas de toda la organización.

* Los roles administrativos no registran ingreso/salida salvo que también tengan una capability operativa explícita para hacerlo.

* En el MVP, una visita creada por un usuario con `manage_visits` puede nacer en estado `authorized` si el usuario tiene permisos suficientes para autorizar dentro del alcance correspondiente.

* Si se implementa creación por residente/propietario sin autorización directa, la visita debe nacer en estado `pending` hasta que un actor autorizado la apruebe.

* Las transiciones válidas del MVP son:

  * `pending -> authorized`
  * `authorized -> checked_in`
  * `checked_in -> checked_out`
  * `pending -> cancelled`
  * `authorized -> cancelled`

* No se permite hacer check-in de una visita cancelada, vencida, pendiente o ya ingresada.

* No se permite hacer check-out de una visita que no esté ingresada.

* Cada transición funcional debe registrar:

  * actor autenticado;
  * fecha/hora;
  * estado anterior;
  * estado nuevo;
  * notas opcionales;
  * metadata operacional cuando aplique.

* El check-in puede registrar metadata operacional:

  * acceso/portería;
  * tipo de acceso;
  * patente o vehículo;
  * observaciones.

* El check-out puede registrar metadata operacional:

  * acceso/portería;
  * observaciones;
  * novedad/incidencia opcional.

* Todas las acciones de tabla y detalle deben exponerse mediante dropdown de acciones.

* No deben existir botones inline para acciones operativas o administrativas dentro de las tablas.

* Los serializers deben exponer acciones permitidas por visita según:

  * estado actual;
  * capability del usuario;
  * alcance de propiedad;
  * reglas de transición.

* El backend debe resolver el estado inicial de la visita y validar cualquier solicitud de autorización inmediata; el frontend no decide ni fuerza el estado final.

* El detalle de visita debe mostrar información completa para usuarios con `manage_visits`.

* El detalle de visita debe mostrar información restringida para usuarios con solo `view_authorized_visits`.

* `audited` se usará como auditoría técnica, pero el historial visible de estados debe provenir de un historial funcional explícito.
