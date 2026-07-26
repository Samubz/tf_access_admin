# Tasks

> Implementación de la capa de exposición sobre los servicios de onboarding ya entregados (change archivado `normalize-user-identity-and-property-onboarding`). Aditivo salvo el cableado del importador (con tests de red).

## 1. Endpoints HTTP de onboarding (§18)

- [x] 1.1 Rutas + `Admin::OnboardingRequestsController`: `index`/`new`/`create` (invita vía `Accounts::InvitePerson` + entrega email), `revoke`, `resolve_conflict`. Autorización `OnboardingRequestPolicy`; tenant desde contexto. Backend testeado; falta la UI (§6).
  - Tests: `onboarding_requests_controller_test.rb` (index, create+email encolado, no-manager bloqueado). 3/3.
- [x] 1.2 `OnboardingAcceptancesController` (`get/post onboarding/accept/:token`): resuelve org por token, muestra info neutral (org + email enmascarado), acepta vía `Accounts::AcceptInvitation`.
  - Tests: `onboarding_acceptances_controller_test.rb` (show neutral, token inválido, aceptación crea cuenta confirmada + membresía activa). 3/3.
- [~] 1.3 `OnboardingRequestPolicy::Scope` org-scoped implementado: devuelve las solicitudes de la org solo si el actor tiene `manage_people`, si no `none`. ✅ (`onboarding_request_policy_test.rb`, 4/4).
  - **Pendiente (con 1.1):** la acción `index` HTTP que consume el scope + la UI.

## 2. Entrega por email (mailer + i18n)

- [x] 2.1 `OnboardingMailer#invitation` + vistas html/text; `deliver_later` (Sidekiq) desde el controller; link de un solo uso (`onboarding_acceptance_url`), nombre de la org, sin PII.
- [x] 2.2 i18n `onboarding_mailer.invitation.*` en es/en/pt. Test: `onboarding_mailer_test.rb` (org en asunto/cuerpo, link presente, sin documento). 1/1.

## 3. Aceptación que crea cuenta nueva (Flujo A/B)

- [x] 3.1 `Accounts::AcceptInvitation` ampliado: sin cuenta resuelta crea `User` (password del titular + name/dni/language con fallback a datos de la `Person`, `skip_confirmation!`) + `LinkUserToPerson` + `AcceptOnboarding`; **auto-confirma el email** en ambos ramos (existente sin confirmar también). `AccountRequired` ahora exige password.
  - Tests: `invitation_test.rb` (9/9) — Flujo A/B crea cuenta confirmada+vinculada+membresía activa; incorporación; single-use/inválido/expirado.

## 4. Gate de confirmación (§14.2)

- [x] 4.1 `config.allow_unconfirmed_access_for = 0.days` en `config/initializers/devise.rb` (sin periodo de gracia). Con auto-confirmación al aceptar (D3), el gate aplica sobre todo al auto-registro.
  - Tests: `test/models/user_confirmation_gate_test.rb` — no confirmado no `active_for_authentication?`; confirmado sí. Suite completa 1128, 0 fallos.

## 4b. Política de contraseña (D6)

- [x] 4b.1 Validación `User#password_meets_complexity` (`PASSWORD_COMPLEXITY`): min 8 + minúscula + mayúscula + dígito + símbolo `[$%@.\-_]`; mensaje `admin.users.validations.password_complexity` en es/en/pt. Frontend Zod (`schemas/user.ts`) alineado: **añadido el dígito** que faltaba (`password_number`). Migrados los tests (`password1` → `Password1@`).
  - Tests: `test/models/user_password_policy_test.rb` (7/7); suite completa 1118, 0 fallos; type-check sin errores nuevos.

## 5. Cableado del clasificador en bulk import (§13→§18)

- [x] 5.1 `ImportPeopleRow`/validadores usan `ClassifyPeopleRow` para **clasificar**: crear solo las filas `ready_to_create_person`; el resto (invitación/incorporación/revisión/conflicto) se registra con su estado para que **el gestor** dispare la acción; `duplicate` idempotente; `invalid` rechazada. **No** auto-envía invitaciones ni crea solicitudes.
  - Tests: batch mixto (crear/incorporar/conflicto/duplicado/invalid); no se auto-envían correos; idempotencia.
- [x] 5.2 UI de bulk import muestra el estado por fila (i18n). `Admin::BulkImportRowSerializer` expone `onboarding_classification`; `BulkPeopleImportImportStep.vue` añade tabla "Row states" (fetch vía `/rows` reutilizado, ahora paginada) con badge por clasificación, visible al completar el import. i18n es/en/pt.
- [x] 5.3 Escenario "Manager triggers invitations after review": `BulkImportServices::TriggerRowInvitations` (nuevo) reclasifica cada fila `requires_invitation`/`requires_incorporation` defensivamente y llama `Accounts::InvitePerson` (por fila o en lote, `POST .../trigger_invitations`); idempotente vía `target_record` (reutilizado, sin migración) y reclasificación previa; conflicto/duplicado detectados en el momento no envían email. UI: botón por fila + "Invite all pending" en la tabla "Row states", con confirmación y toast de resultado.
  - Tests: `trigger_row_invitations_test.rb` (7/7 — invita, incorpora, idempotencia, reclasifica a conflict/duplicate, fallo por fila no aborta el lote, `row_ids` escopa); `bulk_imports_controller_test.rb` (autorización, cross-tenant, scoping). 0 fallos.

## 6. Frontend (§19)

- [x] 6.1 Pantallas de invitación e incorporación con info **neutral** (email-blind); pantalla de aceptación por token; estados de clasificación. Vue + Inertia + i18n.
  - **Revisado (feedback del usuario):** las pantallas separadas `admin/onboarding_requests/{index,new}.vue` duplicaban el formulario de "Nueva persona" — se retiraron. Consolidado en `admin/people`: checkbox "enviar invitación" en el form de creación (`components/admin/person/Form.vue`), columna de estado de invitación (`linked`/`pending`/`not_invited`) y acción "Enviar invitación" por fila en `admin/people/index.vue`. Backend: `Accounts::InvitePerson.call_for_person`/`.deliver` (invita a una persona ya conocida sin re-resolver identidad, evita duplicados); `Admin::PeopleController#invite` (nuevo, `POST /admin/people/:id/invite`) + checkbox en `#create`. `Admin::OnboardingRequestsController` queda solo con `revoke`/`resolve_conflict` (endpoints, sin UI propia); `index`/`new`/`create` eliminados junto con su ruta, policy `index?`/`invite?` huérfanas y i18n muerto. `onboarding/{accept,invalid}.vue` (holder-facing, neutral: org + email enmascarado, sin listar otras orgs; Flujo A/B con contraseña + complejidad reutilizada) sin cambios. i18n es/en/pt. `npm run check` sin errores nuevos (2 preexistentes no relacionados). No se pudo verificar visualmente en navegador: el sandbox de este entorno bloquea `bin/dev` (permiso de `getcwd`), no relacionado con el cambio.
  - Tests: `people_controller_test.rb` (+7: invitation_status en index, create+checkbox, invite éxito/ya-invitado/no-manager, auditoría), `onboarding_requests_controller_test.rb` (reescrito: solo revoke, 3/3). 0 fallos.

## 7. Auditoría y verificación (§15, §5/§8/§10/§11, §20, §22)

- [x] 7.1 Auditoría de operaciones sensibles vía endpoints (actor/estado previo-posterior; sin documentos/tokens/secretos). Ya cubierto por `audited only: %i[status requested_relationship conflict_reason expires_at]` en `OnboardingRequest` + `TenantAudit`/`current_user_method`; verificado con tests de controller (create/revoke: actor, estado previo/posterior, sin `token_digest` ni documento).
- [x] 7.2 Verificar specs de decisión/aislamiento/privacidad/propiedad (§5/§8/§10/§11) contra la implementación. Cubierto por `onboarding_mailer_test`, `invitation_test`, `onboarding_request_policy_test`, `user_confirmation_gate_test`, `user_password_policy_test`; gap encontrado y cerrado: revocación por un manager distinto del emisor (`onboarding_requests_controller_test`).
- [x] 7.3 Enumerar/cerrar cobertura de tests (§20); `openspec validate --strict` en verde (§22); `graphify update app`. Suite backend relacionada (115 tests: onboarding requests/acceptances/mailer/invitation/policy/gate/password/bulk_import) 0 fallos; `openspec validate onboarding-http-and-delivery --strict` en verde.
- [x] 7.4 Auditoría de spec-compliance de toda la rama (a pedido del usuario, sin decisiones unilaterales): 3 exploraciones en paralelo (spec/design/tasks verbatim, backend literal, frontend literal) + revisión con el usuario. Gap cerrado: 5.3 (arriba). Bugs de esta sesión corregidos: falta `admin.onboarding_requests.errors.identity_conflict` (causaba toast de éxito falso en conflicto de identidad en `new.vue`) y error silencioso en `onboarding/accept.vue` (`props.errors.base` nunca mostrado). Decisión confirmada con el usuario: `resolve_conflict` queda sin UI (intencional, capability super-admin). Tests de regresión: `onboarding_requests_controller_test.rb`, `onboarding_acceptances_controller_test.rb`.
