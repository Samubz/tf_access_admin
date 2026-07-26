# Concierge Visit Access Flow

## Why

`visit-management` ya define el ciclo de vida de una visita, las transiciones de check-in/check-out y el scope operativo básico de conserjería. El flujo privado de creación de visitas desde residentes agrega visitas autorizadas que deben quedar disponibles en ese mismo scope operativo.

Falta formalizar como capability independiente el flujo diario de portería: encontrar rápidamente una visita, distinguir las esperadas hoy de las personas actualmente dentro de la propiedad, registrar su ingreso y registrar su salida sin exponer información administrativa innecesaria.

Este change define la sección **4. Flujo de portería: ingreso y salida** sobre los contratos existentes. No reemplaza la gestión administrativa ni crea una nueva fuente de autorización.

## What Changes

* Definir una pantalla operativa de portería acotada a las propiedades donde el conserje tiene `StaffAssignment` activo.
* Incorporar búsqueda por:
  * documento del visitante;
  * nombre del visitante;
  * unidad.
* Separar dos listas principales:
  * visitas esperadas hoy;
  * visitas actualmente dentro de la propiedad.
* Exponer acciones backend-driven:
  * `authorized` y vigente: `Registrar ingreso`;
  * `checked_in`: `Registrar salida`;
  * `cancelled`: sin ingreso;
  * `expired`, o autorización vencida calculada desde `valid_until`: solicitar nueva autorización.
* Definir check-in para persistir `checked_in_at`, `checked_in_by_id`, transición a `checked_in`, auditoría técnica e historial funcional.
* Definir check-out para persistir `checked_out_at`, `checked_out_by_id`, transición a `checked_out`, auditoría técnica e historial funcional.
* Impedir doble check-in activo, transiciones inválidas y operaciones fuera de la propiedad asignada.
* Mantener `Authorization::Resolver`, `VisitPolicy` y las capabilities `view_authorized_visits`, `register_visit_entry` y `register_visit_exit` como fuentes de verdad.
* Usar serializers mínimos para conserjería, suficientes para búsqueda, confirmación, acciones y trazabilidad operacional.
* Mantener datos que permitan reportes futuros de entradas, salidas, permanencia y visitas aún dentro, sin implementar un módulo completo de reportes.

Los resultados `cancelled` o vencidos pueden mostrarse únicamente como respuesta mínima de búsqueda para explicar que el ingreso no está permitido. No forman parte de las listas operativas normales de visitas esperadas o actualmente dentro.

## Capabilities

### New Capabilities

* `concierge-visit-access-flow`: búsqueda operativa, listas de portería y registro de ingreso/salida con aislamiento por propiedad, permisos explícitos y exposición mínima de datos.

### Modified Capabilities

* `visit-management`: este change especializa la experiencia operativa de portería sobre visitas existentes, incluidas las creadas desde administración y desde residentes. No cambia el modelo de identidad, ciclo de vida MVP ni autorización base.
* `operational-roles-and-permissions`: reutiliza sin ampliar las capabilities existentes y conserva `concierge` como rol por propiedad derivado de `StaffAssignment`.

## Impact

**Bounded contexts:**

* Visits
* Authentication & Authorization
* Staff Assignments
* Persons
* Residential Properties and Units
* Auditing and functional history

**Contratos involucrados:**

* `Visit`: estados, timestamps, actores y ubicación.
* `VisitPolicy`: scope, `check_in?`, `check_out?` y detalle restringido.
* `Authorization::Resolver`: capabilities contextualizadas por organización y propiedad.
* `StaffAssignment`: fuente exclusiva del rol operacional de conserjería por propiedad.
* `Person`: identidad de visitante y anfitrión.
* `User`: actor autenticado de ingreso y salida.

**Implementación futura prevista:**

* scopes/queries de “esperadas hoy” y “actualmente dentro”;
* búsqueda operacional tenant-safe;
* endpoints y servicios de check-in/check-out;
* serializers/props mínimos;
* pantalla y confirmaciones basadas en mockups;
* tests de estados, autorización, aislamiento e historial.

La implementación de esos componentes será detallada en `tasks.md`; este proposal define el alcance funcional y las reglas de negocio.

## Business Rules

* El conserje opera únicamente dentro de la organización activa y de propiedades donde su `Person` tenga un `StaffAssignment` activo y vigente de conserjería.
* `property_admin` y `concierge` nunca son roles globales.
* Ver visitas operativas exige `view_authorized_visits` para la propiedad.
* Registrar ingreso exige `register_visit_entry` para la propiedad de la visita.
* Registrar salida exige `register_visit_exit` para la propiedad de la visita.
* Toda decisión se resuelve mediante `Authorization::Resolver` y `VisitPolicy`; la UI no infiere permisos por rol o estado.
* `Person` representa visitante y anfitrión.
* `User` representa al actor autenticado que ejecuta check-in/check-out.
* `checked_in_by_id` y `checked_out_by_id` apuntan a `User`, nunca a `Person`.
* Las búsquedas se restringen primero por organización y propiedades asignadas, y luego por documento, nombre o unidad.
* La aparición de una visita en resultados de búsqueda no implica autorización para ejecutar acciones; las acciones disponibles deben venir calculadas por backend según estado, ventana de validez y capabilities.
* Las visitas esperadas hoy son visitas `authorized`, programadas o válidas durante el día local de la propiedad y todavía habilitadas para ingreso.
* El cálculo de “hoy” debe usar la zona horaria operativa de la propiedad o, si no existe, la zona horaria de la organización.
* Las visitas actualmente dentro son visitas con estado `checked_in` y sin salida registrada.
* Solo una visita `authorized` y dentro de su ventana de validez puede transicionar a `checked_in`.
* Una visita `cancelled`, `expired` o temporalmente vencida no puede registrar ingreso.
* La condición de visita vencida puede calcularse operativamente desde `valid_until`; no requiere implementar un job ni una transición persistida a `expired` en este change.
* Una visita ya `checked_in` no puede registrar un segundo ingreso activo.
* Solo una visita `checked_in` puede transicionar a `checked_out`.
* Check-in y check-out deben ser transacciones atómicas que actualizan estado, timestamp, actor, auditoría e historial funcional.
* No se permite acceso cross-organization ni cross-property.
* El serializer de conserjería expone únicamente identidad mínima del visitante, unidad, anfitrión, horario/validez, estado, timestamps operativos, acciones permitidas y timeline mínimo.
* El sistema conserva datos suficientes para calcular duración como `checked_out_at - checked_in_at` o, para visitas aún dentro, desde `checked_in_at` hasta el momento de consulta.

## Out of Scope

* Crear o modificar roles globales.
* Exponer perfiles administrativos completos de visitante, anfitrión o actores.
* Permitir que conserjería cree, edite, autorice o cancele visitas.
* Implementar notificaciones al residente; solo se deja un punto de integración opcional posterior.
* Implementar reportes, dashboards históricos o exportaciones completas.
* Implementar jobs automáticos o una transición completa a `expired`.
* Cambiar el flujo administrativo de visitas.
* Cambiar el flujo privado de creación desde residentes.
* Integrar hardware, QR, biometría o dispositivos físicos de acceso.

## Open Questions

* ¿Se debe bloquear solo el doble check-in de la misma visita, o también múltiples visitas activas simultáneas del mismo visitante hacia la misma unidad?