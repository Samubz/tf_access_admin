# Improve Units Foundation Design

## Context

`Unit` ya contiene la mayoría de los campos objetivo y usa
`acts_as_tenant`, `acts_as_paranoid` y auditoría. Actualmente:

* pertenece obligatoriamente a `ResidentialProperty`;
* puede pertenecer a `PropertySection`;
* normaliza `identifier` mediante
  `AlphanumericHyphenCodeValidatable.normalize_identifier`;
* valida same-tenant, pero no expresa directamente que la sección debe ser de la
  misma propiedad;
* depende de índices parciales para unicidad;
* se crea y actualiza principalmente desde `BulkImportServices::ImportUnitsRow`;
* no tiene servicios canónicos de create/update/move/archive/restore;
* `UnitPolicy#create?` y `update?` no expresan por sí solos el contexto de
  propiedad destino;
* mezcla lifecycle de negocio (`status`) con capacidad técnica de soft delete
  sin un contrato explícito.

El change `improve-property-sections` define el contrato de elegibilidad de
secciones para contener unidades: una sección destino debe pertenecer a la misma
organización y propiedad, estar efectivamente activa y cumplir la regla
`can_contain_units?` o equivalente definida por `property-section`.

En la configuración actual, esa elegibilidad corresponde a los tipos `block`,
`tower` y `floor`, pero `Unit` debe consumir el contrato de elegibilidad y no
duplicar la regla de tipos.

## Goals

* Garantizar integridad tenant/property/section.
* Formalizar unicidad tanto con sección como sin sección.
* Centralizar normalización y mutaciones en servicios reutilizables.
* Separar update descriptivo, movimiento, archive y restore.
* Proteger concurrencia y convertir conflictos DB en errores de dominio.
* Mantener unidades buscables por identificador y nombre.
* Endurecer autorización por propiedad.
* Permitir que bulk import y futuros flujos interactivos compartan reglas.

## Non-Goals

* Crear un CRUD Vue/Inertia completo de unidades más allá de los ajustes
  necesarios para consumir los servicios canónicos.
* Rediseñar ownerships, occupancies, leases o visits.
* Permitir movimientos entre propiedades u organizaciones.
* Implementar hard delete o purga física.
* Resolver sin auditoría el mapeo final de tipos legacy.
* Rediseñar completamente la interfaz del bulk import; este change solo alinea
  su lógica de dominio con el contrato canónico de unidades.

## Unit model contract

| Campo | Contrato |
| --- | --- |
| `organization_id` | obligatorio, derivado desde property e inmutable |
| `residential_property_id` | obligatorio e inmutable |
| `property_section_id` | opcional; misma organización y property |
| `identifier` | obligatorio; valor visible saneado para presentación y edición |
| `normalized_identifier` | obligatorio, derivado desde `identifier` y usado para búsqueda/unicidad |
| `display_name` | opcional; nombre descriptivo de la unidad |
| `unit_type` | obligatorio y limitado al catálogoobligatorio; limitado al catálogo canónico para nuevas escrituras, con tolerancia transitoria para valores legacy auditados |
| `status` | obligatorio; default `available`; limitado al catálogo vigente  |
| `area_m2` | opcional; decimal positivo |
| `metadata` | JSON extensible, no fuente primaria de relaciones |
| `deleted_at` | soft delete técnico; no representa archive |

`organization_id` y `residential_property_id` no son atributos movibles. El
único cambio estructural permitido es `property_section_id`, mediante
`Units::MoveToSection`, incluyendo el movimiento al contexto sin sección.

## Identifier normalization

`Units::NormalizeIdentifier` es la fuente canónica para modelo, servicios,
bulk import, búsquedas y backfills.

La normalización debe:

1. rechazar `nil`, vacío o whitespace-only;
2. aplicar trim;
3. normalizar Unicode de forma acordada;
4. colapsar o transformar separadores/whitespace de manera determinista;
5. aplicar case folding;
6. producir el mismo resultado en todos los canales de escritura y búsqueda.

El valor visible `identifier` puede conservar una presentación legible y saneada,
pero `normalized_identifier` nunca se acepta como fuente confiable desde el
cliente. Cualquier `normalized_identifier` recibido por params, planilla o API
debe ser ignorado y recalculado por `Units::NormalizeIdentifier`.

Ejemplo conceptual:

```text
"  Torre A 101 "
→ identifier: "Torre A 101"
→ normalized_identifier: "torre-a-101"
```
Este ejemplo no obliga a que todos los separadores visibles se reemplacen por
guiones en `identifier`; esa transformación aplica al valor canónico. La
implementación debe mantener estable la diferencia entre presentación visible y
clave normalizada.

La implementación debe definir una estrategia segura para backfill Unicode. Si
PostgreSQL no garantiza la misma normalización que Ruby, el backfill se realiza
por lotes con la función canónica antes de añadir `NOT NULL` o índices.

## Uniqueness contexts

La unicidad se aplica a registros con `deleted_at IS NULL`, con protección de
modelo/servicio y base de datos.

### Unit assigned to section

```text
organization_id
+ residential_property_id
+ property_section_id
+ normalized_identifier
```

### Unit without section

```text
organization_id
+ residential_property_id
+ normalized_identifier
+ property_section_id IS NULL
```

Se requieren índices parciales separados o una estrategia equivalente porque
PostgreSQL no considera dos `NULL` iguales en un índice único convencional.

Consecuencias:

* `Piso 1 / 101` y `Piso 2 / 101` pueden coexistir;
* dos unidades `101` sin sección en la misma propiedad no pueden coexistir;
* mover una unidad revalida la unicidad en el contexto destino;
* archive no libera el identificador;
* soft delete sí puede liberarlo;
* restore falla si otra unidad no eliminada ocupa el contexto.

Los conflictos concurrentes de create, move o restore se convierten desde
`ActiveRecord::RecordNotUnique` en errores de dominio sobre `identifier`.

## Property and section coherence

Una unidad puede no tener sección. Cuando tiene sección:

* la sección existe;
* pertenece a la misma organización;
* pertenece a la misma `ResidentialProperty`;
* no está soft-deleted;
* está efectivamente activa según el contrato de `property-section`;
* es elegible para contener unidades según el contrato de `property-section`.

`Unit` no debe duplicar la lógica interna que determina si una sección acepta
unidades. Debe consultar un método/servicio del dominio de secciones, por ejemplo
`PropertySection#can_contain_units?`, `PropertySections::Eligibility` o el
contrato equivalente definido por `improve-property-sections`.

La sección se carga dentro del scope de la propiedad autorizada. Un ID
inexistente o cross-property produce un error de `property_section_id`; nunca se
interpreta como “sin sección”.

Una unidad sin sección sigue perteneciendo a la propiedad y participa en el
contexto raíz de unicidad.

## Unit type strategy

Catálogo objetivo:

* `apartment`;
* `house`;
* `office`;
* `commercial_unit`;
* `parking_space`;
* `storage_room`;
* `common_area`;
* `other`.

Los valores actuales `studio`, `duplex`, `penthouse`, `parking`, `storage`,
`commercial` y `warehouse` requieren auditoría y una tabla de mapeo aprobada.

Durante transición:

* nuevas unidades solo usan tipos canónicos;
* registros legacy no se renombran silenciosamente;
* una actualización no relacionada no debe quedar bloqueada únicamente por un
  tipo legacy tolerado transitoriamente;
* si una actualización modifica `unit_type`, el nuevo valor debe pertenecer al
  catálogo canónico;
* el constraint final se estrecha después de completar el mapeo.

## Status lifecycle

| Estado | Significado |
| --- | --- |
| `available` | unidad disponible, sin ocupación operativa asumida por este change |
| `occupied` | unidad ocupada según reglas externas de occupancy |
| `inactive` | unidad temporalmente no operativa |
| `maintenance` | unidad fuera de operación por mantenimiento |
| `archived` | retiro de negocio no destructivo |

Este change no recalcula automáticamente `occupied` desde occupancies; esa
sincronización requiere una decisión separada para evitar dos fuentes de verdad.
Mientras no exista esa integración, `occupied` se trata como un estado
administrativo explícito y no como una proyección automática de
`UnitOccupancy`.

### Archive

`Units::Archive`:

* autoriza `manage_units` en la propiedad;
* cambia `status` a `archived`;
* no asigna `deleted_at`;
* conserva ownerships, occupancies, leases, residents y visits;
* no libera el contexto de unicidad;
* es atómico e idempotente.

### Soft delete and restore

Soft delete queda reservado para operaciones técnicas o de administración
excepcional y no es el lifecycle ordinario.

`Units::Restore`:

* recibe explícitamente una unidad soft-deleted;
* autoriza sobre su propiedad original;
* revalida tenant, property, section y unicidad;
* valida `unit_type` y `status` según la estrategia vigente de transición
  legacy/canónica;
* rechaza restore si el identificador fue reutilizado;
* restaura `deleted_at` sin cambiar implícitamente `status`;
* si el registro tenía `status = archived`, continúa archivado después del
  restore;
* preserva historial y relaciones.

La reactivación de una unidad archivada a otro estado no forma parte de
`Restore`; sería una transición de status explícita.

### Relationship preservation semantics

Tanto archive como soft delete preservan todas las relaciones de dominio:
ownerships, occupancies, leases, authorized residents y visits. A nivel de
modelo Rails, esto se implementa **sin cascadas destructivas** (`dependent:
:destroy` / `dependent: :delete_all`). Las asociaciones no tienen `dependent:`
callback, permitiendo que `Unit#destroy` (a través de `acts_as_paranoid`) solo
marque `deleted_at` sin tocar registros relacionados.

La ausencia de cascada es intencional:

* Soft delete y archive son operaciones de lifecycle administrativo, no
  remoción de datos transaccionales.
* Las relaciones pueden pertenecer a múltiples contextos o tener su propio
  lifecycle (e.g., `UnitOccupancy` puede existir sin unidad).
* Preservar relaciones permite reconstrucción, auditoría y recuperación.
* Direct `Unit#destroy` (fuera del servicio técnico) falla con un `abort` en el
  callback `ensure_soft_delete_authorized`, protegiendo la integridad.

Tests verifican explícitamente que soft delete, archive y restore no destruyen
ni soft-deletean ownerships, occupancies, leases, authorized residents o visits.

## Domain services

### `Units::NormalizeIdentifier`

* recibe un identificador;
* devuelve resultado visible/canónico o error;
* no consulta la base de datos;
* es reutilizable por modelo, servicios, búsqueda y bulk import.

### `Units::Create`

* recibe actor, property, section opcional y atributos;
* autoriza `manage_units` en la property;
* exige property operable;
* deriva organization desde property;
* resuelve la sección dentro de property;
* usa `available` como status inicial por defecto;
* permite status inicial distinto solo en flujos explícitamente autorizados
  como import/backfill, validándolo contra el catálogo permitido;
* normaliza y valida;
* crea atómicamente;
* traduce conflictos de unicidad.

### `Units::Update`

* actualiza `identifier`, `display_name`, `unit_type`, `status`, `area_m2` y
  `metadata`;
* permite cambios de `status` solo entre `available`, `occupied`, `inactive` y
  `maintenance`;
* no permite archive mediante update genérico;
* no cambia organization, property ni section;
* no restaura soft deletes;
* revalida normalización y unicidad.

### `Units::MoveToSection`

* recibe unidad y sección destino opcional;
* mantiene organization y property;
* carga la sección dentro de la misma property;
* permite mover al contexto sin sección;
* valida elegibilidad/operatividad;
* revalida unicidad destino;
* ejecuta el cambio dentro de una transacción;
* usa locks cuando sean necesarios para preservar consistencia de lectura;
* depende de constraints únicos en DB como última línea de defensa ante
  concurrencia;
* preserva ownerships, occupancies y visits.

### `Units::Archive`

Aplica el lifecycle descrito arriba; no llama `destroy`.

### `Units::Restore`

Aplica el restore técnico descrito arriba y maneja conflictos de reutilización
del identificador.

## Authorization design

Todas las mutaciones usan `Authorization::Resolver` y `UnitPolicy` con contexto
de la propiedad concreta.

| Acción | tenant_admin | property_admin asignado | concierge asignado | residente/otro |
| --- | --- | --- | --- | --- |
| index/show administrativo | propiedades de su organización con `view_units` | propiedad asignada con `view_units` | propiedad asignada con `view_units`, si la capability existe | denegado salvo scope mínimo explícito |
| create/update/move/archive/restore | propiedades de su organización con `manage_units` | propiedad asignada con `manage_units` | denegado salvo capability explícita futura | denegado |
| cross-property/cross-org | denegado | denegado | denegado | denegado |

`property_admin` se deriva exclusivamente de un `StaffAssignment` activo y
vigente. `manage_units` no concede acceso a otras propiedades.

Para create, la policy recibe la property destino; autorizar `Unit` sin contexto
no es suficiente. Para move, la autorización se evalúa sobre la propiedad actual
de la unidad y la sección destino se resuelve dentro de esa misma propiedad. Para
restore, se carga el registro con un scope explícito que incluye soft-deleted sin
relajar el tenant/property scope.

## Search and read model

Las unidades deben poder buscarse dentro de un scope autorizado por:

* `identifier`;
* `normalized_identifier`;
* `display_name`;
* property;
* section;
* type;
* status.

Las búsquedas normalizan el término con `Units::NormalizeIdentifier` cuando
corresponde. Los índices deben soportar lookup por property/section/status y
unicidad, evitando búsquedas globales sin tenant.

## Bulk import boundary

El bulk import conserva validación de planilla, preview, modos de importación y
reportes. No obstante:

* no crea ni actualiza `Unit` directamente mediante lógica propia;
* delega normalización y creación a `Units::Create`;
* delega actualización a `Units::Update` solo en modos de importación que
  explícitamente permitan actualizar unidades existentes;
* usa `Units::MoveToSection` solo cuando el modo de importación permita cambiar
  placement;
* conserva errores por fila;
* nunca confía en organization/property/section de la planilla sin resolverlos
  desde el contexto autorizado.

La migración completa del bulk import puede hacerse incrementalmente, pero no
debe quedar una segunda definición divergente de normalización o unicidad.

## Database strategy

La implementación debe:

1. auditar duplicados con sección;
2. auditar duplicados sin sección;
3. auditar `normalized_identifier` vacío o inconsistente;
4. auditar secciones cross-property/cross-organization;
5. auditar tipos/status legacy;
6. auditar restores que entrarían en conflicto;
7. resolver o bloquear explícitamente datos incompatibles;
8. ejecutar backfill por lotes;
9. añadir `NOT NULL`, checks e índices solo después de la auditoría.

Constraints esperados:

* FKs de organization, property y section;
* validación de dominio y, si se decide reforzar en DB, constraint o FK compuesta
  para que `units.organization_id` coincida con la organización de
  `residential_property`;
* `NOT NULL` para organization, property, identifier,
  normalized_identifier, unit_type, status y metadata;
* checks de tipo/status después de completar auditoría, backfill y transición de
  valores legacy;
* check `area_m2 > 0` cuando no sea null;
* índice único parcial para unidades con sección;
* índice único parcial para unidades sin sección;
* índices property/section/status y búsqueda normalizada.

La coherencia section→property no puede garantizarse con una FK simple a
`property_section_id`; requiere validación de dominio y, si se decide reforzar
en DB, una estrategia de clave compuesta cuidadosamente migrada.

## Error contract

Los servicios exponen un contrato de resultado consistente con las convenciones existentes de la aplicación. El patrón concreto puede ser objeto resultado o excepción controlada, pero debe representar semánticamente:

* `success`, con la unidad persistida;
* `noop`, cuando la operación idempotente no requiere cambios;
* `invalid`, con errores por campo/base;
* `unauthorized`, propagado mediante Pundit;
* `conflict`, convertido desde constraints de DB a error de dominio.


Errores esperados:

* `identifier` blank/invalid/taken;
* `property_section_id` invalid/cross-property/not-operative/not-eligible;
* `property_section_id` cannot-change-property;
* `residential_property_id` immutable;
* `organization_id` immutable;
* `unit_type` invalid;
* `status` invalid/transition-not-allowed;
* `area_m2` invalid;
* restore conflict.

## Testing strategy

### Model/database

* propiedad/organización obligatorias y coherentes;
* section opcional y same-property;
* normalización Unicode;
* unicidad con y sin section;
* mismo identifier en otra section/property/org;
* tipos/status y área;
* soft delete y restore conflict;
* constraints y concurrencia;
* archive no libera unicidad;
* soft delete libera unicidad solo si `deleted_at` deja el registro fuera de los
  índices parciales;
* restore conserva status existente.

### Services

* create/update/move/archive/restore;
* section inexistente/cross-property/cross-org;
* move a nil y a section válida;
* move con conflicto;
* archive idempotente;
* restore válido y restore conflictivo;
* rollback y traducción de `RecordNotUnique`;
* update no permite cambiar property, organization ni section;
* update no permite archivar mediante update genérico;
* create ignora `organization_id`, `residential_property_id` y
  `normalized_identifier` enviados por cliente;
* move preserva ownerships, occupancies y visits.

### Policy/requests

* tenant admin con `view_units` y `manage_units`;
* property admin con assignment activo/vigente y capabilities correctas;
* property admin con `view_units` pero sin `manage_units`;
* concierge asignado con `view_units`, si aplica;
* assignment inactivo/futuro/vencido;
* usuario sin `manage_units`;
* cross-property y cross-organization;
* cliente no puede asignar organization/property arbitrarias.

### Bulk import

* usa normalización canónica;
* respeta section/property;
* convierte duplicados en errores por fila;
* no crea una unidad mediante un bypass de los servicios.

## Open questions

1. ¿Cuál es el mapeo aprobado para tipos legacy (`studio`, `duplex`,
   `penthouse`, `parking`, `storage`, `commercial`, `warehouse`)?
2. ¿Debe `status = occupied` derivarse automáticamente de occupancies activas o
   mantenerse como estado administrativo?
3. ¿Qué operación privilegiada, fuera del flujo ordinario, puede ejecutar soft
   delete?
4. ¿La búsqueda parcial de identificadores requiere trigram index desde este
   change o basta búsqueda exacta/prefix tenant-scoped?
5. ¿Cuál será el mecanismo canónico para consultar si una `PropertySection`
   puede contener unidades: método de modelo, servicio de dominio o flag
   persistido?

## Closure decisions (§9.6–§9.8)

Decisiones tomadas durante la implementación frente a las Open Questions y el
cierre del change:

1. **Tipos legacy** (`studio`, `duplex`, `penthouse`, etc.) — *Resuelta:
   tolerancia transitoria + catálogo canónico en escrituras.* Los registros
   legacy persistidos no bloquean updates no relacionados. Toda escritura que
   modifique `unit_type` exige un valor de `UnitTypes::CANONICAL`. No se
   remapean silenciosamente; auditoría/backfill de legacy queda fuera de este
   change.
2. **`status = occupied`** — *Resuelta: administrativo, sin inferencia.* Permanece
   en el catálogo y puede asignarse explícitamente vía `Units::Update` o import
   autorizado, pero este change no deriva `status` automáticamente desde
   occupancies u ownerships activas.
3. **Soft delete privilegiado** — *Resuelta: canal técnico único.*
   `Units::SoftDelete` es el único camino de producción; `Unit#destroy` directo
   queda bloqueado (`destroy_requires_service`). Restore vía `Units::Restore`;
   archive vía `Units::Archive` (no usa `deleted_at`).
4. **Búsqueda parcial / trigram** — *Resuelta: sin trigram en este change.*
   `Units::Search` combina `Units::NormalizeIdentifier`, match exacto en
   `normalized_identifier` e `ILIKE` en identifier/display_name dentro del scope
   autorizado. El índice lookup tenant/property cubre el caso principal.
5. **Elegibilidad de sección para unidades** — *Resuelta: delegación a
   property-section.* `Unit` valida mediante `PropertySection#can_contain_units?`
   y reglas de estado efectivo; no duplica la lista de tipos elegibles.

### Verificación manual de UI (§9.5)

* **Búsqueda:** APIs JSON en el canal anidado de property (`units#index`),
  catálogo org-wide (`admin/units#index`) y `visits#form_units` delegan a
  `Units::Search` con input normalizado y scope de policy.
* **Unicidad:** mutaciones canónicas redirigen con errores Inertia por campo;
  bulk import reporta duplicados/errores por fila en preview e import.
* **Alcance UI:** no hay página Vue dedicada de catálogo/búsqueda org-wide de
  unidades; la estructura de property sigue usando el árbol de secciones.

### Alineación proposal / design / spec / tasks (§9.7)

* Contrato de `Unit`, servicios `Units::*`, policy property-scoped, controllers
  canónicos, bulk import alineado y suite de tests §8 completada.
* Delta spec `specs/unit/spec.md` coherente con las decisiones anteriores.
* Tasks 1–8 marcados `[x]` antes del cierre §9.
