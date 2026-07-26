# Improve Property Setup Flow

## Why

Hoy la configuración inicial de una propiedad residencial exige crear la propiedad, sus secciones y sus unidades en pantallas separadas, sin contexto compartido ni visibilidad del resultado final. Eso aumenta errores, abandono del flujo y duplicación de esfuerzo para administradores que necesitan dejar operativa una propiedad completa antes de gestionar visitas, personas y unidades.

Este change introduce un flujo guiado de cinco pasos que orquesta la creación de propiedad, estructura y unidades en una sola experiencia, respetando el dominio existente y las políticas de autorización actuales.

## What Changes

* Introducir un wizard de configuración de propiedad con cinco pasos: datos de la propiedad, estructura, unidades, resumen y confirmación.
* Definir un contrato UX observable basado en las vistas de referencia `mockups/improve-property-setup-flow/create-property-step-1.png` a `create-property-step-5.png`.
* Permitir definir estructura interna mediante tres modos: sin secciones, estructura manual o estructura rápida con previsualización.
* Permitir crear unidades mediante generación automática desde la estructura, creación individual o múltiple, e importación desde Excel reutilizando el bulk import existente.
* Mostrar un resumen editable antes de confirmar, con errores, advertencias, duplicados y elementos omitidos.
* Finalizar con una pantalla de éxito y acciones siguientes claras para continuar la administración.
* Persistir la propiedad como `draft` al completar el Step 1 y crear secciones y unidades incrementalmente en Steps 2 y 3, delegando a los servicios de dominio existentes en cada paso.
* Exigir autorización capability-based y aislamiento por organización en todo el flujo.
* No permitir que el cliente fuerce `organization_id` ni relaciones inconsistentes entre propiedad, secciones y unidades.

## Capabilities

### New Capabilities

* `property-setup-wizard`: flujo guiado de configuración inicial de una propiedad residencial, incluyendo layout del wizard, navegación entre pasos, manejo de estado, validación, resumen, confirmación, integración con secciones/unidades/bulk import y pantalla final de éxito.

### Modified Capabilities

* `residential-property`: se introducen dos nuevos valores de status (`draft`, `configured`) y se extiende el gate de operabilidad para incluirlos, permitiendo que secciones y unidades se creen sobre propiedades en setup. Se requiere migración para actualizar el check constraint `residential_properties_status_allowed`.
* `property-section`: el gate `property_operable?` se extiende para aceptar `draft` y `configured`, permitiendo crear secciones durante el wizard.
* `unit`: el gate `property_operable?` se extiende para aceptar `draft` y `configured`, permitiendo crear unidades durante el wizard.

## Bounded context

**Dominios afectados:**

* Residential Properties — punto de entrada y datos base de la propiedad.
* Property Sections — definición de estructura jerárquica opcional.
* Units — creación manual, masiva o por importación.
* Bulk Imports — reutilización del flujo existente de importación de unidades.
* Authentication & Authorization — acceso al wizard y confirmación final.

**Puntos de integración:**

* Servicios de creación/actualización de `ResidentialProperty`, `PropertySection` y `Unit`.
* Bulk import existente para unidades desde Excel.
* Políticas Pundit y capabilities (`manage_properties`, `manage_property`, `manage_units`, `view_units` según corresponda).
* Serializers/props Inertia para el estado del wizard y el resumen.
* i18n en `es`, `en` y `pt` para todo texto visible.

## Impact

**Modelos y tablas involucrados:**

* Migración requerida: actualizar check constraint `residential_properties_status_allowed` para incluir `draft` y `configured`.


* `ResidentialProperty`
* `PropertySection`
* `Unit`
* `BulkImport` y tablas asociadas al import existente
* `Organization` como contexto tenant

**Servicios y componentes de implementación futura:**

* Orquestador de setup, p. ej. `Properties::Setup::*` o equivalente alineado con convenciones del proyecto.
* Controlador/rutas del wizard bajo el namespace admin existente.
* Páginas y componentes Vue del wizard.
* Serializer del estado del wizard y del resumen.
* Policy dedicada o extensión de `ResidentialPropertyPolicy` para iniciar y confirmar el flujo.
* Tests de request, policy, servicio de orquestación y flujo de UI crítico.

**Referencias visuales obligatorias:**

* `mockups/improve-property-setup-flow/create-property-step-1.png`
* `mockups/improve-property-setup-flow/create-property-step-2.png`
* `mockups/improve-property-setup-flow/create-property-step-3.png`
* `mockups/improve-property-setup-flow/create-property-step-4.png`
* `mockups/improve-property-setup-flow/create-property-step-5.png`

**Dependencias de otros changes:**

* `improve-property-foundation` — contrato de `ResidentialProperty`.
* `improve-property-sections` — contrato de jerarquía y elegibilidad de secciones.
* `improve-units-foundation` / `improve-units-flow` — servicios canónicos de unidades y bulk import.

**Impacto en tenant isolation y autorización:**

* Solo usuarios con capability para crear propiedades en la organización actual pueden iniciar el wizard.
* Toda creación final debe derivar `organization_id` del contexto autenticado.
* Secciones y unidades del borrador deben permanecer ligadas a la propiedad en preparación dentro del mismo tenant.
* Confirmación final debe rechazar cualquier payload que intente asociar registros a otra organización o propiedad ajena.

## Non-goals

* Rediseñar por completo los CRUD independientes de propiedades, secciones o unidades fuera del flujo guiado.
* Cambiar reglas de dominio de unicidad o elegibilidad ya definidas en specs existentes (el lifecycle de `residential-property` sí se extiende con `draft` y `configured`, declarado en Modified Capabilities).
* Implementar configuración de propietarios, residentes, staff assignments o visitas dentro del wizard.
* Sustituir o duplicar la lógica interna del bulk import; solo integrarlo al paso de unidades.
* Definir estilos visuales a nivel de píxeles, tokens de diseño o componentes UI nuevos no requeridos por el contrato funcional.
* Implementar código, migraciones, rutas, controllers, servicios, componentes Vue o tests en esta etapa.

## Validation

El flujo se considerará conforme cuando:

* Un usuario autorizado pueda completar los cinco pasos: la propiedad se persiste como `draft` en Step 1, las secciones y unidades se crean en Steps 2 y 3, y la confirmación en Step 5 transiciona la propiedad a `configured`.
* Un usuario no autorizado no pueda iniciar ni confirmar el wizard.
* La UI respete el contrato UX derivado de las cinco vistas de referencia.
* El resumen refleje con precisión lo que ha sido configurado (propiedad, secciones y unidades ya persistidas), incluyendo errores y advertencias.
* La confirmación ofrezca acciones siguientes sin dejar al usuario en un callejón sin salida.
* Ningún paso permita forzar `organization_id` ni relaciones inconsistentes desde el cliente.
