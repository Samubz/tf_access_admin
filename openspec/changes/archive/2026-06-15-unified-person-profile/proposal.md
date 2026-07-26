## Why

La plataforma ya gestiona propietarios (`UnitOwnership`) y residentes (`UnitOccupancy`) sobre la entidad `Person`, pero la identidad de persona aún no está formalizada como núcleo del dominio ni existe un lugar único para consultar todos los contextos de una persona. Antes de implementar visitas y staff operativo, hace falta consolidar `Person` como **fuente única de identidad** por organización y ofrecer un **Perfil Unificado de Persona** donde visualizar datos personales, relación con usuario, unidades, propiedades, roles calculados y (en el futuro) visitas y staff.

Sin esta base, cada flujo resuelve personas de forma parcial, no hay visibilidad transversal de contextos y se compromete deduplicación, auditoría y aislamiento multi-tenant.

## What Changes

- Formalizar `Person` como entidad única de identidad dentro de una organización; **no** crear tablas paralelas (`owners`, `visitors`, `staff_people`, `residents`).
- Centralizar deduplicación por `document_number_digest` y email normalizado en un servicio compartido.
- Definir **roles contextuales derivados** (no almacenados como atributo principal) desde relaciones:
  - Propietario → `unit_ownerships`
  - Residente/ocupante → `unit_occupancies`
  - Visitante → futuras visitas asociadas a `Person`
  - Conserje, administrador, personal de aseo → futuras asignaciones laborales por propiedad
  - Usuario del sistema → `people.user_id` opcional + Rolify
- Nueva pantalla admin **Perfil Unificado de Persona** (`show`) con header, badges de roles y tabs: Resumen, Propiedades, Residencias, Staff, Visitas, Historial.
- Navegación al perfil desde listado de personas, tablas de propietarios/residentes en unidad y (futuro) visitas.
- Completar modelo `Person` (asociaciones, validaciones, API de roles) sin romper datos existentes.
- Tabs Staff y Visitas como estructura preparada con empty states; datos reales en cambios futuros.
- Mantener `edit` para edición de datos personales; el perfil es vista de consulta y contexto.
- Consolidar toda la información contextual de una persona en una única pantalla de consulta, evitando navegación entre módulos para reconstruir su contexto.
- Header consolidado con información principal de la persona, badges de roles calculados y acceso rápido a acciones disponibles.

## Capabilities

### New Capabilities

- `unified-person-profile`: Identidad única por organización, deduplicación, roles derivados, relación opcional con `User`, pantalla de perfil unificado con tabs y navegación transversal desde ownerships/occupancies.

### Modified Capabilities

- _(ninguna — `unit-owner-management` y `unit-occupancy-management` no cambian requisitos; añadirán enlaces al perfil como detalle de implementación)_

## Impact

**Bounded context:** Persons (identidad) transversal a Units, Residential Properties, Visits (futuro) y Organization membership.

**Modelos afectados:**
- `Person` (asociaciones, validaciones, roles contextuales)
- `User`, `OrganizationMembership` (sin cambio de cardinalidad)
- `UnitOwnership`, `UnitOccupancy` (consumidores del resolver; datos en tabs del perfil)
- Futuras entidades de visitas consumirán `Person` como identidad principal; la tab Visitas se prepara como estructura sin datos reales.

**Backend nuevo o extendido:**
- `People::FindExisting` — deduplicación centralizada
- `People::ContextualRoles` — roles derivados
- `Admin::PeopleController#show` + ruta `GET /admin/people/:id`
- Serializers de perfil: ownerships, occupancies, auditoría, placeholders staff/visitas

**Frontend (Inertia + Vue + Shadcn):**
- `admin/people/show.vue` — perfil unificado con `TabNav`
- Componentes: `PersonProfileHeader`, tabs (`PersonSummaryTab`, `PersonOwnershipsTab`, `PersonOccupanciesTab`, `PersonStaffTab`, `PersonVisitsTab`, `PersonHistoryTab`)
- Enlaces desde `admin/people/index`, `UnitOwnersTable`, `UnitOccupantsTable`
- Empty states y tablas reutilizando patrones de Unit Owners / Occupancies

**Policies:** `PersonPolicy#show?`

**Tests:** resolver, modelo, controller show, integración navegación, políticas

**Migraciones:** evaluar necesidad de `email_digest` e índices de soporte para deduplicación; evitar cambios de esquema innecesarios.

**Fuera de alcance explícito:**
- CRUD de visitas (solo tab preparado)
- CRUD de staff / asignaciones laborales (solo tab preparado)
- Eliminación de `visitor_profiles`
- Migración masiva de datos históricos duplicados

## Business Rules

- Una persona existe una sola vez por organización.
- Deduplicación por `document_number_digest` y email normalizado.
- Una persona puede estar asociada a múltiples propiedades de la misma organización.
- Múltiples ownerships, occupancies y asignaciones de propiedad por persona.
- Una persona puede ser propietaria, residente y visitante simultáneamente.
- Los roles contextuales se derivan exclusivamente de relaciones del dominio y no de columnas persistidas en `Person`.
- Asociación `Person` ↔ `User` opcional.
- Aislamiento estricto por `organization_id`.
