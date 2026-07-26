## Context

Los servicios de onboarding existen y están probados (change archivado). Esta capa los expone por HTTP, entrega el token por email y completa el Flujo A/B (crear cuenta al aceptar), ahora viable porque `provision_tenant_identity` fue eliminado (crear un `User` ya no auto-crea una `Person`).

Puntos de anclaje ya implementados:
- `Accounts::InvitePerson.call(...) → Result(onboarding_request:, token:, person:)` (token en claro solo en memoria; se persiste el digest).
- `Accounts::AcceptInvitation.call(token:, organization:)` — hoy incorpora cuentas existentes y lanza `AccountRequired` cuando no hay cuenta resuelta.
- `OnboardingRequestPolicy` (revoke → `manage_people`; assign_role → `manage_staff_assignments`; resolve_conflict → `resolve_identity_conflicts`).
- `BulkImportServices::ClassifyPeopleRow` (aditivo, aún no cableado).

## Decisiones

### D1 — Endpoints y contrato de entrada
Un controller admin de onboarding con acciones para: revocar, resolver conflicto; y un endpoint (autenticado) de aceptación por token. Tenant siempre desde `Current.organization`/contexto; el cliente nunca envía `organization_id`. Cada acción `authorize`-a vía `OnboardingRequestPolicy`.

**Invitar/incorporar se expone desde `admin/people`, no desde una pantalla de "solicitudes" (revisado — feedback de producto).** La pantalla original de `admin/onboarding_requests/{index,new}` duplicaba el formulario de "Nueva persona". Se retiró y se consolidó:
- `Admin::PeopleController#create` gana un checkbox "enviar invitación" que, tras crear la `Person`, invita con los mismos datos recién guardados.
- `Admin::PeopleController#invite` (`POST /admin/people/:id/invite`) invita a una persona ya existente desde el índice.
- Ambos usan `Accounts::InvitePerson.call_for_person(person:, ...)` — **no** `Accounts::InvitePerson.call` (que resuelve identidad desde cero por email/documento). Reinvitar a una persona ya conocida por sus atributos crudos arriesga no encontrarla (p. ej. si no tiene documento, ya que la resolución por email solo mira `metadata["import_email"]`, poblado solo en altas por bulk import) y crear una **persona duplicada** vía el camino find-or-create de `call`. `call_for_person` recibe el objeto `Person` directamente, sin re-resolver identidad, y valida que no tenga ya cuenta (`user_id`) ni una invitación pendiente antes de crear la `OnboardingRequest`.
- El **estado** de invitación (`linked`/`pending`/`not_invited`) se muestra como columna en `admin/people` (`Admin::PersonSerializer#invitation_status`, derivado de `user_id` + `onboarding_requests` pendientes, sin N+1 vía `.includes`); "Enviar invitación" solo se ofrece si la persona tiene email y no está ya invitada; "Revocar invitación" se ofrece para filas `pending` (reutiliza `Admin::OnboardingRequestsController#revoke`, sin pantalla propia).
- `resolve_conflict` **no tiene UI** (decidido): requiere la capability super-admin `resolve_identity_conflicts`, distinta de `manage_people`; puede vivir en otra superficie a futuro.

**Canal de aceptación = ambos (decidido).** El link abre una página web que, si detecta la app móvil instalada (universal link/scheme), hace deep-link a la app (auth JWT); si no, permite aceptar en web (Inertia, incluyendo fijar contraseña en Flujo A/B). ⚠️ **Dependencia externa:** requiere que la app móvil (repo aparte) soporte universal links / un scheme acordado — a coordinar antes de implementar el deep-link.

### D2 — Entrega por email
`OnboardingMailer` + job Sidekiq. El correo lleva solo un **link de un solo uso** (token en la URL, digest en BD; consumido al aceptar) con **expiración de 14 días**; **sin** datos personales sensibles, documento ni el token fuera del link. **Identifica a la organización que invita** por su nombre ("La organización X te invita a…") — auto-revelación permitida; nunca revela otras orgs del titular. i18n en `es`/`en`/`pt` (una clave por locale). `InvitePerson` ya devuelve el token en claro para que el mailer lo envíe una sola vez.

### D3 — Flujo A/B (crear cuenta al aceptar) + auto-confirmación
Ampliar `Accounts::AcceptInvitation`: cuando no hay cuenta resuelta, crear el `User` (contraseña que fija el titular) y **vincularlo explícitamente** vía `Accounts::LinkUserToPerson` + `Memberships::AcceptOnboarding`, sin hooks. **Aceptar por token auto-confirma el email (decidido):** abrir el link de un solo uso prueba posesión del correo, así que la cuenta queda `confirmed_at` al aceptar — sin segundo correo de confirmación.

### D4 — Gate de confirmación
Devise `config.allow_unconfirmed_access_for = 0` (o verificación explícita en sesión) para que un `User` no confirmado no use la app. Con D3, los invitados quedan confirmados al aceptar, por lo que el gate aplica sobre todo al **auto-registro** (cuenta creada sin pasar por un token de invitación).

### D5 — Política de contraseña
Al fijar contraseña (alta por invitación, Flujo A/B, y cualquier alta/cambio de `User`) el sistema exige **mínimo 8 caracteres con al menos una minúscula, una mayúscula, un número y un carácter especial**. Se implementa como validación en `User` (junto a Devise `:validatable`), con mensaje i18n en `es`/`en`/`pt`. Aplica de forma consistente a todos los caminos de creación/cambio de contraseña.

### D6 — Cableado del clasificador en bulk import + disparo de invitaciones
`ImportPeopleRow`/validadores consultan `ClassifyPeopleRow` y **clasifican** cada fila; el import **no** envía invitaciones ni crea solicitudes automáticamente. `ready_to_create_person` crea la persona; `requires_invitation`/`requires_incorporation`/`requires_review`/`conflict` se **muestran como estado** (tabla "Row states", paginada) para que el gestor dispare la acción explícitamente; `duplicate` es idempotente; `invalid` se rechaza. Nunca se fusiona identidad.

**Disparo de invitaciones (implementado).** `BulkImportServices::TriggerRowInvitations` — por fila o en lote (`POST .../trigger_invitations`, `row_ids` opcional) — **reclasifica cada fila justo antes de actuar** (defensivo: el estado real pudo cambiar desde el import) y llama `Accounts::InvitePerson.call` (con re-resolución de identidad completa, a diferencia de D1 porque aquí sí puede haber conflicto/cambio de estado genuino). Idempotencia en tres capas: (1) filas con `target_record` ya asignado no se re-seleccionan — se reutiliza esa columna polimórfica existente (antes solo apuntaba a la `Person` creada; ahora también apunta a la `OnboardingRequest` creada, sin migración, porque las clasificaciones son mutuamente excluyentes); (2) la reclasificación detecta duplicados/conflictos antes de invitar; (3) `ActiveRecord::RecordNotUnique` (carrera de doble envío contra el índice único de solicitudes pendientes) se captura por fila sin abortar el lote.

### D7 — Privacidad en la UI
Las pantallas del gestor muestran solo información **neutral** (email-blind): nunca revelan si el correo ya tiene cuenta ni otras organizaciones del titular. La aceptación ocurre del lado del titular tras autenticarse.

### D8 — Redirect fuera de Inertia al aceptar
`OnboardingAcceptancesController#create`, al aceptar con éxito, redirige a `new_user_session_path` (Devise, fuera de la SPA). Un `redirect_to` plano rompe el flujo: el cliente Inertia sigue el 302 vía `fetch`, recibe HTML sin cabecera `X-Inertia`, y con `useDialogForErrorModal: true` (config de este proyecto) lo muestra dentro de su modal de error en vez de navegar. Se usa `inertia_location(url)` (helper de `inertia_rails`) en su lugar: responde `409` + `X-Inertia-Location`, que el cliente interpreta como señal de navegación real (`window.location`). El flash de éxito se setea manualmente (`flash[:notice] = ...`) antes de llamar `inertia_location`, ya que este no acepta el atajo `redirect_to ..., notice:`.

## Risks / Trade-offs
- Creación de cuenta al aceptar toca el flujo de contraseña/confirmación de Devise; mitigar con tests de integración del endpoint de aceptación.
- Cablear el clasificador cambia el comportamiento del importador actual; usar los tests de bulk import como red y preservar la idempotencia.
- Cualquier otro redirect desde una acción Inertia hacia una ruta no-Inertia (fuera de la SPA) debe usar `inertia_location`, no `redirect_to` — revisar si aparecen casos nuevos.

## Migration Plan
Aditivo sobre lo entregado; sin migraciones destructivas. La entrega por email y los endpoints son nuevos; el cambio de comportamiento del importador se cubre con tests antes de activarlo. El pivote de UI (retirar `admin/onboarding_requests/{index,new}`) fue un ajuste de scope confirmado con el usuario durante la implementación, no un backfill de datos: no requiere migración.
