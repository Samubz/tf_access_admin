# Refine Units Foundation Spec

## Why

`Unit` ya tiene una base tenant-safe, property-scoped y section-aware, pero el
flujo necesita cerrar algunos bordes del contrato para que creación,
actualización, movimiento, archive, búsqueda, autorización y bulk import usen
las mismas reglas.

Este change refina el contrato OpenSpec existente sin introducir cambios de
implementación en esta etapa. Su objetivo es evitar bypasses por update genérico,
separar lectura de mutación, aclarar unicidad por organización, mantener `metadata`
como dato no autoritativo y alinear bulk import con los servicios canónicos.

## What Changes

* Explicitar que el mismo `normalized_identifier` puede existir en otra
  organización.
* Impedir que `Units::Update` cambie organización, propiedad, sección o archive
  una unidad.
* Permitir que update solo cambie datos descriptivos u operational status dentro
  del contrato permitido.
* Alinear bulk import con `Units::Create`, `Units::Update` y
  `Units::MoveToSection` según el modo de importación configurado.
* Separar lectura con `view_units` de mutación con `manage_units`.
* Ajustar los scenarios de tenant admin, property admin y concierge para usar
  capabilities y `StaffAssignment` vigentes.
* Reforzar `UnitPolicy::Scope` para excluir propiedades fuera del alcance
  asignado.
* Aclarar que la búsqueda normaliza el input antes de consultar
  `normalized_identifier`.
* Declarar que `metadata` no puede reemplazar campos estructurales ni conceder
  autorización.
* Explicitar que `area_m2` puede estar ausente y que solo se valida como
  positivo cuando está presente.
* Mover la regla de property archivada a un requirement propio de lifecycle de
  property.

## Impact

**Capability afectada:**

* `unit`

**Dependencias conceptuales:**

* `residential-property`: el lifecycle de la propiedad limita mutaciones
  ordinarias del catálogo de unidades.
* `property-section`: la elegibilidad y actividad efectiva de secciones siguen
  delegadas a su contrato.
* `operational-roles-and-permissions`: autorización mediante `view_units`,
  `manage_units` y `StaffAssignment` activo por propiedad.

## Out of Scope

* Rediseñar completamente el CRUD de unidades o su UI.
* Rediseñar completamente bulk import o su interfaz.
* Cambiar catálogos base de tipos o estados fuera del contrato existente.
* Cambiar el contrato de `property-section`.
* Introducir roles globales.
