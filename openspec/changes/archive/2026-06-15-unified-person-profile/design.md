## Context

`Person` es hoy la tabla de identidad para propietarios, residentes y membresías. `person_type` distingue natural/jurídica, no el rol contextual. La deduplicación está dispersa en `UnitOwnerships::FindExistingPerson` y `BulkImportServices::ResolveImportOwnerPerson`. No existe ruta `show` en `Admin::PeopleController`; el listado enlaza solo a `edit`.

Patrones UX de referencia en el proyecto:
- `admin/units/show.vue` — `TabNav`, paneles por tab, `UnitPlaceholderTab` para secciones futuras
- `UnitOwnersPanel` / `UnitOccupantsPanel` — tablas paginadas, drawers, empty states
- `UnitChangeHistorySidebar` — historial lateral en vista de unidad
- Shadcn Vue, Inertia, `AdminDataTable`, badges y breadcrumbs existentes

`visitor_profiles` tiene `person_id` opcional; visitas futuras y staff laboral aún no tienen tablas de asignación.

## Goals / Non-Goals

**Goals:**

- `people` como única entidad de identidad por organización.
- Servicio central de deduplicación y validaciones de unicidad.
- Roles contextuales derivados con soporte de múltiples roles simultáneos.
- Pantalla **Perfil Unificado de Persona** con 6 tabs y navegación desde listado, propietarios y residentes.
- Compatibilidad total con ownerships/occupancies existentes.
- Preparar tabs Staff y Visitas sin datos reales iniciales.

**Non-Goals:**

- Implementar visitas o staff operativo.
- Eliminar `visitor_profiles`.
- Crear tablas `owners`, `visitors`, `staff_people`.
- Reemplazar flujos de edición existentes (`edit` permanece para mutaciones).

## Decisions

### 1. Identidad única en `Person`

Toda identidad vive en `people`. Roles operativos solo vía relaciones contextuales. Rechazado: tablas por rol o columna `role_type` única.

### 2. Roles contextuales derivados

`People::ContextualRoles` calcula badges/roles:

| Clave API | Badge UI | Fuente |
|---|---|---|
| `owner` | Propietario | `unit_ownerships` activos |
| `resident` | Residente | `unit_occupancies` activos |
| `visitor` | Visitante | `visitor_profiles` o futuros `visit_participants` |
| `concierge` | Conserje | futura asignación staff |
| `property_admin` | Administrador | futura asignación staff |
| `cleaning_staff` | Personal de aseo | futura asignación staff |
| `system_user` | Usuario | `user_id` presente |

Rolify (`tenant_admin`, `manager`, etc.) se expone aparte como `tenant_role` en tab Resumen; no se mezcla con badges de dominio residencial.

Una persona puede acumular varios badges (ej. Propietario + Residente + Usuario).

### 3. Resolver central `People::FindExisting`

Prioridad: (1) `document_number_digest`, (2) email vía `User#person_for`, (3) `metadata.import_email`. Excluye soft-deleted. `UnitOwnerships::FindExistingPerson` y `ResolveImportOwnerPerson` delegan aquí.

### 4. Validación de unicidad en `Person`

Validación app + índice DB existente para documento. Email: validación app; migración opcional `email_digest` en follow-up.

### 5. Ruta y controller `show`

Añadir `resources :people, only: [..., :show]` y `Admin::PeopleController#show` que renderiza Inertia `admin/people/show` con props paginadas por tab cuando aplique.

`edit` sigue para formulario de edición; `show` es vista de consulta. El listado y tablas de unidad enlazan a `show`; acción "Editar" dentro del perfil lleva a `edit`.

### 6. Layout del perfil (UX)

**Header (`PersonProfileHeader`):**
- Nombre completo (`display_name`)
- Documento, email, teléfono, estado (`status`)
- Fila de `Badge` por cada rol contextual calculado
- Acción secundaria: Editar persona

**Tabs (`TabNav`, mismo componente que unidad):**

| Tab | Contenido | Fase |
|---|---|---|
| Resumen | Datos personales, usuario asociado, roles, fechas (created_at, membership) | Implementar |
| Propiedades | Tabla ownerships: propiedad, sección, unidad, %, estado | Implementar |
| Residencias | Tabla occupancies: propiedad, sección, unidad, tipo, estado | Implementar |
| Staff | Tabla propiedades donde trabaja | Placeholder + empty state |
| Visitas | Historial de visitas | Placeholder + empty state |
| Historial | Auditoría de `Person`, ownerships, occupancies | Implementar |

Reutilizar `AdminDataTable`, `UnitPlaceholderTab` (o variante), empty states i18n consistentes con owners/occupants.

**Historial:** reutilizar patrón de `UnitChangeHistorySidebar` o tabla de audits filtrada por `person_id` y asociaciones. Cargar en tab Historial (no sidebar lateral en v1 del perfil, para simplificar layout).

**Summary Metrics (cards):**

Mostrar métricas rápidas:

- Propiedades activas
- Residencias activas
- Visitas registradas
- Propiedades donde trabaja

Las métricas se muestran como cards compactas debajo del header.

### 7. Serializers y props

`Admin::PersonProfileSerializer` (o extensión de `PersonSerializer`) para header.

Tablas:
- `Admin::PersonOwnershipRowSerializer` — denormaliza property, section, unit, percentage, status
- `Admin::PersonOccupancyRowSerializer` — denormaliza property, section, unit, occupancy_type, status

Props de `show`:
```ruby
{
  person: ...,
  contextual_roles: [...],
  ownerships: [...], ownerships_pagination: ...,
  occupancies: [...], occupancies_pagination: ...,
  staff_assignments: [],          # placeholder
  visits: [],                     # placeholder
  change_history: [...],
  permissions: { update: ..., destroy: ... }
}
```

Paginación server-side en Propiedades y Residencias si el volumen lo requiere (mismo patrón que unit show).

### 8. Navegación transversal

| Origen | Acción |
|---|---|
| `admin/people/index` | Clic en fila o acción "Ver perfil" → `show` |
| `UnitOwnersTable` | Nombre de persona como enlace → `show` |
| `UnitOccupantsTable` | Nombre de persona como enlace → `show` |
| Futuras visitas | Enlace a `show` (contrato preparado) |

Breadcrumbs: `Personas > {display_name}` vía `getPeopleBreadcrumbs` extendido.

### 9. Asociaciones en `Person`

Añadir `has_many :unit_occupancies`, `has_many :visitor_profiles, optional transitional association`. Scopes `with_active_ownerships`, `with_active_occupancies`.

### 10. Estrategia `visitor_profiles` y staff

`VisitorProfile` = perfil extendido con `person_id` canónico. Tab Visitas muestra empty state con copy preparado.

Staff futuro: tabla de asignaciones `(person_id, residential_property_id, staff_role)` — **no crear en este change**. Tab Staff con columnas definidas (Propiedad, Rol, Estado) y empty state.

### 11. Compatibilidad

Sin migración de datos. Servicios `CreateWithPerson` adoptan resolver central. Flujos existentes intactos.

## Risks / Trade-offs

- **[Riesgo] N+1 en tablas de perfil** → `includes(unit: { property_section: :residential_property })` en queries.
- **[Riesgo] Email sin constraint DB** → validación app; `email_digest` opcional después.
- **[Riesgo] Confusión tenant_role vs contextual_roles** → API y UI separados; labels distintos en Resumen.
- **[Riesgo] Duplicados históricos** → dedup solo en altas/ediciones nuevas.
- **[Trade-off] Tabs Staff/Visitas vacíos** → empty states claros evitan sensación de bug.

## Migration Plan

1. Servicio central + modelo Person.
2. Controller `show`, serializers, policy.
3. Página Vue y componentes de perfil.
4. Enlaces desde index, owners, occupants.
5. Tests y despliegue.

Rollback: revertir ruta/show y enlaces; sin cambios destructivos.

## Decision: email_digest y deduplicación

**Decisión (cerrada):** No se añade columna `email_digest` ni índice único de email a nivel DB en este change.

- **Documento:** deduplicación vía `document_number_digest` con índice DB existente.
- **Email:** validación en aplicación (`Person` uniqueness scope) y resolución central en `People::FindExisting` (prioridad: digest → `User#person_for` → `metadata.import_email`).
- **Follow-up opcional:** migración `email_digest` + índice único parcial si el volumen o colisiones lo justifican.

## Open Questions

- ¿Paginación en tabs Propiedades/Residencias desde v1 o cargar todo si < N registros?
- ¿Tab Historial unifica audits de Person + ownerships + occupancies o solo Person?
- ¿Normalizar `metadata.import_email` a columna dedicada en este change?
- ¿Las tabs Visitas y Staff deben ocultarse cuando no exista funcionalidad implementada o mostrarse siempre con empty state?