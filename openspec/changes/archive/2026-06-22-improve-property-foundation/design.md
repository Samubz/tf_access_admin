# Improve Property Foundation Design

## Context

`ResidentialProperty` usa `acts_as_tenant :organization` y `acts_as_paranoid`. La tabla ya contiene nombre, código, tipo, dirección, país, timezone, estado, metadata y `deleted_at`.

El estado actual presenta estas brechas:

* `status` valida presencia, pero no inclusión.
* El frontend solo ofrece `active` e `inactive`.
* El nombre no tiene validación ni constraint de unicidad.
* El código sí tiene un índice único parcial por organización.
* create/update operan directamente sobre Active Record desde el controller.
* destroy invoca el modelo directamente.
* asociaciones principales usan `dependent: :destroy`, por lo que una eliminación puede propagar efectos destructivos.
* no existe un servicio de archivado ni un contrato que distinga inactividad, archivado, soft delete y hard delete.
* la policy actual separa `manage_properties` organizacional de `manage_property` por propiedad, pero el lifecycle nuevo requiere acciones explícitas.

El diagnóstico base se encuentra en `docs/sdd/residential-catalog-current-state.md`.

## Goals

* Establecer un contrato mínimo y consistente para propiedades.
* Definir unicidad y normalización de nombre dentro del tenant.
* Controlar valores y transiciones de estado.
* Reemplazar la eliminación destructiva como operación ordinaria por archivado.
* Separar creación, actualización y archivado en servicios de dominio.
* Mantener autorización capability-based y property-scoped.
* Definir una estrategia de validación por capas y cobertura de tests.

## Non-Goals

* Implementar los cambios.
* Refactorizar secciones o unidades.
* Diseñar un motor genérico de workflows.
* Añadir restauración, purga o retención avanzada.
* Rehacer toda la UI de propiedades.
* Cambiar `StaffAssignment` o introducir roles globales.

## ResidentialProperty model contract

### Required identity and tenancy

| Campo | Contrato |
| --- | --- |
| `organization_id` | obligatorio, FK válida y tenant inmutable durante el lifecycle |
| `name` | obligatorio, recortado, no vacío y único por organización |
| `property_type` | obligatorio y limitado a `PropertyTypes::ALL` |
| `status` | obligatorio y limitado al catálogo de estados |

### Location

La ubicación mínima usa los campos existentes:

* `address_line`;
* `city`;
* `region`;
* `country`;
* `timezone`.

`metadata` permanece disponible para datos de ubicación no estructurados o futuros, pero no reemplaza campos estructurados cuando estos existen.

Se requiere al menos una representación útil de ubicación. La decisión exacta entre exigir `address_line` o aceptar metadata estructurada se mantiene como pregunta abierta hasta revisar necesidades de propiedades rurales, condominios horizontales y complejos sin dirección postal convencional.

### Name uniqueness

El nombre se compara después de:

1. trim;
2. colapso de whitespace;
3. comparación case-insensitive;
4. scope por `organization_id`;
5. exclusión de registros soft-deleted.

La protección debe existir en modelo/servicio para errores amigables y en base de datos para concurrencia. El mismo nombre es válido en organizaciones distintas.

`code` continúa siendo opcional y único por organización cuando está presente. Nombre y código son reglas independientes.

## Status lifecycle

Estados:

| Estado | Significado |
| --- | --- |
| `active` | propiedad operacional que admite gestión normal |
| `inactive` | propiedad temporalmente suspendida, reversible |
| `archived` | propiedad retirada, conservada para historia y consulta |

Transiciones previstas:

| Desde | Hacia | Regla |
| --- | --- | --- |
| creación | `active` | default |
| `active` | `inactive` | usuario autorizado |
| `inactive` | `active` | usuario autorizado |
| `active` | `archived` | `Properties::Archive` |
| `inactive` | `archived` | `Properties::Archive` |

`archived` es terminal dentro de este change. Una restauración futura requiere un contrato separado.

Los servicios de secciones, unidades, imports, staff assignments y visitas deberán consultar el estado de la propiedad en cambios posteriores. Este change define la expectativa, pero no refactoriza todavía esos módulos.

## Creation update and archive design

### `Properties::Create`

Responsabilidades:

* recibir actor, organización y atributos permitidos;
* autorizar creación organizacional;
* asignar la organización desde contexto confiable;
* normalizar nombre, código y ubicación;
* validar contrato y unicidad;
* crear la propiedad atómicamente;
* devolver resultado estructurado y errores de dominio.

No acepta `organization_id` arbitrario desde el cliente.

### `Properties::Update`

Responsabilidades:

* recibir actor, propiedad y atributos;
* autorizar en contexto de la propiedad;
* impedir cambio de organización;
* normalizar y validar;
* aplicar cambios permitidos;
* separar cambios ordinarios de la transición a `archived`.

El update genérico no debe archivar mediante asignación directa de `status`.

### `Properties::Archive`

Responsabilidades:

* autorizar una acción organizacional explícita;
* bloquear nuevas mutaciones concurrentes cuando corresponda;
* cambiar el estado a `archived`;
* conservar secciones, unidades, personas relacionadas, assignments, visitas e historial;
* registrar actor, timestamp y auditoría/evento de dominio si la arquitectura vigente lo requiere;
* ser idempotente o devolver un resultado controlado si la propiedad ya está archivada.

### Controller boundary

El controller:

* autentica;
* carga mediante policy scope;
* permite parámetros;
* invoca el servicio;
* traduce el resultado a Inertia/HTTP.

No decide unicidad, normalización, transición de estado, dependencias ni estrategia delete/archive.

## Authorization design

La autorización pasa por Pundit y `Authorization::Resolver`.

| Acción | `tenant_admin` | `property_admin` asignado | Sin assignment/capability |
| --- | --- | --- | --- |
| index/show | organización propia | propiedades asignadas | denegado |
| create | organización propia | denegado | denegado |
| update | organización propia | propiedad asignada | denegado |
| activate/deactivate | organización propia | propiedad asignada si `manage_property` lo permite | denegado |
| archive | organización propia | denegado por defecto | denegado |
| hard delete/purge | no es operación pública ordinaria | denegado | denegado |

Reglas adicionales:

* `same_organization?` se aplica a acciones sobre registros.
* `ResidentialPropertyPolicy::Scope` limita resultados a tenant y property IDs accesibles.
* `property_admin` se deriva exclusivamente de `StaffAssignment` activo y vigente.
* `manage_property` no se reutiliza fuera de la propiedad que lo concedió.
* `manage_properties` es organizacional y no cruza tenants.
* el servicio vuelve a autorizar; ocultar UI no sustituye policy.

## Delete vs archive strategy

Hay cuatro conceptos distintos:

1. `inactive`: suspensión reversible.
2. `archived`: retiro operacional no destructivo.
3. soft delete: ocultamiento mediante `deleted_at`.
4. hard delete: eliminación física.

La operación soportada por producto en este change es `archive`.

Una propiedad con dependencias no puede soft-delete ni hard-delete mediante el flujo administrativo normal, porque las asociaciones actuales podrían producir cascadas. La implementación futura debe sustituir la acción destructiva visible por `archive` y evitar `dependent: :destroy` como mecanismo de lifecycle del catastro.

Si una propiedad nunca fue utilizada y no tiene dependencias, una eliminación administrativa excepcional puede evaluarse posteriormente. La purga física queda fuera de alcance.

Dependencias mínimas que bloquean eliminación:

* secciones;
* unidades;
* ownerships y occupancies indirectos;
* personas vinculadas indirectamente;
* staff assignments;
* visitas activas o futuras;
* settings, áreas comunes, reservas, incidentes, accesos, anuncios y otros datos operativos.

## Validation strategy

### Model

* presencia de organización, nombre, tipo y estado;
* inclusión de tipo y estado;
* unicidad amigable de nombre normalizado;
* unicidad de código activo;
* coherencia de ubicación y timezone;
* organización inmutable.

### Database

* `NOT NULL` y FK para organización;
* constraints/índices para estados permitidos;
* índice único tenant-scoped sobre nombre normalizado activo;
* conservación del índice único de código;
* estrategia compatible con soft delete.

### Services

* ownership del contexto tenant;
* normalización;
* lifecycle;
* autorización;
* dependencia delete/archive;
* manejo controlado de conflictos concurrentes.

### Controller

* strong params;
* carga por policy scope;
* mapeo consistente de errores.

### Frontend

* schema alineado con el catálogo backend;
* `archived` no se selecciona como un cambio ordinario en el formulario;
* acción separada y confirmada para archivar;
* errores server-side por campo;
* propiedad archivada mostrada en modo no operativo o de solo lectura según permisos.

El backend y la base de datos siguen siendo fuente de verdad.

## Testing strategy

### Model/database

* propiedad válida;
* organización y nombre obligatorios;
* tipo y estado válidos;
* nombre duplicado normalizado en la misma organización;
* mismo nombre en organizaciones distintas;
* conflicto concurrente de nombre;
* código duplicado;
* soft-deleted records y reutilización según política;
* defaults de estado, país y timezone.

### Services

* create/update/archive exitosos;
* organización derivada del contexto;
* organización inmutable;
* normalización;
* archivado idempotente;
* dependencias preservadas;
* rollback atómico.

### Policy/scopes

* tenant admin dentro de su organización;
* property admin con assignment activo;
* assignment inactivo/futuro/vencido;
* propiedad no asignada;
* usuario sin permisos;
* cross-organization;
* create/archive denegados a property admin.

### Requests/controllers

* controller delega a servicios;
* errores de validación consumibles por Inertia;
* ausencia de mutación al denegar;
* archivado usa acción explícita y no cascada destructiva.

### UI contract

* catálogo de estados;
* errores de nombre duplicado;
* acción de archive separada;
* vista de propiedad archivada;
* acciones ocultas según props calculadas en backend.

## Open Questions

1. ¿Debe existir una dirección estructurada obligatoria (`address_line`) o basta metadata de ubicación para tipos de propiedad sin dirección postal convencional?
2. ¿Se permite restaurar una propiedad `archived`? Este change la trata como terminal.
3. ¿Puede reutilizarse inmediatamente el nombre de una propiedad archivada dentro de la misma organización, o debe reservarse para evitar ambigüedad histórica?
4. ¿Existe un caso legítimo para eliminar una propiedad completamente vacía desde UI, o toda eliminación debe convertirse en archive?
5. ¿`property_admin` puede activar/desactivar la propiedad asignada o solo editar datos descriptivos? El diseño conserva `manage_property`, pero recomienda separar esas acciones en policy.
6. ¿Qué dependencias adicionales deben bloquear una eliminación excepcional además de las conocidas actualmente?

## Closure decisions (§8.7)

Decisiones tomadas durante la implementación frente a las Open Questions:

1. **Ubicación mínima** — *Diferida.* La validación mínima quedó en `country` + `timezone` (presencia + timezone válido). `address_line` permanece opcional y `metadata` sigue disponible. No se exige dirección postal estructurada; revisar con casos rurales/condominios en un change posterior.
2. **Restaurar `archived`** — *Resuelta: terminal.* No existe restauración; `archived` es estado final dentro de este change. Una restauración requerirá un contrato separado.
3. **Reutilización de nombre archivado** — *Resuelta: reservado.* El índice único es `WHERE deleted_at IS NULL` y `archived` **no** usa `deleted_at` (sigue presente). Por tanto una propiedad archivada conserva su slot de nombre normalizado y el nombre **no** es reutilizable mientras exista, evitando ambigüedad histórica.
4. **Eliminación desde UI** — *Resuelta: solo archive.* `destroy` ordinario fue reemplazado por la acción explícita `archive` (no destructiva). No se expone hard delete/purge en el flujo administrativo.
5. **`property_admin` activate/deactivate** — *Resuelta: unificada.* Quien tiene `manage_property` sobre la propiedad asignada puede actualizar datos descriptivos y transicionar `active`/`inactive` (vía `Properties::Update`). `create`/`archive` siguen siendo organizacionales (`manage_properties`) y se le deniegan. No se introdujo una capability separada para activate/deactivate.
6. **Dependencias adicionales para eliminación excepcional** — *Diferida.* Al no exponerse hard delete (todo es archive no destructivo), no se definió una lista de bloqueo de borrado físico; queda fuera de alcance hasta que exista (si existe) una eliminación excepcional.
