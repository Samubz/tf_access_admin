# Improve Property Foundation

## Why

`ResidentialProperty` es la raíz del catastro residencial y condiciona secciones, unidades, asignaciones operativas, personas relacionadas y visitas. Hoy la creación y actualización operan directamente desde `Admin::ResidentialPropertiesController`, no existen servicios de dominio para el ciclo de vida de la propiedad, `status` solo valida presencia y la eliminación invoca `destroy` sobre un modelo con asociaciones `dependent: :destroy`.

La base actual también garantiza unicidad del `code` activo por organización, pero no define ni protege la unicidad del nombre. El frontend conoce únicamente `active` e `inactive`, mientras que el dominio necesita una estrategia explícita de archivado que preserve dependencias.

Este change endurece primero el contrato de `ResidentialProperty`. Debe completarse antes de refactorizar la creación de secciones, unidades, bulk imports o flujos dependientes como visitas.

## What Changes

* Definir el contrato mínimo de una propiedad residencial:
  * `organization_id`;
  * `name`;
  * `property_type`;
  * `status`;
  * información de ubicación mediante los campos de dirección existentes y `metadata` extensible.
* Exigir nombre normalizado único por organización entre propiedades no eliminadas, permitiendo el mismo nombre en organizaciones diferentes.
* Mantener `code` opcional y único por organización cuando está presente.
* Controlar `status` con `active`, `inactive` y `archived`.
* Definir un ciclo de vida explícito:
  * creación en `active` por defecto;
  * activación/desactivación controlada;
  * archivado no destructivo;
  * una propiedad archivada deja de admitir nuevas operaciones de catastro ordinarias.
* Preferir archivado sobre eliminación cuando la propiedad tenga dependencias.
* Impedir hard delete de propiedades con secciones, unidades, personas relacionadas, staff assignments, visitas futuras u otras dependencias operativas.
* Evitar que el archivado destruya o archive en cascada secciones, unidades, visitas o relaciones.
* Introducir como objetivo futuro servicios:
  * `Properties::Create`;
  * `Properties::Update`;
  * `Properties::Archive`.
* Mantener controllers delgados: autenticación, autorización, parámetros, invocación de servicio y respuesta.
* Alinear `ResidentialPropertyPolicy` con `Authorization::Resolver` y scopes tenant-safe:
  * `tenant_admin` gestiona propiedades dentro de su organización;
  * `property_admin` ve y actualiza solo propiedades con `StaffAssignment` activo;
  * creación y archivado permanecen como operaciones organizacionales;
  * ningún rol operacional de propiedad se vuelve global.
* Exigir cobertura de modelo, servicios, policy, controller/request, aislamiento y lifecycle.

## Impact

**Capability nueva:**

* `residential-property`: contrato fundacional de identidad, ubicación, estado, lifecycle, servicios y autorización de propiedades residenciales.

**Capabilities relacionadas:**

* `operational-roles-and-permissions`: conserva `manage_properties` como capability organizacional y `manage_property` como capability acotada a propiedades asignadas.
* `unit-owner-management` y `unit-occupancy-management`: dependen de unidades bajo una propiedad activa y tenant-consistent.
* `visit-management`, `residential-visit-management` y `concierge-visit-access-flow`: dependen del scope y estado operacional de la propiedad, pero no se modifican funcionalmente en este change.

**Componentes de implementación futura:**

* `ResidentialProperty` y constraints de base de datos;
* servicios `Properties::*`;
* `ResidentialPropertyPolicy` y scope;
* `Admin::ResidentialPropertiesController`;
* serializer/props y UI administrativa mínima del lifecycle;
* tests de modelo, servicios, policy, requests y sistema.

**Datos existentes:**

La implementación futura deberá auditar nombres duplicados y valores de estado existentes antes de agregar constraints. Este OpenSpec no ejecuta migraciones ni modifica datos.

## Business Rules

* Toda propiedad pertenece a exactamente una organización.
* La organización se deriva del contexto autenticado y no se acepta como autoridad desde el cliente.
* `name` es obligatorio, se recorta y normaliza para comparación.
* Dos propiedades no eliminadas de la misma organización no pueden compartir el mismo nombre normalizado.
* Organizaciones distintas pueden utilizar el mismo nombre.
* `property_type` es obligatorio y pertenece al catálogo existente de tipos.
* `status` solo admite `active`, `inactive` o `archived`.
* Una propiedad nueva comienza `active`, salvo una decisión explícita y autorizada del servicio.
* `inactive` representa una suspensión operacional reversible.
* `archived` representa retiro no destructivo y conserva catastro, historial y referencias.
* El archivado se ejecuta mediante una operación de dominio; no equivale a `destroy`.
* Una propiedad archivada no acepta nuevas secciones, unidades, bulk imports, asignaciones operativas ni visitas, salvo operaciones explícitas de consulta, auditoría o restauración futura.
* Hard delete se deniega si existe cualquier dependencia relevante, incluyendo:
  * `PropertySection`;
  * `Unit`;
  * ownerships u occupancies que relacionen personas con sus unidades;
  * `StaffAssignment`;
  * visitas futuras o activas;
  * configuración, áreas comunes u otros registros operativos asociados.
* La operación pública normal para retirar una propiedad con dependencias es archivar.
* `tenant_admin` puede crear, ver, actualizar y archivar propiedades únicamente en su organización.
* `property_admin` puede ver y actualizar una propiedad solo con `StaffAssignment` activo y vigente para ella.
* `property_admin` no puede crear propiedades nuevas ni archivarlas por defecto, porque ambas son operaciones de alcance organizacional.
* Un usuario sin capabilities no puede listar, ver, crear, actualizar, archivar ni eliminar propiedades fuera de su alcance.
* El acceso cross-organization siempre se deniega.
* Los servicios de dominio son la fuente de validaciones y decisiones de lifecycle; el controller y el frontend no pueden omitirlas.

## Out of Scope

* Implementar código, migraciones, servicios, policies, controllers, rutas, UI o tests.
* Refactorizar `PropertySection`, `Unit` o bulk import.
* Crear el alta interactiva de unidades.
* Redefinir jerarquías de secciones.
* Cambiar flujos de ownership, occupancy o visitas.
* Implementar restauración de propiedades archivadas.
* Diseñar purga física, retención legal o anonimización completa.
* Convertir `property_admin` en rol global.
* Crear nuevos roles organizacionales.
* Resolver en este change todas las dependencias operativas de una propiedad archivada; solo se establece el contrato fundacional.
