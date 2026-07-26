## 1. Catálogo y resolver de autorización

- [x] 1.1 Crear `Authorization::Capabilities` con constantes y mapas por rol operativo MVP
- [x] 1.2 Crear `Authorization::Resolver` con contexto `user`, `organization`, `property: nil`, `unit: nil`, `record: nil`
- [x] 1.3 Implementar resolución en capas: rol organizacional → StaffAssignment activo por propiedad → ownership/occupancy activo por unidad
- [x] 1.4 Crear `Authorization::PropertyScope` para `accessible_property_ids`
- [x] 1.5 Memoizar en `Current` un resolver base por `user` + `organization`, y cachear evaluaciones por contexto (`property`, `unit`, `record`) sin reutilizar scopes incorrectos
- [x] 1.6 Tests unitarios del resolver por cada rol MVP (grant y deny)
- [x] 1.7 Garantizar que `property_admin`, `concierge`, `cleaning_staff` e `internal_staff` se resuelven exclusivamente por `StaffAssignment` activo asociado a una propiedad, nunca como roles globales

## 2. Extensión de ApplicationPolicy

- [x] 2.1 Añadir `resolver`, `allowed?(capability)`, `property_accessible?(property)` a `ApplicationPolicy`
- [x] 2.2 Implementar `record_residential_property` helper (o concern) para resolver propiedad del recurso
- [x] 2.3 Mantener `same_organization?` y alinear con resolver
- [x] 2.4 Tests de helpers de policy base

## 3. Actualización de políticas existentes

- [x] 3.1 Actualizar `ResidentialPropertyPolicy` — capacidades y scope por propiedades accesibles
- [x] 3.2 Actualizar `PropertySectionPolicy` — heredar alcance de propiedad padre
- [x] 3.3 Actualizar `UnitPolicy` — `view_units` / `manage_units` scoped
- [x] 3.4 Actualizar `PersonPolicy` — `view_people` / `manage_people`; residente ve su propia persona
- [x] 3.5 Actualizar `UnitOwnershipPolicy` — `manage_ownerships` scoped
- [x] 3.6 Actualizar `UnitOccupancyPolicy` — `manage_occupancies` scoped
- [x] 3.7 Actualizar `UserPolicy` — `manage_users` solo Super Admin Org
- [x] 3.8 Actualizar `BulkImportPolicy` — capacidades según alcance de propiedad
- [x] 3.9 Tests de policy por rol y alcance: tenant_admin, property_admin de propiedad asignada, property_admin de otra propiedad, concierge de propiedad asignada, concierge de otra propiedad, resident/owner de unidad propia, client sin acceso

## 4. VisitPolicy placeholder

- [x] 4.1 Crear contrato documentado para futura `VisitPolicy` sin crear modelo, migración, controller ni rutas de visitas
- [x] 4.2 Definir métodos esperados: `index?`, `show?`, `create?`, `authorize?`, `check_in?`, `check_out?`
- [x] 4.3 Definir reglas esperadas por capability: `create_visits`, `authorize_visits`, `register_visit_entry`, `register_visit_exit`

## 5. StaffAssignment operacional

- [x] 5.1 Añadir scopes activos en `StaffAssignment` (`active`, vigencia por fechas)
- [x] 5.2 Verificar que `StaffAssignment` activo sea la única fuente de roles operativos por propiedad dentro de `Authorization::Resolver`
- [x] 5.3 Mapear `StaffTypes::MANAGER` ↔ `property_admin` en resolver y badges
- [x] 5.4 Definir mapa de capacidades para staff types existentes, normalizando:
  - `manager` / `property_admin` → `property_admin`
  - `concierge` / `security` → `concierge`
  - `cleaning` / `cleaning_staff` → `cleaning_staff`
  - `maintenance` / `other` → `internal_staff`
- [x] 5.5 Auditar `StaffAssignment` (create/update status)
- [x] 5.6 Tests de integración staff → capacidades
- [x] 5.7 Añadir validaciones de vigencia en `StaffAssignment`: `ends_at >= starts_at` y estado activo/inactivo consistente

## 6. Contextual roles y perfil unificado

- [x] 6.1 Extender `People::ContextualRoles` con badges staff desde `StaffAssignment` activo
- [x] 6.2 Actualizar `People::ContextualRoles.batch_for` para staff en batch
- [x] 6.3 Exponer `staff_assignments` reales en `Admin::PeopleController#show`
- [x] 6.4 Actualizar `PersonStaffTab` para listar asignaciones activas
- [x] 6.5 Alinear `permissions` prop del perfil con `Authorization::Resolver`
- [x] 6.6 Tests de contextual roles staff y permisos de perfil

## 7. Contratos de dominio para UI futura

- [x] 7.1 Documentar `OperationalUserSummary` (serializer o type stub)
- [x] 7.2 Definir contrato de entrada/salida para servicios `OperationalRoles::*` que serán implementados en sección 8
- [x] 7.3 Exponer `capabilities` en shared props Inertia del layout admin
- [x] 7.4 Tipos TypeScript `OperationalCapabilities` para frontend

## 8. Servicios de asignación (sin UI)

- [x] 8.1 Implementar `OperationalRoles::AssignPropertyAdmin`
- [x] 8.2 Implementar `OperationalRoles::AssignConcierge`
- [x] 8.3 Implementar `OperationalRoles::AssignInternalStaff`
- [x] 8.4 Implementar `OperationalRoles::RevokeAssignment`
- [x] 8.5 Validar `person.user_id` presente cuando la asignación requiere acceso al sistema
- [x] 8.6 Tests de servicios de asignación

## 9. Gestión visual de roles operativos

 - [x] 9.1 Crear rutas admin para gestión de roles operativos
 - [x] 9.2 Crear controller admin para listar usuarios operativos, roles disponibles, matriz de permisos y asignaciones actuales
 - [x] 9.3 Conectar acciones de asignar/revocar roles con los servicios `OperationalRoles::*`
 - [x] 9.4 Crear serializers/props para `OperationalUserSummary`, roles disponibles, propiedades accesibles, staff assignments y capabilities efectivas
 - [x] 9.5 Crear vista de listado de roles/usuarios operativos basada en `mockups/roles_list.png`
 - [x] 9.6 Crear vista de detalle por rol basada en `mockups/details_per_rol.png`
 - [x] 9.7 Crear vista o componente de matriz de permisos basada en `mockups/matrix_of_permissions.png`
 - [x] 9.8 Crear vista o drawer de asignación de roles basada en `mockups/assign_roles_view.png`
 - [x] 9.9 Restringir propiedades seleccionables según el alcance del usuario actual
 - [x] 9.10 Ocultar o deshabilitar acciones según `capabilities` del usuario actual
 - [x] 9.11 Mantener todas las acciones de filas dentro de dropdowns
 - [x] 9.12 Agregar estados empty, loading, success y error para asignación/revocación de roles
 - [x] 9.13 Agregar tests de autorización para endpoints admin de gestión de roles operativos
 - [ ] 9.14 Agregar tests frontend mínimos para renderizado condicional según capabilities


## 10. Aislamiento y regresión

- [x] 10.1 Tests cross-organization denial en todas las políticas actualizadas
- [x] 10.2 Tests cross-property denial para property_admin y concierge
- [x] 10.3 Verificar que `tenant_admin` existentes conservan acceso org-wide
- [x] 10.4 Ejecutar suite de tests afectados (policies, resolver, people, units)
- [x] 10.5 Ejecutar `graphify update app` tras cambios en código
- [x] 10.6 Test explícito: usuario `property_admin` de Propiedad A no puede acceder ni modificar Propiedad B
- [x] 10.7 Test explícito: usuario `concierge` de Propiedad A no puede consultar datos de Propiedad B

## 11. Cierre

- [x] 11.1 Revisar navegación admin: ocultar ítems según `capabilities` en layout
- [x] 11.2 Documentar decisión Rolify-on-Person vs User (follow-up opcional)
- [x] 11.3 Archivar/sync specs delta al completar implementación
