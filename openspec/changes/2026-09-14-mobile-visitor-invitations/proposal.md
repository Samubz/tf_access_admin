## Why

La app móvil `tf_access_mobile` no funciona contra `tf_access_admin`: llama endpoints que no existen (`/me`, `/units`, `/organization/:id`, `.../visit?day=`), el login del API exige rol `tenant_admin` (un residente recibe 403) y el flujo de invitación solo captura nombre, documento y teléfono. Además, el push actual avisa a los autorizadores de la unidad, nunca al visitante, y no existe forma de que un visitante sin cuenta la obtenga.

Objetivo de producto: un residente invita a un visitante externo desde la app indicando su correo. El visitante recibe una notificación push si ya tiene cuenta y la app instalada; si no tiene cuenta, recibe un correo con el detalle de la visita y un enlace de un solo uso para crearla. Al entrar, el visitante solo ve sus invitaciones.

## What Changes

- **API privada móvil completa** bajo `/api/v1/private`: `GET/PATCH /me`, `GET /units`, `GET /organization/:id`, `GET /organization/:id/residential_property/:id`, `GET /units/:unit_id/visits?day=`, `GET /invitations`. Contratos alineados con lo que la app ya consume.
- **Login API para cualquier miembro** confirmado de la organización del subdominio (se retira la exigencia de `tenant_admin`).
- **Correo del visitante** como identificador: `POST /units/:unit_id/visits` acepta `visitor.email` (obligatorio); `name` obligatorio; `document` y `phone` opcionales. Búsqueda de `Person` por correo dentro de la organización.
- **Vinculación o alta de cuenta del visitante** (`Visits::NotifyVisitor`): con `User` existente se enlaza y notifica; sin `User` se emite un `OnboardingRequest` con relación nueva `visitor` y se envía correo con enlace de aceptación. Reutiliza `Accounts::InvitePerson` / `AcceptInvitation` / `LinkUserToPerson`.
- **Rol `visitor`** organizacional con única capacidad `view_own_visits`; membresía activa al aceptar.
- **Push al visitante**: tipo `visit_invitation`; transporte **Expo Push Service** además de FCM, seleccionado por formato de token; `DeviceNotRegistered` invalida el token.
- **Correos** `VisitMailer#invitation` (con cuenta) e `#invitation_with_account` (sin cuenta), i18n `es`/`en`/`pt`.

## Capabilities

### New Capabilities

- `mobile-private-api`: contrato de la API privada consumida por la app móvil (perfil, organizaciones, propiedades, unidades, visitas por día, invitaciones del visitante).

### Modified Capabilities

- `residential-visit-management`: el correo del visitante identifica a la `Person`; documento y teléfono pasan a opcionales; notificación al visitante tras crear la visita.
- `property-onboarding`: relación `visitor` en la solicitud de onboarding; correo de invitación de visita con enlace de aceptación.
- `operational-roles-and-permissions`: rol organizacional `visitor` con capacidad `view_own_visits`; login API abierto a todo miembro.
- `fcm-push-notifications`: transporte Expo Push junto a FCM; tipo `visit_invitation`; invalidación de token en `DeviceNotRegistered`.

## Impact

**Bounded context:** Visits, People/Onboarding, Authorization, Notifications, API privada. Integración con la app móvil (change `2026-09-14-visitor-invitation-and-push` en `tf_access_mobile`) y con Expo Push Service.

**Modelos y tablas:** `people` (índice por digest de correo), `onboarding_requests` (valor `visitor` en `requested_relationship`), `organization_memberships` (rol `visitor`), `notifications` (tipo `visit_invitation`), `device_tokens` (sin cambio de esquema; acepta tokens Expo).

**Servicios:** `Residents::ResolveVisitorPerson`, `Visits::ResolveVisitorPerson`, `People::FindExisting` (búsqueda por correo), nuevo `Visits::NotifyVisitor`, `Accounts::InvitePerson.call_for_person` (relación `visitor`), `Memberships::AcceptOnboarding` (rol `visitor`), `Authorization::Capabilities` / `StaffRoleMapper` / `Resolver`, nuevo `ExpoPush::Client`, nuevo `Notifications::PushTransport`, `DeliverPushNotificationJob`, nuevos serializers `Api::Private::*`.

**Tenant isolation:** todo endpoint resuelve la organización por subdominio; `Person` del visitante se crea y busca solo dentro de la organización; el `User` sigue siendo global y único por correo (spec `user-account-linking` sin cambios). El visitante nunca obtiene capacidades sobre unidades ni propiedades.

**Dependencias:** `2026-07-18-onboarding-http-and-delivery` (archivado), `2026-07-13-add-fcm-push-notifications` (archivado).

## Non-goals

- Selector de organización en la app (el subdominio decide el tenant).
- Código o QR de acceso para el visitante (se expone `access_code: null` hasta que exista).
- Aceptar o rechazar la invitación por parte del visitante.
- Reintentos automáticos de push (se mantiene la política de un intento).
- SMS o WhatsApp.
- Configuración de proveedor de correo en producción (Resend queda como tarea de infraestructura separada; este change solo garantiza que funcione con SMTP/MailHog).
