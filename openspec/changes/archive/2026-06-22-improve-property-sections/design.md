# Improve Property Sections Design

## Context

El modelo actual usa `organization_id`, `residential_property_id`, `parent_id`, `name`, `section_type`, `position`, `metadata` y soft delete. No tiene `normalized_name` ni `status`.

La jerarquía actual:

* solo admite raíz → hija;
* impide nietos mediante `parent_must_be_root_section`;
* impide que un contenedor tenga unidades;
* reparte reglas entre `PropertySection#parent_is_valid` y `PropertySectionHierarchy`;
* usa `dependent: :destroy` para hijos, unidades y visitas.

La UI refleja esa limitación: solo los nodos raíz ofrecen “agregar subsección”, el parent no puede cambiar durante edición y `root_parent_options` excluye nodos profundos. Existen dos controllers con update/destroy duplicados.

`PropertySection::TreeBuilder` ya construye un árbol recursivo, pero:

* confía en un scope preparado externamente;
* mezcla secciones y unidades;
* no incluye status, path, disabled ni permissions;
* limita parent options a raíces;
* no formaliza aislamiento como parte de su contrato.

`improve-property-foundation` establece que una propiedad archivada no acepta nuevas mutaciones de catastro. Este change aplica esa regla a secciones.

## Goals

* Unificar el contrato jerárquico en una fuente de verdad.
* Formalizar estructuras residenciales de máximo dos niveles: sección raíz y subsección.
* Garantizar tenancy, propiedad, aciclicidad y unicidad entre hermanos.
* Separar create/update/move/archive mediante servicios.
* Formalizar un TreeBuilder seguro y reutilizable.
* Sustituir delete destructivo por archive.
* Definir que solo secciones `block`, `tower` y `floor` son elegibles para contener unidades, dejando la validación concreta para el futuro change de `Unit`.

## Non-Goals

* Implementar el change.
* Mover secciones entre propiedades.
* Implementar todavía la validación en `Unit` para impedir asociación a secciones no elegibles.
* Refactorizar unidades o importaciones.
* Crear un framework genérico de árboles.
* Implementar restore o purge.

## PropertySection model contract

| Campo | Contrato |
| --- | --- |
| `organization_id` | obligatorio e igual a la organización de la propiedad |
| `residential_property_id` | obligatorio e inmutable |
| `parent_id` | opcional; mismo tenant y propiedad |
| `name` | obligatorio y normalizado |
| `normalized_name` | obligatorio, derivado y usado para unicidad |
| `section_type` | obligatorio y limitado al catálogo |
| `position` | entero para orden entre hermanos; si no se entrega, el sistema puede asignarlo |
| `status` | `active`, `inactive` o `archived` |
| `metadata` | JSON extensible, no fuente primaria de jerarquía |

### Name normalization

`normalized_name` se deriva mediante:

1. trim;
2. colapso de whitespace;
3. normalización Unicode acordada;
4. comparación case-insensitive.

La unicidad usa:

```text
organization_id
+ residential_property_id
+ parent context
+ normalized_name
+ non-deleted record
```

Para raíces, el contexto de parent debe tratar `NULL` como un único valor lógico. La protección existe tanto en modelo/servicio como en base de datos.

## Hierarchy rules

La jerarquía es un árbol/forest limitado a dos niveles dentro de una propiedad: secciones raíz y subsecciones.

Reglas:

* una sección raíz tiene `parent_id = null`;
* una subsección puede tener `parent_id`, pero su parent debe ser una sección raíz;
* no se permite crear una sección nieta;
* no se permite mover una sección bajo una subsección;
* todo parent existe y pertenece a la misma organización y propiedad;
* una sección no se parenta a sí misma;
* una sección no puede usar un descendiente como parent;
* mover una sección mantiene la misma `residential_property_id` y `organization_id`;
* el servicio valida la jerarquía dentro de una transacción y bloquea los registros necesarios para evitar movimientos concurrentes incompatibles;
* `position` se interpreta dentro del conjunto de hermanos;
* el path se deriva de ancestors, no se persiste como fuente de verdad;
* una propiedad archivada o un parent no efectivamente activo no acepta nuevos hijos ni movimientos entrantes.

La UI puede renderizar el árbol de forma recursiva por simplicidad técnica, pero el contrato de dominio mantiene máximo dos niveles.

## Section type strategy

Catálogo objetivo:

* `building`;
* `tower`;
* `floor`;
* `block`;
* `stage`;
* `sector`;
* `parking_area`;
* `storage_area`;
* `other`.

`section_type` describe la función estructural; no concede permisos.

Este change define que solo secciones con `section_type` `block`, `tower` o `floor` son elegibles para contener unidades.

Las secciones con `section_type` `building`, `stage`, `sector`, `parking_area`, `storage_area` u `other` no son elegibles para asociar unidades directamente.

La validación concreta en `Unit` queda para el futuro change de unidades, pero debe consumir esta regla de elegibilidad.

Valores actuales como `parking`, `storage`, `commercial`, `amenities`, `entrance` y `garden` necesitan auditoría y mapeo. No deben eliminarse sin estrategia de datos.

## Status lifecycle

| Estado | Significado |
| --- | --- |
| `active` | sección operable si toda la cadena ancestral está activa |
| `inactive` | suspensión reversible |
| `archived` | retiro no destructivo y terminal en este change |

Estado efectivo:

```text
section effectively active =
  property active
  AND section active
  AND every ancestor active
```

Una sección puede conservar `status = active` bajo un ancestor archivado, pero su estado efectivo es no operativo. Esto evita cascadas de actualización y conserva la intención histórica de cada nodo.

Transiciones:

* creación → `active`;
* `active` ↔ `inactive`;
* `active`/`inactive` → `archived`;
* restore queda fuera de alcance.

## Create update move archive design

### `PropertySections::Create`

* recibe actor, property, parent opcional y atributos;
* autoriza `manage_sections` en la property;
* exige property activa;
* deriva organización desde property;
* valida parent, nombre, tipo, posición y estado;
* crea atómicamente;
* no acepta property/organization arbitrarias del cliente.

### `PropertySections::Update`

* modifica datos descriptivos;
* no cambia property ni organization;
* no mueve parent;
* no archiva mediante asignación genérica de status;
* normaliza y valida unicidad.

### `PropertySections::Move`

* recibe sección, nuevo parent opcional y posición;
* autoriza sobre property origen;
* mantiene la misma property y organization;
* rechaza auto-parent, descendiente, parent no operativo y conflictos de nombre;
* recalcula/normaliza posiciones de siblings cuando corresponda;
* preserva el subárbol;
* registra auditoría del cambio de parent/path.

### `PropertySections::Archive`

* autoriza explícitamente;
* cambia status a `archived`;
* preserva descendientes, unidades, visitas y metadata;
* vuelve el subárbol efectivamente no operativo;
* no usa `destroy` ni `deleted_at` como representación de archive;
* es atómico e idempotente/controlado.

### Controller boundary

Los controllers cargan por policy scope, filtran parámetros, invocan servicios y traducen resultados. Debe existir un único canal canónico para mutaciones; el listado plano puede redirigir a la estructura, pero no duplicar lógica de update/archive.

## TreeBuilder design

`PropertySections::TreeBuilder` es un query/presenter de dominio read-only.

### Input

* organización actual;
* propiedad autorizada;
* actor o permission context;
* opciones explícitas para incluir unidades, archivadas o nodos deshabilitados.

No acepta una colección arbitraria sin verificar property/tenant scope.

### Construction

* carga únicamente secciones de la property;
* evita N+1 con preload de asociaciones solicitadas;
* agrupa por `parent_id`;
* detecta huérfanos/ciclos defensivamente y no recurre infinitamente;
* ordena siblings por `position`, `normalized_name` e id;
* incluye raíces y subsecciones, respetando el límite de dos niveles;
* calcula `depth` y path, con profundidad máxima esperada de raíz/subsección;
* marca estado persistido y efectivo.

### Node contract

```json
{
  "id": "uuid",
  "name": "Piso 1",
  "normalized_name": "piso 1",
  "section_type": "floor",
  "position": 1,
  "status": "active",
  "effective_status": "active",
  "parent_id": "uuid",
  "depth": 2,
  "path": ["Torre A", "Piso 1"],
  "selected": false,
  "disabled": false,
  "permissions": {
    "view": true,
    "edit": true,
    "move": true,
    "add_child": false,
    "archive": true
  },
  "children": []
}
```
`add_child` solo puede ser `true` para secciones raíz efectivamente activas cuando el actor tenga permiso y la propiedad permita mutaciones. Para subsecciones siempre debe ser `false`.
`selected` puede ser una proyección de presentación solicitada. `disabled` expresa elegibilidad para una operación concreta, no autorización general.

### Vue/Inertia boundary

La página de estructura compone:

* árbol presentacional, que puede implementarse recursivamente aunque el dominio limite la profundidad a dos niveles;
* formulario de create/update;
* diálogo/flujo de move;
* confirmación de archive.

El estado fuente proviene de props. La búsqueda/expansión/selección local puede vivir en un composable tipado. Las mutaciones se emiten hacia la página y vuelven a cargar props; el frontend no reconstruye reglas de ciclos, scope o permissions.

## Authorization design

Toda acción usa `Authorization::Resolver` y Pundit con contexto de property.

| Acción | tenant_admin | property_admin asignado | otro usuario |
| --- | --- | --- | --- |
| index/show/tree | propiedades de su organización | property asignada | denegado |
| create/update/move/archive | propiedades de su organización | property asignada con `manage_sections` | denegado |
| cross-property/cross-org | denegado | denegado | denegado |

Para create, la policy recibe un contexto que incluye la property destino; `authorize PropertySection` sin record/property no es suficiente.

`property_admin` se resuelve únicamente desde `StaffAssignment` activo y vigente. `manage_sections` nunca se reutiliza para otra property.

Una property archivada impide mutaciones ordinarias aunque el actor tenga capability.

## Delete vs archive strategy

Se distinguen:

* `inactive`: pausa reversible;
* `archived`: retiro no destructivo;
* soft delete: mecanismo técnico excepcional;
* hard delete: purga fuera de alcance.

Una sección con children, units, visits u otras dependencias no puede eliminarse física ni lógicamente mediante el flujo normal. Archive conserva el subárbol y las referencias.

La implementación futura debe reemplazar acciones de delete en la UI por archive y revisar `dependent: :destroy`.

## Validation strategy

### Model

* presencias e inclusiones;
* normalización;
* misma organización/property;
* auto-parent, ciclos y límite máximo de dos niveles;
* unicidad entre siblings;
* position positiva;
* organization/property inmutables.

### Database

* FKs y `NOT NULL`;
* constraints de tipo/status;
* `normalized_name`;
* índice único con parent context, incluido root;
* índices de traversal por property/parent/position;
* protección compatible con soft delete.

### Services

* property activa;
* autorización contextual;
* movimiento seguro;
* archivado;
* concurrencia;
* resultados/errores estructurados.

### Controller

* carga tenant-safe;
* strong params;
* delegación;
* contrato de errores Inertia.

### Frontend

* schemas alineados con catálogos backend;
* no permite elegir property/org;
* parent options entregadas por backend;
* acciones backend-driven;
* soporte visual para raíz y subsección, sin permitir crear un tercer nivel;
* errores server-side por campo.

## Testing strategy

### Model/database

* raíz y subsección;
* organización/property obligatorias y coherentes;
* auto-parent, ciclos y parent cross-property/org;
* normalización y unicidad entre siblings, incluidas raíces;
* mismo nombre bajo otro parent;
* tipos/status;
* position y orden;
* conflictos concurrentes.

### Services

* create/update/move/archive;
* movimientos root↔child y entre ramas;
* preservación de subárbol;
* rechazo de descendant parent;
* parent/property no operativos;
* archive con children/units;
* rollback.

### TreeBuilder

* múltiples raíces y subsecciones;
* orden estable;
* scope tenant/property;
* path/depth/effective status;
* permissions;
* huérfanos/ciclos defensivos;
* no expone ni permite tercer nivel;
* inclusión opcional de units sin N+1.

### Authorization

* tenant admin;
* property admin asignado;
* assignment inactivo/futuro/vencido;
* cross-property;
* cross-organization;
* usuario sin capability.

### Requests/UI contract

* controllers delegan a servicios;
* único canal de mutación;
* props y errores;
* tree actions backend-driven;
* archived/inactive disabled;
* búsqueda y selección en árbol de máximo dos niveles.

## Open Questions

1. Resuelto: la jerarquía admite máximo dos niveles: raíz y subsección.
2. ¿Qué mapeo se aplicará a tipos legacy `commercial`, `amenities`, `entrance` y `garden`?
3. Resuelto parcialmente: `section_type` sigue siendo descriptivo para jerarquía, pero solo `block`, `tower` y `floor` son elegibles para contener unidades.
4. ¿Puede reactivarse/restaurarse una sección archivada?
5. ¿Archivar un parent debe requerir confirmación especial por afectar el estado efectivo de todo el subárbol?
6. ¿Las posiciones deben ser densas y únicas entre siblings o basta orden estable con empates?
7. Resuelto: `PropertySections::TreeBuilder` incluye units mediante la opción explícita `include_units:` (read-only, con eager loading), sin un builder separado.

## Closing decisions and Unit-change dependencies

Decisiones resueltas durante la implementación (referencia para el futuro change de `Unit`):

- **Jerarquía de dos niveles** — raíz y subsección; sin nietos. Centralizada en `PropertySectionHierarchy` (única fuente de verdad para parent, ciclos, dos niveles y estado efectivo).
- **Elegibilidad de unidades** — solo `block`, `tower` y `floor` son elegibles para contener unidades. Expuesto en `SectionTypes::UNIT_ELIGIBLE` y `SectionTypes.eligible_for_units?` / `PropertySection#eligible_for_units?`. **El change de `Unit` DEBE consumir esta regla** para validar la asociación, en lugar de reimplementar la lista.
- **Estado efectivo** — `PropertySection#effective_status` (más restrictivo entre property + ancestros + sección). Una unidad asociada a una sección no efectivamente activa debe tratarse como no operativa; el change de `Unit` debe derivar operatividad desde `effective_status`, no solo desde `status`.
- **Lifecycle no destructivo** — archive (`status = archived`) preserva subárbol, units y visits; no hay hard delete por el flujo normal. El change de `Unit` no debe asumir borrado en cascada de secciones.
- **Autorización con property context** — `manage_sections` se evalúa por property (`PropertySectionPolicy`); el change de `Unit` debe seguir el mismo patrón de capability por property, sin roles globales.
- **Tipos legacy** (Open Q #2) y **restore de secciones archivadas** (Open Q #4) siguen abiertos y quedan fuera del alcance del change de `Unit` salvo decisión explícita.
