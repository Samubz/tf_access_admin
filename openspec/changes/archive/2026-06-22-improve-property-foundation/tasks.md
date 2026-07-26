# Improve Property Foundation Tasks

> Las tareas describen implementación futura. Este change no implementa código y ninguna tarea está completada.

## 1. Modelo y migraciones

* [x] 1.1 Auditar datos existentes: nombres duplicados, nombres vacíos y estados no canónicos
* [x] 1.2 Definir constantes/enums para `active`, `inactive` y `archived`
* [x] 1.3 Añadir constraint de estado permitido
* [x] 1.4 Definir columna o expresión normalizada para unicidad case-insensitive del nombre
* [x] 1.5 Añadir índice único por organización para nombres normalizados no eliminados
* [x] 1.6 Verificar FK y `NOT NULL` de `organization_id`, `name`, `property_type` y `status`
* [x] 1.7 Revisar asociaciones `dependent: :destroy` para evitar cascadas durante lifecycle de propiedad
* [x] 1.8 Definir auditoría mínima de cambios de estado y lifecycle

## 2. Validaciones y normalización

* [x] 2.1 Normalizar nombre mediante trim, colapso de whitespace y comparación case-insensitive
* [x] 2.2 Validar nombre único dentro de la organización con error de campo
* [x] 2.3 Mantener código opcional y único por organización cuando está presente
* [x] 2.4 Validar inclusión de `property_type`
* [x] 2.5 Validar inclusión de `status`
* [x] 2.6 Definir validación de ubicación mínima y timezone
* [x] 2.7 Impedir cambio de `organization_id`
* [x] 2.8 Manejar `RecordNotUnique` concurrente como error de dominio

## 3. Servicios de dominio

* [x] 3.1 Implementar `Properties::Create`
* [x] 3.2 Implementar `Properties::Update`
* [x] 3.3 Implementar `Properties::Archive`
* [x] 3.4 Derivar organización desde contexto confiable en create
* [x] 3.5 Centralizar normalización y validaciones de lifecycle
* [x] 3.6 Separar activate/deactivate de cambios descriptivos cuando corresponda
* [x] 3.7 Hacer archive no destructivo, atómico e idempotente
* [x] 3.8 Preservar secciones, unidades, personas relacionadas, assignments, visitas y datos operativos al archivar
* [x] 3.9 Definir errores/resultados estructurados para controller y UI

## 4. Policy y scopes

* [x] 4.1 Alinear `ResidentialPropertyPolicy` con acciones index/show/create/update/archive
* [x] 4.2 Mantener `manage_properties` como capability organizacional
* [x] 4.3 Mantener `manage_property` acotada a propiedades con assignment activo
* [x] 4.4 Permitir create/archive a tenant admin dentro de su organización
* [x] 4.5 Permitir view/update a property admin solo en propiedades asignadas
* [x] 4.6 Denegar create/archive a property admin por defecto
* [x] 4.7 Denegar assignments inactivos, futuros o vencidos
* [x] 4.8 Garantizar scopes tenant-safe y cross-property
* [x] 4.9 No introducir roles globales de `property_admin`

## 5. Controllers y props

* [x] 5.1 Delegar create a `Properties::Create`
* [x] 5.2 Delegar update a `Properties::Update`
* [x] 5.3 Reemplazar destroy ordinario por una acción explícita de archive
* [x] 5.4 Delegar archive a `Properties::Archive`
* [x] 5.5 Mantener carga de registros mediante policy scope
* [x] 5.6 Unificar contrato de errores Inertia
* [x] 5.7 Exponer permisos backend-driven para editar, activar/desactivar y archivar
* [x] 5.8 Evitar aceptar `organization_id` desde parámetros del cliente

## 6. UI mínima

* [x] 6.1 Alinear schema frontend con estados canónicos
* [x] 6.2 Mantener `archived` fuera del selector ordinario de creación/edición
* [x] 6.3 Añadir acción separada de archive con confirmación explícita
* [x] 6.4 Mostrar errores de nombre duplicado en el campo correspondiente
* [x] 6.5 Mostrar estado archivado y limitar acciones según props backend
* [x] 6.6 Definir estados loading, success, error y forbidden
* [x] 6.7 Mantener el formulario como superficie de datos y no como fuente de reglas de lifecycle

## 7. Tests

* [x] 7.1 Testear creación válida
* [x] 7.2 Testear rechazo sin organización
* [x] 7.3 Testear rechazo sin nombre
* [x] 7.4 Testear nombre duplicado normalizado dentro de la misma organización
* [x] 7.5 Testear mismo nombre en organizaciones distintas
* [x] 7.6 Testear valores válidos e inválidos de status
* [x] 7.7 Testear defaults y normalización
* [x] 7.8 Testear que propiedades con secciones o unidades no se eliminan físicamente
* [x] 7.9 Testear dependencias indirectas de personas y staff assignments
* [x] 7.10 Testear visitas activas/futuras como dependencia
* [x] 7.11 Testear archivado controlado y preservación de dependencias
* [x] 7.12 Testear tenant admin dentro y fuera de su organización
* [x] 7.13 Testear property admin asignado y no asignado
* [x] 7.14 Testear assignment inactivo, futuro y vencido
* [x] 7.15 Testear usuario sin permisos
* [x] 7.16 Testear aislamiento cross-organization y cross-property
* [x] 7.17 Testear delegación de controllers a servicios
* [x] 7.18 Testear conflicto concurrente de unicidad
* [x] 7.19 Testear contrato mínimo de serializer/props y acciones backend-driven

## 8. Cierre

* [x] 8.1 Ejecutar suite de modelos, servicios, policies, requests y frontend
* [x] 8.2 Ejecutar RuboCop y chequeos TypeScript/Vue
* [x] 8.3 Verificar manualmente create, update, deactivate, activate y archive
* [x] 8.4 Verificar que archive no altera dependencias
* [x] 8.5 Ejecutar `openspec validate improve-property-foundation --type change --strict`
* [x] 8.6 Ejecutar Graphify después de la implementación futura, no durante este change documental
* [x] 8.7 Preparar cierre y registrar decisiones de Open Questions resueltas
