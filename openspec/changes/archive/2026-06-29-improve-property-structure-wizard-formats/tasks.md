## 1. Auditoría del wizard actual

- [x] 1.1 Leer `Step2Structure.vue` y mapear todos los campos del modo `quick` actual (towers, floors_per_tower, tower_prefix, floor_prefix, units_per_floor)
- [x] 1.2 Leer `structurePreview.ts` y mapear `QuickStructureParams`, `buildQuickStructureTree` y `quickStructureCounts`
- [x] 1.3 Leer el controller del wizard y el serializer para entender qué props llegan al step 2 hoy
- [x] 1.4 Leer el modelo `PropertySection` para confirmar `section_type` enum, `eligible_for_units?` y `can_contain_units?`
- [x] 1.5 Leer la spec de `property-section` existente para identificar contratos que no deben romperse

## 2. Catálogo de formatos de estructura

- [x] 2.1 Crear `app/services/properties/setup/structure_format_catalog.rb` con el hash de formatos para los 7 tipos soportados (`building`, `tower`, `condominium`, `horizontal_community`, `residential_complex`, `sector`, `mixed_use`), usando constantes de `SectionTypes`
- [x] 2.2 Crear value object `PropertyStructureFormat = Data.define(:levels, :units_in)` con levels `[{ section_type:, label_key:, suffix_type: }]`
- [x] 2.3 Crear `Properties::Setup::StructureFormatResolver.for(property_type:)` que retorna el `PropertyStructureFormat` o `nil` si el tipo no tiene formato mapeado
- [x] 2.4 Escribir tests unitarios para el catálogo: un test por `property_type` verificando niveles, `units_in` y `suffix_type`; un test para tipo no mapeado que retorna `nil`

## 3. Serialización del formato al frontend

- [x] 3.1 Agregar `structure_format` y `units_in` a `Admin::PropertySetup::WizardSerializer#as_json`, resueltos desde `StructureFormatResolver.for(property_type:)` (o `null` si no hay formato)
- [x] 3.2 Pasar el formato resuelto a `structure_preview_params` en `WizardController` para que `GenerateStructurePreview` reciba los niveles/section_types del formato
- [x] 3.3 Agregar tipos TypeScript para `PropertyStructureFormat` (con `levels` y `units_in`) en `app/javascript/types/`
- [x] 3.4 Escribir test del serializer: verifica `structure_format` y `units_in` correctos por `property_type`, y `null` cuando no hay formato

## 4. Extender los servicios de preview/commit existentes (format-aware)

- [x] 4.1 Extender `Properties::Setup::GenerateStructurePreview` para aceptar un `PropertyStructureFormat` y generar nodos según sus niveles (1 o 2), `section_type`, prefijos y `suffix_type`; mantener compatibilidad con el comportamiento tower/floor actual
- [x] 4.2 Eliminar `estimated_units` de los `counts` retornados por `GenerateStructurePreview` (el preview de estructura ya no calcula unidades)
- [x] 4.3 Extender `Properties::Setup::ApplyQuickStructure` para construir secciones desde el formato activo en lugar de asumir tower/floor; conservar la transacción y el rollback total existentes
- [x] 4.4 Escribir/actualizar tests para `GenerateStructurePreview`: cada formato del catálogo, sufijo número y letra, formatos de 1 y 2 niveles, building sin torres
- [x] 4.5 Escribir/actualizar tests para `ApplyQuickStructure`: persiste la estructura correcta por formato; rollback ante fallo

## 6. Frontend — formularios dinámicos de step 2

- [x] 6.1 Crear componente `QuickStructureForm.vue` que recibe `format: PropertyStructureFormat` como prop y renderiza los campos apropiados según los niveles (tower/floor, floor-only, sector/block, block-only); el modo `quick` no se muestra en el selector si `format` es `null`
- [x] 6.2 Reemplazar la sección `v-if="selectedMode === 'quick'"` de `Step2Structure.vue` con `<QuickStructureForm :format="structureFormat" />`
- [x] 6.3 Agregar prop `structureFormat` a `Step2Structure.vue` recibida desde el wizard
- [x] 6.4 Agregar toggle "¿El edificio tiene torres?" que aparece solo cuando `property_type === 'building'` y cambia el formato efectivo de tower/floor a floor-only
- [x] 6.5 Eliminar el campo `units_per_floor` / `units_per_leaf` del formulario quick de `Step2Structure.vue` y de `QuickStructureParams` en `structurePreview.ts`
- [x] 6.6 Eliminar `estimated_units` de `quickStructureCounts()` en `structurePreview.ts`; el panel de preview de Step 2 muestra solo secciones (torres, pisos, sectores, bloques según formato) sin conteo de unidades
- [x] 6.7 Reutilizar los tipos existentes de nodos del preview (`structurePreview.ts`); extenderlos solo si el formato requiere campos nuevos
- [x] 6.8 Agregar advertencia inline en `ManualSectionForm.vue` cuando el `section_type` seleccionado no forma parte del formato recomendado
- [x] 6.9 Agregar i18n keys en todos los locales (`es`, `en`, `pt`) para los nuevos textos de formulario, advertencias y toggle de torres

## 7. Frontend — reutilizar panel de preview y flujo existente

- [x] 7.1 Auditar `StructurePreviewPanel.vue` y `StructurePreviewTreeNode.vue` existentes; confirmar que aceptan nodos de secciones con `section_type`/`depth` y unidades opcionales, ajustando props/tipos solo si es necesario
- [x] 7.2 Confirmar que `StructurePreviewPanel.vue` se usa en `Step2Structure.vue` (solo secciones) y `Step3Units.vue` (secciones + unidades); ajustar el binding según el formato activo
- [x] 7.3 Adaptar la llamada existente al endpoint `structure_preview` del wizard para enviar los parámetros del formato activo (no solo tower/floor); alimentar el resultado al panel
- [x] 7.4 Confirmar que el commit de estructura ocurre vía `advance` (step 2 → `ApplyQuickStructure`); manejar errores mostrando mensaje claro con opción de repetir preview

## 8. Step 3 — gate de modo automatic y formulario adaptado

- [x] 8.1 Agregar `structure_mode` a las props del wizard en step 3 para que el frontend sepa si step 2 fue `quick`, `manual` o `none`
- [x] 8.2 En `Step3Units.vue`, mostrar la opción de generación automática solo cuando `structure_mode === 'quick'`; en los demás casos mostrar únicamente bulk import
- [x] 8.3 Leer `units_in` de las props del wizard en `Step3Units.vue` y usarlo para determinar las opciones de formato de identificador
- [x] 8.4 Cuando `units_in === 'floor'`, mostrar opciones "piso + correlativo" (101, 102...) y "solo correlativo" (1, 2...)
- [x] 8.5 Cuando `units_in === 'block'`, mostrar opciones "bloque + correlativo" (B101, B102...) y "solo correlativo" (1, 2...)
- [x] 8.6 Agregar validación en backend que verifica que la sección destino de cada unidad tenga el `section_type` igual a `units_in`
- [x] 8.7 Renombrar `quantity_per_floor` a `units_per_leaf` en `Step3Units.vue` y adaptar su etiqueta según `units_in`: "Unidades por piso" cuando `floor`, "Unidades por bloque" cuando `block`
- [x] 8.8 Agregar i18n keys para las nuevas opciones de formato de identificador y etiqueta adaptada en `es`, `en` y `pt`
- [x] 8.9 Escribir tests para la validación backend de `units_in`
- [ ] 8.10 Escribir tests de controller/frontend para el gate: automatic disponible solo con structure_mode quick

## 9. Reinicio de formato al cambiar property_type

- [x] 9.1 Detectar cambio de `property_type` al navegar de step 2 a step 1 en el wizard frontend
- [x] 9.2 Descarta los valores de structure del wizardState cuando el formato cambia
- [x] 9.3 Mostrar aviso "El tipo de propiedad cambió. La configuración de estructura fue reiniciada."
- [x] 9.4 Asegurar que el controller del wizard retorna el nuevo `structure_format` al regresar a step 2

## 10. Compatibilidad con propiedades existentes y verificación final

- [x] 10.1 Verificar que propiedades con secciones existentes de cualquier tipo siguen visualizándose correctamente
- [x] 10.2 Verificar que el wizard en modo de re-configuración (propiedad con secciones ya creadas) muestra step 2 en modo lectura
- [x] 10.3 Verificar que ningún cambio de `property_type` en edición altera secciones ya persistidas
- [x] 10.4 Ejecutar suite de tests del wizard para confirmar que los scenarios existentes no regresionan
- [x] 10.5 Revisar i18n: confirmar que todas las keys existen en `es`, `en` y `pt` sin strings hardcodeados
