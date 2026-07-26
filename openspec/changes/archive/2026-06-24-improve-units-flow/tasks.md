# Improve Units Flow Tasks

> Estas tareas implementan el refinamiento del flujo de `Unit`: update descriptivo seguro, bulk import alineado por modo, autorización separada por `view_units`/`manage_units`, búsqueda normalizada, metadata no autoritativa y lifecycle de propiedad. Ninguna está completada.

## 1. Revisión inicial del flujo existente

* [x] 1.1 Revisar implementación actual de `Unit`, validaciones, scopes, callbacks y concerns relacionados
* [x] 1.2 Revisar servicios existentes `Units::*` si ya existen
* [x] 1.3 Revisar controllers o endpoints que crean, actualizan, mueven, archivan o restauran unidades
* [x] 1.4 Revisar serializers/props usados para listar o mostrar unidades
* [x] 1.5 Revisar implementación actual de `UnitPolicy` y `UnitPolicy::Scope`
* [x] 1.6 Revisar implementación actual del bulk import de unidades
* [x] 1.7 Identificar cualquier bypass actual de normalización, unicidad, authorization o lifecycle

## 2. Update descriptivo seguro

* [x] 2.1 Ajustar `Units::Update` para que solo actualice datos descriptivos y operational status permitido
* [x] 2.2 Impedir que `Units::Update` cambie `organization_id`
* [x] 2.3 Impedir que `Units::Update` cambie `residential_property_id`
* [x] 2.4 Impedir que `Units::Update` cambie `property_section_id`
* [x] 2.5 Impedir que `Units::Update` permita `status = archived`
* [x] 2.6 Permitir cambios de status operativo solo dentro del contrato permitido
* [x] 2.7 Asegurar que archive pase exclusivamente por `Units::Archive`
* [x] 2.8 Asegurar que cambios de section pasen exclusivamente por `Units::MoveToSection`
* [x] 2.9 Traducir intentos inválidos de update a errores de dominio o errores de validación consistentes

## 3. Unicidad tenant-scoped

* [x] 3.1 Verificar que la unicidad de `normalized_identifier` incluya organización, propiedad y placement context
* [x] 3.2 Asegurar que el mismo identifier pueda existir en otra organización
* [x] 3.3 Asegurar que el mismo identifier pueda existir en otra propiedad
* [x] 3.4 Asegurar que el mismo identifier pueda existir en otra section válida dentro de la misma propiedad
* [x] 3.5 Asegurar que los errores de duplicado se reporten sobre `identifier`
* [x] 3.6 Mantener protección ante concurrencia mediante índices/constraints existentes o nuevos si corresponde

## 4. Section eligibility

* [x] 4.1 Asegurar que `Unit` valide eligibility de section usando el contrato de `property-section`
* [x] 4.2 Eliminar hardcoding propio de tipos `block`, `tower` o `floor` dentro de `Unit` si existe
* [x] 4.3 Usar `can_contain_units?` o el mecanismo equivalente existente para validar eligibility
* [x] 4.4 Rechazar section no elegible con error en `property_section_id`
* [x] 4.5 Rechazar create o move hacia section inactiva, archivada, soft-deleted o no efectivamente activa
* [x] 4.6 Mantener la validación de same organization y same property para section asignada

## 5. Bulk import alineado por modo

* [x] 5.1 Refactorizar bulk import para reutilizar `Units::NormalizeIdentifier`
* [x] 5.2 Refactorizar creación de unidades desde bulk import para delegar a `Units::Create`
* [x] 5.3 Impedir que bulk import actualice unidades existentes si el modo de importación no permite updates
* [x] 5.4 Delegar actualización descriptiva a `Units::Update` solo cuando el modo permita updates
* [x] 5.5 Impedir que bulk import cambie placement si el modo de importación no permite cambios de section
* [x] 5.6 Delegar cambios de placement a `Units::MoveToSection` solo cuando el modo permita placement changes
* [x] 5.7 Reportar filas no permitidas como skipped, warning, failed o el estado equivalente ya usado por el importador
* [x] 5.8 Mantener preview, errores por fila y counters existentes
* [x] 5.9 Asegurar que bulk import no mantenga reglas divergentes de normalización, unicidad o authorization

## 6. Authorization y policy scope

* [x] 6.1 Actualizar `UnitPolicy` para separar lectura con `view_units` de mutación con `manage_units`
* [x] 6.2 Permitir lectura del catálogo de unidades a actores con `view_units` para la property concreta
* [x] 6.3 Denegar create, update, move y archive a actores sin `manage_units`
* [x] 6.4 Autorizar tenant admin dentro de propiedades de su organización según capabilities correspondientes
* [x] 6.5 Autorizar property admin solo mediante `StaffAssignment` activo y vigente en la property concreta
* [x] 6.6 Permitir lectura a property admin con `view_units`
* [x] 6.7 Permitir mutación a property admin con `manage_units`
* [x] 6.8 Permitir lectura a concierge asignado solo si tiene `view_units`
* [x] 6.9 Denegar mutaciones a concierge si no tiene `manage_units`
* [x] 6.10 Actualizar `UnitPolicy::Scope` para excluir unidades de properties fuera del alcance autorizado
* [x] 6.11 Mantener exclusión estricta de unidades de otras organizaciones
* [x] 6.12 Evitar introducir roles globales nuevos

## 7. Búsqueda y serialización

* [x] 7.1 Actualizar búsqueda de unidades para normalizar input antes de consultar `normalized_identifier`
* [x] 7.2 Mantener búsqueda dentro de scopes autorizados por organization/property
* [x] 7.3 Soportar búsqueda por identifier visible, normalized identifier canónico, display name, section, type y status según el flujo existente
* [x] 7.4 Evitar que el cliente use `normalized_identifier` como dato confiable de escritura
* [x] 7.5 Asegurar que serializers/props expongan identifier, display name, type, status, property y section context para vistas autorizadas
* [x] 7.6 Evitar exponer relaciones sensibles si no están autorizadas separadamente
* [x] 7.7 Evitar N+1 al cargar property/section en listados o búsqueda

## 8. Metadata no autoritativa y area opcional

* [x] 8.1 Asegurar que `metadata` no sobrescriba campos estructurales: property, section, identifier, type, status o lifecycle
* [x] 8.2 Asegurar que `metadata` no conceda roles, capabilities ni acceso
* [x] 8.3 Mantener authorization resuelta por `Authorization::Resolver`, policies y assignments, no por metadata
* [x] 8.4 Permitir `area_m2` ausente
* [x] 8.5 Validar `area_m2` positivo solo cuando esté presente
* [x] 8.6 Mantener metadata como dato extensible no crítico

## 9. Lifecycle de property

* [x] 9.1 Implementar o verificar que property archivada rechace mutaciones ordinarias de unidades
* [x] 9.2 Denegar create, update, move, archive y restore cuando el lifecycle de property no permita cambios de catálogo
* [x] 9.3 Mantener esta validación separada de section eligibility
* [x] 9.4 Reportar errores de property lifecycle de forma consistente con el resto de errores de dominio

## 10. Controllers e integración del flujo

* [x] 10.1 Actualizar controllers/endpoints de unidades para delegar mutaciones a servicios canónicos
* [x] 10.2 Impedir que params del cliente asignen arbitrariamente organization, property, section o normalized_identifier fuera del servicio correspondiente
* [x] 10.3 Unificar respuestas de errores por campo/base
* [x] 10.4 Asegurar que create use property destino explícita y autorizada
* [x] 10.5 Asegurar que update no modifique placement ni lifecycle reservado
* [x] 10.6 Asegurar que move, archive y restore usen endpoints/acciones explícitas si existen
* [x] 10.7 Mantener compatibilidad con vistas o flujos existentes de unidades

## 11. Tests

* [x] 11.1 Testear que update no cambia organization ni property
* [x] 11.2 Testear que update no cambia section placement
* [x] 11.3 Testear que update no permite `status = archived`
* [x] 11.4 Testear que update permite operational status permitido
* [x] 11.5 Testear mismo identifier en otra organización
* [x] 11.6 Testear eligibility de section delegada al contrato de `property-section`
* [x] 11.7 Testear bulk import crea mediante `Units::Create`
* [x] 11.8 Testear bulk import no actualiza cuando el modo no lo permite
* [x] 11.9 Testear bulk import actualiza mediante `Units::Update` cuando el modo lo permite
* [x] 11.10 Testear bulk import no mueve placement cuando el modo no lo permite
* [x] 11.11 Testear bulk import mueve mediante `Units::MoveToSection` cuando el modo lo permite
* [x] 11.12 Testear actor con `view_units` puede leer catálogo
* [x] 11.13 Testear actor con `view_units` pero sin `manage_units` no puede mutar
* [x] 11.14 Testear property admin con `StaffAssignment` activo y `view_units`
* [x] 11.15 Testear property admin con `StaffAssignment` activo y `manage_units`
* [x] 11.16 Testear concierge con `view_units` solo lectura
* [x] 11.17 Testear `UnitPolicy::Scope` excluye properties fuera del assignment
* [x] 11.18 Testear búsqueda normalizando case, whitespace o Unicode
* [x] 11.19 Testear búsqueda no filtra unidades fuera del scope autorizado
* [x] 11.20 Testear metadata no sobrescribe campos estructurales
* [x] 11.21 Testear metadata no concede autorización
* [x] 11.22 Testear `area_m2` ausente aceptado
* [x] 11.23 Testear `area_m2 <= 0` rechazado
* [x] 11.24 Testear property archivada rechaza mutaciones ordinarias de unidades
* [x] 11.25 Testear controllers delegando a servicios canónicos

## 12. Validación y cierre

* [x] 12.1 Ejecutar suite de modelos, servicios, policies, requests y bulk import afectada
* [x] 12.2 Ejecutar RuboCop
* [x] 12.3 Ejecutar chequeos TypeScript/Vue si se tocaron props o UI
* [x] 12.4 Ejecutar Brakeman si aplica al flujo modificado
* [x] 12.5 Ejecutar `openspec validate improve-units-flow --type change --strict`
* [x] 12.6 Confirmar que proposal, design, spec y tasks están alineados
* [x] 12.7 Actualizar Graphify después de implementar código si el proyecto lo requiere
