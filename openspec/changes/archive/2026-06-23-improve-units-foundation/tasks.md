# Improve Units Foundation Tasks

## Status: ARCHIVED ✅

**Completed:** 2026-06-23

All implementation tasks completed and tested. Key deliverables:
- Unit domain model with organization/property/section validation
- Canonical service layer (Create, Update, MoveToSection, Archive, Restore, SoftDelete)
- Migration with normalized-identifier backfill, partial unique indexes, and FK constraints
- Policy-based authorization with property-scoped create requirement
- Bulk import integration with canonical service boundary
- 72+ integration tests + 19 migration constraint tests
- OpenSpec alignment verified

### Note on Deferred Items

- **Task 4.8 (type/status checks)**: Deferred pending legacy type audit and catalog mapping. Constraint infrastructure in place; validation enforcement blocked until legacy data reconciliation completes.

## 1. Modelo y catálogos

* [x] 1.1 Formalizar el contrato mínimo de `Unit`
* [x] 1.2 Derivar organization desde residential property
* [x] 1.3 Hacer organization y residential property inmutables
* [x] 1.4 Validar section opcional de misma organization/property
* [x] 1.5 Validar que section esté efectivamente activa
* [x] 1.6 Validar que section sea elegible para unidades según el contrato `property-section` (`can_contain_units?` o equivalente)
* [x] 1.7 Normalizar y validar identifier
* [x] 1.8 Validar unicidad por contexto con y sin section
* [x] 1.9 Permitir mismo identifier bajo secciones distintas
* [x] 1.10 Normalizar y validar `unit_type`
* [x] 1.11 Normalizar y validar `status`
* [x] 1.12 Validar `area_m2` positivo cuando exista
* [x] 1.13 Mantener metadata como dato extensible no relacional
* [x] 1.14 Impedir que metadata sobrescriba property, section, identifier, type, status, lifecycle o autorización
* [x] 1.15 Tolerar transitoriamente tipos legacy auditados sin bloquear updates no relacionados
* [x] 1.16 Exigir catálogo canónico cuando una escritura modifique `unit_type`
* [x] 1.17 Auditar cambios de identifier, section, type, status y area

## 2. Servicios de dominio

* [x] 2.1 Implementar `Units::NormalizeIdentifier`
* [x] 2.2 Implementar `Units::Create`
* [x] 2.3 Implementar `Units::Update`
* [x] 2.4 Implementar `Units::MoveToSection`
* [x] 2.5 Implementar `Units::Archive`
* [x] 2.6 Implementar `Units::Restore`
* [x] 2.7 Separar atributos descriptivos, placement y lifecycle
* [x] 2.8 Mantener create/move/archive/restore atómicos
* [x] 2.9 Convertir conflictos DB concurrentes en errores de dominio
* [x] 2.10 Definir contrato de resultado success/noop/invalid/unauthorized/conflict
* [x] 2.11 Preservar ownerships, occupancies, leases y visits
* [x] 2.12 Ignorar o rechazar `organization_id`, `residential_property_id` y `normalized_identifier` enviados por cliente
* [x] 2.13 Impedir que `Units::Update` cambie property, organization o section
* [x] 2.14 Impedir que `Units::Update` use `status = archived`
* [x] 2.15 Permitir cambios de status solo entre `available`, `occupied`, `inactive` y `maintenance`
* [x] 2.16 Permitir status inicial distinto de `available` solo en flujos autorizados como import/backfill

## 3. Lifecycle y soft delete

* [x] 3.1 Definir archive como `status = archived`
* [x] 3.2 Impedir que archive use `destroy` o `deleted_at`
* [x] 3.3 Mantener identificador reservado para unidades archivadas no eliminadas
* [x] 3.4 Restringir soft delete al canal técnico aprobado
* [x] 3.5 Revalidar unicidad al restaurar una unidad soft-deleted
* [x] 3.6 Rechazar restore cuando el contexto fue reutilizado
* [x] 3.7 Mantener status original durante restore técnico
* [x] 3.8 Definir transición explícita si se implementa reactivación de archived

## 4. Migraciones, constraints e índices

* [x] 4.1 Ejecutar backfill de `normalized_identifier` con `Units::NormalizeIdentifier`
* [x] 4.2 Verificar y reforzar FKs de organization, residential property y section
* [x] 4.3 Añadir o verificar `NOT NULL` para organization, property, identifier, normalized_identifier, unit_type, status y metadata
* [x] 4.4 Añadir validación de dominio y, si se aprueba, constraint/FK compuesta para coherencia unit organization ↔ property organization
* [x] 4.5 Añadir índice único parcial para unidades con sección y `deleted_at IS NULL`
* [x] 4.6 Añadir índice único parcial para unidades sin sección y `deleted_at IS NULL`
* [x] 4.7 Añadir check `area_m2 > 0` cuando no sea null
* [ ] 4.8 Añadir checks de tipo/status solo después de completar auditoría, backfill y transición legacy (DEFERRED: pending legacy type audit and catalog mapping)
* [x] 4.9 Añadir índices tenant/property/section/status y búsqueda normalizada
* [x] 4.10 Verificar compatibilidad de índices únicos con `acts_as_paranoid`

## 5. Policy y scopes

* [x] 5.1 Evaluar `view_units` y `manage_units` con property context
* [x] 5.2 Autorizar create con property destino explícita
* [x] 5.3 Autorizar update/move/archive/restore sobre property original
* [x] 5.4 Mantener scopes organization/property-safe
* [x] 5.5 Autorizar tenant admin dentro de su organización
* [x] 5.6 Autorizar property admin con assignment activo y `view_units` para lectura
* [x] 5.7 Autorizar property admin con assignment activo y `manage_units` para mutaciones
* [x] 5.8 Autorizar concierge asignado con `view_units` solo para lectura, si esa capability existe
* [x] 5.9 Denegar mutaciones a actores con `view_units` pero sin `manage_units`
* [x] 5.10 Denegar assignment inactivo, futuro o vencido
* [x] 5.11 Denegar cross-property y cross-organization
* [x] 5.12 Denegar residentes, concierge y usuarios sin `manage_units` para mutaciones
* [x] 5.13 No introducir roles globales

## 6. Controllers, serializers y búsqueda

* [x] 6.1 Definir canal canónico para mutaciones de Unit
* [x] 6.2 Delegar create/update/move/archive/restore a servicios
* [x] 6.3 Cargar property, unit y section mediante policy scopes
* [x] 6.4 Ignorar o rechazar organization/property arbitrarias del cliente sin persistir valores no confiables
* [x] 6.5 Unificar errores por campo/base
* [x] 6.6 Exponer identifier, display name, placement, type y status necesarios
* [x] 6.7 Implementar búsqueda tenant-scoped por identifier normalizado/display name
* [x] 6.8 Normalizar input de búsqueda antes de consultar `normalized_identifier`
* [x] 6.9 Mantener búsqueda dentro de scopes autorizados por organization/property
* [x] 6.10 Evitar N+1 al cargar property/section y relaciones solicitadas

## 7. Integración con bulk import

* [x] 7.1 Reutilizar `Units::NormalizeIdentifier`
* [x] 7.2 Delegar creación a `Units::Create`
* [x] 7.3 Delegar actualización descriptiva a `Units::Update` solo cuando el modo de importación permita actualizar unidades existentes
* [x] 7.4 Delegar cambio de sección a `Units::MoveToSection` solo cuando el modo de importación permita cambiar placement
* [x] 7.5 Mantener preview, modos y errores por fila
* [x] 7.6 Rechazar section cross-property/cross-organization
* [x] 7.7 Mantener comportamiento idempotente y seguro ante concurrencia
* [x] 7.8 Reportar como skipped/warning/failed las filas que intenten update o move en modos que no lo permiten
* [x] 7.9 Ignorar cualquier `normalized_identifier` incluido en la planilla y recalcularlo desde `identifier`

## 8. Tests

* [x] 8.1 Testear creación válida con y sin sección
* [x] 8.2 Testear rechazo de unidad sin property/organization
* [x] 8.3 Testear section de otra property/organization
* [x] 8.4 Testear section inexistente, inactiva, archivada o no elegible
* [x] 8.5 Testear normalización de identifier, incluido Unicode
* [x] 8.6 Testear duplicado dentro de misma section
* [x] 8.7 Testear duplicado entre unidades sin section
* [x] 8.8 Testear mismo identifier en otra section/property/organization
* [x] 8.9 Testear duplicados con status inactive/maintenance/archived
* [x] 8.10 Testear soft delete liberando contexto
* [x] 8.11 Testear restore exitoso y restore conflictivo
* [x] 8.12 Testear tipos, status, area y metadata
* [x] 8.13 Testear que metadata no sobrescribe campos estructurales ni autorización
* [x] 8.14 Testear update sin cambio implícito de property/section
* [x] 8.15 Testear move a otra section y al contexto sin section
* [x] 8.16 Testear move con conflicto de identifier
* [x] 8.17 Testear archive no destructivo e idempotente
* [x] 8.18 Testear preservación de ownerships, occupancies, leases y visits
* [x] 8.19 Testear conflictos concurrentes de create/move/restore
* [x] 8.20 Testear tenant admin y property admin asignado
* [x] 8.21 Testear assignments inactivos/futuros/vencidos
* [x] 8.22 Testear cross-property, cross-organization y usuario sin permiso
* [x] 8.23 Testear controllers delegando a servicios
* [x] 8.24 Testear bulk import usando el contrato canónico
* [x] 8.25 Añadir migration tests para datos compatibles e incompatibles
* [x] 8.26 Testear que update no permite `status = archived`
* [x] 8.27 Testear que update permite solo transiciones operativas permitidas
* [x] 8.28 Testear actor con `view_units` pero sin `manage_units`
* [x] 8.29 Testear concierge con `view_units`, si aplica
* [x] 8.30 Testear bulk import no actualiza ni mueve placement cuando el modo no lo permite
* [x] 8.31 Testear que import ignora `normalized_identifier` de la planilla
* [x] 8.32 Testear búsqueda normalizando input y respetando scope autorizado

## 9. Cierre

* [x] 9.1 Ejecutar suite de modelos, servicios, policies, requests y bulk import
* [x] 9.2 Ejecutar RuboCop y chequeos TypeScript/Vue afectados
* [x] 9.3 Ejecutar Brakeman
* [x] 9.4 Ejecutar `openspec validate improve-units-foundation --type change --strict`
* [x] 9.5 Verificar manualmente búsqueda y errores de unicidad si existe UI
* [x] 9.6 Registrar decisiones sobre tipos legacy y status occupied
* [x] 9.7 Confirmar que proposal/design/spec/tasks están alineados
* [x] 9.8 Registrar decisiones de open questions cerradas durante la implementación
* [x] 9.9 Actualizar Graphify solo después de implementar código
