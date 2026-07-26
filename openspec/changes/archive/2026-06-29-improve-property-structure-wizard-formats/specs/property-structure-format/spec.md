## ADDED Requirements

### Requirement: Structure wizard derives format from property type
El sistema SHALL seleccionar un formato de estructura recomendado según el `property_type` de la propiedad. El formato define los niveles de sección (hasta 2) y el nivel donde se ubican las unidades (`units_in`).

#### Scenario: building usa tower entonces floor con unidades en floor
- **WHEN** el `property_type` es `building`
- **THEN** el formato tiene nivel 1 `tower` (sufijo letra) y nivel 2 `floor` (sufijo número), con `units_in: floor`

#### Scenario: building permite eliminar tower para quedar con floor únicamente
- **WHEN** el `property_type` es `building` y el usuario desactiva el nivel tower
- **THEN** el formato efectivo tiene solo nivel 1 `floor` (sufijo número), con `units_in: floor`

#### Scenario: tower usa floor con unidades en floor
- **WHEN** el `property_type` es `tower`
- **THEN** el formato tiene solo nivel 1 `floor` (sufijo número), con `units_in: floor`

#### Scenario: condominium usa sector entonces block con unidades en block
- **WHEN** el `property_type` es `condominium`
- **THEN** el formato tiene nivel 1 `sector` (sufijo número) y nivel 2 `block` (sufijo número), con `units_in: block`

#### Scenario: horizontal_community usa sector entonces block con unidades en block
- **WHEN** el `property_type` es `horizontal_community`
- **THEN** el formato tiene nivel 1 `sector` (sufijo número) y nivel 2 `block` (sufijo número), con `units_in: block`

#### Scenario: residential_complex usa tower entonces floor con unidades en floor
- **WHEN** el `property_type` es `residential_complex`
- **THEN** el formato tiene nivel 1 `tower` (sufijo letra) y nivel 2 `floor` (sufijo número), con `units_in: floor`

#### Scenario: sector usa block con unidades en block
- **WHEN** el `property_type` es `sector`
- **THEN** el formato tiene solo nivel 1 `block` (sufijo número), con `units_in: block`

#### Scenario: mixed_use usa tower entonces floor con unidades en floor
- **WHEN** el `property_type` es `mixed_use`
- **THEN** el formato tiene nivel 1 `tower` (sufijo letra) y nivel 2 `floor` (sufijo número), con `units_in: floor`

#### Scenario: property_type sin formato en catálogo deshabilita modo quick
- **WHEN** el `property_type` de la propiedad no tiene un formato mapeado en el catálogo
- **THEN** el modo `quick` no se ofrece en step 2
- **AND** el usuario debe usar modo `manual` para definir la estructura

---

### Requirement: Quick structure form uses the selected format
El sistema SHALL renderizar distintos formularios de generación rápida según el formato activo. Los campos mostrados deben corresponder a los niveles del formato.

#### Scenario: Formato tower/floor muestra campos de torres y pisos
- **WHEN** el formato activo tiene niveles `[tower, floor]`
- **THEN** el formulario muestra: cantidad de torres, cantidad de pisos por torre, prefijo de torre, prefijo de piso

#### Scenario: Formato floor-only muestra solo campos de pisos
- **WHEN** el formato activo tiene solo nivel `[floor]`
- **THEN** el formulario muestra: cantidad de pisos, prefijo de piso

#### Scenario: Formato sector/block muestra campos de sectores y bloques
- **WHEN** el formato activo tiene niveles `[sector, block]`
- **THEN** el formulario muestra: cantidad de sectores, cantidad de bloques por sector, prefijo de sector, prefijo de bloque

#### Scenario: Formato block-only muestra solo campos de bloques
- **WHEN** el formato activo tiene solo nivel `[block]`
- **THEN** el formulario muestra: cantidad de bloques, prefijo de bloque

---

### Requirement: Step 3 automatic mode is only available when step 2 used quick mode
El sistema SHALL ofrecer la generación automática de unidades en step 3 únicamente cuando el modo de estructura seleccionado en step 2 fue `quick`. En los modos `manual` y `none`, step 3 SHALL mostrar solo la opción de importación masiva (bulk import).

#### Scenario: Step 2 quick habilita generación automática en step 3
- **WHEN** el usuario completó step 2 en modo `quick`
- **THEN** step 3 muestra la opción de generación automática de unidades
- **AND** step 3 muestra la opción de bulk import

#### Scenario: Step 2 manual deshabilita generación automática en step 3
- **WHEN** el usuario completó step 2 en modo `manual`
- **THEN** step 3 muestra únicamente la opción de bulk import
- **AND** la opción de generación automática no está disponible

#### Scenario: Step 2 none deshabilita generación automática en step 3
- **WHEN** el usuario completó step 2 en modo `none`
- **THEN** step 3 muestra únicamente la opción de bulk import
- **AND** la opción de generación automática no está disponible

---

### Requirement: Step 3 unit identifier format adapts to units_in
El sistema SHALL adaptar las opciones de formato de identificador de unidades en step 3 según el `units_in` del formato activo. El identificador SHALL reflejar el nivel hoja de la estructura.

#### Scenario: units_in floor ofrece formato piso+correlativo o solo correlativo
- **WHEN** el `units_in` del formato activo es `floor`
- **THEN** step 3 ofrece la opción "piso + correlativo" (ej. 101, 102, 201...) y "solo correlativo" (ej. 1, 2, 3...)

#### Scenario: units_in block ofrece formato bloque+correlativo o solo correlativo
- **WHEN** el `units_in` del formato activo es `block`
- **THEN** step 3 ofrece la opción "bloque + correlativo" (ej. B101, B102...) y "solo correlativo" (ej. 1, 2, 3...)

#### Scenario: Backend rechaza unidades en nivel incorrecto
- **WHEN** el frontend envía unidades con sección destino cuyo `section_type` no coincide con `units_in`
- **THEN** el backend retorna error de validación y no persiste ninguna unidad

---

### Requirement: Manual structure creation respects recommended formats
El sistema SHALL permitir creación manual de secciones, pero SHALL mostrar advertencia cuando el `section_type` creado no corresponde al formato recomendado del `property_type`.

#### Scenario: Usuario crea secciones compatibles con el formato sin advertencias
- **WHEN** el usuario crea manualmente secciones con `section_type` incluidos en el formato recomendado
- **THEN** no se muestra ninguna advertencia y la creación procede normalmente

#### Scenario: Usuario crea sección con tipo no recomendado y recibe advertencia
- **WHEN** el usuario intenta crear una sección con `section_type` que no forma parte del formato recomendado para el `property_type`
- **THEN** el sistema muestra una advertencia inline explicando el formato sugerido
- **AND** la creación no queda bloqueada; el usuario puede continuar si lo desea

#### Scenario: Usuario crea jerarquía incompatible a nivel padre y recibe bloqueo
- **WHEN** el usuario intenta agregar una sección hija en un nivel que excede los niveles permitidos por el formato
- **THEN** el sistema bloquea la operación con mensaje de error explicando el límite de jerarquía

#### Scenario: Usuario puede crear propiedad sin secciones cuando el tipo lo permite
- **WHEN** el usuario selecciona modo "sin secciones" en step 2
- **THEN** el wizard avanza a step 3 sin requerir secciones
- **AND** las unidades del step 3 quedan asociadas directamente a la propiedad

#### Scenario: Cambio de property_type en step 1 reinicia formato de step 2
- **WHEN** el usuario vuelve al step 1 y cambia el `property_type`
- **THEN** el formato activo en step 2 se recalcula y la estructura previa se descarta
- **AND** el wizard muestra aviso indicando que la configuración de estructura fue reiniciada

---

### Requirement: Structure preview renders current structure state
El sistema SHALL mostrar un panel de preview de estructura en todo momento durante el step 2, independientemente del modo activo. El panel refleja el estado actual de la estructura y se actualiza reactivamente.

#### Scenario: Preview en modo none muestra estado vacío
- **WHEN** el modo activo es `none`
- **THEN** el panel de preview muestra un estado vacío indicando que no habrá secciones

#### Scenario: Preview en modo manual actualiza en vivo
- **WHEN** el modo activo es `manual` y el usuario crea o elimina una sección
- **THEN** el panel de preview refleja la estructura actualizada sin recargar la página

#### Scenario: Preview en modo quick muestra batch generado en memoria
- **WHEN** el modo activo es `quick` y el usuario configura parámetros de generación
- **THEN** el panel de preview muestra la lista de secciones que se crearán, con nombre, nivel y estado (`:new`, `:duplicate`, `:conflict`)
- **AND** el panel se actualiza al cambiar cualquier parámetro

#### Scenario: Preview quick detecta duplicado con sección existente
- **WHEN** una sección del batch generado tiene el mismo nombre que una sección ya existente en la propiedad
- **THEN** esa sección aparece con estado `:duplicate` y no se incluye en el conteo de nuevas

#### Scenario: Preview quick detecta conflicto interno en el batch
- **WHEN** dos secciones del mismo batch generan el mismo nombre
- **THEN** ambas aparecen con estado `:conflict`

#### Scenario: Preview quick no persiste datos
- **WHEN** el panel muestra el batch de modo quick
- **THEN** la base de datos no contiene secciones nuevas hasta que el usuario confirma el commit

#### Scenario: Commit persiste el batch de modo quick
- **WHEN** el usuario confirma el preview de modo quick y no hay ítems con estado `:conflict` o errores bloqueantes
- **THEN** `ApplyQuickStructure` persiste todas las secciones con estado `:new` en transacción
- **AND** se registra auditoría del batch

#### Scenario: Error en commit hace rollback total
- **WHEN** ocurre una falla de unicidad concurrente durante el commit de modo quick
- **THEN** se hace rollback de toda la transacción
- **AND** no quedan secciones parcialmente creadas
- **AND** el usuario recibe un error claro y puede repetir el preview

---

### Requirement: Existing properties remain compatible
El sistema NO SHALL alterar propiedades ya configuradas cuando se introduce el nuevo sistema de formatos.

#### Scenario: Propiedad existente con estructura no estándar sigue visualizándose
- **WHEN** una propiedad tiene secciones cuyo `section_type` no coincide con el formato del `property_type`
- **THEN** las secciones se siguen mostrando correctamente
- **AND** el wizard no obliga a migrar ni eliminar la estructura existente

#### Scenario: El wizard aplica formatos nuevos solo a nuevas configuraciones
- **WHEN** el wizard se abre para una propiedad sin secciones
- **THEN** el formato recomendado se aplica al step 2
- **AND** cuando se abre para una propiedad con secciones ya confirmadas, el step 2 muestra esas secciones en modo lectura

#### Scenario: Cambios de formato no alteran estructuras confirmadas
- **WHEN** el `property_type` de una propiedad ya configurada se edita fuera del wizard
- **THEN** las secciones existentes no son modificadas automáticamente
