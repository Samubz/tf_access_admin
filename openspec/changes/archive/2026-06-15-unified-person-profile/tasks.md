## 1. Servicio central de identidad

- [x] 1.1 Crear `People::FindExisting` con prioridad documento → email vía User → email en metadata
- [x] 1.2 Añadir tests del resolver (match, sin match, soft-deleted excluido)
- [x] 1.3 Refactorizar `UnitOwnerships::FindExistingPerson` para delegar al servicio central
- [x] 1.4 Refactorizar `BulkImportServices::ResolveImportOwnerPerson` para delegar al servicio central

## 2. Modelo Person y roles derivados

- [x] 2.1 Añadir `has_many :unit_occupancies` y `has_many :visitor_profiles` en `Person`
- [x] 2.2 Crear `People::ContextualRoles` con owner, resident, visitor, concierge, property_admin, cleaning_staff, system_user
- [x] 2.3 Añadir validación de unicidad por documento y email en la organización
- [x] 2.4 Tests de modelo: roles múltiples simultáneos, duplicados, asociaciones

## 3. Integración con flujos existentes

- [x] 3.1 Actualizar `UnitOccupancies::CreateWithPerson` para usar resolver central
- [x] 3.2 Actualizar flujo `UnitOwnerships::CreateWithPerson` (o equivalente) para usar resolver central
- [x] 3.3 Verificar importación masiva sin duplicados
- [x] 3.4 Tests de integración para alta propietario/residente con documento/email duplicado

## 4. Backend perfil unificado

- [x] 4.1 Añadir ruta `show` en `resources :people` y acción `Admin::PeopleController#show`
- [x] 4.2 Implementar `PersonPolicy#show?` y eager loading para ownerships/occupancies
- [x] 4.3 Crear serializers de filas: ownership y occupancy con property, section, unit
- [x] 4.4 Exponer props: person, contextual_roles, ownerships, occupancies, paginación, change_history, staff_assignments [], visits [], permissions
- [x] 4.5 Implementar agregador de historial combinando audits de Person, UnitOwnership y UnitOccupancy
- [x] 4.6 Ordenar historial descendente por fecha y normalizar payload para UI
- [x] 4.7 Tests de controller, policy y serializers del perfil
- [x] 4.8 Exponer métricas resumen del perfil (active_ownerships_count, active_occupancies_count, visits_count, staff_assignments_count)

## 5. Página Perfil Unificado (Vue)

- [x] 5.1 Crear `admin/people/show.vue` con `TabNav` (Resumen, Propiedades, Residencias, Staff, Visitas, Historial)
- [x] 5.2 Crear `PersonProfileHeader` (nombre, documento, email, teléfono, estado, badges, enlace Editar)
- [x] 5.2.1 Mostrar badges de roles contextuales derivados
- [x] 5.3 Crear `PersonSummaryTab` (datos personales, usuario, roles, fechas)
- [x] 5.3.1 Mostrar cards de métricas rápidas debajo del header
- [x] 5.4 Crear `PersonOwnershipsTab` con `AdminDataTable` (propiedad, sección, unidad, %, estado)
- [x] 5.4.1 Enlazar propiedad y unidad desde PersonOwnershipsTab
- [x] 5.5 Crear `PersonOccupanciesTab` con `AdminDataTable` (propiedad, sección, unidad, tipo, estado)
- [x] 5.5.1 Enlazar propiedad y unidad desde PersonOccupanciesTab
- [x] 5.6 Crear `PersonStaffTab` con columnas preparadas y empty state
- [x] 5.6.1 Crear empty state para Staff
- [x] 5.7 Crear `PersonVisitsTab` con estructura preparada y empty state
- [x] 5.7.1 Crear empty state para Visitas
- [x] 5.8 Crear `PersonHistoryTab` con tabla/listado de auditoría
- [x] 5.9 Tipos TypeScript para props del perfil (`types/person_profile.ts` o extensión de `person.ts`)
- [x] 5.10 Breadcrumbs: `Personas > {display_name}`
- [x] 5.11 Implementar perfil siguiendo:
  - mockups/person-profile-overview.png
  - mockups/person-profile-properties.png
  - mockups/person-profile-residences.png
  - mockups/person-profile-history.png
## 6. Navegación y listado

- [x] 6.1 Actualizar `admin/people/index` — acción "Ver perfil" y/o clic en fila hacia `show`
- [x] 6.2 Enlazar nombre de persona en `UnitOwnersTable` al perfil unificado
- [x] 6.3 Enlazar nombre de persona en `UnitOccupantsTable` al perfil unificado
- [x] 6.4 Mostrar badges de roles contextuales en listado de personas (columna o chips)
- [x] 6.5 Traducciones `es` / `en` / `pt` para perfil, tabs, badges y empty states

## 7. Preparación visitantes y staff

- [x] 7.1 Documentar en código que `VisitorProfile` es perfil extendido con `person_id` canónico
- [x] 7.2 Documentar contrato de futura tabla de asignaciones staff (person + residential_property + role)

## 8. Cierre

- [x] 8.1 Documentar decisión sobre email_digest y deduplicación
- [x] 8.2 Ejecutar suite de tests afectados
- [x] 8.3 Ejecutar `graphify update app` tras cambios en código
