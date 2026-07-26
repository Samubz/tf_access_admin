# Residential Visit Management Design

## Context

El dominio existente separa tres conceptos:

* `Person` representa identidad canónica dentro de una organización.
* `User` representa al actor autenticado.
* Las capacidades operativas se derivan de relaciones activas y acotadas: `UnitOccupancy`, `UnitOwnership` y `StaffAssignment`.

El flujo administrativo de visitas y el flujo operativo de conserjería ya tienen superficies propias. El registro desde residente se incorpora como una tercera superficie: una API privada, autenticada y contextual a una unidad. No es una variante visual del administrador.

## Goals

* Definir el contrato privado para que un residente habilitado registre una visita autorizada para su propia unidad.
* Preservar identidad, tenancy, scopes y ciclo de vida existentes.
* Garantizar trazabilidad de `User` y relaciones correctas con `Person`.
* Hacer que la visita resultante aparezca en el scope operativo de la conserjería correspondiente.

## Non-Goals

* Crear UI administrativa o Vue para residentes.
* Implementar un portal móvil completo.
* Cambiar el modelo de roles operativos.
* Introducir una identidad paralela para visitantes.

## Resident private API visit registration

### Actor

El actor es un `User` autenticado en una API privada, operando dentro de una organización activa. El sistema resuelve `user.person_for(organization)` y usa esa `Person` como anfitrión.

El término “residente” en este flujo describe una capacidad contextual sobre la unidad, no un rol global persistido en `User` o `Person`. La relación puede provenir de una `UnitOccupancy` activa o de una `UnitOwnership` activa, conforme al contrato vigente de capacidades por unidad.

### Preconditions

* Existe una sesión o credencial privada válida para el `User`.
* El `User` es miembro de la organización activa y tiene una `Person` asociada en ella.
* `unit_id` identifica una unidad de la organización activa.
* La `Person` del `User` posee una `UnitOccupancy` o `UnitOwnership` activa, vigente y no eliminada sobre esa unidad.
* El resolver concede `create_visits` para esa unidad.
* Como este endpoint produce una visita `authorized`, el resolver también debe conceder `authorize_visits` para esa misma unidad.
* Si la capacidad se deriva de `UnitOccupancy`, `can_authorize_visits` debe ser `true`.
* No se acepta contexto de otra organización, propiedad o unidad, aunque los identificadores sean válidos globalmente.

### Conceptual payload

```json
{
  "unit_id": "uuid",
  "visitor": {
    "name": "Nombre del visitante",
    "document": "Documento",
    "phone": "+56..."
  },
  "scheduled_at": "2026-06-21T18:30:00-04:00"
}
```

El payload es conceptual y no fija todavía nombres de ruta, versión, envelope JSON ni formato final de errores.

El cliente no controla:

* `organization_id`;
* `residential_property_id`;
* `property_section_id`;
* `host_person_id`;
* `created_by_id`;
* `authorized_by_id`;
* `status`.

Esos valores se resuelven en backend desde el contexto autenticado, la unidad y las reglas de autorización.

### Identity resolution

El visitante se resuelve con el mecanismo tenant-safe existente:

1. buscar una `Person` activa de la organización por documento normalizado/digest;
2. reutilizarla cuando existe;
3. crear una `Person` dentro de la organización cuando no existe;
4. aplicar nombre y teléfono de acuerdo con las reglas de resolución y actualización de identidad existentes;
5. nunca consultar ni reutilizar una `Person` de otra organización.

La operación usa:

* `visitor_person_id = visitor_person.id`;
* `host_person_id = authenticated_user.person_for(current_organization).id`.

No se crea ni se usa `visitor_profiles` como identidad primaria.

### Resulting state

La operación crea una `Visit` con:

* organización obtenida del contexto autenticado;
* unidad validada dentro del alcance del residente;
* propiedad y sección derivadas desde la unidad;
* visitante y anfitrión como `Person`;
* `created_by_id` igual al `User` autenticado;
* `authorized_by_id` igual al mismo `User`;
* `authorized_at` registrado;
* estado final `authorized`;
* horario basado en `scheduled_at` y defaults de validez del dominio;
* evento funcional de creación con estado resultante `authorized`, preservando el contrato vigente de historial.

La resolución/creación de `Person`, la creación de `Visit` y su historial funcional deben constituir una operación atómica cuando se implemente.

### Authorization

La autorización se evalúa con contexto explícito de organización y unidad:

```text
authenticated User
  -> Person in current organization
  -> active UnitOccupancy or UnitOwnership for unit_id
  -> create_visits + authorize_visits on that same unit
  -> create Visit as authorized
```

Reglas:

* una relación activa con la unidad habilita el alcance de creación según el contrato actual;
* la autorización inmediata exige `authorize_visits`;
* una ocupación activa con `can_authorize_visits = false` no satisface esa exigencia;
* una relación en otra unidad no puede autorizar esta unidad;
* una relación en otra propiedad u organización no puede ampliar el scope;
* los IDs y el estado enviados por el cliente no reemplazan la decisión del backend;
* el rechazo ocurre antes de persistir visitante nuevo, visita o historial, o revierte toda la transacción.

### Concierge relationship

Una visita creada correctamente entra al mismo scope operativo existente que cualquier otra visita `authorized`.

La conserjería puede verla solamente si:

* el `User` de conserjería se resuelve a una `Person` de la organización;
* esa `Person` tiene un `StaffAssignment` activo y vigente para la propiedad derivada desde la unidad;
* el resolver concede `view_authorized_visits` en esa propiedad;
* la visita continúa en un estado visible para el flujo operativo.

El origen privado de la visita no crea una excepción de visibilidad ni un rol adicional. Un conserje asignado a otra propiedad recibe un scope que excluye la visita.

### Flow boundaries

* Es una API privada autenticada; no es un endpoint administrativo.
* No se crean páginas, drawers, componentes Vue ni navegación admin.
* No se implementa una aplicación móvil completa.
* No se permite seleccionar un anfitrión diferente del residente autenticado.
* No se permite seleccionar organización, propiedad o sección.
* No se permite crear para unidades sin relación activa.
* No se permite forzar `authorized` sin `authorize_visits`.
* No se cambia la capacidad de conserjería para crear, editar o autorizar visitas.
* No se amplía el scope de `property_admin` ni `concierge`.
* No se introduce una identidad alternativa a `Person`.

## Security and tenancy

La búsqueda de la unidad debe partir de un scope tenant-safe y posteriormente comprobar la relación activa del residente. No basta con encontrar una unidad por UUID y comparar después.

La resolución de `Person` visitante debe estar restringida a la organización activa. El mismo documento en organizaciones diferentes representa registros independientes.

La visibilidad de conserjería se calcula por la propiedad derivada desde la unidad; nunca por una propiedad enviada por el residente.

## Error contract principles

La implementación futura debe distinguir, sin filtrar datos de otros tenants:

* autenticación ausente o inválida;
* contexto organizacional inválido;
* unidad no accesible;
* relación residencial inactiva;
* falta de autorización para crear una visita autorizada;
* datos de visitante inválidos;
* fecha/hora inválida.

Para recursos fuera del tenant o del scope del actor, la respuesta no debe confirmar la existencia del recurso.

## Alternatives considered

### Reutilizar el endpoint administrativo

Rechazado. Mezclaría scopes, payloads y responsabilidades de dos actores distintos, y podría exponer capacidades o campos administrativos a residentes.

### Usar `Person` como actor en columnas de auditoría

Rechazado. El dominio ya define `User` como actor autenticado y `Person` como identidad.

### Crear `visitor_profiles`

Rechazado. Duplicaría identidad y contradiría el perfil unificado.

### Aceptar propiedad, sección, anfitrión o estado desde el cliente

Rechazado. Esos valores se derivan del contexto autenticado y de `unit_id`; aceptarlos como autoridad abriría riesgos cross-property y de escalamiento de privilegios.
