# Improve Units Foundation

## Why

`Unit` depende de una `ResidentialProperty` y puede ubicarse dentro de una
`PropertySection`, pero su contrato todavía no está completamente endurecido:

* la coherencia entre la propiedad de la unidad y la propiedad de la sección no
  está validada explícitamente;
* la unicidad de `normalized_identifier` depende principalmente de índices y
  necesita formalizar el contexto con y sin sección;
* la creación y actualización viven principalmente dentro del bulk import, sin
  servicios de dominio reutilizables;
* `UnitPolicy` debe evaluar `manage_units` en la propiedad concreta;
* archive, soft delete y restore no tienen límites de lifecycle claramente
  diferenciados;
* los catálogos actuales de tipos y estados no coinciden completamente con el
  catálogo objetivo;
* faltan pruebas directas de modelo, servicios, concurrencia y aislamiento.

Este change sigue a `improve-property-foundation` e
`improve-property-sections`. Consume sus decisiones: la propiedad se obtiene
desde contexto autorizado y una sección destino debe pertenecer a la misma
propiedad, estar efectivamente activa y ser elegible para contener unidades.

## What Changes

* Definir el contrato mínimo de `Unit`:
  * `organization_id`;
  * `residential_property_id`;
  * `property_section_id`;
  * `identifier`;
  * `normalized_identifier`;
  * `display_name`;
  * `unit_type`;
  * `status`;
  * `area_m2`;
  * `metadata`;
  * `deleted_at`.
* Exigir propiedad y organización coherentes e inmutables.
* Permitir una sección opcional, siempre de la misma organización y propiedad.
* Exigir que la sección destino esté efectivamente activa, acepte unidades y
  tenga un tipo elegible según el contrato `property-section`.
* Centralizar la normalización mediante `Units::NormalizeIdentifier`.
* Formalizar dos contextos de unicidad para unidades no soft-deleted:
  * con sección: organización + propiedad + sección + identificador normalizado;
  * sin sección: organización + propiedad + identificador normalizado dentro de un contexto raíz explícito.
  * Respaldar ambos contextos con constraints o índices parciales separados, evitando que `property_section_id = NULL` permita duplicados activos en la raíz de la propiedad.

* Permitir el mismo identificador en secciones diferentes de una misma
  propiedad.
* Impedir duplicados aunque la unidad existente esté `inactive`,
  `maintenance` o `archived`; archive no libera el identificador.
* Mantener soft delete como mecanismo técnico excepcional. Un registro
  soft-deleted deja de ocupar su contexto de unicidad, pero restore debe
  revalidarlo y rechazar conflictos.
* Definir el catálogo objetivo de tipos:
  `apartment`, `house`, `office`, `commercial_unit`, `parking_space`,
  `storage_room`, `common_area` y `other`.
* Definir estados:
  `available`, `occupied`, `inactive`, `maintenance` y `archived`.
* Definir servicios:
  * `Units::Create`;
  * `Units::Update`;
  * `Units::MoveToSection`;
  * `Units::Archive`;
  * `Units::Restore`;
  * `Units::NormalizeIdentifier`.
* Endurecer `UnitPolicy` y scopes para usar `view_units` y `manage_units` con
  contexto de propiedad, sin roles globales.
* Exigir que bulk import y futuros flujos interactivos consuman el mismo
  contrato de servicios, sin duplicar reglas.

## Impact

**Nueva capability de dominio:**

* `unit`: unidad tenant-safe, normalizada, buscable, relocatable y con lifecycle
  explícito dentro de una propiedad.

**Dependencias:**

* `residential-property`: la unidad pertenece a una propiedad y no puede
  trasladarse a otra mediante update o move.
* `property-section`: una sección opcional debe ser de la misma organización y
  propiedad, estar efectivamente activa y ser elegible para contener unidades
  según el contrato vigente de `property-section`.
* `operational-roles-and-permissions`: reutiliza `view_units`, `manage_units`,
  `Authorization::Resolver` y `StaffAssignment` activo por propiedad.
* `unit-owner-management`, `unit-occupancy-management` y
  `residential-visit-management`: conservan sus referencias a la unidad; archive
  o restore no debe borrar ownerships, occupancies ni visits.
* bulk import de unidades: deberá delegar create/update/normalización a los
  servicios canónicos.

**Implementación futura afectada:**

* modelo, concerns y constraints de `units`;
* migraciones, índices parciales y auditoría de datos previa;
* catálogos `UnitTypes` y `UnitStatuses`;
* servicios `Units::*`;
* `UnitPolicy`;
* bulk import;
* controllers/serializers que muten unidades;
* tests de modelo, servicios, policy, migración, request, concurrencia y bulk import.

Antes de aplicar constraints o cambiar catálogos, la implementación deberá
auditar identificadores duplicados, unidades sin sección, secciones
cross-property, tipos legacy, estados legacy y registros soft-deleted que
entrarían en conflicto al restaurarse.

La auditoría de datos deberá producir una estrategia explícita de resolución
antes de activar constraints más estrictos: normalización de identificadores,
mapeo de tipos legacy, mapeo de estados legacy, resolución de duplicados y
tratamiento de unidades soft-deleted en conflicto.

## Business Rules

* Toda unidad pertenece a exactamente una organización y una propiedad.
* La organización de la unidad coincide con la organización de su propiedad.
* Organización y propiedad se derivan desde contexto autorizado y son
  inmutables.
* `property_section_id` es opcional.
* Una sección asignada pertenece a la misma organización y propiedad.
* Una sección asignada está efectivamente activa: la sección y sus ancestros no
  están archivados, inactivos ni soft-deleted, según el contrato de
  `property-section`.
* Una sección asignada es elegible para contener unidades según el contrato de
  `property-section`.
* Ningún flujo de update, move, archive o restore puede cambiar la organización
  ni la propiedad de una unidad.
* `Units::MoveToSection` solo puede cambiar la sección dentro de la misma
  propiedad y organización.
* `identifier` es obligatorio y genera `normalized_identifier`.
* La comparación normalizada aplica trim, colapso/separación canónica de
  whitespace, Unicode y case folding de forma consistente.
* Un identificador no puede repetirse entre unidades no soft-deleted dentro del
  mismo contexto de sección.
* Las unidades sin sección comparten un contexto raíz explícito dentro de la
  propiedad; `NULL` no permite duplicados.
* El mismo identificador puede existir bajo secciones distintas.
* El mismo identificador puede existir en propiedades u organizaciones
  distintas.
* `inactive`, `maintenance` y `archived` continúan ocupando el contexto de
  unicidad mientras `deleted_at` sea nulo.
* Archive es un cambio de lifecycle operacional: usa `status = archived`, mantiene `deleted_at = NULL` y no libera el identificador.
* Soft delete es un mecanismo técnico excepcional: usa `deleted_at`, excluye la unidad de los contextos de unicidad activos y puede liberar el identificador.
* Restore de un registro soft-deleted debe revalidar organización, propiedad, sección, tipo, estado y unicidad antes de persistir.
* Restore falla de forma controlada si el contexto de unicidad fue reutilizado por otra unidad no soft-deleted.
* `area_m2`, cuando existe, es mayor que cero.
* `metadata` es extensible, pero no reemplaza propiedad, sección, tipo, estado ni
  identificador.
* `metadata` no puede usarse para almacenar datos necesarios para autorización,
  unicidad, lifecycle o relaciones estructurales.
* `tenant_admin` puede ver y gestionar unidades dentro de su organización.
* `property_admin` puede ver y gestionar unidades únicamente en propiedades con
  `StaffAssignment` activo y vigente que conceda `view_units` y `manage_units`.
* Actores operativos como `concierge` solo pueden ver unidades si un
  `StaffAssignment` activo por propiedad concede `view_units`; no pueden
  gestionarlas salvo que exista una capability explícita.
* `property_admin` no es un rol global.
* No existe acceso cross-organization ni cross-property.

## Out of Scope

* Implementar un CRUD Vue/Inertia completo de unidades más allá de los ajustes necesarios para consumir el contrato endurecido.
* Rediseñar completamente el bulk import o su interfaz; este change solo debe alinear sus reglas de dominio con los servicios canónicos.
* Crear un portal móvil o flujo para residentes.
* Implementar un CRUD Vue/Inertia completo de unidades.
* Rediseñar completamente el bulk import o su interfaz.
* Modificar ownerships, occupancies, leases o visits más allá de preservar sus
  referencias.
* Mover unidades entre propiedades u organizaciones.
* Implementar hard delete o purga física.
* Decidir arbitrariamente el mapeo de tipos legacy sin una auditoría de datos.
* Convertir `property_admin` o cualquier actor operativo en rol global.
