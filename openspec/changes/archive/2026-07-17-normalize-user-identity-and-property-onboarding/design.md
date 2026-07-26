## Context

Estado actual verificado en el código:

- **`Person` es identidad por organización** (`acts_as_tenant :organization`, `acts_as_paranoid`), con `user_id` opcional e índices únicos parciales por `(organization_id, document_type, document_number_digest)` y `(organization_id, user_id)` cuando no están borrados (`app/models/person.rb`). El spec `unified-person-profile` ya establece "one person record per organization".
- **`User` es global** (`users.email` UNIQUE global, sin `organization_id`). `User has_many :people` y `has_many :organizations, through: :people`. Un `User` puede tener una `Person` por organización.
- **`User#provision_tenant_identity`** (after_create) crea `Person` + `OrganizationMembership.accept!` + rol `CLIENT` en `ActsAsTenant.current_tenant`, sin deduplicar.
- **`OrganizationMembership`** usa AASM `invited → active → suspended → revoked`, único parcial activo/invitado por `(organization_id, person_id)`.
- **`People::FindExisting`** deduplica org-scoped: `document_number_digest` → email (busca `User` global y luego `person_for(org)`) → email en `metadata['import_email']`.
- **`BulkImportServices::ImportPeopleRow`** crea `Person` + membership aceptada; nunca crea `User`.
- **No existe entidad de invitación/onboarding**; `invited` es un estado sin token, expiración ni aceptación.
- Autorización: `Authorization::Resolver` **siempre parte de `User`**, nunca de `Person` (config `openspec/config.yaml`). Capacidades como `manage_people`, `view_people`.

Este documento justifica las decisiones que el spec convierte en requisitos verificables.

## Goals / Non-Goals

**Goals:**

- Declarar el modelo de identidad de dos niveles y su cardinalidad como contrato explícito.
- Separar resolución de identidad, gestión de cuenta e incorporación en servicios canónicos independientes.
- Definir el correo como clave de identidad transversal (match automático) y la política anti-mezcla sin fusión automática.
- Especificar la entidad y el ciclo de vida de onboarding con token, expiración, aceptación y revocación.
- Definir el contrato de privacidad cross-tenant y la auditoría de operaciones sensibles.
- Normalizar el comportamiento de bulk import y el manejo de conflictos.

**Non-Goals:**

- Nueva autenticación, SSO o proveedor externo de identidad.
- Fusión automática de personas o limpieza masiva de duplicados.
- Rediseño de propietarios/ocupantes o de roles no relacionados.
- Ejecución de migración de datos históricos (solo se define la estrategia).

## Decisiones

### D1 — Separación Person / User / membresía / relación con unidades

`User` = **cuenta de autenticación global**. `Person` = **identidad canónica dentro de una organización**. `OrganizationMembership` = relación operativa persona↔organización. `UnitOwnership` / `UnitOccupancy` / `StaffAssignment` = relaciones contextuales independientes. Ninguna operación de identidad o cuenta crea o altera automáticamente relaciones con unidades. Se conserva la separación existente; se elimina la auto-provisión implícita.

### D2 — Cardinalidad Person ↔ User

- Un `User` → **N `Person`** (a lo sumo **una activa por organización**; ya garantizado por el índice parcial `(organization_id, user_id)`).
- Una `Person` → **a lo sumo un `User`** (`user_id` nullable, único parcial por organización).
- La 1:N cross-organización es **intencional y documentada**: el mismo humano usa la misma cuenta global en varias organizaciones, con una proyección `Person` independiente por tenant.
- No se introduce identidad de persona global: el rediseño a `Person` global queda descartado por romper `acts_as_tenant` en todo el dominio.

### D2b — Modelo de entrada (auto-registro + invitación)

Se adopta **auto-registro + invitación** (no invite-only). Un humano **puede crear su propia cuenta** (`User` global) sin `Person` ni contexto de org; es una cuenta "vacía" hasta que una organización lo incorpora. Se **elimina** `provision_tenant_identity`: registrarse ya no auto-crea `Person`/membresía/rol. La `Person`, membresía y rol cliente se crean **solo** dentro de un flujo de onboarding explícito.

Motivación adicional (dominio de visitas): una cuenta sin `Person` es una identidad global válida que puede actuar como **visitante** —presentar un QR y autocompletar datos de visita (`VisitorProfile`/`Visit`)— sin requerir membresía en ninguna organización. La implementación de visitas queda fuera de alcance; aquí solo se garantiza que `User` sin `Person` es un estado válido.

### D3 — Identificadores canónicos y autoridad de datos

- **Identificador transversal de cuenta:** `users.email` **confirmado** (único global) es la clave de identidad transversal. Quien confirma el correo en el registro se asume dueño (estándar de la industria: GitHub/Slack/Workspace). Un cambio de correo exige una solicitud de reverificación aparte.
- **Identificador de persona dentro de la org:** `(organization_id, document_type, document_number_digest)`.
- **Datos globales** (propiedad de `User`): email de autenticación, `name`, `dni`, idioma, estado de cuenta.
- **Datos contextuales** (propiedad de `Person`, por organización): `display_name`, documento cifrado/digest, email/teléfono de contacto en `metadata`, roles, membresía.
- **Autoridad de actualización:** cada organización actualiza solo los datos contextuales de su `Person`. Ninguna organización sobrescribe automáticamente datos de otra ni datos globales de `User` de un titular ya existente.
- **Evolución futura (fuera de alcance):** un segundo factor confirmado (teléfono) reforzaría la prueba de identidad y habilitaría recuperación de cuenta y continuidad tras un cambio de correo.

### D4 — Resolución por correo confirmado + señales débiles

Extender `People::FindExisting` a `People::ResolveIdentityMatch`:

- **Match de cuenta por correo confirmado = automático y server-side.** Resolver `Person`→`User` por correo confirmado no requiere reto "¿eres tú?". El correo confirmado *identifica* la cuenta; el control de seguridad no está en identificar, sino en **activar el join** (ver D7b).
- **Señales débiles nunca establecen identidad:** solo nombre, solo teléfono. Un dato aportado por una organización (p. ej. correo tecleado en un import, sin confirmación del titular) resuelve la cuenta por correo pero **no sobrescribe** los datos de la `Person`/`User` existentes.
- **Conflictos** (documento coincide pero correo difiere, `User` ya vinculado a otra `Person` en la misma org, etc.): se registran sin cambiar asociaciones y exigen resolución explícita.

Se **descarta** un esquema de "niveles de confianza" como control principal: el correo confirmado es la clave, y la salvaguarda es la regla de activación del join, no un umbral de confianza difuso.

### D5 — Política de desvinculación

La **desvinculación** de un `User` de una `Person` es reversible y auditada: no borra la `Person` ni sus relaciones con unidades; registra actor, motivo y estado previo/posterior. No hay fusión automática de `Person`; la reconciliación de cuentas duplicadas (mismo humano, correos distintos) queda fuera de alcance.

### D6 — Privacidad entre organizaciones (gestor email-blind)

El gestor **nunca** selecciona ni ve cuentas existentes: aporta un correo y el sistema resuelve la cuenta por detrás. La respuesta al gestor es **neutral e idéntica** exista o no una cuenta ("invitación enviada"), y nunca revela nombre de otra organización, propiedades, unidades, roles, historial, otros emails, documento completo ni datos de membresía ajena. Igual que invitar a una org de GitHub no revela las demás orgs del invitado. El contrato exacto se especifica en `identity-resolution`.

### D7a — Entidad de onboarding con token

Nueva entidad **`OnboardingRequest`** que unifica invitación e incorporación (propiedad y unidad son opcionales, por eso el nombre no se ancla a "property"):

- Campos: `organization_id`, `residential_property_id` (opcional), `unit_id` (opcional), `person_id` (opcional), `user_id` (opcional), `requested_relationship` (membership / property_access / ownership / occupancy / staff), `requested_by_id` (actor), `status` (`pending`, `accepted`, `rejected`, `expired`, `revoked`, `conflict`), `expires_at`, `token_digest` (nunca el token en claro), `conflict_reason`, `metadata` mínima, historial de cambios (`audited`).
- Un solo concepto cubre "invitar a persona sin cuenta" e "incorporar cuenta existente"; el `user_id` opcional distingue ambos casos. Se evalúan y descartan entidades separadas (`OrganizationInvitation`, `MembershipInvitation`, `PersonAccountLinkRequest`) para no fragmentar el contrato; se documenta el criterio en el spec.
- **Idempotencia:** una solicitud pendiente equivalente (misma org, persona/usuario y relación) no se duplica.
- **Expiración/revocación:** `expires_at` obligatorio; revocación explícita por actor autorizado; expiradas y revocadas no conceden acceso.

### D7b — Regla de activación del join (decisión clave)

La **sensibilidad de lo que concede el join** determina si la membresía nace activa o pendiente. El corte confirmado es **rol transversal vs roles específicos de organización**:

- **`client`** es el único rol **transversal** (self-scope) → activo-declinable.
- **`tenant_admin`, `content_manager`, `property_admin`, `concierge`, `cleaning_staff`, `internal_staff`** son **específicos de la organización** → pendiente-acepta.

La línea divisoria se apoya en el modelo de capacidades existente (`Authorization::Resolver`, roles→capacidades):

- **Join de solo cliente (self-scope)** → membresía **activa de inmediato**, **visible** para el titular y **declinable/revocable** por él. Este es el ramo frecuente (propietario/residente): el correo confirmado es dueño, entra directo, y la salvaguarda es que el vínculo aparece en "todas mis Person" y puede rechazarlo.
- **Join con roles operativos o acceso a datos sensibles** → membresía/rol **pendiente**, requiere **aceptación explícita** del titular antes de conceder acceso, y sigue siendo **revocable** después.
- El titular puede **aceptar/rechazar cada rol** que se le otorga y **revocar** uno ya aceptado.

Esto reemplaza cualquier "solicitud de unión" con fricción para el caso cliente, mientras exige consentimiento explícito solo cuando el join otorga poder operativo. Se descarta tanto el auto-link silencioso y oculto como el accept obligatorio para todo.

### D8 — Aceptación y entrega segura (para joins pendientes)

- Token de un solo uso con expiración; se almacena solo su digest. No se diseña criptografía propia (usar generadores estándar del framework).
- Aceptación explícita del titular; verificación del contexto **después** de iniciar sesión (no confiar solo en posesión del enlace).
- Email destino confirmado y enmascarado en la UI del gestor; verificación adicional si cambia el email conocido mientras hay una invitación pendiente. No se adjunta información sensible a los correos.

### D9 — Manejo de conflictos

`IdentityConflicts::Resolve` registra un conflicto (p. ej. documento coincide con una persona pero el email pertenece a otra cuenta) **sin** cambiar ninguna asociación y exige resolución explícita por un actor con capacidad global de resolución de identidad (no un gestor de propiedad). Los 18 casos se enumeran en `identity-resolution` y `bulk-import-people`.

### D10 — Integración con bulk import

`ImportPeopleRow` deja de crear ciegamente: cada fila se **clasifica** (crear / vincular / requiere invitación / requiere incorporación / requiere revisión / conflicto / duplicada / inválida) usando `People::ResolveIdentityMatch`. Ambiguos y conflictos nunca se fusionan ni se auto-vinculan; se registran para revisión.

### D11 — Autorización

- Buscar/ver coincidencias, crear personas, invitar, solicitar incorporación, cancelar invitaciones, crear membresías y revocar acceso: capacidades por organización (`manage_people`, y capacidades nuevas de onboarding) vía Pundit + `Authorization::Resolver`, partiendo siempre de `User`.
- **Asignar y revocar roles**: restringido al **rol manager**. Ningún otro rol asigna/revoca roles.
- **Resolver conflictos globales de identidad**: capacidad dedicada `resolve_identity_conflicts`, separada de `manage_people`, por defecto en super admin y **delegable** a un rol de confianza sin dar acceso a datos de otra org. **Modificar datos globales de `User`**: capacidad separada de nivel superior. Un gestor de propiedad **no** las obtiene automáticamente.
- **Gate de confirmación:** el email vincula la cuenta con o sin confirmar, pero un `User` **no confirmado no puede usar la app** (Devise `:confirmable`, sin acceso previo a la confirmación).
- **Roles operativos confirmables:** `StaffAssignment` incorpora **estado de confirmación + `confirmed_at`** (similar a confirmable). Se crea sin confirmar y no concede acceso hasta que el titular confirma; la membresía cliente activa no se altera mientras el rol está pendiente. Tras revocar, se puede re-invitar reutilizando este flujo.
- **Declinar (cliente):** el titular puede declinar una membresía cliente activa; esto revoca la membresía y **desvincula** `User`↔`Person`, pero la `Person` y sus ownerships/occupancies **permanecen** propiedad de la organización (auditado y reversible). Un join operativo requiere aceptación explícita y puede ser el **primer contacto** (crea membresía + rol al aceptar, sin membresía previa).
- Los identificadores de tenant se derivan del contexto (`Current.organization`), no se aceptan desde el cliente.

### D12 — Auditoría

Toda operación sensible registra actor, organización, propiedad opcional, persona, usuario, acción, estado previo/posterior, fecha, motivo, método de resolución, evidencia mínima e identificador de invitación/solicitud. **Nunca** persiste documentos completos, tokens ni secretos. Se apoya en `audited` y en la metadata de la solicitud.

### D13 — Restricciones de base de datos

- `Person.user_id` único parcial por organización (existente) — mantener.
- `users.email` único global (existente) — mantener como credencial.
- `document_number_digest` único parcial por `(organization_id, document_type)` para personas no borradas (existente) — mantener.
- Membresías únicas activas/invitadas por `(organization_id, person_id)` (existente) — mantener.
- Nueva unicidad parcial para solicitudes de onboarding **pendientes** por `(organization_id, person_id/user_id, requested_relationship, scope)`.
- `StaffAssignment`, `UnitOwnership`, `UnitOccupancy`: `validates_same_tenant` (existente) — la incorporación no las crea implícitamente.

## Risks / Trade-offs

- **`User` global vs Person por-org** puede permitir que un humano tenga dos `User` (emails distintos en dos orgs). Mitigación: la resolución con confianza `strong` y el onboarding basado en cuenta existente reducen la incidencia; la deduplicación cross-tenant de cuentas queda fuera de alcance por privacidad.
- **Reemplazar `provision_tenant_identity`** puede afectar flujos que asumen la auto-creación de `Person`/membership al crear `User`. Mitigación: estrategia de migración y compatibilidad en tasks §21.
- **Privacidad neutral** puede complicar la UX del gestor (menos información para decidir). Es una decisión deliberada a favor del aislamiento.

## Migration Plan

- Introducir la entidad y los servicios detrás de los flujos existentes sin borrar datos.
- Sustituir `provision_tenant_identity` por invocación explícita de servicios canónicos, preservando el comportamiento para cuentas ya existentes.
- La remediación de duplicados históricos y la reconciliación cross-tenant de cuentas se documentan pero **no se ejecutan** aquí; requieren un change separado con estrategia aprobada.

## Open Questions

Decisiones ya cerradas con el equipo: modelo de dos niveles (`User` global + `Person` por org), correo confirmado como clave transversal, gestor email-blind, regla de activación del join (cliente activo-declinable / roles org pendiente-acepta), entrada por **auto-registro + invitación** (`User` sin `Person` es estado válido), capacidad dedicada `resolve_identity_conflicts`, y nombre `OnboardingRequest`. Queda como riesgo asumido —no bloqueante— la posibilidad de que un mismo humano tenga dos `User` con correos distintos (sin fusión automática; reconciliación diferida a un change separado).
