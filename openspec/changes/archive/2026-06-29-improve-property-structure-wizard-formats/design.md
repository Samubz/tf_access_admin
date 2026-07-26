## Context

El wizard de configuración de propiedad tiene tres steps: (1) datos de la propiedad incluyendo `property_type`, (2) estructura/secciones, (3) unidades. El step 2 actualmente ofrece tres modos: `none`, `manual`, `quick`. En modo `quick` se muestran inputs fijos (torres, pisos, prefijos) que no se adaptan al tipo de propiedad. En modo `manual` se puede crear cualquier jerarquía sin restricción de tipo.

El resultado es que propiedades de tipo `tower` pueden recibir secciones de tipo `sector`, o propiedades de tipo `sector` pueden tener torres, produciendo estructuras incoherentes que complican el alta de unidades y la visualización de la propiedad.

## Goals / Non-Goals

**Goals:**
- Definir un catálogo declarativo de formatos de estructura por `property_type`.
- Hacer que el step 2 derive su formulario desde el `property_type` elegido en step 1.
- Mostrar inputs de generación rápida distintos por formato (tower/floor, floor-only, sector/block, block-only).
- Guiar o advertir al usuario en modo manual cuando la jerarquía no coincida con el formato recomendado.
- Panel de preview genérico reutilizable en Step 2 (solo secciones) y Step 3 (secciones + unidades opcionales).
- Validar que el target level (`units_in`) sea el nivel hoja correcto.
- Mantener compatibilidad con propiedades existentes.

**Non-Goals:**
- Cambiar el contrato público de `Unit`.
- Cambiar el flujo de bulk import de unidades.
- Importación CSV/Excel.
- Más de 2 niveles de jerarquía.
- Modificar secciones o unidades existentes.
- Rediseñar step 1 más allá de pasar `property_type` al wizard state.

## Decisions

### 1. `PropertyStructureFormat` como value object central

`PropertyStructureFormat` encapsula la configuración de estructura para un tipo de propiedad:

```ruby
PropertyStructureFormat = Data.define(:levels, :units_in)
# levels: array de 1 o 2 elementos
#   { section_type: :tower | :floor | :sector | :block, label_key: String, suffix_type: :letter | :number }
# units_in: section_type del nivel hoja donde se ubican las unidades
```

El catálogo de formatos vive en `Properties::Setup::StructureFormatCatalog` como un hash constante indexado por `property_type` (string), usando las constantes de `SectionTypes` (`TOWER`, `FLOOR`, `SECTOR`, `BLOCK`). Esto centraliza las reglas y evita duplicación entre backend y frontend.

### 2. `StructureFormatResolver` expone el formato al wizard

`Properties::Setup::StructureFormatResolver.for(property_type:)` retorna el `PropertyStructureFormat` correspondiente. Si el `property_type` no tiene formato en el catálogo, retorna `nil` — en ese caso el modo `quick` no se ofrece y el usuario debe usar modo `manual`.

El catálogo completo (7 tipos soportados):

| property_type          | nivel 1  | nivel 2 | units_in | suffix L1 | suffix L2 |
|------------------------|----------|---------|----------|-----------|-----------|
| `building`             | `tower`  | `floor` | `floor`  | letter    | number    |
| `tower`                | `floor`  | —       | `floor`  | number    | —         |
| `condominium`          | `sector` | `block` | `block`  | number    | number    |
| `horizontal_community` | `sector` | `block` | `block`  | number    | number    |
| `residential_complex`  | `tower`  | `floor` | `floor`  | letter    | number    |
| `sector`               | `block`  | —       | `block`  | number    | —         |
| `mixed_use`            | `tower`  | `floor` | `floor`  | letter    | number    |

`condominium` siempre usa `sector → block`. Los condominios verticales con torres deben modelarse como `residential_complex` o `building`.

### 3. El formato se serializa al frontend como parte de las props del wizard

`Admin::PropertySetup::WizardSerializer#as_json` agrega dos claves nuevas: `structure_format` (resuelto desde `StructureFormatResolver.for(property_type:)`, o `null`) y `units_in` (derivado del formato). El frontend consume el formato para:
- Renderizar el formulario correcto en modo `quick`.
- Mostrar advertencias en modo `manual`.
- Conocer `units_in` para el step 3.

El formato se re-serializa si el usuario vuelve al step 1 y cambia `property_type`. El wizardState en el frontend descarta los valores de estructura previos cuando el formato cambia.

### 4. Modo quick: formularios distintos por formato

El componente `Step2Structure.vue` renderiza una sección de generación rápida diferente según el formato recibido:

| formato     | campos mostrados                                                  |
|-------------|-------------------------------------------------------------------|
| tower/floor | cantidad de torres, pisos por torre, prefijo torre, prefijo piso |
| floor-only  | cantidad de pisos, prefijo piso                                   |
| sector/block | cantidad de sectores, bloques por sector, prefijo sector, prefijo bloque |
| block-only  | cantidad de bloques, prefijo bloque                               |

El formulario dinámico vive en un componente nuevo `QuickStructureForm.vue` que recibe el `format` como prop y renderiza los campos apropiados.

### 5. Caso especial `building`: eliminar nivel tower

Para `building`, el formato base incluye 2 niveles (tower → floor). Si el edificio no tiene torres, el usuario puede desactivar el nivel 1. El wizard muestra un toggle "¿El edificio tiene torres?". Al desactivarlo, el formato efectivo se convierte en floor-only. Este toggle solo aparece cuando `property_type === 'building'`.

### 6. Modo manual: advertencia, no bloqueo

En modo `manual`, el usuario puede crear secciones de cualquier `section_type`. Sin embargo, cuando el tipo creado no coincide con los tipos recomendados por el formato, el wizard muestra una advertencia inline (no bloquea). El bloqueo ocurre solo si el usuario intenta crear una sección hija en un nivel que no corresponde al padre según el formato.

Esto permite flexibilidad para casos edge, mientras guía la experiencia habitual.

### 7. Reutilizar el flujo preview/commit existente, hecho format-aware

El wizard **ya tiene** el flujo preview/commit para estructura quick; no se crean servicios ni controllers nuevos. Se extienden los existentes para que sean conscientes del formato:

- **Preview** — `Properties::Setup::GenerateStructurePreview` (expuesto por `WizardController#structure_preview`, devuelve JSON paginado). Hoy está hardcodeado a `tower → floor`. Se extiende para recibir el `PropertyStructureFormat` y generar los `section_type`, prefijos y sufijos del formato activo (incluyendo formatos de 1 nivel y el caso building sin torres).
- **Commit** — `Properties::Setup::ApplyQuickStructure` (invocado al avanzar de step 2 vía `WizardController#advance` → `apply_structure_step!`). Ya persiste en transacción con rollback total. Se extiende para construir las secciones desde el formato en lugar de asumir tower/floor.

El panel de preview es un componente de visualización de árbol que recibe `sections` (requerido) y `units` (opcional). Cuando `units` está presente, las muestra anidadas bajo su sección hoja. Cuando no, muestra solo la jerarquía de secciones. El componente `StructurePreviewPanel.vue` **ya existe** (junto con `StructurePreviewTreeNode.vue` y `UnitsPreviewPanel.vue`); se reutiliza tal cual:

- **Step 2, modo none**: `sections: []` → estado vacío.
- **Step 2, modo manual**: `sections: [secciones persistidas]`, `units: null`.
- **Step 2, modo quick**: `sections: [batch en memoria]`, `units: null`.
- **Step 3, modo automatic**: `sections: [secciones existentes]`, `units: [batch en memoria]`.

Los modos `none` y `manual` no pasan por el commit de batch — `none` no persiste nada y `manual` usa `PropertySections::Create` por sección.

### 8. Step 3: modo automatic gateado por modo quick de step 2

El modo de generación automática de unidades en step 3 solo está disponible cuando step 2 usó modo `quick`. En ese caso el wizard tiene un `structure_format` definido con `units_in` conocido.

```
Step 2 modo quick  →  Step 3: automatic + bulk import
Step 2 modo manual →  Step 3: solo bulk import
Step 2 modo none   →  Step 3: solo bulk import
```

El controller del wizard incluye `structure_mode` en las props del step 3. El frontend usa ese valor para mostrar u ocultar la opción de generación automática.

### 9. Step 3: formulario de identificador de unidades adaptado a `units_in`

Los 7 tipos del catálogo colapsan en dos patrones de identificador determinados por `units_in`:

```
units_in: floor  →  building, tower, residential_complex, mixed_use
units_in: block  →  condominium, horizontal_community, sector
```

El formulario de generación automática en step 3 muestra las opciones de formato según `units_in`:

| units_in | opción A                         | opción B          | ejemplo A   | ejemplo B |
|----------|----------------------------------|-------------------|-------------|-----------|
| `floor`  | piso + correlativo               | solo correlativo  | 101, 102... | 1, 2...   |
| `block`  | bloque + correlativo             | solo correlativo  | B101, B102..| 1, 2...   |

El frontend lee `units_in` de las props del wizard. El backend valida que las unidades creadas pertenezcan a secciones del `section_type` correcto.

### 10. Validación de `units_in` en backend

El `units_in` del formato se envía como parte de las props del wizard al step 3. El controller de unidades (step 3) valida que las secciones destino seleccionadas tengan el `section_type` correcto según `units_in`. Esta validación ocurre en backend independientemente del frontend para garantizar integridad.

### 11. Compatibilidad con propiedades existentes

Los formatos aplican solo durante el flujo del wizard (nueva configuración). Las propiedades ya configuradas conservan sus secciones sin alteración. El wizard muestra el estado actual de secciones en modo lectura si la propiedad ya tiene secciones creadas y el usuario abre step 2 nuevamente.

### 12. Sincronización de formato al cambiar `property_type` en step 1

Cuando el usuario vuelve al step 1 y cambia `property_type`, el wizardState invalida el `structure` guardado en step 2. El frontend muestra un aviso: "El tipo de propiedad cambió. La configuración de estructura se reinició." El usuario debe re-configurar step 2 con el nuevo formato.

## Risks / Trade-offs

- **Modo manual sin bloqueo total**: el usuario puede crear estructuras no recomendadas. Mitigación: advertencia visible y suficiente para guiar la experiencia habitual; el bloqueo total crearía fricción innecesaria para casos edge legítimos.
- **Race condition en commit**: otro usuario puede crear secciones entre preview y commit. Mitigación: `CommitSections` re-valida en transacción y hace rollback total; el usuario recibe error claro y puede repetir preview.
- **Propiedades existentes con estructura incoherente**: no se migran automáticamente. El wizard las muestra en modo lectura sin forzar re-configuración.

## Migration Plan

No hay migraciones de schema nuevas. Las tablas `property_sections` ya existen.

Rollout:
1. Crear `Properties::Setup::StructureFormatCatalog`, `StructureFormatResolver` y el value object `PropertyStructureFormat`.
2. Extender `Properties::Setup::GenerateStructurePreview` y `ApplyQuickStructure` para que sean format-aware (sin servicios ni controllers nuevos).
3. Agregar `structure_format` y `units_in` a `WizardSerializer`; pasar el `PropertyStructureFormat` al `structure_preview` params.
4. Adaptar `Step2Structure.vue` con `QuickStructureForm.vue`, toggle de torres y advertencias en modo manual; reutilizar `StructurePreviewPanel.vue` existente.
5. Adaptar `Step3Units.vue`: gate de modo automatic por `structure_mode`, formulario de identificador por `units_in`.
6. Sin rollback especial; el wizard manual sigue disponible como fallback.

## Open Questions

- ¿Se necesita persistir el `property_type` en `wizardState` del backend o solo viaja como prop entre steps?
- ¿Cuál es el límite máximo de secciones generables en un batch (para performance de preview)?
