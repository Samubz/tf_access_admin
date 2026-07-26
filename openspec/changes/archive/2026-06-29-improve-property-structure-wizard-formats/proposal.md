## Why

El wizard de configuración de propiedad permite crear secciones manualmente o con generación rápida, pero no valida ni adapta el formulario al `property_type` seleccionado en el step 1. Esto produce jerarquías incoherentes (ej. un edificio de tipo `tower` con secciones de tipo `sector`) y no guía al usuario sobre la estructura esperada para cada tipo de propiedad.

## What Changes

- Introducción de un catálogo de formatos de estructura por `property_type` (`PropertyStructureFormat`), definido en backend y consumido por frontend.
- El step 2 del wizard renderiza formularios dinámicos según el formato derivado del `property_type` elegido en step 1.
- La generación rápida de secciones muestra inputs distintos por formato (ej. torres + pisos, sectores + bloques, solo pisos, solo bloques).
- La creación manual advierte o bloquea jerarquías incompatibles con el formato recomendado.
- Panel de preview genérico de estructura, reutilizado en Step 2 (solo secciones) y Step 3 (secciones + unidades); en modo quick el commit persiste el batch tras confirmar (sin escritura en DB durante el preview).
- Las unidades solo pueden generarse en el nivel hoja definido por el formato (`units_in`).
- Si el usuario vuelve al step 1 y cambia `property_type`, el formato se recalcula y el step 2 se reinicia.
- Compatibilidad hacia atrás: las propiedades ya configuradas no se ven afectadas.

## Capabilities

### New Capabilities

- `property-structure-format`: Catálogo declarativo de formatos de estructura por `property_type`, con hasta 2 niveles y definición explícita de nivel destino de unidades (`units_in`).

### Modified Capabilities

- `property-setup-wizard`: El step 2 deriva su formulario desde el `property_type` seleccionado en step 1. La generación rápida y manual son ahora sensibles al formato de la propiedad.

## Impact

**Bounded context**: Property Setup · Property Sections · Units

**Modelos afectados**: `ResidentialProperty`, `PropertySection`, `Unit` (solo validación de sección destino en step 3; sin cambios al contrato público)

**Nuevos objetos**:
- `PropertyStructureFormat` — value object con niveles, `section_type` por nivel y `units_in`.
- `Properties::Setup::StructureFormatCatalog` — hash de formatos por `property_type`.
- `Properties::Setup::StructureFormatResolver` — retorna el `PropertyStructureFormat` dado un `property_type`.

**Servicios extendidos** (no nuevos):
- `Properties::Setup::GenerateStructurePreview` — se hace format-aware (hoy hardcodea tower/floor).
- `Properties::Setup::ApplyQuickStructure` — persiste secciones desde el formato activo.

**Controladores / rutas**: Sin controllers ni rutas nuevas. Se reutiliza `Admin::PropertySetup::WizardController` (`structure_preview`, `advance`) y se extiende `WizardSerializer` con `structure_format` + `units_in`.

**Frontend**: Refactor del componente `Step2Structure.vue` para renderizar formulario dinámico por formato; reutiliza `StructurePreviewPanel.vue` existente.

**Tablas**: `property_sections` (sin migraciones nuevas)

**Tenant isolation**: toda operación está scoped a `Current.organization` y al `ResidentialProperty` correcto.

**Authorization**: requiere capability de administración de la propiedad.

## Non-goals

- No importa desde CSV/Excel (eso permanece como está en bulk import).
- No genera occupancies, ownerships ni asignaciones de staff.
- No modifica secciones o unidades existentes (solo crea nuevas).
- No cambia el contrato público de `Unit`.
- No cambia el flujo de bulk import de unidades.
- No rediseña el step 1 más allá de pasar `property_type` al wizard state.
- No soporta más de 2 niveles de jerarquía.
