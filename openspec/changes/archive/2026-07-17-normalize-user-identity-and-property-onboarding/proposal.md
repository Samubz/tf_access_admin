## Why

La plataforma mezcla hoy tres procesos distintos —resolver la identidad de una persona, crear o vincular una cuenta de autenticación, e incorporar a esa persona a una organización, propiedad o unidad— en flujos implícitos y no normalizados.

Consecuencias actuales verificadas en el código:

- `User#provision_tenant_identity` (`app/models/user.rb`) **auto-crea** una `Person`, una `OrganizationMembership` aceptada y el rol `CLIENT` en el tenant activo cada vez que se crea un `User`, **sin deduplicar** contra personas existentes por documento o email.
- `Admin::UsersController#create` es un `User.new(...).save` plano; el administrador fija la contraseña directamente, sin invitación ni confirmación de identidad.
- `Admin::PeopleController` expone `linkable_users` (id, nombre, **email**) en el formulario, pero `person_params` no permite `user_id`: la vinculación persona↔usuario está insinuada en la UI pero no cableada ni protegida por una confirmación del titular.
- `People::FindExisting` deduplica solo dentro de la organización (documento → email vía `User` global → email en metadata) y no participa en el alta de usuarios ni de personas por UI.
- `BulkImportServices::ImportPeopleRow` crea `Person` + membership aceptada, **nunca** crea ni vincula `User`, y solo distingue crear/saltar duplicado.
- No existe ninguna entidad de invitación u onboarding con token, expiración, aceptación o entrega por email. El estado `invited` de `OrganizationMembership` no tiene flujo de aceptación real.
- `users.email` es único **global**: crear una cuenta con un email ya usado en otra organización falla revelando implícitamente que la cuenta existe en otra organización.

Sin un contrato normalizado, una misma persona puede duplicarse, mezclarse con otra por coincidencias parciales, o recibir accesos e invitaciones dirigidos a la cuenta equivocada; y un gestor puede inferir la participación de una persona en otra organización.

## What Changes

- **Formalizar el modelo de dos niveles de identidad** sin rediseñar la autenticación:
  - `User` = cuenta de autenticación **global** (identificador canónico de la *cuenta*); un `User` puede existir **sin `Person`** (cuenta auto-registrada sin contexto de org).
  - `Person` = proyección de identidad **por organización** (identidad canónica *dentro* del tenant).
  - Cardinalidad: un `User` puede tener **N `Person`** (a lo sumo una activa por organización); una `Person` puede tener **a lo sumo un `User`**.
- **Modelo de entrada: auto-registro + invitación.** Un humano puede crear su propia cuenta (sin `Person`); las `Person`/membresías/roles se crean **solo** dentro de un flujo de onboarding explícito. Se **elimina** `provision_tenant_identity` (auto-provisión ciega al crear `User`).
- **Separar explícitamente** los tres procesos hoy fusionados: (1) resolución de identidad, (2) creación/vinculación de cuenta, (3) incorporación a organización/propiedad/unidad, mediante servicios canónicos con responsabilidad única.
- **Correo como clave de identidad transversal:** resolver `Person`→`User` por correo es automático y server-side (con o sin confirmar); el **gestor permanece email-blind** (no selecciona cuentas ni conoce otras orgs del titular). La confirmación **no** condiciona la vinculación pero **sí** el uso: un `User` no confirmado **no puede usar la app**. Señales débiles (solo nombre/teléfono) nunca establecen identidad; no hay fusión automática.
- **Regla de activación del join según sensibilidad:** un join de **rol cliente** (transversal, self-scope) nace **activo, visible y declinable**; un join con **roles operativos** (org-específicos) nace **pendiente** y requiere **aceptación explícita** del titular. Los roles operativos (`StaffAssignment`) son **confirmables** (estado de confirmación + `confirmed_at`) y no conceden acceso hasta confirmarse. **Solo el rol manager** asigna o revoca roles.
- **Introducir una entidad de onboarding con token** (`OnboardingRequest`) que modele invitación e incorporación de una cuenta existente o futura a una nueva organización/propiedad/unidad, con estado, expiración, aceptación/rechazo, motivo de conflicto, metadata mínima y auditoría — separada de `OrganizationMembership`. Idempotente; permite re-invitar tras revocar.
- **Definir un contrato de privacidad neutral** entre organizaciones: las respuestas de resolución no revelan existencia, nombre, propiedades, unidades, roles, historial ni emails de otras organizaciones. Un `User` ve todas sus `Person` vinculadas cross-org (self-scope); ningún gestor.
- **Conflictos de identidad** se registran sin cambiar asociaciones y se resuelven solo con la capacidad dedicada `resolve_identity_conflicts` (no un gestor de propiedad).
- **Declinar (cliente)** revoca la membresía y **desvincula** `User`↔`Person`, pero la `Person` y sus ownerships/occupancies **permanecen** propiedad de la organización (auditado, reversible).
- **Normalizar el comportamiento de bulk import**: clasificar cada fila (lista para crear / lista para vincular / requiere invitación / requiere incorporación / requiere revisión / conflicto / duplicada / inválida) sin fusionar identidades ambiguas; el import **nunca** otorga roles operativos (siempre cliente).
- **Registrar auditoría** de operaciones sensibles (resolución, vinculación, invitación, incorporación, revocación) sin persistir documentos completos, tokens ni secretos.

Este change **define el contrato (specs, design, tasks)**; no implementa código ni ejecuta migración de datos.

## Capabilities

### New Capabilities

- `person-identity`: identidad canónica de dos niveles (`User` global que puede existir sin `Person`, `Person` por organización), cardinalidad, correo como clave de agrupación transversal, vista self-scope cross-org, atributos globales vs contextuales, auto-`Person` visitante al generar visita, restricciones de base de datos.
- `identity-resolution`: correo como clave de identidad transversal (match automático server-side), gestor email-blind, señales débiles que no establecen identidad, registro y autoridad de resolución de conflictos, contrato de privacidad cross-tenant.
- `user-account-linking`: creación de `User`, vinculación automática por correo, el gestor no selecciona cuentas, gate de confirmación (no confirmado no usa la app), desvinculación con trazabilidad.
- `property-onboarding`: entidad `OnboardingRequest`, regla de activación del join (cliente activo-declinable / roles operativos pendiente-acepta), roles operativos confirmables, solo rol manager asigna/revoca, expiración, idempotencia, re-invitación tras revocar, entrega segura.
- `organization-membership`: participación multi-organización con permisos e información contextual aislados, revocación por organización.
- `bulk-import-people`: clasificación de filas y manejo de conflictos en importación masiva sin fusión automática.

### Modified Capabilities

- `unified-person-profile`: se **mantiene** ("Person es la única entidad de identidad por organización"); este change lo complementa formalizando la relación con `User` y la incorporación, sin cambiar sus requisitos existentes.

## Impact

**Bounded context:** Identidad y cuentas (`Person`, `User`), Membresía (`OrganizationMembership`), Onboarding (nueva entidad `OnboardingRequest`), transversal a Organizations, Residential Properties, Units, Staff Assignments, Unit Ownerships/Occupancies y Bulk Import. Autorización vía Pundit + `Authorization::Resolver`. Multitenancy estricta (`acts_as_tenant`).

**Modelos afectados:**
- `Person` (`app/models/person.rb`) — cardinalidad con `User`, autoridad de datos, restricciones.
- `User` (`app/models/user.rb`) — **eliminación de `provision_tenant_identity`**; `User` sin `Person` como estado válido; gate de confirmación para uso de la app; email como identificador de cuenta.
- `OrganizationMembership` (`app/models/organization_membership.rb`) — relación con onboarding; el estado `invited` deja de usarse como sustituto de invitación.
- `StaffAssignment` (`app/models/staff_assignment.rb`) — **nuevo estado de confirmación + `confirmed_at`** (patrón confirmable); el rol operativo no concede acceso hasta confirmarse. `Authorization::Resolver` deriva roles operativos solo confirmados.
- `UnitOwnership`, `UnitOccupancy` — no cambian su contrato; se aclara que la incorporación no crea automáticamente estas relaciones.
- **Nueva tabla/modelo** `OnboardingRequest` (organización, propiedad opcional, unidad opcional, persona, usuario resuelto opcional, relación y roles solicitados, actor, estado, `expires_at`, token digest, motivo de conflicto, metadata, historial).

**Servicios afectados o nuevos (nombres referenciales, a ajustar a convenciones del repo):**
- Extender `People::FindExisting` → `People::ResolveIdentityMatch` (match por correo + registro de conflictos, sin niveles de confianza como control principal).
- `People::Create`, `Accounts::InvitePerson`, `Accounts::LinkUserToPerson`, `Memberships::RequestOnboarding`, `Memberships::AcceptOnboarding`, `Memberships::RejectOnboarding`, `Memberships::Revoke`, `IdentityConflicts::Resolve`.
- Integración con `BulkImportServices::ImportPeopleRow` / validación de filas.

**Controllers / contratos de entrada:**
- `Admin::UsersController`, `Admin::PeopleController`, `Admin::People::BulkImportsController` y nuevos endpoints de onboarding/aceptación; los identificadores de tenant se derivan del contexto, no se aceptan del cliente.

**Policies:** `PersonPolicy`, `UserPolicy`, `OrganizationPolicy`, y nueva `OnboardingRequestPolicy` / `IdentityConflictPolicy`.

**Frontend (Inertia + Vue):** pantallas de resolución de identidad, invitación e incorporación; el gestor ve solo información neutral. (El detalle de UI se limita a lo necesario para el flujo.)

**Dependencias:** ninguna en otro change activo. Se apoya en el spec existente `unified-person-profile`.

**Fuera de alcance:** nueva autenticación, proveedor externo de identidad / SSO, fusión automática de personas, migraciones destructivas, limpieza masiva de duplicados históricos, rediseño de propietarios/ocupantes, **implementación del flujo de visitas** (la auto-creación de `Person` visitante al generar una visita se define como contrato pero se implementa en el change de visitas). La estrategia de migración se define aquí; su ejecución masiva queda para un change separado. Riesgo asumido y diferido: un mismo humano con dos `User` de correos distintos (sin fusión automática).
