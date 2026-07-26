# README

# Crear un nuevo proyecto desde este repositorio base

Este repositorio está pensado para ser usado como **base de nuevos proyectos**.  
Cada nuevo proyecto que nazca desde aquí debe poder:

- comenzar con una base estándar
- tener su propio desarrollo independiente
- seguir recibiendo mejoras futuras desde este repositorio base

Para lograrlo, el flujo oficial es:

- el proyecto nuevo se crea como **repositorio independiente**
- este repositorio base se configura como remoto `upstream`
- el proyecto nuevo usa su propio `origin`
- cuando existan mejoras en la base, el proyecto nuevo puede traerlas desde `upstream`

---

## Uso de este repositorio

Este repositorio es una base para nuevos proyectos.  
Los proyectos derivados deben crearse como repositorios independientes y mantener este repositorio configurado como `upstream` para poder recibir mejoras futuras.

---

## Política de proyectos derivados

Todo proyecto que nazca desde este repositorio debe:

- crear su propio repositorio independiente
- configurar este repositorio como `upstream`
- realizar su desarrollo sobre `origin`
- sincronizar periódicamente cambios desde `upstream`

---

## Conceptos clave

- **origin**: repositorio del proyecto nuevo
- **upstream**: repositorio base del cual nació el proyecto

### Ejemplo

- `origin` → `git@github.com:empresa/proyecto-cliente-a.git`
- `upstream` → `git@github.com:empresa/dashboard-base.git`

---

## Flujo oficial para crear un nuevo proyecto

### 1. Crear el nuevo repositorio en GitHub
Crear manualmente en GitHub un repositorio nuevo para el proyecto.

```bash
git@github.com:empresa/proyecto-cliente-a.git
```
***Este repositorio debe estar vacío al inicio.***


### 2. Crear carpeta en local y setear origin

```bash
mkdir new-project
cd /new-project
git init
git checkout main
git remote add origin git@github.com:Samubz/admin_base.git
git pull origin main
```

### 3. Cambiar la configuración de remotos
Renombrar el remoto actual para que el repositorio base quede como upstream:
```bash
git remote rename origin upstream
```
Agregar el repositorio nuevo como origin:
```bash
git remote add origin git@github.com:Samubz/new-peoject.git
```


### 4. Verificar remotos
```bash
git remote -v
```
Debería verse algo similar a esto:
```bash
origin	git@github.com:Samubz/fidelidade_admin.git (fetch)
origin	git@github.com:Samubz/fidelidade_admin.git (push)
upstream	git@github.com:Samubz/admin_base.git (fetch)
upstream	git@github.com:Samubz/admin_base.git (push)
```

### 5. Subir el proyecto nuevo a su propio repositorio
```bash
git push -u origin main
```
Si la rama principal del proyecto usa master o develop, reemplazar main por la correspondiente.

## Flujo de trabajo diario del proyecto nuevo

A partir de este punto:
- todo el desarrollo del proyecto se hace contra origin
- los cambios comunes del dashboard base se traen desde upstream

## Cómo traer cambios nuevos desde el repositorio base

### 1. Obtener cambios del repositorio base
```bash
git fetch upstream
```
### 2. Integrar cambios en la rama principal del proyecto
Si la rama principal es main:
```bash
git checkout main
git merge upstream/main
```
Si usan develop como rama de integración:
```bash
git checkout develop
git merge upstream/main
```
Esto depende de la estrategia de ramas del equipo.

## Ejemplo completo

```bash
git clone git@github.com:empresa/dashboard-base.git proyecto-nuevo
cd proyecto-nuevo

git remote rename origin upstream
git remote add origin git@github.com:empresa/proyecto-nuevo.git

git remote -v

git push -u origin main
```
Cuando existan cambios nuevos en la base:

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```


## Crear un usuario

Rolify está declarado en **`Person`**, no en `User`. Los roles globales (p. ej. `super_admin`) y por organización (`tenant_admin`) se asignan con `person.add_role(...)` sobre la persona del tenant.

```bash

bin/rails c

email = 'sambzgo@gmail.com'
password = '123123'

subdomain = 'demo-pro'
organization = Organization.find_or_initialize_by(subdomain: subdomain)
organization.assign_attributes(
  name: organization.name.presence || "Bar & Cocina Demo",
  plan: Organization::PLAN_PRO
)
organization.save!

ActsAsTenant.with_tenant(organization) do
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(
    name: user.name.presence || "Admin demo",
    dni: user.dni.presence || "DEMO-1",
    language: user.language.presence || Languages::ES,
    password: password,
    password_confirmation: password
  )
  user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
  user.save!

  person = user.person_for(organization)
  if person.nil?
    person = user.people.create!(
      organization: organization,
      display_name: user.name.presence || user.email,
      status: "active",
      person_type: PersonTypes::NATURAL
    )
    membership = OrganizationMembership.create!(organization: organization, person: person)
    membership.accept!
    person.add_role(AvailableRoles::CLIENT) unless person.has_role?(AvailableRoles::CLIENT)
  end

  ActsAsTenant.without_tenant do
    person.add_role(AvailableRoles::SUPER_ADMIN) unless person.has_role?(AvailableRoles::SUPER_ADMIN)
  end
  person.add_role(AvailableRoles::TENANT_ADMIN, organization) unless person.has_role?(AvailableRoles::TENANT_ADMIN, organization)

  puts <<~MSG
    Listo.
      Organización: #{organization.name} (#{organization.subdomain}) id=#{organization.id} plan=#{organization.plan}
      Usuario:      #{user.email} (super_admin: #{user.super_admin?}, tenant_admin: #{user.tenant_admin?(organization)})
  MSG
end
exit
```

## Para iniciar el proyecto

```bash
bundle install
npm install

foreman start -f Procfile.dev
```

ingresar a
- http://demo-pro.localhost:5100/home

### To install shadcn modules
```bash
npm run shadcn -- add hover-card -y
```

## Correo local (MailHog)

En desarrollo, los correos se entregan por SMTP a una instancia local de MailHog en vez de enviarse de verdad (nunca llegan a un destinatario real).

```bash
docker compose up -d mailhog
```

Luego visita `http://localhost:8025` para ver todos los correos capturados (asunto, destinatarios, contenido renderizado).

Para detenerlo:

```bash
docker compose down
```

Si tu instancia de MailHog corre en otro host/puerto, sobrescribe los valores por defecto (`localhost`/`1025`) en tu `.env`:

```bash
MAILHOG_SMTP_ADDRESS=localhost
MAILHOG_SMTP_PORT=1025
```

Ver `.env.example` para los valores de referencia.

## Push notifications locales (PushHog)

En desarrollo, las push notifications (FCM) se envían a un simulador local compatible con la API de Firebase (ej. PushHog) en vez de a Firebase real.

Por defecto, `FCM_BASE_URL` apunta a `https://fcm.googleapis.com` (real). Para redirigir a un simulador local, sobrescribe en tu `.env`:

```bash
FCM_BASE_URL=http://localhost:8090
FCM_PROJECT_ID=development
```

`FCM_PROJECT_ID` no es validado por el simulador local; solo es relevante con credenciales reales de Firebase (autenticación OAuth2 real queda fuera de alcance por ahora).

Ver `.env.example` para los valores de referencia.
