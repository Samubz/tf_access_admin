# Tasks

> Orden obligatorio: sección 1 y 2 primero (sin ellas la app no arranca), luego 3 a 6, luego 7. Cada sección termina con sus tests en verde. Mirror de CRUDs existentes: `Api::V1::Private::Units::VisitsController` para endpoints privados, `Admin::PeopleController#invite` para invitaciones.

## 1. Login API para todo miembro (D1)

- [x] 1.1 `Api::V1::Auth::SessionsController#create`: eliminada la exigencia de `TENANT_ADMIN` (la membresía ya la garantiza `User.find_for_authentication`); `role` derivado en `api_role_for` (rol organizacional o `resident`; `visitor` se añade en la sección 4).
- [x] 1.2 Tests: residente ok, no miembro 401 sin token, no confirmado 401. (Visitante ok queda para la sección 4.)

## 2. Endpoints privados y serializers (D2)

- [x] 2.1 Inspeccionar `Units::VisitsController` y `Private::BaseController`; crear `Api::V1::Private::ProfilesController` (`show`, `update`) en rutas `get/patch "me"`. Adjunto `has_one_attached :avatar` en `User`. Serializer `Api::Private::ProfileSerializer`.
- [x] 2.2 `Api::V1::Private::UnitsController#index` + `Api::Private::UnitSerializer`. Query vía scope `Unit.with_active_relationship_for(person)` (nuevo, reutilizable en 2.3).
- [x] 2.3 `Api::V1::Private::OrganizationsController#show` y `Organizations::ResidentialPropertiesController#show` con `Api::Private::ResidentialPropertySerializer`; 404 si `:id != Current.organization.id`.
- [x] 2.4 `Units::VisitsController#index` con `day` (parse estricto, 422) y `Api::Private::VisitSummarySerializer`.
- [x] 2.5 Rutas en `config/routes.rb` bajo `namespace :private`.
- [x] 2.6 Tests de controlador por endpoint: feliz, 401, 403 sin relación, 404 tenant cruzado, 422 day inválido.

## 3. Correo del visitante e identidad (D3)

- [ ] 3.1 Migración: `people.email_digest` (string) + índice único parcial `(organization_id, email_digest) WHERE email_digest IS NOT NULL`; backfill por lotes con `find_each`.
- [ ] 3.2 `Person`: callback que mantiene `email_digest` desde el correo normalizado; `People::FindExisting.by_email(organization:, email:)`.
- [ ] 3.3 `Visits::ResolveVisitorPerson`: orden documento → correo → crear; error de conflicto `Visits::ResolveVisitorPerson::IdentityConflict`.
- [ ] 3.4 `Residents::ResolveVisitorPerson` y `Units::VisitsController#create`: permitir `email`, exigir `name` y `email` válido (formato), 422 i18n en conflicto.
- [ ] 3.5 Tests: reutiliza por correo (case-insensitive), crea, no cruza organización, conflicto 422, email inválido 422.

## 4. Relación y rol `visitor` (D5)

- [ ] 4.1 `OnboardingRequest::RequestedRelationships` += `visitor`; validación sin unidad/propiedad. Migración solo si el enum está en BD (verificar; si es constante Ruby, no hay migración).
- [ ] 4.2 `Memberships::AcceptOnboarding`: rama `visitor` → membresía activa rol `visitor`.
- [ ] 4.3 `AvailableRoles::VISITOR`, `Authorization::Capabilities::VIEW_OWN_VISITS`, `StaffRoleMapper` `visitor → [view_own_visits]`, `Resolver` otorga `view_own_visits` a `visitor_person` de visitas de la org.
- [ ] 4.4 `VisitPolicy#show_own?` y scope `VisitPolicy::OwnScope` (por `visitor_person.user_id`).
- [ ] 4.5 i18n `roles.visitor` en es/en/pt.
- [ ] 4.6 Tests: aceptación crea membresía visitor y permite login API; resolver matriz visitor; visitor 403 en create visits.

## 5. Endpoint de invitaciones (D2)

- [ ] 5.1 `Api::V1::Private::InvitationsController#index` + `Api::Private::InvitationSerializer` (`access_code: nil`).
- [ ] 5.2 Tests: solo propias, solo futuras/hoy, excluye canceladas, sin PII de terceros.

## 6. Notificación al visitante y correos (D4, D6)

- [ ] 6.1 `NotificationTypes` += `visit_invitation`; `Notifications::VisitInvitationPushPayload`.
- [ ] 6.2 `VisitMailer#invitation` e `#invitation_with_account` + vistas html/text + i18n `visit_mailer.*` es/en/pt. Mirror de `OnboardingMailer`.
- [ ] 6.3 `Accounts::InvitePerson.call_for_person` acepta `requested_relationship: :visitor`.
- [ ] 6.4 `Visits::NotifyVisitor` con las tres ramas, manejo de `AlreadyInvited`, captura de errores a `visit.metadata`.
- [ ] 6.5 Cablear en `Residents::CreateAuthorizedVisit` fuera de la transacción.
- [ ] 6.6 Tests: tres ramas, `AlreadyInvited` sin token nuevo, error no bloquea, mailer sin PII y con/sin enlace, locale.

## 7. Expo Push (D7)

- [ ] 7.1 `ExpoPush::Client` (Net::HTTP, `EXPO_PUSH_BASE_URL`, credenciales `expo.access_token`), `Result` con `error_code`.
- [ ] 7.2 `Notifications::PushTransport.for(device_token)`.
- [ ] 7.3 `DeliverPushNotificationJob`: usar selector; `DeviceNotRegistered` → failed + destroy token.
- [ ] 7.4 `.env.example`: `EXPO_PUSH_BASE_URL=http://localhost:8091`. Documentar credencial `expo.access_token` en README de despliegue.
- [ ] 7.5 Tests con WebMock: ok, DeviceNotRegistered, red caída, selección de transporte.

## 8. Cierre

- [ ] 8.1 `bin/rails test` completo, RuboCop, Brakeman.
- [ ] 8.2 `graphify update app`.
- [ ] 8.3 Prueba manual con MailHog y simulador de push: crear visita desde curl con correo nuevo, verificar correo con enlace, aceptar, login API como visitor, `GET /invitations`.
