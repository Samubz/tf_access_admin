# Concierge Visit Access Flow Design

## Context

El dominio existente ya ofrece:

* `Visit` con estados `authorized`, `checked_in`, `checked_out`, `cancelled` y estados post-MVP preparados como `expired`;
* timestamps y actores `User` para check-in/check-out;
* `VisitPolicy` con `check_in?`, `check_out?` y scope de conserjería;
* `Authorization::Resolver` con capabilities por propiedad;
* `StaffAssignment` activo como fuente exclusiva de `concierge`;
* historial funcional separado de la auditoría técnica;
* serializers restringidos para operación de acceso;
* visitas autorizadas provenientes tanto del flujo administrativo como de `residential-visit-management`.

Este change organiza esas piezas en una experiencia de portería centrada en velocidad, seguridad y mínima exposición de datos.

## Goals

* Permitir búsqueda rápida de visitas por documento, nombre o unidad.
* Mostrar visitas esperadas hoy y visitantes actualmente dentro.
* Registrar check-in/check-out con estado, timestamp, actor e historial coherentes.
* Bloquear transiciones inválidas, duplicadas o fuera del scope del conserje.
* Mantener trazabilidad suficiente para reportes futuros.
* Presentar únicamente información operacional mínima.

## Non-Goals

* Gestión administrativa de visitas.
* Creación, autorización, edición o cancelación por conserjería.
* Perfil completo de personas.
* Reportes avanzados.
* Notificaciones implementadas.
* Automatización completa del estado `expired`.
* Integración física de control de acceso.

## Portería main screen

La pantalla representa una propiedad operacional a la vez. Si un conserje tiene assignments activos en varias propiedades, debe seleccionar o ingresar explícitamente al contexto de una propiedad autorizada; la selección no combina datos de distintas propiedades.

La pantalla contiene:

* contexto visible de propiedad;
* buscador operacional;
* sección/lista **Esperadas hoy**;
* sección/lista **Actualmente dentro**;
* acceso a detalle mínimo;
* acción `Registrar ingreso` cuando backend entrega `check_in`;
* acción `Registrar salida` cuando backend entrega `check_out`.

Las acciones se basan en `permissions`/`actions` calculadas por backend. El frontend no habilita una acción solo por observar el valor de `status`.

## Search criteria

La búsqueda acepta criterios combinables o un término normalizado que cubra:

* documento del visitante;
* nombre completo o parcial del visitante;
* identificador o nombre visible de la unidad.

Orden de seguridad:

1. organización activa;
2. propiedad seleccionada y autorizada;
3. scope operacional de `VisitPolicy`;
4. filtros de búsqueda;
5. serialización mínima.

La búsqueda no puede utilizarse para descubrir visitantes, unidades o visitas de otras propiedades u organizaciones.

Para apoyar una decisión en portería, una búsqueda exacta o suficientemente específica puede devolver un resultado mínimo de visita `cancelled` o vencida dentro de la propiedad asignada, con una acción vacía y una explicación operacional. Esos registros no aparecen en las listas normales ni otorgan acceso al perfil de la persona.

## Operational lists

### Expected today

Incluye visitas:

* de la propiedad activa;
* con estado `authorized`;
* cuyo `scheduled_at` o ventana `[valid_from, valid_until]` intersecta el día local de la propiedad;
* si no existe `scheduled_at`, el criterio debe basarse en `valid_from`/`valid_until`;
* si no existe `valid_until`, la visita puede considerarse vigente según la regla de negocio definida por `visit-management`;
* cuya ventana aún permite el ingreso al momento de ejecutar la acción.

La lista puede mostrar una autorización que más tarde deja de ser válida, pero el backend debe revalidar la ventana temporal al confirmar check-in.

Orden recomendado:

1. hora programada ascendente;
2. visitante;
3. unidad.

### Currently inside

Incluye visitas:

* de la propiedad activa;
* con estado `checked_in`;
* con `checked_in_at` presente;
* sin `checked_out_at`.

Orden recomendado: ingreso más antiguo primero, para hacer visibles permanencias prolongadas.

Cada fila expone visitante, unidad, anfitrión, horario relevante, estado, duración actual calculada y acciones permitidas.

## Visible state rules

| Estado efectivo | Etiqueta operacional | Acción |
| --- | --- | --- |
| `authorized` y vigente | Autorizada | Registrar ingreso |
| `checked_in` | Dentro de la propiedad | Registrar salida |
| `cancelled` | Cancelada | Ninguna; ingreso denegado |
| `expired` | Expirada | Ninguna; solicitar nueva autorización |
| `authorized` con `valid_until` vencido | Expirada calculada | Ninguna; solicitar nueva autorización |
| cualquier otro estado | No operable | Ninguna |

`expired` permanece preparado/post-MVP. Para este flujo basta un criterio efectivo calculado desde `valid_until` cuando no exista transición persistida automática. La etiqueta calculada no debe mutar el estado por sí sola.

## Check-in design

Para MVP, la prevención mínima obligatoria es impedir doble check-in de la misma visita. Bloquear múltiples visitas activas del mismo visitante hacia la misma unidad queda como decisión de dominio separada, salvo que `visit-management` ya lo haya definido.

### Preconditions

* `User` autenticado.
* Organización activa.
* `StaffAssignment` de conserjería activo y vigente para la propiedad.
* Capability `register_visit_entry`.
* Visita en la misma organización y propiedad.
* Estado persistido `authorized`.
* Ventana temporal vigente.
* `checked_in_at` ausente y sin ingreso activo previo.

### Confirmation payload

El contrato puede aceptar:

* fecha/hora de ingreso, sujeta a reglas del servidor;
* acceso/portería;
* tipo de acceso;
* patente opcional;
* observaciones opcionales.

El servidor controla `checked_in_by_id`, estado final y timestamp efectivo permitido.

### Atomic result

Dentro de una transacción:

1. revalidar policy, propiedad, estado y ventana;
2. transicionar `authorized -> checked_in`;
3. persistir `checked_in_at`;
4. persistir `checked_in_by_id = current_user.id`;
5. guardar metadata operacional permitida;
6. registrar auditoría técnica;
7. registrar evento funcional `checked_in`.

La propia transición impide un segundo check-in desde `checked_in`. La implementación futura debe manejar concurrencia para que dos confirmaciones simultáneas no produzcan dos ingresos activos ni eventos duplicados.

### Optional notification contract

Después de un commit exitoso podría emitirse un evento de dominio como `visit.checked_in` con IDs tenant-safe para notificar al residente. La entrega, canal, job y contenido de la notificación quedan fuera de alcance.

## Check-out design

### Preconditions

* `User` autenticado.
* Organización activa.
* `StaffAssignment` de conserjería activo y vigente para la propiedad.
* Capability `register_visit_exit`.
* Visita en la misma organización y propiedad.
* Estado `checked_in`.
* `checked_in_at` presente.
* `checked_out_at` ausente.

### Confirmation payload

El contrato puede aceptar:

* acceso/portería;
* observaciones opcionales;
* metadata operacional permitida.

Campos como patente, tipo de acceso o incidencia quedan como extensiones futuras salvo que ya existan en `metadata`.

### Atomic result

Dentro de una transacción:

1. revalidar policy, propiedad y estado;
2. transicionar `checked_in -> checked_out`;
3. persistir `checked_out_at`;
4. persistir `checked_out_by_id = current_user.id`;
5. guardar metadata operacional permitida;
6. registrar auditoría técnica;
7. registrar evento funcional `checked_out`.

La salida no puede preceder al ingreso. Después del commit, la visita sale de “Actualmente dentro” y puede permanecer temporalmente en “Salidas recientes” conforme a `visit-management`.

## Authorization

La autorización usa contexto explícito de la propiedad de la visita:

```text
authenticated User
  -> Person in current organization
  -> active StaffAssignment for property P
  -> concierge capability map for P
  -> VisitPolicy scoped to Visit in P
  -> register_visit_entry / register_visit_exit
```

Reglas:

* `view_authorized_visits` controla búsqueda/listado operacional.
* `register_visit_entry` controla check-in.
* `register_visit_exit` controla check-out.
* Tener una capability no implica las otras.
* Un assignment en P no concede acceso a Q.
* Un assignment inactivo, futuro o vencido no concede capabilities.
* El rol `concierge` no se persiste globalmente en `User` o `Person`.
* `VisitPolicy` y el servicio revalidan la acción; ocultar botones no constituye autorización.

## Minimal data visibility

El serializer de conserjería puede exponer:

* id de visita;
* estado persistido y estado operacional efectivo;
* nombre del visitante;
* documento parcialmente protegido o completo solo cuando el contrato operacional autorizado lo requiera;
* unidad;
* nombre mínimo del anfitrión;
* `scheduled_at`, `valid_from`, `valid_until`;
* `authorized_at`;
* `checked_in_at`, `checked_out_at`;
* actor autorizador, de ingreso y de salida en formato resumido cuando sea necesario para trazabilidad;
* metadata operacional permitida;
* duración calculada;
* `permissions`/`actions`;
* timeline funcional mínimo.

No expone:

* perfil administrativo completo;
* relaciones de ownership/occupancy;
* roles o memberships;
* auditoría técnica completa;
* notas administrativas sensibles;
* datos de otras visitas o propiedades.

## Audit, functional history and reportability

`audited` conserva cambios técnicos en estado, timestamps, actores y metadata auditada. El timeline operacional usa `VisitStatusHistory` o el historial funcional equivalente.
* referencia al `User` autenticado que ejecutó la transición, usando la columna existente del historial funcional;

Cada transición exitosa registra:

* organización y visita;
* tipo de evento;
* estado anterior y nuevo;
* `actor_user_id`;
* momento;
* notas permitidas;
* metadata operacional permitida.

Los datos deben permitir responder posteriormente:

* quién entró;
* a qué unidad fue;
* quién autorizó;
* quién registró el ingreso;
* quién registró la salida;
* cuánto tiempo permaneció;
* qué visitas siguen dentro.

La duración no requiere una columna nueva: puede calcularse desde los timestamps mientras no exista una necesidad analítica distinta.

## Visual references

Los mockups son referencias visuales, no fuente de autorización:

mockups/checkin.png
mockups/checkout.png
mockups/visit-detail.png

Elementos reutilizables:

* resumen de visitante, unidad y anfitrión;
* badge de estado;
* formularios de acceso/portería y observaciones;
* confirmaciones explícitas;
* timeline mínimo;
* actores resumidos.

La nueva pantalla principal prioriza las listas “Esperadas hoy” y “Actualmente dentro”, aunque los mockups históricos muestren tabs más generales.

## Testing strategy

### Scope and search

* búsqueda por documento, nombre y unidad;
* normalización y coincidencias parciales controladas;
* exclusión cross-organization/cross-property;
* assignment activo versus inactivo;
* listas de hoy y actualmente dentro.

### Check-in

* transición válida;
* timestamp y actor `User`;
* metadata permitida;
* rechazo de `cancelled`, vencida, `checked_in`, `checked_out` y cualquier estado no autorizado;
* doble confirmación secuencial y concurrente;
* capability ausente.

### Check-out

* transición válida;
* timestamp y actor `User`;
* rechazo desde estado distinto de `checked_in`;
* salida duplicada;
* capability ausente;
* otra propiedad.

### Serialization and UI contract

* payload mínimo;
* acciones backend-driven;
* ausencia de perfil administrativo;
* estado vencido calculado;
* refresco de ambas listas después de transiciones.

### Audit and history

* evento y audit asociados a cada transición;
* actor, timestamps, from/to status y metadata;
* rollback atómico ante fallos.
