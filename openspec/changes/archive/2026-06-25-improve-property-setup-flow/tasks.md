# Improve Property Setup Flow Tasks

> Implementación del wizard guiado de configuración inicial de propiedades.

## 1. Revisión de patrones existentes

- [x] 1.1 Revisar `Admin::ResidentialPropertiesController`, rutas y página Inertia actuales de alta de propiedad
- [x] 1.2 Revisar flujos existentes de `PropertySection` y componentes de árbol/edición manual
- [x] 1.3 Revisar creación manual, masiva e importación de `Unit`, incluido bulk import
- [x] 1.4 Revisar `ResidentialPropertyPolicy`, `PropertySectionPolicy`, `UnitPolicy` y `BulkImportPolicy`
- [x] 1.5 Revisar servicios `Properties::Create`, `PropertySections::*`, `Units::Create` y contratos de preview/import existentes
- [x] 1.6 Comparar layout y affordances con `mockups/improve-property-setup-flow/create-property-step-1.png` a `create-property-step-5.png`

## 2. Backend de borrador y orquestación

- [x] 2.1 Añadir `draft` y `configured` a `PropertyStatuses` (módulo Ruby + constantes ALL y SETUP)
- [x] 2.2 Migrar check constraint `residential_properties_status_allowed` para incluir `draft` y `configured`
- [x] 2.3 Extender `property_operable?` en `Units::Base`, `PropertySections::Base`, `UnitPolicy` y `PropertySections::TreeBuilder` para incluir `draft` y `configured`
- [x] 2.4 Implementar `Properties::Setup::InitializeDraft` para crear la propiedad con `status = draft` al avanzar del Step 1 al Step 2
- [x] 2.5 Implementar `Properties::Setup::Configure` para transicionar `draft → configured` (Step 5)
- [x] 2.6 Implementar `Properties::Activate` para transicionar `configured → active`
- [x] 2.7 Implementar `Properties::Setup::ValidateStep` para pasos 1 a 4
- [x] 2.8 Implementar `Properties::Setup::BuildPreview` para resumen inicial, estructura y unidades
- [x] 2.9 Implementar `Properties::Setup::GenerateStructurePreview` para estructura rápida (paginada)
- [x] 2.10 Implementar `Properties::Setup::GenerateUnitsPreview` para generación automática desde estructura (paginada)
- [x] 2.11 Implementar `Properties::Setup::Confirm` validando estado final y delegando a `Properties::Setup::Configure`
- [x] 2.12 Implementar `Properties::Setup::Cancel` con lógica condicional: en `draft` permite elegir entre eliminar o conservar; en `configured`/`active` retorna sin acción destructiva
- [x] 2.13 Rechazar payloads que intenten forzar `organization_id` o relaciones inconsistentes

## 3. Rutas, controller y autorización

- [x] 3.1 Eliminar o redirigir `Admin::ResidentialPropertiesController#new` y `#create`; el wizard es la única entrada canónica
- [x] 3.2 Agregar rutas del wizard bajo el namespace admin existente
- [x] 3.3 Crear controller delgado para show/advance/back/cancel/confirm del wizard
- [x] 3.4 Autorizar inicio y confirmación con `manage_properties` en la organización actual
- [x] 3.5 Exponer solo props mínimas y tipadas para cada paso
- [x] 3.6 Integrar `Properties::Setup::Cancel` en la acción cancel del controller, con modal condicional por status en el frontend
- [x] 3.7 Exponer acciones siguientes post-confirmación respetando capabilities existentes

## 4. Paso 1 — Datos de la propiedad

- [x] 4.1 Crear UI del paso 1 con formulario de nombre, tipo, dirección, estimación y metadata opcional
- [x] 4.2 Implementar panel auxiliar "Resumen inicial" con estado del flujo
- [x] 4.3 Validar campos requeridos usando contrato de `residential-property`
- [x] 4.4 Al avanzar al Step 2, persistir la propiedad como `draft` vía `Properties::Setup::InitializeDraft`
- [x] 4.5 Agregar i18n `admin.property_setup.step1.*` en `es`, `en` y `pt`

## 5. Paso 2 — Estructura / secciones

- [x] 5.1 Crear selector de modo: sin secciones, manual o rápida
- [x] 5.2 Implementar flujo "Sin secciones" sin exigir jerarquía
- [x] 5.3 Implementar edición manual de secciones jerárquicas en borrador
- [x] 5.4 Implementar formulario de estructura rápida con parámetros y prefijos
- [x] 5.5 Mostrar vista previa de árbol y contadores en panel auxiliar
- [x] 5.6 Exigir confirmación de preview antes de avanzar en modo rápido
- [x] 5.7 Mostrar empty state cuando el modo manual no tiene secciones
- [x] 5.8 Agregar i18n `admin.property_setup.step2.*` en `es`, `en` y `pt`

## 6. Paso 3 — Unidades

- [x] 6.1 Crear barra de contexto con nombre de propiedad y resumen de estructura
- [x] 6.2 Implementar creación de unidad individual en borrador
- [x] 6.3 Implementar generación múltiple/automática desde estructura con preview de identificadores
- [x] 6.4 Integrar importación Excel reutilizando bulk import existente sin duplicar reglas
- [x] 6.5 Mostrar errores, advertencias y duplicados de unidades/import en el paso
- [x] 6.6 Bloquear avance cuando existan errores bloqueantes
- [x] 6.7 Agregar i18n `admin.property_setup.step3.*` en `es`, `en` y `pt`

## 7. Paso 4 — Resumen

- [x] 7.1 Crear tarjetas resumen de propiedad, estructura, unidades y dirección
- [x] 7.2 Mostrar secciones detalladas de datos, árbol de estructura y tabla preview de unidades
- [x] 7.3 Incluir errores, advertencias, duplicados y omitidos en el resumen
- [x] 7.4 Permitir volver a pasos anteriores para corregir información
- [x] 7.5 Mostrar aviso informativo de que se podrá ajustar la configuración después de confirmar
- [x] 7.6 Agregar i18n `admin.property_setup.step4.*` en `es`, `en` y `pt`

## 8. Paso 5 — Confirmación y éxito

- [x] 8.1 Crear pantalla de confirmación con checklist, resumen final y panel de consecuencias
- [x] 8.2 Exigir checkbox de confirmación explícita antes de persistir
- [x] 8.3 Ejecutar confirmación vía `Properties::Setup::Confirm` (transiciona `draft → configured`) y mostrar estado de éxito con conteos finales
- [x] 8.4 Ofrecer acciones siguientes: detalle de propiedad, administrar unidades, importar propietarios, configurar residentes
- [x] 8.5 Manejar fallos de confirmación con errores accionables; la propiedad permanece en `draft` con sus registros intactos
- [x] 8.6 Agregar i18n `admin.property_setup.step5.*` en `es`, `en` y `pt`

## 9. Shell del wizard y navegación

- [x] 9.1 Crear contenedor común con título, descripción y stepper de cinco pasos
- [x] 9.2 Implementar footer con acciones `Atrás`, `Cancelar` y avance/confirmación según paso
- [x] 9.3 Marcar pasos completados, actual y pendientes según estado del borrador
- [x] 9.4 Preservar datos al navegar hacia atrás y recalcular previews dependientes
- [x] 9.5 Agregar i18n compartida `admin.property_setup.wizard.*` en `es`, `en` y `pt`

## 10. Tests y validación

- [x] 10.1 Tests de policy para inicio, confirmación y acceso cross-organization
- [x] 10.2 Tests de modelo/servicio para `PropertyStatuses` extendido y `property_operable?` con `draft` y `configured`
- [x] 10.3 Tests de servicio para `Properties::Setup::Configure`, `Properties::Activate` y `Properties::Setup::Cancel`
- [x] 10.4 Tests de servicio para validación por paso y previews paginadas
- [x] 10.5 Tests de request para avance, retroceso, cancelación (draft y configured) y confirmación
- [ ] 10.6 Tests de integración con bulk import dentro del paso 3 sobre propiedad draft
- [ ] 10.7 Tests de system/Inertia para flujo feliz de cinco pasos
- [ ] 10.8 Verificación manual del layout contra las cinco mockups de referencia

## 11. Entrada al flujo y rollout

- [x] 11.1 Conectar acción "Nueva propiedad" al wizard
- [x] 11.2 Confirmar que `Admin::ResidentialPropertiesController#new` y `#create` fueron eliminados o redirigidos (ver tarea 3.1)
- [x] 11.3 Verificar que usuarios no autorizados no vean la entrada al wizard
- [x] 11.4 Verificar que propiedades `draft` y `configured` aparecen en el catálogo con badge de estado para usuarios autorizados
- [ ] 11.5 Verificar que la acción de activación explícita (`configured → active`) es accesible desde el detalle de la propiedad
