# Improve Property Sections

## Why

`PropertySection` representa la estructura interna de una propiedad, pero hoy su contrato está fragmentado:

* la jerarquía requiere formalizar como regla de dominio un máximo de dos niveles;
* las reglas viven parcialmente en el modelo y parcialmente en `PropertySectionHierarchy`;
* no existe `normalized_name` ni unicidad amigable por parent;
* no existe estado controlado para lifecycle de secciones;
* create/update/destroy operan directamente sobre Active Record desde dos controllers distintos;
* el movimiento de secciones está bloqueado en la UI y no tiene servicio de dominio;
* `PropertySection::TreeBuilder` existe, pero su contrato combina árbol, unidades y opciones de formulario sin permisos backend-driven;
* la eliminación actual puede destruir subsecciones, unidades y visitas mediante asociaciones en cascada.

Este change normaliza la jerarquía después de `improve-property-foundation` y antes del futuro endurecimiento de `Unit`. Una unidad necesita una propiedad válida y, cuando usa sección, una ubicación jerárquica consistente.

## What Changes

* Definir el contrato mínimo de `PropertySection`:
  * `organization_id`;
  * `residential_property_id`;
  * `parent_id`;
  * `name`;
  * `normalized_name`;
  * `section_type`;
  * `position`;
  * `status`;
  * `metadata`.
* Exigir que organización, propiedad y parent pertenezcan al mismo contexto tenant/property.
* Formalizar una jerarquía máxima de dos niveles: sección raíz y subsección.
* Impedir crear o mover secciones por debajo del segundo nivel.
* Validar que la jerarquía sea acíclica, aunque la profundidad máxima esté limitada.
* Impedir auto-parent, ciclos, movimientos hacia descendientes y movimientos que generen un tercer nivel.
* Exigir nombre normalizado único entre hermanos del mismo parent.
* Permitir el mismo nombre bajo parents distintos dentro de una propiedad.
* Ordenar hermanos por `position` y luego por nombre normalizado.
* Controlar `section_type` mediante un catálogo canónico orientado a estructura residencial.
* Definir `block`, `tower` y `floor` como los únicos tipos de sección elegibles para contener unidades.
* Controlar `status` con `active`, `inactive` y `archived`.
* Definir estado efectivo: una sección solo es operable cuando ella, todos sus ancestros y su propiedad están activos.
* Preferir archivado no destructivo sobre eliminación cuando existan subsecciones, unidades, visitas u otras dependencias.
* Definir servicios futuros:
  * `PropertySections::Create`;
  * `PropertySections::Update`;
  * `PropertySections::Move`;
  * `PropertySections::Archive`;
  * `PropertySections::TreeBuilder`.
* Unificar creación, edición, movimiento y archivado mediante servicios; los controllers no deciden jerarquía, unicidad ni lifecycle.
* Endurecer `PropertySectionPolicy` para evaluar `manage_sections` en el contexto de la propiedad concreta.
* Entregar a Inertia/Vue un árbol property-scoped con profundidad, path, estado efectivo y permissions/actions calculadas en backend.

## Impact

**Capability nueva:**

* `property-section`: estructura jerárquica tenant-safe dentro de una propiedad, con normalización, lifecycle, movimiento, árbol y autorización.

**Dependencias:**

* `residential-property`: una sección depende de una propiedad tenant-consistent y no archivada para mutaciones ordinarias.
* `operational-roles-and-permissions`: reutiliza `manage_sections`, `Authorization::Resolver` y `StaffAssignment` activo por propiedad.
* futuro change de `Unit`: podrá exigir que una sección pertenezca a la misma propiedad, esté efectivamente activa y cumpla la regla de elegibilidad definida para unidades.
* bulk import de unidades: deberá consumir el contrato futuro de elegibilidad de sección, sin refactorizarse en este change.

**Implementación futura afectada:**

* modelo, concern de jerarquía y constraints de `property_sections`;
* services `PropertySections::*`;
* `PropertySectionPolicy`;
* controllers anidado y plano;
* `PropertySection::TreeBuilder`, serializers y props;
* pantalla de estructura y componentes Vue;
* tests de modelo, servicios, policy, requests, árbol y UI.

La implementación deberá auditar datos existentes incompatibles: nombres hermanos duplicados, valores de tipo, jerarquías inválidas y posiciones repetidas.

## Business Rules

* Toda sección pertenece a exactamente una organización y una propiedad.
* La organización de la sección coincide con la organización de su propiedad.
* La propiedad se obtiene desde contexto autorizado y no puede cambiarse mediante update/move.
* Una sección raíz tiene `parent_id = null`.
* Una sección no raíz tiene un parent de la misma organización y propiedad.
* La jerarquía admite máximo dos niveles: raíz y subsección.
* Una sección raíz tiene `parent_id = null`.
* Una subsección puede tener `parent_id`, pero su parent debe ser una sección raíz.
* No se permite crear una sección nieta.
* La jerarquía nunca contiene ciclos.
* Una sección no puede ser parent de sí misma ni moverse bajo uno de sus descendientes.
* `name` es obligatorio y genera `normalized_name`.
* `normalized_name` es único entre secciones no eliminadas con el mismo parent y propiedad.
* Dos ramas distintas pueden usar el mismo nombre.
* Secciones raíz comparten un contexto de unicidad explícito; `parent_id = null` no permite duplicados.
* `position` es un entero positivo usado para ordenar hermanos; empates se resuelven por nombre normalizado e id.
* El catálogo objetivo de tipos incluye `building`, `tower`, `floor`, `block`, `stage`, `sector`, `parking_area`, `storage_area` y `other`.
* Solo las secciones con `section_type` `block`, `tower` o `floor` pueden contener unidades.
* Las secciones con `section_type` `building`, `stage`, `sector`, `parking_area`, `storage_area` u `other` no son elegibles para asociar unidades directamente.
* Valores legacy requieren una estrategia explícita de mapeo antes de aplicar constraints.
* `status` solo admite `active`, `inactive` o `archived`.
* Una sección nueva comienza `active` si su propiedad y parent están activos.
* Una sección es efectivamente activa solo si ella, sus ancestros y su propiedad están activos.
* No se crean ni mueven secciones bajo una propiedad o parent inactivo/archivado.
* Archivar una sección no elimina ni cambia físicamente sus descendientes o unidades; el subárbol queda efectivamente no operativo por su ancestro archivado.
* El hard delete se deniega cuando existen subsecciones, unidades, visitas u otras dependencias.
* `tenant_admin` gestiona secciones dentro de propiedades de su organización.
* `property_admin` gestiona secciones únicamente en propiedades con `StaffAssignment` activo y vigente que conceda `manage_sections`.
* `property_admin` nunca es global.
* No existe acceso cross-organization ni cross-property.
* La UI recibe permissions/actions del backend; no infiere autorización desde status, depth o tipo.

## Out of Scope

* Implementar código, migraciones, services, controllers, policies, UI o tests.
* Endurecer `Unit` o crear su flujo interactivo.
* Refactorizar el bulk import de unidades.
* Mover secciones entre propiedades.
* Implementar drag-and-drop; el contrato de movimiento no depende de una interacción específica.
* Definir reglas finales de qué `section_type` puede contener unidades.
* Implementar restauración de secciones archivadas.
* Implementar hard delete o purga física.
* Convertir `property_admin` en rol global.
* Exponer el árbol completo de otra propiedad u organización.
