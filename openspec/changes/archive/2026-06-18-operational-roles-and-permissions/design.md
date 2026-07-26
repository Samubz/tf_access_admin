# Design: Operational Roles and Permissions

## Context

La aplicación ya posee una base de dominio para administración residencial:

* `Organization`
* `User`
* `Person`
* `OrganizationMembership`
* `ResidentialProperty`
* `PropertySection`
* `Unit`
* `UnitOwnership`
* `UnitOccupancy`
* `StaffAssignment`

También existen policies Pundit para recursos como:

* `PersonPolicy`
* `UnitPolicy`
* `UnitOwnershipPolicy`
* `UnitOccupancyPolicy`
* `ResidentialPropertyPolicy`
* `PropertySectionPolicy`
* `BulkImportPolicy`

Sin embargo, la autorización actual está centrada principalmente en roles administrativos globales como `super_admin` / `tenant_admin`, lo que no representa bien el dominio operacional de propiedades residenciales.

Antes de implementar visitas, se necesita un modelo de permisos más granular, porque el módulo de visitas expondrá información sensible:

* Personas
* Documentos
* Teléfonos
* Residentes
* Propietarios
* Autorizaciones
* Entradas
* Salidas
* Historial de acceso

El sistema debe distinguir entre:

* Administración global de la organización
* Administración de una propiedad específica
* Operación de portería/conserjería en una propiedad específica
* Participación como residente o propietario de una unidad específica
* Personal interno con permisos limitados

---

# Goals

* Definir un modelo de autorización operacional basado en capacidades.
* Separar roles organizacionales de roles por propiedad.
* Centralizar la resolución de permisos en `Authorization::Resolver`.
* Usar `StaffAssignment` como fuente de roles operativos por propiedad.
* Usar `UnitOwnership` y `UnitOccupancy` como fuente de capacidades de propietario/residente.
* Extender policies existentes para dejar de depender solo de `admin?`.
* Preparar el sistema para futuras `VisitPolicy` y flujos de visitas.
* Mantener aislamiento estricto por organización y por propiedad.
* Evitar que `Person` defina permisos directamente.

---

# Non-Goals

* No implementar CRUD de visitas.
* No implementar pantallas de gestión de usuarios y permisos.
* No crear portal self-service para residentes/propietarios.
* No migrar completamente Rolify desde `Person` a `User` si actualmente existe dependencia.
* No crear una matriz de permisos configurable desde UI.
* No crear nuevas tablas si `StaffAssignment` ya soporta el dominio mínimo.
* No convertir `property_admin` ni `concierge` en roles globales.

---

# Core Design Principles

## 1. Person is identity, not authorization

`Person` representa identidad.

Una persona puede ser:

* Propietario
* Residente
* Visitante
* Conserje
* Administrador de propiedad
* Personal de aseo
* Usuario del sistema

Pero esos roles no deben persistirse como una columna única en `people`.

Incorrecto:

```ruby
person.role = "concierge"
```

Correcto:

```text
Person
  ↓
StaffAssignment(role: concierge, residential_property_id: ...)
```

o:

```text
Person
  ↓
UnitOccupancy
  ↓
Unit
```

`Person` puede participar en autorización solo como puente de identidad desde el `User` autenticado hacia relaciones del dominio.

---

## 2. User is the authorization subject

Las policies deben evaluar al `current_user`, no directamente a `Person`.

Flujo conceptual:

```text
current_user
  ↓
OrganizationMembership
  ↓
Person asociada en la organización
  ↓
StaffAssignments activos
  ↓
Ownerships activos
  ↓
Occupancies activos
  ↓
Capabilities efectivas
```

---

## 3. Organizational roles are global within the organization

Los roles organizacionales aplican a toda la organización.

Rol mínimo:

```text
organization_admin / tenant_admin / content_managger
```

Puede administrar recursos transversales de la organización.

Ejemplos:

* Crear propiedades
* Gestionar usuarios
* Gestionar propiedades
* Ver recursos de toda la organización
* Administrar configuraciones globales

---

## 4. Property roles are never global

Los roles operativos de propiedad siempre tienen alcance por `ResidentialProperty`.

Roles mínimos:

```text
property_admin
concierge
cleaning_staff
internal_staff
```

Un usuario puede tener distintos roles en distintas propiedades.

Ejemplo:

```text
Pedro
  - property_admin en Edificio A
  - concierge en Edificio B
  - sin acceso a Edificio C
```

Esto significa que `property_admin` no equivale a `tenant_admin`.

También significa que `concierge` no puede ver información de todas las propiedades de la organización.

---

## 5. Owner and resident are derived capabilities

`owner` y `resident` no son roles persistidos en `User` ni en `Person`.

Se derivan desde:

```text
UnitOwnership → owner
UnitOccupancy → resident
```

Estas relaciones otorgan capacidades limitadas sobre unidades específicas.

Ejemplos futuros:

* Crear visitas para su unidad
* Autorizar visitas para su unidad
* Consultar visitas asociadas a su unidad

---

# Authorization Model

## Role Sources

| Fuente                   | Alcance      | Ejemplo                                         |
| ------------------------ | ------------ | ----------------------------------------------- |
| `OrganizationMembership` | Organización | `organization_admin`                            |
| `StaffAssignment`        | Propiedad    | `property_admin`, `concierge`, `cleaning_staff` |
| `UnitOwnership`          | Unidad       | propietario                                     |
| `UnitOccupancy`          | Unidad       | residente                                       |
| `User`                   | Sistema      | autenticación y acceso                          |
| `Person`                 | Identidad    | vínculo contextual, no permiso directo          |

---

# Operational Roles

## Organization Admin

Alcance:

```text
Organization
```

Puede:

* Gestionar propiedades de la organización.
* Gestionar usuarios.
* Gestionar personas.
* Gestionar unidades.
* Gestionar propietarios.
* Gestionar residentes.
* Ver información sensible dentro de la organización.
* Acceder a todas las propiedades de la organización.

No depende de `StaffAssignment`.

---

## Property Admin

Alcance:

```text
ResidentialProperty
```

Fuente:

```text
StaffAssignment(staff_type: property_admin)
```

Puede dentro de sus propiedades asignadas:

* Gestionar unidades.
* Gestionar secciones.
* Gestionar personas relacionadas a la propiedad.
* Gestionar propietarios.
* Gestionar residentes.
* Prepararse para gestionar visitas.
* Ver información sensible necesaria para administración.

No puede:

* Administrar propiedades no asignadas.
* Administrar usuarios globales de la organización.
* Ver datos de otras propiedades sin asignación.

---

## Concierge

Alcance:

```text
ResidentialProperty
```

Fuente:

```text
StaffAssignment(staff_type: concierge)
```

Puede dentro de sus propiedades asignadas:

* Consultar visitas autorizadas.
* Registrar ingreso de visitas.
* Registrar salida de visitas.
* Consultar información mínima necesaria para control de acceso.
* Consultar unidad destino de una visita.
* Consultar nombre de residente/propietario autorizante cuando aplique.

No puede:

* Crear propietarios.
* Editar propietarios.
* Crear residentes.
* Editar residentes.
* Gestionar personas.
* Ver documentos completos si no es estrictamente necesario.
* Administrar usuarios.
* Acceder a propiedades no asignadas.

---

## Cleaning Staff

Alcance:

```text
ResidentialProperty
```

Fuente:

```text
StaffAssignment(staff_type: cleaning_staff)
```

Permisos por defecto:

* Ninguno sobre datos sensibles.
* Acceso solo si una capability específica lo permite.

Regla:

```text
cleaning_staff no obtiene permisos administrativos por defecto.
```

---

## Internal Staff

Alcance:

```text
ResidentialProperty
```

Fuente:

```text
StaffAssignment(staff_type: internal_staff)
```

Permisos por defecto:

* Ninguno sobre datos sensibles.
* Puede recibir capacidades específicas en el futuro.

Regla:

```text
internal_staff no obtiene permisos por defecto.
```

---

## Owner

Alcance:

```text
Unit
```

Fuente:

```text
UnitOwnership activo
```

Puede en futuras visitas:

* Crear visitas para su unidad.
* Autorizar visitas para su unidad.
* Consultar visitas propias o de su unidad según reglas futuras.

No puede:

* Administrar unidades.
* Administrar residentes de otras unidades.
* Ver información sensible de terceros.

---

## Resident

Alcance:

```text
Unit
```

Fuente:

```text
UnitOccupancy activa
```

Puede en futuras visitas:

* Crear visitas para su unidad.
* Autorizar visitas para su unidad si el tipo de ocupación lo permite.
* Consultar visitas propias o de su unidad según reglas futuras.

No puede:

* Administrar otras unidades.
* Gestionar propietarios.
* Gestionar personas de terceros.

---

# Capability Catalog

Las policies no deberían preguntar directamente:

```ruby
user.admin?
```

Deberían consultar capacidades:

```ruby
can?(:manage_units, property)
```

o helpers equivalentes.

## Capabilities

| Capability                         | Descripción                                         |
| ---------------------------------- | --------------------------------------------------- |
| `manage_organization`              | Administrar configuración global de la organización |
| `manage_users`                     | Gestionar usuarios de la organización               |
| `manage_properties`                | Crear/editar propiedades                            |
| `manage_property`                  | Gestionar una propiedad específica                  |
| `manage_sections`                  | Gestionar secciones de una propiedad                |
| `manage_units`                     | Gestionar unidades                                  |
| `view_people`                      | Consultar personas                                  |
| `manage_people`                    | Crear/editar personas                               |
| `view_sensitive_person_data`       | Ver datos sensibles de personas                     |
| `manage_ownerships`                | Crear/editar/eliminar ownerships                    |
| `manage_occupancies`               | Crear/editar/eliminar occupancies                   |
| `view_visits`                      | Consultar visitas                                   |
| `manage_visits`                    | Gestionar visitas                                   |
| `create_visits`                    | Crear visitas                                       |
| `authorize_visits`                 | Autorizar visitas                                   |
| `register_visit_entry`             | Registrar ingreso                                   |
| `register_visit_exit`              | Registrar salida                                    |
| `view_minimal_access_control_data` | Ver datos mínimos para portería                     |
| `view_own_unit_context`            | Ver contexto de unidades propias                    |

---

# Capability Matrix

## Organization Admin

| Capability                   | Scope          |
| ---------------------------- | -------------- |
| `manage_organization`        | organization   |
| `manage_users`               | organization   |
| `manage_properties`          | organization   |
| `manage_property`            | all properties |
| `manage_sections`            | all properties |
| `manage_units`               | all properties |
| `view_people`                | organization   |
| `manage_people`              | organization   |
| `view_sensitive_person_data` | organization   |
| `manage_ownerships`          | all properties |
| `manage_occupancies`         | all properties |
| `view_visits`                | all properties |
| `manage_visits`              | all properties |

---

## Content Managger

| Capability                   | Scope          |
| ---------------------------- | -------------- |
| `manage_properties`          | organization   |
| `manage_sections`            | all properties |
| `manage_units`               | all properties |
| `view_people`                | organization   |
| `manage_people`              | organization   |
| `view_sensitive_person_data` | organization   |
| `manage_ownerships`          | all properties |
| `manage_occupancies`         | all properties |
| `view_visits`                | all properties |

---

## Property Admin

| Capability                   | Scope                     |
| ---------------------------- | ------------------------- |
| `manage_property`            | assigned property         |
| `manage_sections`            | assigned property         |
| `manage_units`               | assigned property         |
| `view_people`                | assigned property context |
| `manage_people`              | assigned property context |
| `view_sensitive_person_data` | assigned property context |
| `manage_ownerships`          | assigned property         |
| `manage_occupancies`         | assigned property         |
| `view_visits`                | assigned property         |
| `manage_visits`              | assigned property         |

---

## Concierge

| Capability                         | Scope             |
| ---------------------------------- | ----------------- |
| `view_visits`                      | assigned property |
| `register_visit_entry`             | assigned property |
| `register_visit_exit`              | assigned property |
| `view_minimal_access_control_data` | assigned property |

---

## Owner

| Capability              | Scope      |
| ----------------------- | ---------- |
| `create_visits`         | owned unit |
| `authorize_visits`      | owned unit |
| `view_own_unit_context` | owned unit |

---

## Resident

| Capability              | Scope                                       |
| ----------------------- | ------------------------------------------- |
| `create_visits`         | occupied unit                               |
| `authorize_visits`      | occupied unit, if allowed by occupancy type |
| `view_own_unit_context` | occupied unit                               |

---

## Cleaning Staff / Internal Staff

No obtienen permisos administrativos por defecto.

Pueden recibir capacidades explícitas en una futura matriz configurable.

---

# Authorization Resolver

## Class

```ruby
Authorization::Resolver
```

## Responsibility

Resolver capacidades efectivas de un usuario dentro de una organización y, cuando aplique, dentro de una propiedad o unidad.

## Inputs

```ruby
user
organization
property: nil
unit: nil
```

## Output

Debe exponer una API clara para policies:

```ruby
resolver.can?(:manage_units, property)
resolver.can?(:manage_ownerships, unit)
resolver.accessible_properties_for(:manage_units)
resolver.accessible_units_for(:create_visits)
```

## Resolution Flow

```text
1. Validar que el user pertenece a la organization.
2. Resolver organization membership.
3. Resolver person asociada al user dentro de la organization.
4. Resolver staff assignments activos de esa person.
5. Resolver ownerships activos de esa person.
6. Resolver occupancies activos de esa person.
7. Construir capacidades efectivas.
8. Aplicar alcance organization/property/unit.
```

## Important Rule

`Authorization::Resolver` siempre debe partir desde `User`.

No debe autorizar directamente desde `Person`.

---

# Property Scope

## Class

```ruby
Authorization::PropertyScope
```

## Responsibility

Resolver qué propiedades puede ver u operar un usuario según sus capacidades.

## Methods

```ruby
accessible_properties
managed_properties
concierge_properties
staff_properties
owned_unit_properties
occupied_unit_properties
```

## Rules

### Organization Admin

Retorna todas las propiedades de la organización.

### Property Admin

Retorna solo propiedades donde tiene `StaffAssignment` activo como `property_admin`.

### Concierge

Retorna solo propiedades donde tiene `StaffAssignment` activo como `concierge`.

### Cleaning Staff / Internal Staff

Retorna propiedades asignadas, pero sin permisos administrativos por defecto.

### Owner / Resident

Retorna propiedades relacionadas con sus unidades activas.

---

# Policy Strategy

## ApplicationPolicy

Debe dejar de depender exclusivamente de:

```ruby
admin?
```

Agregar helpers:

```ruby
authorization
can?(capability, resource = nil)
property_for(record)
unit_for(record)
organization_for(record)
```

Ejemplo:

```ruby
def can?(capability, resource = record)
  authorization.can?(capability, resource)
end
```

`ApplicationPolicy` debe centralizar acceso a `Authorization::Resolver`.

---

## ResidentialPropertyPolicy

| Acción     | Regla                                                       |
| ---------- | ----------------------------------------------------------- |
| `index?`   | usuario con alguna propiedad accesible o organization admin |
| `show?`    | organization admin o asignación en propiedad                |
| `create?`  | organization admin                                          |
| `update?`  | organization admin o property_admin de esa propiedad        |
| `destroy?` | organization admin                                          |

---

## PropertySectionPolicy

| Acción                             | Regla                                               |
| ---------------------------------- | --------------------------------------------------- |
| `index?` / `show?`                 | property_admin o organization admin,content_managger                 |
| `create?` / `update?` / `destroy?` | property_admin de la propiedad u organization admin, content_managger |

---

## UnitPolicy

| Acción                             | Regla                                                                   |
| ---------------------------------- | ----------------------------------------------------------------------- |
| `index?`                           | property_admin, concierge con vista mínima, owner/resident según unidad, content_managger |
| `show?`                            | property_admin, owner/resident de la unidad, organization admin, content_managger         |
| `create?` / `update?` / `destroy?` | property_admin u organization admin, content_managger                                     |

Conserje no gestiona unidades.

---

## PersonPolicy

| Acción                | Regla                                                                                                               |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `index?`              | organization admin o property_admin                                                                                 |
| `show?`               | organization admin, property_admin si persona está relacionada a su propiedad, owner/resident solo su propio perfil, content_managger |
| `create?` / `update?` | organization admin o property_admin dentro de su propiedad, content_managger                                                          |
| `destroy?`            | organization admin, content_managger                                                                                                  |

Conserje no debe tener acceso general a perfiles de persona.

Para visitas futuras, conserje solo debe acceder a datos mínimos mediante capability específica.

---

## UnitOwnershipPolicy

| Acción                             | Regla                                               |
| ---------------------------------- | --------------------------------------------------- |
| `index?` / `show?`                 | organization admin o property_admin de la propiedad, content_managger |
| `create?` / `update?` / `destroy?` | `manage_ownerships` sobre la propiedad, content_managger              |

Owner no gestiona ownerships.

Concierge no gestiona ownerships.

---

## UnitOccupancyPolicy

| Acción                             | Regla                                               |
| ---------------------------------- | --------------------------------------------------- |
| `index?` / `show?`                 | organization admin o property_admin de la propiedad, content_managger |
| `create?` / `update?` / `destroy?` | `manage_occupancies` sobre la propiedad, content_managger             |

Resident no gestiona occupancies.

Concierge no gestiona occupancies.

---

## BulkImportPolicy

| Acción                              | Regla                                                                                  |
| ----------------------------------- | -------------------------------------------------------------------------------------- |
| `create?` / `validate?` / `import?` | organization admin o property_admin si el import está acotado a una propiedad asignada |
| `show?` / `status?`                 | organization admin o property_admin de la propiedad del import                         |

---

## UserPolicy

| Acción                             | Regla              |
| ---------------------------------- | ------------------ |
| `index?` / `show?`                 | organization admin |
| `create?` / `update?` / `destroy?` | organization admin |

Property admin no gestiona usuarios globales en MVP.

---

## VisitPolicy Placeholder

No se implementa CRUD de visitas en este cambio.

Pero se define contrato futuro.

| Acción       | Regla esperada                              |
| ------------ | ------------------------------------------- |
| `create?`    | owner/resident de la unidad, property_admin |
| `authorize?` | owner/resident autorizado de la unidad      |
| `check_in?`  | concierge o property_admin de la propiedad  |
| `check_out?` | concierge o property_admin de la propiedad  |
| `index?`     | según property scope                        |
| `show?`      | según relación con unidad o propiedad       |

---

# Policy Scopes

Cada policy scope debe aplicar:

```text
organization_id
+
property scope
+
capability
```

## Example: UnitPolicy::Scope

```text
organization_admin:
  all units in organization

property_admin:
  units from assigned properties

concierge:
  units from assigned properties, only if needed for access-control context

owner/resident:
  own units only
```

## Example: PersonPolicy::Scope

```text
organization_admin:
  all people in organization

property_admin:
  people related to assigned properties through ownerships/occupancies/staff assignments

concierge:
  no general person listing in MVP

owner/resident:
  own person record only
```

---

# Data Model

## Existing StaffAssignment

`StaffAssignment` is used as operational role assignment per property.

Expected fields:

```text
person_id
residential_property_id
staff_type
status / active
starts_at
ends_at
```

No new table is required for MVP if `StaffAssignment` already supports:

* person
* property
* staff type
* active/inactive lifecycle

## Staff Type Mapping

| staff_type                    | Operational role |
| ----------------------------- | ---------------- |
| `manager` / `property_admin`  | `property_admin` |
| `concierge`                   | `concierge`      |
| `cleaning` / `cleaning_staff` | `cleaning_staff` |
| `internal` / `internal_staff` | `internal_staff` |

If current constants differ, define mapping in `Authorization::StaffRoleMapper`.

---

# Security Rules

## Organization Isolation

No policy may authorize access to records outside the current organization.

Every resolver query must be scoped by organization.

## Property Isolation

Property roles only apply to their assigned property.

A `property_admin` of Property A cannot manage Property B.

A `concierge` of Property A cannot view visits or residents of Property B.

## Sensitive Data

Sensitive person data includes:

* full document number
* phone
* email
* resident/owner relationship
* visit history

Only these roles may access sensitive data:

* organization admin, content_managger
* property admin for related property

Concierge receives only minimal access-control data.

## Minimal Access for Concierge

Concierge can access:

* visitor name
* unit destination
* visit status
* authorization status
* check-in/check-out status

Concierge should not access:

* full person profile
* ownership percentages
* resident management
* user management
* document details beyond what is required for access control

---

# Frontend Contract

No new UI is implemented in this change.

However, backend should expose a stable contract for future UI.

## Suggested props

```ts
type OperationalCapabilities = {
  manageOrganization: boolean
  manageUsers: boolean
  manageProperties: boolean
  manageUnits: boolean
  managePeople: boolean
  manageOwnerships: boolean
  manageOccupancies: boolean
  manageVisits: boolean
  createVisits: boolean
  authorizeVisits: boolean
  registerVisitEntry: boolean
  registerVisitExit: boolean
}

type ManagedProperty = {
  id: string
  name: string
  roles: string[]
}
```

Possible usage:

```text
permissions
capabilities
managed_properties
staff_assignments_summary
```

---

# Migration Plan

## Phase 1: Authorization core

* Add `Authorization::Capabilities`.
* Add `Authorization::Resolver`.
* Add `Authorization::PropertyScope`.
* Add staff role mapping if needed.

## Phase 2: Policy integration

Update:

* `ApplicationPolicy`
* `ResidentialPropertyPolicy`
* `PropertySectionPolicy`
* `UnitPolicy`
* `PersonPolicy`
* `UnitOwnershipPolicy`
* `UnitOccupancyPolicy`
* `BulkImportPolicy`
* `UserPolicy`

## Phase 3: Future visit contract

Add placeholder `VisitPolicy` or documented policy contract.

Do not implement visit models or controllers.

## Phase 4: Compatibility

Map existing `tenant_admin` behavior to organization-level capability.

Document behavioral breaking change for `client`.

---

# Testing Strategy

## Resolver tests

Cover:

* organization admin gets organization-wide capabilities
* property admin gets capabilities only for assigned property
* concierge gets only access-control capabilities
* owner gets unit-scoped capabilities
* resident gets unit-scoped capabilities
* internal staff gets no default sensitive capabilities
* user without membership gets no capabilities

## Property scope tests

Cover:

* organization admin sees all properties
* property admin sees assigned properties only
* concierge sees assigned properties only
* owner/resident sees related properties only
* cross-organization properties are never returned

## Policy tests

Cover:

* `PersonPolicy`
* `UnitPolicy`
* `UnitOwnershipPolicy`
* `UnitOccupancyPolicy`
* `ResidentialPropertyPolicy`
* `PropertySectionPolicy`
* `BulkImportPolicy`
* `UserPolicy`

## Security tests

Cover:

* cross-organization denial
* cross-property denial
* concierge cannot manage ownerships
* concierge cannot manage occupancies
* property admin cannot manage unassigned property
* owner/resident cannot access other units
* `client` without operational assignment loses admin access

---
## UX References / Mockups

The following mockups define the intended user experience for future operational role management screens. They are reference material for the authorization model and frontend contracts, but they do not require implementing new role-management screens in this change unless explicitly added to `tasks.md`.

* `mockups/roles_list.png`
  Reference for the future operational roles/users listing. It shows how administrators should review users, linked people, assigned properties, operational roles, account status, and available actions.

* `mockups/details_per_rol.png`
  Reference for a future role detail view. It shows how a specific operational role should explain its scope, capabilities, assigned users, and restrictions.

* `mockups/matrix_of_permissions.png`
  Reference for the capability matrix. It should stay aligned with `Authorization::Capabilities` and the role-to-capability map used by `Authorization::Resolver`.

* `mockups/assign_roles_view.png`
  Reference for the future role assignment flow. It shows how administrators should assign or revoke property-scoped roles such as `property_admin`, `concierge`, `cleaning_staff`, and `internal_staff`.


# Risks / Trade-offs

## Risk: StaffAssignment is person-based while authorization is user-based

Authorization starts from `User`, but property roles are stored on `Person`.

Mitigation:

```text
Authorization::Resolver resolves user → person → staff assignments.
```

If a user has no associated person in the organization, property staff capabilities cannot be resolved.

---

## Risk: Existing policies assume admin?

Some policies may rely on `admin?`.

Mitigation:

```text
Keep admin? temporarily as organization admin helper, but migrate policies to capabilities.
```

---

## Risk: Concierge sees too much data

Mitigation:

```text
Define separate capability view_minimal_access_control_data.
Do not reuse PersonPolicy#show? for concierge visit workflows.
```

---

## Risk: Property admin needs limited user visibility

MVP decision:

```text
Property admin does not manage users globally.
```

Future change can add delegated user invitations scoped by property.

---

## Risk: Staff type naming mismatch

Current `StaffAssignment.staff_type` values may not match desired operational roles.

Mitigation:

```text
Use Authorization::StaffRoleMapper.
Avoid hardcoding raw staff_type values across policies.
```

---

# Open Questions

* ¿`tenant_admin` será el nombre final o debe normalizarse a `organization_admin`?
* ¿`StaffAssignment` ya tiene lifecycle suficiente (`active`, `starts_at`, `ends_at`) o requiere ajuste futuro?
* ¿`property_admin` podrá invitar usuarios en una fase posterior?
* ¿Residente y propietario tienen siempre las mismas capacidades sobre visitas o dependerá de configuración por unidad/propiedad?
* ¿Conserje podrá buscar personas libremente o solo consultar visitas autorizadas?
* ¿Qué datos mínimos de documento necesita portería para validar identidad sin exponer información sensible completa?


