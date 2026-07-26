# Improve Units Flow Design

## Context

Este change refina el contrato de `Unit` definido por
`improve-units-foundation`. La implementación ya debe tratar a una unidad como
un recurso tenant-safe, ligado a una `ResidentialProperty`, opcionalmente
ubicado en una `PropertySection`, con normalización canónica de identificador,
lifecycle explícito y autorización property-scoped.

El problema a resolver es de precisión contractual: algunos flujos pueden quedar
ambiguos si update genérico, bulk import, búsqueda, metadata o policy scope no
expresan exactamente qué está permitido.

## Decisions

### Update is descriptive and operational only

`Units::Update` no es un canal para mover unidades ni ejecutar lifecycle
operations. Organización, propiedad y sección son placement fields protegidos.
Archive debe pasar por `Units::Archive`, y los cambios de sección por
`Units::MoveToSection`.

Update puede persistir cambios descriptivos y cambios de operational status
permitidos, como `available` a `inactive` o `maintenance`, siempre dentro del
contrato de estados. `status = archived` no es un operational status permitido
para update genérico y requiere `Units::Archive`.

### Bulk import follows explicit modes

Bulk import no mantiene reglas paralelas de normalización ni unicidad. Las filas
de creación delegan a `Units::Create`.

Cuando una fila coincide con una unidad existente, solo puede actualizar datos si
el modo de importación permite updates. Si la fila cambia placement, solo puede
usar `Units::MoveToSection` cuando el modo permite cambios de placement.

Si el modo no lo permite, la fila debe reportarse según la configuración del
import: rejected, skipped, warned o equivalente.

### Authorization separates read and mutate

`view_units` permite leer catálogos dentro del scope autorizado. `manage_units`
permite crear, actualizar, mover, archivar o restaurar unidades.

Un actor con `view_units` pero sin `manage_units` no puede mutar. Tenant admins
se evalúan dentro de propiedades de su organización. Property admins se evalúan
contra la propiedad concreta y dependen de un `StaffAssignment` activo y vigente
que otorgue la capability relevante. Property admins dependen de un `StaffAssignment`
activo y vigente que otorgue la capability relevante.

Concierge puede leer solo si un assignment activo le concede `view_units`; no
recibe mutación por defecto.

### Scope is organization and property aware

`UnitPolicy::Scope` no solo excluye organizaciones ajenas. También excluye
unidades de propiedades fuera del assignment o alcance autorizado del actor.

### Identifier uniqueness remains tenant-scoped

`normalized_identifier` uniqueness is scoped by organization, residential
property and placement context. The same canonical identifier may exist in a
different organization because tenant isolation is part of the uniqueness
contract.

This clarification prevents search, validation or import logic from treating
identifiers as globally unique.

### Search normalizes input

La búsqueda acepta input visible de usuario, pero el sistema lo normaliza antes
de comparar contra `normalized_identifier`. El campo normalizado sigue siendo
una clave canónica interna para matching, no un valor confiable enviado por el
cliente.

### Metadata is extensible, not authoritative

`metadata` puede guardar atributos no críticos, pero no sustituye columnas ni
contratos de tenant, property, section, identifier, uniqueness, lifecycle o
authorization.

### Area remains optional

`area_m2` is optional. When present, it must be positive. Missing area must not
block create, update, import or search flows.

### Property lifecycle is separate from section eligibility

La regla de que una propiedad archivada rechaza mutaciones ordinarias pertenece
al lifecycle de `ResidentialProperty`, no al requirement de elegibilidad de
secciones.

## Non-Goals

* Rediseñar completamente los servicios, policies, controladores o UI fuera del flujo de unidades afectado por este refinamiento.
* Redefinir los catálogos base de tipos o estados definidos por
  `improve-units-foundation`.
* Cambiar el contrato de `property-section`.
* Cambiar el contrato de roles más allá de `view_units`, `manage_units` y
  assignments por propiedad.
