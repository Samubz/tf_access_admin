# Estado actual del flujo de catastro residencial

> Documento diagnóstico (Etapa 0 — "Levantar estado actual antes de proponer cambios").
> No introduce cambios de código. Sirve como base para un futuro change OpenSpec/SDD de
> refactorización del flujo de creación de propiedades, secciones y unidades.
> Fecha: 2026-06-21.

## 1. Resumen ejecutivo

El catastro residencial se compone de tres entidades jerárquicas: `ResidentialProperty` →
`PropertySection` → `Unit`. Todas son `acts_as_tenant :organization` y `acts_as_paranoid`
(soft delete vía `deleted_at`).

- **Propiedades**: se crean/editan con un CRUD Inertia clásico
  (`Admin::ResidentialPropertiesController`) que opera **directamente sobre el modelo**, sin
  service object ni form object. La organización se inyecta por `acts_as_tenant`.
- **Secciones**: se crean desde la pantalla "Estructura" de la propiedad
  (`structure.vue` + `StructureForm.vue`), vía el controlador anidado
  `Admin::ResidentialProperties::PropertySectionsController`, usando
  `@residential_property.property_sections.build`. La jerarquía está **fija a dos niveles**
  (raíz → hija) y se aplica con validaciones de modelo + el concern `PropertySectionHierarchy`.
  Existe **además** un controlador plano `Admin::PropertySectionsController` (index/edit/update/
  destroy) que duplica parte de la responsabilidad.
- **Unidades**: **no existe un alta interactiva de unidad individual**. Las rutas exponen
  `units, only: [:show]`. La única vía de creación (y de actualización masiva) es el
  **bulk import** de planillas (`BulkImportServices::*`), donde
  `ImportUnitsRow#create_unit!` es el punto real de creación.

La lógica de negocio del catastro vive mayormente en modelos/concerns (jerarquía, normalización,
unicidad) y, para unidades, en services de bulk import. Los controllers de propiedad y sección
no tienen capa de servicio. Las reglas de unicidad descansan **solo en índices únicos parciales
de la base de datos**, sin validación de modelo equivalente, lo que provoca `RecordNotUnique`
(error 500) en lugar de errores de validación amigables en los flujos interactivos.

## 2. Archivos revisados

**Modelos / concerns**
- `app/models/residential_property.rb`
- `app/models/property_section.rb`
- `app/models/unit.rb`
- `app/models/concerns/property_section_hierarchy.rb`
- `app/models/concerns/alphanumeric_hyphen_code_validatable.rb`
- `app/models/concerns/tenant_scoped_associations.rb`
- `app/models/concerns/section_types.rb` (y por referencia `unit_types.rb`, `unit_statuses.rb`, `property_types.rb`, `normalizable_attributes.rb`)

**Controllers**
- `app/controllers/admin/residential_properties_controller.rb`
- `app/controllers/admin/residential_properties/property_sections_controller.rb`
- `app/controllers/admin/residential_properties/units_controller.rb`
- `app/controllers/admin/residential_properties/structures_controller.rb`
- `app/controllers/admin/property_sections_controller.rb`
- `app/controllers/admin/residential_properties/bulk_imports_controller.rb`

**Policies**
- `app/policies/residential_property_policy.rb`
- `app/policies/property_section_policy.rb`
- `app/policies/unit_policy.rb`
- `app/policies/concerns/residential_property_context.rb`

**Services (catastro / bulk import relevantes)**
- `app/services/bulk_import_services/create_units_import.rb`
- `app/services/bulk_import_services/import_units_row.rb`
- (y por inventario: `process_units_import.rb`, `validate_units_import.rb`,
  `units_import_row_validator.rb`, `units_column_mapper.rb`, etc.)

**Serializers**
- `app/serializers/admin/residential_property_serializer.rb`
- `app/serializers/admin/property_section_serializer.rb`
- `app/serializers/admin/unit_serializer.rb` (por referencia)

**Vistas Inertia / Vue**
- `app/javascript/pages/admin/residential_properties/{index,new,edit,structure}.vue`
- `app/javascript/pages/admin/property_sections/index.vue`
- `app/javascript/components/admin/residential_property/Form.vue`
- `app/javascript/components/admin/property_section/{StructureForm,SectionTree,SectionTreeNode,SectionTreeUnit}.vue`
- `app/javascript/components/admin/bulk_units/*` (drawer e import multi-paso)
- `app/javascript/lib/schemas/{residential_property,property_section,property_section_structure}.ts`

**Rutas**
- `config/routes.rb` (bloque `namespace :admin`)

**Tests**
- `test/models/property_section_hierarchy_test.rb`
- `test/models/property_section/{breadcrumb_path_test,tree_builder_test}.rb`
- `test/models/unit/{change_history_test,occupancy_stats_test}.rb`
- `test/controllers/admin/residential_properties/units_controller_test.rb`
- `test/services/bulk_import_services/*` (validación, mapeo, ownership)
- `test/policies/*` (no incluye property/section/unit catalog policies)

## 3. Flujo actual: propiedades

- **Creación**: `ResidentialPropertiesController#new` renderiza
  `admin/residential_properties/new` con un `ResidentialProperty.new` serializado y
  `property_types`. El submit hace POST a `#create`, que usa el `before_action
  :set_residential_property` → `ResidentialProperty.new(residential_property_params)` y luego
  `@residential_property.save`. **No hay service ni form object**; el modelo se usa directo.
- **Validación**: en el modelo — `name` presente, `property_type` presente + incluido en
  `PropertySptypes::ALL`, `status` presente. Normalización de strings opcionales
  (`code/address_line/city/region` → `presence`) y `trims_attributes`.
- **Autorización**: `authorize ResidentialProperty` con `create? = allowed?(:manage_properties)`
  (capacidad organizacional). `update?` usa `manage_property` + `same_organization?`.
  `index/edit/update/destroy` usan `policy_scope(ResidentialProperty)` para aislamiento.
- **Tenant**: la organización se asigna implícitamente vía `acts_as_tenant` (no aparece en los
  strong params), lo cual es correcto pero implícito.

## 4. Flujo actual: secciones

- **Creación**: desde `structure.vue` (panel de árbol + `StructureForm.vue`). El form Vee/Zod
  envía `{ property_section: { name, code, section_type, parent_id, position } }` a
  `Admin::ResidentialProperties::PropertySectionsController#create`, que hace
  `@residential_property.property_sections.build(...)` + `save`. Redirige siempre a la pantalla
  de estructura, pasando `inertia: { errors: ... }` en caso de fallo.
- **Jerarquía**: estrictamente **dos niveles**, definida en el concern
  `PropertySectionHierarchy`:
  - raíz (`parent_id` nulo) puede tener subsecciones;
  - hija (con `parent_id`) **no** puede tener más hijas;
  - el padre debe ser una sección raíz (`parent_must_be_root_section`);
  - una sección con hijos no puede anidarse bajo otra (`section_with_children_cannot_be_nested`);
  - el padre no puede tener unidades (`parent_cannot_have_units`);
  - una sección contenedora (con hijos) no puede tener unidades (`container_cannot_have_units`).
- **Validaciones adicionales en el modelo**: `validates_same_tenant :residential_property,
  :parent`, y `parent_is_valid` (no auto-referencia, padre existente, misma propiedad,
  no circular). `assign_default_position` calcula posición por defecto entre hermanos.
- **`section_type` es puramente descriptivo**: no determina si una sección acepta unidades o
  subsecciones. `accepts_units? = children.none?` y `accepts_child_sections? = root_section?`
  dependen solo de la posición en el árbol, no del tipo. → regla de negocio ambigua.
- **Doble controlador**: `Admin::PropertySectionsController` (plano) ofrece index/edit/update/
  destroy; `#edit` solo redirige a la pantalla de estructura con `?edit=<id>`. `#update` y
  `#destroy` existen **también** aquí, duplicando la lógica del controlador anidado.

## 5. Flujo actual: unidades

- **No hay alta interactiva individual**. Rutas: `resources :units, only: [:show]`. El
  `UnitsController` solo implementa `#show` (detalle con ownerships, occupancies, visits,
  historial). No hay `new/create/edit/update/destroy` interactivos.
- **Única vía de creación**: bulk import. `CreateUnitsImport` arma el `BulkImport`, adjunta el
  archivo y guarda metadata/opciones; el procesamiento por fila
  (`ImportUnitsRow#create_unit!`) es donde se hace `Unit.create!(...)`.
- **Relación con propiedad/sección**: `belongs_to :residential_property` (obligatorio),
  `belongs_to :property_section, optional: true`. La sección se toma de
  `@payload["property_section_id"]` o del `bulk_import.property_section_id`.
- **Validaciones de modelo**: `unit_type` presente + en `UnitTypes::ALL`; `identifier`
  presente + formato alfanumérico-guión (con espacios permitidos); `normalized_identifier`
  presente; `status` presente + en `UnitStatuses::ALL` (normalizado a downcase);
  `validates_same_tenant :residential_property, :property_section`;
  `property_section_accepts_units` (rechaza secciones contenedoras). `assign_normalized_identifier`
  computa `normalized_identifier` en `before_validation`. `audited` sobre cambios de atributos.

## 6. Validaciones actuales

### Modelo
- `ResidentialProperty`: name, property_type (inclusión), status. Normalización de opcionales.
- `PropertySection`: name, section_type (inclusión), residential_property presente, code
  (alfanumérico-guión), `validates_same_tenant`, `parent_is_valid`, + 4 validaciones de
  jerarquía del concern.
- `Unit`: unit_type (inclusión), identifier (presencia + formato), normalized_identifier
  (presencia), status (presencia + inclusión), `validates_same_tenant`,
  `property_section_accepts_units`.

### Base de datos
- `residential_properties`: índice único parcial `(organization_id, code)` WHERE `code IS NOT
  NULL AND deleted_at IS NULL`.
- `property_sections`: índice único parcial `(organization_id, residential_property_id,
  parent_id, section_type, code)` WHERE `code IS NOT NULL AND deleted_at IS NULL`.
- `units`: índice único parcial `(organization_id, residential_property_id,
  property_section_id, normalized_identifier)` WHERE `deleted_at IS NULL`.
- FKs a `organization`, `residential_property`, `parent` (auto-referencia), `property_section`.

> **Brecha clave**: la unicidad de `code`/`identifier` vive **solo** en la DB; no hay
> `validates :uniqueness` equivalente en los modelos. En flujos interactivos esto produce
> `ActiveRecord::RecordNotUnique` (500) en vez de un error de validación. El bulk import sí
> rescata `RecordNotUnique` y lo trata como "skipped".

### Controller
- Strong params en cada controlador (`residential_property_params`, `property_section_params`
  duplicado en dos controllers, no hay `unit_params` interactivo).
- Manejo de `ActiveRecord::RecordNotFound` con redirect + flash de error i18n.
- No hay validaciones de negocio en controllers (bien), salvo el armado de payload.

### Service
- Reglas de unicidad/normalización de identificador para unidades implementadas en
  `ImportUnitsRow` y validadores de bulk import (`units_import_row_validator`, etc.).
- No existen services para propiedad ni sección.

### Frontend
- Zod schemas (`residential_property.ts`, `property_section.ts`,
  `property_section_structure.ts`) validan forma/placement antes de enviar.
- Errores de servidor se reaplican al form con `applyErrorsToFormRef` / `useServerFormErrors`.

## 7. Autorización y aislamiento

- Modelo de capacidades (`Authorization::Resolver` / `Capabilities`), no roles hardcodeados.
  - Propiedades: `manage_properties` (org-wide) y `manage_property` (por propiedad).
  - Secciones: `manage_sections`.
  - Unidades: `manage_units` / `view_units` / `view_own_unit_context`.
- `policy_scope` se usa consistentemente para cargar propiedad/sección/unidad, garantizando
  aislamiento por organización y propiedad accesible en la **carga** de recursos.
- **Riesgos detectados**:
  - `PropertySectionPolicy#create?` y `UnitPolicy#create?` validan **solo la capacidad**
    (`allowed?(:manage_sections)` / `manage_units`), **sin** ligar la acción a la propiedad
    destino. El aislamiento por propiedad en `create` depende exclusivamente del `policy_scope`
    sobre `ResidentialProperty` en el `before_action` del controlador anidado. Si alguien
    agregara un alta de sección/unidad por otra ruta o cambiara el controller, no habría
    defensa en profundidad a nivel policy.
  - `validates_same_tenant` protege contra asociar `parent`/`property_section` de otra
    organización a nivel de validación, pero **no** contra asociar una sección de **otra
    propiedad de la misma organización** salvo por `parent_is_valid` (que solo cubre el padre,
    no el caso de una `Unit` apuntando a una sección de otra propiedad dentro de la misma org;
    eso se cubriría por la unicidad/scoping del controlador, no por validación explícita
    `unit.property_section.residential_property == unit.residential_property`).

## 8. Lógica mezclada o responsabilidades difusas

- **Controllers de propiedad y sección sin capa de servicio**: el alta opera sobre el modelo
  directamente (`.new`, `.build`, `.save`). No hay form object que encapsule normalización,
  reglas de unicidad amigables ni orquestación.
- **Duplicación entre controllers de sección**: `Admin::PropertySectionsController` y
  `Admin::ResidentialProperties::PropertySectionsController` comparten `property_section_params`
  y exponen `update`/`destroy` ambos. Responsabilidad difusa sobre cuál es el canal oficial.
- **Validación de jerarquía repartida** entre el modelo (`parent_is_valid`) y el concern
  (`parent_must_be_root_section`), con solapamiento (ambos añaden `parent_invalid` cuando el
  padre es nil). Difícil de razonar como única fuente de verdad.
- **`section_type` desacoplado de las reglas**: el tipo no influye en si acepta unidades/hijos;
  toda la semántica vive en la topología del árbol. Mezcla expectativa de dominio con
  estructura.
- **Creación de unidad encapsulada solo en bulk import**: la regla de creación de `Unit` vive en
  `ImportUnitsRow`, no en un service reutilizable que un alta interactiva pudiera invocar.

## 9. UX actual y fricciones

- **No se puede crear una sola unidad desde la UI**: para dar de alta una unidad hay que subir
  una planilla mediante el drawer de bulk import. Fricción alta para casos simples.
- El botón "crear múltiples" exige seleccionar primero una sección; si no, muestra un toast de
  error (`select_section_first`) — flujo no del todo guiado.
- **Errores de unicidad poco amigables** en alta de propiedad/sección: un `code` duplicado puede
  derivar en `RecordNotUnique` (500) en lugar de un error de campo (ver §6).
- **Confirmación de borrado vía `window.confirm`** nativo en `structure.vue`, inconsistente con
  el resto del sistema de diálogos.
- Doble entrada de gestión de secciones (pantalla "Estructura" anidada vs. index plano
  `property_sections`), potencial confusión de navegación.
- El placement raíz/hija se bloquea en modo edición (`disabled`), pero no hay un flujo claro
  para "mover" una sección entre niveles.

## 10. Tests existentes

- `property_section_hierarchy_test.rb` — **3 tests**: raíz con hija OK; hija no puede tener
  hija; sección con hijos no puede anidarse. (No cubre `parent_cannot_have_units`,
  `container_cannot_have_units`, circularidad, distinta propiedad.)
- `property_section/breadcrumb_path_test.rb`, `property_section/tree_builder_test.rb` — armado
  de árbol y breadcrumb (presentación, no creación).
- `unit/change_history_test.rb`, `unit/occupancy_stats_test.rb` — features auxiliares de la
  unidad, no su creación/unicidad.
- `controllers/admin/residential_properties/units_controller_test.rb` — cubre `#show`.
- `services/bulk_import_services/*` — validación de filas, mapeo de columnas, reglas de
  ownership e identidad de owner (cobertura amplia del import).

**Ausentes**: no hay `residential_property_test.rb`, `unit_test.rb` ni
`property_section_test.rb` (validaciones base/unicidad). No hay tests de
`residential_properties_controller`, `property_sections_controller`, `structures_controller`.
No hay tests de `ResidentialPropertyPolicy`, `PropertySectionPolicy`, `UnitPolicy`.

## 11. Casos borde no cubiertos

- **Secciones jerárquicas inválidas**: solo 3 escenarios testeados; faltan padre-con-unidades,
  contenedor-con-unidades, auto-referencia y ciclos.
- **Unidades duplicadas**: sin test de unicidad de `normalized_identifier` por contexto; en
  flujo interactivo (inexistente) sería `RecordNotUnique`.
- **Unidades sin sección**: `property_section_id` es opcional. El índice único parcial **no
  previene duplicados cuando `property_section_id IS NULL`** (Postgres trata NULLs como
  distintos), por lo que dos unidades con mismo identificador y sin sección podrían coexistir.
  Sin test.
- **Secciones de otra propiedad**: una `Unit` con `property_section` de otra propiedad de la
  misma org no tiene validación explícita `section.residential_property == unit.residential_property`.
- **Propiedad de otra organización**: cubierto a nivel `policy_scope` y `validates_same_tenant`,
  pero sin tests de aislamiento.
- **Soft deletes**: índices únicos excluyen `deleted_at IS NOT NULL`; no hay test que verifique
  que un `code`/`identifier` se puede reutilizar tras soft delete, ni el comportamiento de
  `dependent: :destroy` con paranoia (cascade de secciones/unidades al borrar propiedad).
- **Bulk import**: bien cubierto en validación/mapeo, pero sin test del caso "sección destino de
  otra propiedad/organización" ni "creación con sección contenedora rechazada".
- **Normalización de identificadores**: `normalize_identifier` (downcase + espacios→guión)
  tiene test de concern, pero no su interacción con la unicidad por contexto.

## 12. Problemas actuales detectados

1. **El alta de unidad individual no existe en la UI**; solo se crean vía bulk import, lo que
   obliga a subir planillas incluso para una unidad. La lógica de creación de `Unit` está
   atrapada en `ImportUnitsRow` y no es reutilizable.
2. **No hay capa de servicio/form** para propiedad ni sección: los controllers operan directo
   sobre el modelo. No hay separación clara entre formulario, servicio y modelo.
3. **Unicidad sin validación de modelo**: `code` (propiedad/sección) e `identifier` (unidad)
   dependen solo de índices DB → `RecordNotUnique` (500) en flujos interactivos en vez de
   errores de campo.
4. **Doble controlador de secciones** (`Admin::PropertySectionsController` vs. anidado) con
   `update`/`destroy` duplicados y params repetidos.
5. **Reglas de jerarquía repartidas y solapadas** entre `parent_is_valid` (modelo) y
   `PropertySectionHierarchy` (concern), sin una única fuente de verdad.
6. **`section_type` desacoplado de la semántica**: el tipo no determina si acepta unidades o
   subsecciones; todo depende de la topología, lo que vuelve ambiguo el dominio.
7. **Autorización de `create` sin scoping a la propiedad** en `PropertySectionPolicy` y
   `UnitPolicy`; el aislamiento depende del `policy_scope` del controlador, sin defensa en
   profundidad.
8. **Unicidad de unidad sin sección no garantizada** por el índice (NULL distinto de NULL).
9. **Falta de tests**: no hay tests de modelo para `ResidentialProperty`/`Unit`/`PropertySection`
   (unicidad, validaciones base), ni de los controllers de catastro, ni de las policies de
   catastro, ni de aislamiento por organización/propiedad.
10. **Fricciones de UX**: `window.confirm` nativo, doble navegación para secciones, errores de
    unicidad poco claros, y bulk import como único camino para unidades.

## 13. Recomendación para el futuro OpenSpec

**Change id sugerido**: `residential-catalog-creation-refactor`
(alternativas: `unify-residential-catalog-flow`, `residential-catalog-service-layer`).

**División sugerida de secciones del proposal** (sin crear archivos todavía):

1. **Capa de servicios/forms de catastro** — introducir form/service objects para crear y
   actualizar `ResidentialProperty`, `PropertySection` y `Unit`, con `Unit` creation extraída
   de `ImportUnitsRow` a un service reutilizable por bulk import y por alta individual.
2. **Alta interactiva de unidad individual** — rutas `new/create/edit/update/destroy` para
   unidades en la pantalla de estructura, reutilizando el service de creación.
3. **Unicidad y validaciones consistentes** — añadir `validates :uniqueness` (scoped por
   org/propiedad/sección) en modelos para devolver errores de campo, alineadas con los índices
   DB; resolver el caso de unidad sin sección.
4. **Consolidación de jerarquía de secciones** — unificar las reglas en un único punto y
   definir si `section_type` debe gobernar capacidades (acepta unidades/hijos) o seguir siendo
   descriptivo.
5. **Unificación de controllers de sección** — eliminar la duplicación entre el controlador
   plano y el anidado, definiendo un único canal oficial.
6. **Endurecer autorización** — ligar `create?` de sección/unidad a la propiedad destino
   (defensa en profundidad) y agregar tests de aislamiento por organización/propiedad.
7. **Cobertura de tests** — tests de modelo (validaciones + unicidad + soft delete), de
   policies de catastro, de controllers y de casos borde de §11.
8. **Mejoras de UX** — reemplazar `window.confirm`, clarificar navegación de secciones, mostrar
   errores de unicidad como errores de campo.

---

### Cierre

- **Archivos revisados**: ver §2 (modelos, concerns, 6 controllers, 4 policies, 2 services de
  bulk import, 3 serializers, vistas/escudos Vue, rutas y tests).
- **Archivo documental creado**: `docs/sdd/residential-catalog-current-state.md`.
- **Principales problemas**: alta de unidad solo por bulk import; ausencia de capa de
  servicio/form para propiedad y sección; unicidad sin validación de modelo (500 en lugar de
  error de campo); doble controlador de secciones; jerarquía repartida y `section_type` sin
  semántica; autorización de `create` sin scoping a propiedad; tests de catastro y de
  aislamiento ausentes; fricciones de UX.
- **Siguiente paso**: crear el change OpenSpec `residential-catalog-creation-refactor` con
  `/openspec-propose` (o `opsx:propose`), tomando como base la división de §13 y priorizando
  (a) extracción del service de creación de unidad + alta individual y (b) unicidad/validaciones
  consistentes.
</content>
</invoke>
