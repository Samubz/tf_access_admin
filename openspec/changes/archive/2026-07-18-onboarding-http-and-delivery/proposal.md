## Why

El change `normalize-user-identity-and-property-onboarding` (archivado) entregó la **columna vertebral de dominio**: identidad canónica de dos niveles, la entidad `OnboardingRequest`, `StaffAssignment` confirmable, todos los servicios canónicos (`People::ResolveIdentityMatch`/`Create`, `Accounts::InvitePerson`/`AcceptInvitation`/`LinkUserToPerson`/`ProvisionTenantIdentity`, `Memberships::*`, `IdentityConflicts::Resolve`, `BulkImportServices::ClassifyPeopleRow`), la autorización (`resolve_identity_conflicts` + `OnboardingRequestPolicy`) y la eliminación de `provision_tenant_identity`. Todo verde (suite 1118, 0 fallos).

Falta la **capa de exposición y entrega** que conecta esos servicios con la aplicación real: no hay endpoints HTTP para invitar/incorporar/aceptar, no se entrega el token por email, la aceptación que **crea una cuenta nueva** (Flujo A/B) quedó bloqueada por la auto-provisión (ya eliminada, por lo que ahora se desbloquea), el clasificador de bulk import no está cableado al pipeline ni a la UI, y falta el gate de confirmación de uso.

## What Changes

- **Endpoints HTTP de onboarding** (resto de §18): invitar/incorporar se expone desde `Admin::PeopleController` (`create` con checkbox, `invite` para una persona existente) — **no** desde una pantalla dedicada de "solicitudes"; revocar y resolver conflicto siguen siendo endpoints en `Admin::OnboardingRequestsController` (sin UI de resolución propia, ver más abajo); aceptar por token vía `OnboardingAcceptancesController`. Tenant derivado del contexto, nunca del cliente; autorización vía `OnboardingRequestPolicy`/`PersonPolicy`. **Listado** org-scoped: se resuelve como una columna de estado de invitación (`linked`/`pending`/`not_invited`) en el directorio de personas, no como un índice separado; cualquier actor con `manage_people` puede invitar y revocar (no solo el emisor).
- **Entrega por email del token**: mailer + i18n (`es`/`en`/`pt`) con link **de un solo uso** y **expiración de 14 días**, que **identifica a la organización que invita** por su nombre, **sin datos sensibles ni el token en claro** más allá del link.
- **Aceptación que crea cuenta nueva (Flujo A/B)**: `Accounts::AcceptInvitation` deja de lanzar `AccountRequired` y crea el `User` + vincula la `Person` explícitamente (ya viable sin `provision_tenant_identity`). **Aceptar por token auto-confirma el email** (la posesión del link lo prueba), sin segundo correo. El redirect final (a `new_user_session_path`, fuera de Inertia) usa `inertia_location` — un `redirect_to` plano hace que el cliente Inertia monte la respuesta no-Inertia en su modal de error en vez de navegar.
- **Canal de aceptación = web + móvil**: página web que hace deep-link a la app móvil si está instalada (⚠️ depende de universal links de la app móvil, repo aparte) o permite aceptar en web.
- **Gate de confirmación (§14.2)**: `User` no confirmado no accede (Devise `allow_unconfirmed_access_for = 0`); con la auto-confirmación, aplica sobre todo al auto-registro.
- **Política de contraseña**: mínimo 8 caracteres con minúscula + mayúscula + número + carácter especial, en todo camino de alta/cambio (invitación, alta admin, cambio).
- **Bulk import — clasificar y disparar la acción**: `ClassifyPeopleRow` cableado para **clasificar** cada fila y mostrar el estado en la UI; el import **no** envía invitaciones ni crea solicitudes automáticamente — el gestor las dispara explícitamente (por fila o en lote) vía `BulkImportServices::TriggerRowInvitations`.
- **Frontend (§19)**: **consolidado en `admin/people`** (no en pantallas separadas de "solicitudes de incorporación", que duplicaban el formulario de creación de persona) — checkbox "enviar invitación" al crear, columna de estado de invitación y acciones invitar/revocar por fila en el índice; aceptación por link (holder-facing, neutral); estados de clasificación en bulk import con acción de disparo.
- **Auditoría (§15)** de las operaciones sensibles vía endpoints; **enumeración de tests (§20)**; verificación de specs §5/§8/§10/§11; **validación final (§22)**.

## Capabilities

### Modified Capabilities

- `property-onboarding`: añade la **entrega por email** (con nombre de la org que invita), la **creación de cuenta nueva con auto-confirmación** en la aceptación (Flujo A/B), e **invitar/revocar** desde el directorio de personas (`manage_people`), sin una pantalla de solicitudes separada.
- `bulk-import-people`: añade la **clasificación por fila** en la importación (sin auto-enviar), su reflejo en la UI, y el **disparo explícito** de invitaciones/incorporaciones por el gestor (por fila o en lote).
- `user-account-linking`: añade el **gate de confirmación** a nivel de sesión y la **política de complejidad de contraseña**.

## Impact

**Bounded context:** capa de exposición (HTTP + mailer + Vue) sobre los servicios de onboarding ya entregados. Depende del change archivado `normalize-user-identity-and-property-onboarding`.

**Backend:** `Admin::PeopleController#create`/`#invite` (invitar), `Admin::OnboardingRequestsController#revoke`/`#resolve_conflict` (sin `index`/`new`/`create` propios); `Accounts::InvitePerson.call_for_person`/`.deliver` (invita a una persona ya conocida sin re-resolver identidad); `BulkImportServices::TriggerRowInvitations`; `OnboardingMailer` + vistas i18n; ampliación de `Accounts::AcceptInvitation` (creación de cuenta); integración de `ClassifyPeopleRow` en `BulkImportServices::ImportPeopleRow`/validadores; config Devise para el gate de confirmación.

**Frontend (Inertia + Vue):** todo consolidado en `admin/people` (checkbox de invitación, columna y acciones de estado) en vez de pantallas dedicadas; pantalla de aceptación por token; estados de clasificación y disparo de invitaciones en bulk import; i18n en `es`/`en`/`pt`.

**Fuera de alcance:** rediseño de autenticación, SSO, fusión automática de personas, remediación histórica de duplicados (change separado), UI de resolución de conflictos (endpoint existe, sin pantalla — capability separada de super-admin).
