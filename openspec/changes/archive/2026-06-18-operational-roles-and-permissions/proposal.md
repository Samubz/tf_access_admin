## Why

La plataforma ya gestiona identidad (`Person`), propiedades, unidades, propietarios y residentes, pero la autorización operacional sigue siendo binaria: `super_admin` / `tenant_admin` o nada. Las políticas Pundit existentes (`PersonPolicy`, `UnitPolicy`, `UnitOwnershipPolicy`, `UnitOccupancyPolicy`, etc.) delegan en `ApplicationPolicy#admin?` sin distinguir administración por propiedad, conserjería, residentes/propietarios ni personal interno con permisos limitados.

Antes de implementar visitas —que expondrán datos sensibles de personas, documentos, teléfonos, propietarios, residentes e historial de ingresos/salidas— hace falta un modelo formal de roles operativos y permisos que defina quién puede acceder y modificar cada recurso, con aislamiento estricto por organización y alcance por propiedad.

## What Changes

- Definir un **modelo de autorización operacional** separado de la identidad de `Person`: capacidades derivadas de `User`, `OrganizationMembership` y asignaciones por propiedad (`StaffAssignment`), no de atributos de persona.
- Formalizar roles operativos MVP separados por alcance:
  - Organización: Super Admin de Organización, content managger.
  - Propiedad: Administrador de Propiedad, Conserje/Portería, Personal Interno.
  - Unidad: Residente/Propietario, derivado desde `UnitOccupancy` y `UnitOwnership`.
- Introducir un **resolver de capacidades** (`Authorization::Resolver`) que combine rol organizacional, asignaciones staff activas, ownerships y occupancies del `Person` vinculado al `User`.
- Extender `ApplicationPolicy` y políticas existentes con helpers de capacidad y **policy scopes** acotados por organización y, cuando aplique, por `ResidentialProperty` accesible.
- Activar integración operacional de `StaffAssignment` (tabla ya migrada) como fuente de roles por propiedad para autorización y badges contextuales.
- Las asignaciones operativas por propiedad se resuelven desde el `User` autenticado hacia su `Person` asociada y luego hacia `StaffAssignment` activo.
- Preparar contrato de dominio y permisos base para futuras `VisitPolicy` y flujos de visitas (crear, autorizar, registrar ingreso/salida, consulta mínima en portería).
- Definir contrato de datos para futuras pantallas de gestión de usuarios y permisos (sin implementar UI en este cambio).
- **BREAKING (comportamiento):** usuarios que hoy solo tienen rol `client` dejarán de poder acceder a recursos admin aunque tengan `Person` en la organización; el acceso admin requerirá rol organizacional o asignación operacional explícita. Esto reduce exposición accidental de datos sensibles antes del módulo de visitas.
- Separar explícitamente roles organizacionales de roles por propiedad: `tenant_admin`/`organization_admin` no equivale a `property_admin`, y `property_admin` no otorga acceso global a la organización.
- Personal Interno no obtiene permisos por defecto; sus capacidades deben ser explícitas según `staff_type` o futuras reglas configurables.

## Business Rules

- Los roles de propiedad nunca son globales.
- Un usuario puede tener distintos roles en distintas propiedades.
- Un conserje solo puede acceder a la información mínima necesaria de la propiedad donde está asignado.
- Un administrador de propiedad solo puede gestionar recursos pertenecientes a sus propiedades asignadas.
- Residente/Propietario solo puede operar sobre unidades donde tenga ownership u occupancy activa.
- `Person` representa identidad; no define permisos por sí misma.
- Los roles operativos de propiedad se obtienen desde asignaciones activas (`StaffAssignment`) asociadas a la propiedad correspondiente.
- Residente y Propietario son capacidades derivadas desde `UnitOccupancy` y `UnitOwnership`; no son roles persistidos en `User` ni en `Person`.

## Capabilities

### New Capabilities

- `operational-roles-and-permissions`: modelo de autorización, roles operativos MVP, matriz de permisos, policy scopes, aislamiento multi-tenant, administración por propiedad, integración Pundit y preparación para visitas.

### Modified Capabilities

- `unit-owner-management`: requisitos de autorización de mutaciones de `UnitOwnership` pasan de "admin de organización" a capacidades operacionales (`manage_ownerships`) con alcance por propiedad.
- `unit-occupancy-management`: requisitos de autorización de mutaciones de `UnitOccupancy` pasan de "admin de organización" a capacidades operacionales (`manage_occupancies`) con alcance por propiedad.
- `unified-person-profile`: badges staff (`concierge`, `property_admin`, `cleaning_staff`) se derivan de `StaffAssignment` activo; permisos de consulta/edición del perfil respetan capacidades operacionales.

## Impact

**Bounded context:** Authentication & Authorization transversal a Organizations, Residential Properties, Units, Persons, Visits (futuro).

**Modelos afectados:**
- `User`, `Person`, `OrganizationMembership` (resolución de capacidades; sin nueva cardinalidad obligatoria)
- `StaffAssignment` (activación operacional; ya existe con `person_id`, `residential_property_id`, `staff_type`)
- `UnitOwnership`, `UnitOccupancy` (fuente de capacidades residente/propietario)
- Futuro: `Visit`, `VisitAuthorization` consumirán el mismo resolver

**Backend nuevo o extendido:**
- `Authorization::Capabilities` — catálogo de capacidades
- `Authorization::Resolver` — resolución efectiva por usuario dentro de una organización y, cuando aplique, una propiedad específica.
- `Authorization::PropertyScope` — propiedades accesibles para policy scopes
- Extensión de `ApplicationPolicy` y políticas: `PersonPolicy`, `UnitPolicy`, `UnitOwnershipPolicy`, `UnitOccupancyPolicy`, `ResidentialPropertyPolicy`, `UserPolicy`, `PropertySectionPolicy`, `BulkImportPolicy`
- Placeholder `VisitPolicy` con métodos y scopes definidos (sin CRUD de visitas)
- Serializers/contratos para gestión futura de usuarios: `operational_role`, `managed_properties`, `staff_assignments_summary`

**Frontend (preparación, sin pantallas nuevas):**
- Props `permissions` / `capabilities` en layouts o páginas admin existentes
- Contrato TypeScript para futura UI de usuarios y asignaciones de permisos

**Policies y tests:**
- Specs de políticas por rol y por alcance de propiedad
- Tests del resolver de capacidades y policy scopes
- Tests de aislamiento cross-organization y cross-property

**Migraciones:** ninguna tabla nueva requerida para MVP; posible data migration para mapear `tenant_admin` existentes y documentar equivalencia `StaffTypes::MANAGER` ↔ administrador de propiedad.

**Fuera de alcance explícito:**
- CRUD de visitas
- Pantallas de gestión de usuarios y asignación de permisos (solo contrato de dominio)
- Portal self-service para residentes/propietarios (solo definición de capacidades)
- Migración de Rolify desde `Person` a `User` (evaluada en design; no obligatoria en MVP si el resolver abstrae la fuente)
