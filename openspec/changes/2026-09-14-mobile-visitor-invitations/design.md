## Context

`tf_access_admin` ya tiene: API JWT (`devise-jwt`), `Private::BaseController` que verifica membresía en el tenant, creación de visita por residente (`Residents::CreateAuthorizedVisit` → `Visits::Create`), push FCM completo (`Fcm::Client`, `Notifications::CreateForVisit`, `DeliverPushNotificationJob`), y onboarding por token de un solo uso (`Accounts::InvitePerson`, `AcceptInvitation`, `OnboardingMailer`). La app móvil consume un contrato más amplio que el backend no expone.

## Goals

- Que la app móvil funcione end-to-end contra este backend sin cambiar sus pantallas.
- Invitación de visitante por correo con creación de cuenta y notificación push.

## Non-Goals

Ver `proposal.md`.

## Decisiones

### D1 — Login API para todo miembro
`Api::V1::Auth::SessionsController#create` deja de exigir `AvailableRoles::TENANT_ADMIN`. Condiciones: credenciales válidas, `confirmed?`, y `member_of_tenant?` en la organización del subdominio (mismo predicado que `Private::BaseController#ensure_current_user_belongs_to_tenant!`). La respuesta incluye `role`: `tenant_admin`, `resident` o `visitor`, derivado de `Authorization::Resolver` (primer rol organizacional; `resident` si solo tiene relaciones de unidad). Test existente de "no admin → 403" se reemplaza por "no miembro → 403".

### D2 — Endpoints privados y serializers
Todos en `app/controllers/api/v1/private/`, heredan de `Private::BaseController`, controladores delgados, serializers en `app/serializers/api/private/`. Contratos exactos en `specs/mobile-private-api/spec.md`.

- `GET /me`: `email`, `name`, `dni`, `phone` (`{countryCode, number}` derivado de `Person#phone` de la org actual, o `null`), `dateOfBirth` (`Person#birthdate`), `gender` (**siempre `null`**: no está modelado; `PATCH` lo ignora), `avatarUrl` (Active Storage, adjunto nuevo `User#avatar`), `organizations` (organizaciones donde el user tiene membresía activa, con `units_count` de unidades con relación activa). `role` como en D1.
- `PATCH /me`: `name`, `phone`, `dateOfBirth` y `avatar` multipart. `name` va a `User`; `phone` y `birthdate` a la `Person` de la org actual.
- `GET /units`: unidades con `UnitOccupancy`/`UnitOwnership` activa del `Person` actual. Forma `{ id, name, organization: { id, name } }`.
- `GET /organization/:id` y `GET /organization/:id/residential_property/:id`: `:id` debe coincidir con `Current.organization` (si no, 404); propiedades y unidades filtradas por relación activa del residente; `isOwner`/`occupancyType` desde las relaciones.
- `GET /units/:unit_id/visits?day=YYYY-MM-DD`: guardia `Residents::VisitContext` (misma que `create`); visitas cuyo `scheduled_at` cae en ese día en la zona horaria de la propiedad. `day` inválido → 422.
- `GET /invitations`: visitas donde `visitor_person.user_id == current_user.id`, `scheduled_at >= inicio de hoy`, estados distintos de `cancelled`. Accesible con capacidad `view_own_visits` (también la tienen los residentes que a la vez son visitantes en otra unidad).

### D3 — Correo del visitante como identidad
`POST /units/:unit_id/visits` permite `visitor: %i[name email phone document]`. `Residents::ResolveVisitorPerson` normaliza el correo (`downcase.strip`) y delega en `Visits::ResolveVisitorPerson`, que busca en este orden: documento (si viene), luego correo. Para buscar por correo se agrega `people.email_digest` (blind index SHA-256 del correo normalizado, mismo patrón que `document_number_digest`) con índice único parcial por `organization_id` donde no sea nulo. Migración con backfill. Si no hay coincidencia se crea la `Person` (`People::Create`) con `display_name`, correo, teléfono y documento. Nunca se fusionan personas; un conflicto (mismo documento, distinto correo) devuelve 422 con mensaje i18n.

### D4 — `Visits::NotifyVisitor` (fuera de la transacción)
Llamado por `Residents::CreateAuthorizedVisit` tras `Visits::Create`, en el mismo `.tap` donde hoy se llama `Notifications::CreateForVisit`. Nunca lanza: captura y registra en `visit.metadata["visitor_notification_error"]`.

Ramas sobre `person = visit.visitor_person`:
1. `person.user` presente → `Notification` (`visit_invitation`, canal `push`, `recipient_person: person`) + `DeliverPushNotificationJob`; `VisitMailer.with(visit:).invitation.deliver_later`.
2. `person.user` ausente pero existe `User` confirmado con ese correo → `Accounts::LinkUserToPerson.call(person:, user:)`; si no es miembro de la org, `OrganizationMembership` activa con rol `visitor`; luego como rama 1.
3. Sin `User` → `Accounts::InvitePerson.call_for_person(person:, requested_relationship: :visitor, requested_by_person: actor_person)`; si lanza `AlreadyInvited` se reutiliza la solicitud pendiente **sin nuevo token**, y en ese caso el correo enviado es `invitation` (recordatorio con detalle) sin enlace. Si se generó token → `VisitMailer.with(visit:, onboarding_request:, token:).invitation_with_account.deliver_later`.

`Notification.notification_type` gana el valor `visit_invitation`. `Notifications::VisitInvitationPushPayload`: título y cuerpo i18n con nombre de propiedad y fecha; `data: { type: "visit_invitation", visit_id, residential_property_name, unit_identifier, scheduled_at }`.

### D5 — Relación y rol `visitor`
- `OnboardingRequest::RequestedRelationships` añade `visitor`. Validación: `unit_id` y `residential_property_id` nulos para `visitor`.
- `Memberships::AcceptOnboarding` para `visitor` crea `OrganizationMembership` activa con rol `visitor` (join inmediato, como `membership`).
- `AvailableRoles::VISITOR = "visitor"`, rol organizacional. `Authorization::Capabilities::VIEW_OWN_VISITS`. `StaffRoleMapper` mapea `visitor → [view_own_visits]`. `Resolver` también otorga `view_own_visits` a cualquier user que sea `visitor_person` de alguna visita vigente, para cubrir residentes invitados a otra unidad.
- `VisitPolicy#show?` para el API de invitaciones: `allowed?(VIEW_OWN_VISITS) && record.visitor_person.user_id == user.id`.
- `Private::BaseController#ensure_current_user_belongs_to_tenant!` ya acepta membresía `visitor` sin cambios.

### D6 — Correos
`VisitMailer` (hereda `ApplicationMailer`, usa `tenant_url_options_for`):
- `invitation`: asunto "Invitación a {propiedad}", cuerpo con anfitrión (`display_name` del creador), propiedad, unidad, fecha/hora; sin documento ni datos de otras personas.
- `invitation_with_account`: igual, más párrafo "Creá tu cuenta para ver tu invitación en la app" con `onboarding_acceptance_url(token)` (14 días, un solo uso; reglas de `property-onboarding`).
Vistas html/text, i18n `visit_mailer.*` en `es`/`en`/`pt`. La página de aceptación existente no cambia; al terminar redirige a login web; el correo indica descargar la app.

### D7 — Expo Push junto a FCM
- `ExpoPush::Client#send_notification(token:, title:, body:, data:)` → `POST {EXPO_PUSH_BASE_URL || https://exp.host}/--/api/v2/push/send`, header `Authorization: Bearer` con `credentials.dig(:expo, :access_token)` si existe. Devuelve el mismo `Result(success?, error_message, error_code)` que `Fcm::Client`. Nunca lanza.
- `Notifications::PushTransport.for(device_token)` → `ExpoPush::Client` si `token.start_with?("ExponentPushToken[")`, si no `Fcm::Client`.
- `DeliverPushNotificationJob` usa el selector. Si `error_code == "DeviceNotRegistered"` → `notification.failed!` y `device_token.destroy`.
- Sin cambios en política de un intento ni en rollup de `visit.notification_status`.

### D8 — i18n
Claves nuevas: `api.errors.*` (day inválido, conflicto de identidad), `visit_mailer.*`, `notifications.visit_invitation.{title,body}`, `roles.visitor`. Siempre en los tres locales.

## Riesgos

- Backfill de `email_digest` sobre `people` cifradas: correr en lotes.
- Residente que se invita a sí mismo: rama 1, recibe su propio push; aceptable.
- El `access_code` va `null` hasta que exista un change de códigos de acceso.

## Testing

Minitest: controladores de cada endpoint (feliz, tenant cruzado 404, sin capacidad 403, no autenticado 401), `SessionsController` (residente ok, no miembro 403), `Visits::ResolveVisitorPerson` (por correo, creación, conflicto), `Visits::NotifyVisitor` (tres ramas + `AlreadyInvited`), `Memberships::AcceptOnboarding` con `visitor`, `Authorization::Resolver` con rol `visitor`, `ExpoPush::Client` con WebMock (ok, `DeviceNotRegistered`, red caída), `Notifications::PushTransport`, `VisitMailer` (contenido, sin PII, enlace presente/ausente), `DeliverPushNotificationJob` con token Expo.
