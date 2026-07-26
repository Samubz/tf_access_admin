# Improve Property Setup Flow Design

## Context

La aplicación ya permite crear `ResidentialProperty`, `PropertySection` y `Unit` mediante flujos administrativos separados, con servicios de dominio, políticas capability-based y bulk import existente para unidades.

Hoy un administrador que configura una propiedad nueva debe:

1. crear la propiedad en una pantalla;
2. navegar a secciones y definir estructura en otra;
3. volver a unidades para crearlas manualmente, en lote o por Excel.

No existe un estado compartido ni una vista consolidada del resultado antes de persistir. Las vistas de referencia en `mockups/improve-property-setup-flow/` definen el contrato UX observable del wizard de cinco pasos.

Este diseño orquesta dominios existentes sin cambiar sus reglas fundacionales. La persistencia final debe delegar en los servicios actuales de propiedad, sección y unidad, y en el bulk import ya implementado.

### Affected models, tables and services

| Área | Elementos |
| --- | --- |
| Modelos | `ResidentialProperty`, `PropertySection`, `Unit`, `BulkImport` |
| Tablas | `residential_properties`, `property_sections`, `units`, tablas de bulk import existentes |
| Servicios actuales | `Properties::Create`, `PropertySections::*`, `Units::Create`, bulk import de unidades |
| Nuevos servicios propuestos | `Properties::Setup::InitializeDraft`, `Properties::Setup::Configure`, `Properties::Setup::Cancel`, `Properties::Setup::ValidateStep`, `Properties::Setup::BuildPreview`, `Properties::Setup::GenerateStructurePreview`, `Properties::Setup::GenerateUnitsPreview`, `Properties::Setup::Confirm`, `Properties::Activate` |
| Policies | `ResidentialPropertyPolicy`, `PropertySectionPolicy`, `UnitPolicy`, `BulkImportPolicy` |
| Frontend | nueva página Inertia del wizard y componentes compartidos de stepper, preview y resumen |

### Integration points

* Entrada desde listado o acción "Nueva propiedad" del módulo de propiedades.
* Reutilización de selectores, validaciones y formatos ya usados en CRUD de propiedad, sección y unidad.
* Integración del paso 3 con upload/preview del bulk import existente.
* Pantalla final enlazando a detalle de propiedad, administración de unidades, importación de propietarios y configuración de residentes.

## Goals / Non-Goals

**Goals:**

* Ofrecer un wizard de cinco pasos alineado con las mockups de referencia.
* Persistir la propiedad como `draft` desde Step 1 y crear secciones y unidades incrementalmente en Steps 2 y 3, manteniendo el contexto tenant-scoped en todo momento.
* Validar cada paso reutilizando contratos de dominio existentes.
* Generar previews en memoria solo para la estructura rápida antes de confirmarla; las secciones y unidades definitivas se crean directamente mediante servicios de dominio.
* Confirmar transicionando el status de `draft` a `configured` de forma atómica; los registros ya existen y no hay estado parcial a resolver.
* Exponer resumen, errores, advertencias y duplicados antes de confirmar.
* Terminar con acciones siguientes claras.
* Internacionalizar todo el texto visible del flujo.

**Non-Goals:**

* Rediseñar por completo los CRUD existentes fuera del wizard.
* Cambiar reglas de unicidad, lifecycle o elegibilidad de specs ya archivados.
* Configurar propietarios, residentes, staff o visitas dentro del wizard.
* Duplicar parsing, normalización o reglas de bulk import en el frontend.
* Persistir propiedad real en pasos intermedios salvo que una integración existente lo exija explícitamente.

## Decisions

### 1. Wizard shell follows reference mockups

**Decisión:** implementar un contenedor de wizard con layout estable en los cinco pasos:

* encabezado con título "Configurar propiedad" y descripción breve del flujo guiado;
* stepper horizontal de cinco pasos;
* área principal del paso activo;
* panel auxiliar contextual cuando el paso lo requiera;
* footer con `Atrás`, `Cancelar` y acción primaria de avance o confirmación.

**Rationale:** las mockups ya fijan jerarquía visual, distribución y affordances observables. La implementación debe respetar ese contrato funcional sin acoplarse a valores de estilo exactos.

**Alternativa descartada:** cinco rutas completamente independientes sin contenedor común. Rechazada porque rompe continuidad, resumen lateral y navegación coherente.

### 2. Draft state is the ResidentialProperty record itself

**Decisión:** el borrador del wizard no es una tabla separada ni un token de sesión. El borrador ES la `ResidentialProperty` con `status = draft`, identificada por su `id` y vinculada al `organization_id` del tenant autenticado.

Step 1 crea ese registro. Steps 2 y 3 operan directamente sobre él creando secciones y unidades reales. El wizard se puede retomar en cualquier momento cargando la propiedad draft por su `id`. El cliente recibe el `id` de la propiedad al completar Step 1 y lo incluye en las requests siguientes.

La validación autoritativa ocurre siempre en Rails. El cliente nunca es fuente de verdad para `organization_id` ni relaciones entre entidades.

**Rationale:** reutiliza el modelo de dominio existente como mecanismo de persistencia; elimina la necesidad de una tabla de sesión adicional y simplifica la reanudación del wizard.

**Alternativa descartada:** tabla separada `property_setup_drafts` con token de sesión. Rechazada porque introduce infraestructura extra sin ventaja real dado que la propiedad draft ya es un registro de dominio válido.

### 3. Property persists from Step 1 as draft

**Decisión:** la `ResidentialProperty` se persiste al completar el Step 1 con `status = draft`. Los pasos 2 y 3 operan directamente sobre ese registro real, creando secciones y unidades mediante los servicios de dominio existentes. La confirmación final (Step 5) transiciona el status a `configured`.

**Reemplaza la decisión anterior** de no persistir hasta confirm. Las previews de estructura rápida y generación automática de unidades siguen calculándose en memoria antes de confirmarse como secciones/unidades reales.

**Rationale:** permite retomar el wizard en cualquier momento desde cualquier dispositivo, sin depender de sesión de navegador. El `draft` actúa como aislamiento natural frente a otros flujos.

**Excepción:** si el bulk import existente requiere un `BulkImport` persistido, se vincula a la propiedad draft ya existente.

### 4. Step validation delegates to domain contracts

**Decisión:** cada paso tendrá un validador de servicio:

* paso 1 → contrato `residential-property` para nombre, tipo, dirección y metadata;
* paso 2 → contrato `property-section` para jerarquía, elegibilidad y unicidad; las secciones se crean como registros reales sobre la propiedad draft;
* paso 3 → contrato `unit` y bulk import; las unidades se crean como registros reales sobre la propiedad draft;
* paso 4 → agregador de bloqueos, warnings y duplicados;
* paso 5 → confirmación explícita + autorización final.

**Rationale:** una sola fuente de verdad para reglas de negocio.

### 5. Structure modes

**Decisión:** el paso 2 soportará tres modos mutuamente excluyentes:

| Modo | Comportamiento |
| --- | --- |
| Sin secciones | `structure_mode = none`; unidades quedan solo bajo la propiedad |
| Manual | árbol editable con nodos raíz e hijos según contrato actual de secciones |
| Rápida | generador paramétrico (`towers`, `floors_per_tower`, `units_per_floor`, prefijos) que produce preview jerárquica |

La estructura rápida usará un servicio dedicado, p. ej. `Properties::Setup::GenerateStructurePreview`, que traduce parámetros a nodos `tower` → `floor` compatibles con `property-section`.

**Rationale:** cubre los tres casos de uso del brief y las mockups sin alterar el modelo de secciones.

### 6. Unit creation modes

**Decisión:** el paso 3 expondrá métodos excluyentes:

| Método | Implementación |
| --- | --- |
| Individual | formulario de una unidad; persiste via `Units::Create` sobre la propiedad draft |
| Múltiple / automática | generador desde estructura con tipo, formato de identificador y cantidad por piso; persiste via `Units::Create` |
| Importación Excel | wrapper del flujo bulk import existente, mostrando preview, errores y duplicados en el wizard |

La generación automática puede mostrar una preview paginada de identificadores antes de confirmar el lote; la persistencia ocurre en Step 3, no al confirmar el wizard.

**Rationale:** reutiliza lógica existente y evita reglas paralelas.

### 7. Summary and confirmation are separate steps

**Decisión:** el paso 4 es solo revisión editable; el paso 5 concentra confirmación explícita, checklist, resumen final compacto, panel de consecuencias y checkbox de acknowledgment.

La acción primaria del paso 4 será "Continuar a confirmación"; la del paso 5 será "Confirmar configuración".

**Rationale:** replica el contrato UX de las mockups 4 y 5 y separa revisión de commit irreversible.

### 8. Confirmation transitions status atomically

**Decisión:** al llegar al Step 5, la propiedad, sus secciones y sus unidades ya existen en la base de datos. `Properties::Setup::Confirm` ejecuta en una transacción:

1. validar que el estado final de la propiedad draft sea coherente (secciones elegibles, unidades sin conflictos de unicidad pendientes, autorización vigente);
2. transicionar `status` de `draft` a `configured` vía `Properties::Setup::Configure`.

Si la validación falla, la propiedad permanece en `draft` con todos sus registros intactos y se devuelven errores accionables al paso correspondiente.

**Rationale:** la persistencia incremental ya garantiza que no hay estado parcial inconsistente al confirmar. La transacción de confirmación es liviana: solo protege la transición de status de condiciones de carrera.

### 9. Authorization uses existing capabilities

**Decisión:**

* iniciar y confirmar wizard → `manage_properties` a nivel organizacional;
* acciones siguientes posteriores respetarán `manage_property`, `manage_units`, `view_units` y demás capabilities ya existentes al navegar fuera del wizard.

No se introducirán capabilities nuevas salvo que la implementación demuestre un vacío real.

### 10. Routing and controller shape

**Decisión:** el wizard reemplaza el flujo de creación de propiedad existente. `Admin::ResidentialPropertiesController#new` y `#create` serán eliminados o redirigidos al wizard. No se mantiene el alta tradicional como ruta paralela.

El wizard se implementa como un controlador dedicado siguiendo el patrón admin existente:

* `Admin::PropertySetup::WizardController` con acciones `show`, `update`, `advance`, `back`, `cancel`, `confirm`;
* render Inertia de una página base `PropertySetup/Wizard` con prop `currentStep` y subcomponentes por paso.

**Rationale:** mantener dos rutas de creación genera divergencia de comportamiento y duplicación de mantenimiento. El wizard es la única entrada canónica.

### 12. Property lifecycle: draft → configured → active

**Decisión:** introducir dos nuevos valores en `PropertyStatuses`:

| Status | Significado | Mutable por servicios de sección/unidad |
| --- | --- | --- |
| `draft` | Wizard iniciado, configuración en curso | ✓ |
| `configured` | Wizard completado, pendiente de activación explícita | ✓ |
| `active` | Operativa, flujo normal | ✓ |
| `inactive` | Suspendida temporalmente | ✗ |
| `archived` | Retirada permanentemente | ✗ |

**Transiciones:**

```
draft ──► configured ──► active ⇄ inactive ──► archived
  │              │
  └── (retomable, editable en ambos estados)
```

- Step 1 del wizard persiste la propiedad como `draft`.
- Step 5 ("Confirmar") transiciona a `configured` vía `Properties::Setup::Configure`.
- La activación explícita posterior transiciona a `active` vía `Properties::Activate`.
- Editar una propiedad `configured` la mantiene en `configured` (no retrocede a `draft`).

**Gate de operabilidad:**

`property_operable?` en `Units::Base` y `PropertySections::Base` se extiende a:

```ruby
[PropertyStatuses::DRAFT, PropertyStatuses::CONFIGURED, PropertyStatuses::ACTIVE].include?(property.status)
```

**Aislamiento frente a flujos externos:**

Las propiedades `draft` y `configured` son visibles en el catálogo administrativo con badge indicativo. Los flujos externos (API, integraciones) añadirán su propio gate `property_not_draft!` / `property_not_configured!` cuando se construyan; no se introduce ese gate en los servicios de dominio actuales.

**Catálogo:**

Propiedades `draft` y `configured` se muestran en `/admin/residential_properties` para todos los usuarios con permiso de listar, con badge de estado visible.

**Unicidad de nombre:**

La unicidad de nombre por organización aplica desde el Step 1, igual que para propiedades `active`.

**Rationale:** el `draft` como status de primera clase permite retomar el wizard, aísla la propiedad de operaciones no autorizadas externas y mantiene el diseño aditivo: el gate externo se añade cuando existe el consumidor, no antes.

### 11. i18n namespace

**Decisión:** usar claves bajo `admin.property_setup.*` en `es`, `en` y `pt` para:

* títulos de pasos;
* descripciones;
* labels de formulario;
* empty states;
* mensajes de validación;
* resumen y confirmación;
* acciones siguientes.

### 13. Cancel behavior depends on property status

**Decisión:** la acción "Cancelar" del wizard se comporta de forma diferente según el status de la propiedad en ese momento:

| Status de la propiedad | Comportamiento de Cancel |
| --- | --- |
| `draft` | Muestra un modal de confirmación: el usuario elige entre eliminar la propiedad draft o mantenerla para editarla más tarde. Si elige eliminar, se destruyen la propiedad y sus secciones y unidades asociadas. Si elige mantener, vuelve al listado sin borrar nada. |
| `configured` | Vuelve directamente al listado de propiedades sin acción destructiva. |
| `active` | Vuelve directamente al listado de propiedades sin acción destructiva. |

**Rationale:** en `draft` la propiedad aún no es operativa y el usuario puede no querer dejar registros incompletos. En `configured` y `active` ya existe una propiedad con valor real; cancelar el wizard no debería destruirla.

### 14. property_operable? extended for setup statuses

**Decisión:** `property_operable?` en `Units::Base`, `PropertySections::Base`, `UnitPolicy` y `PropertySections::TreeBuilder` se extiende para incluir `draft` y `configured`:

```ruby
[PropertyStatuses::DRAFT, PropertyStatuses::CONFIGURED, PropertyStatuses::ACTIVE].include?(property.status)
```

Esto permite que el wizard cree secciones y unidades sobre una propiedad draft sin modificar los servicios de dominio individualmente. Los flujos externos (API, integraciones) añadirán su propio gate `property_not_draft!` cuando se construyan.

**Rationale:** el wizard es el único consumidor de propiedades draft hoy. Aplicar el gate en el servicio sería prematuro y forzaría a pasar flags de bypass que contaminarían la interfaz de los servicios.

### 15. Quick structure preview is paginated

**Decisión:** la preview de estructura rápida (`GenerateStructurePreview`) y cualquier preview de unidades en el wizard se devuelven paginadas siguiendo los patrones existentes del proyecto (Kaminari o equivalente).

No se calcula ni se serializa el árbol completo en una sola respuesta. El frontend solicita páginas del preview del mismo modo que solicita páginas de cualquier otro listado.

**Rationale:** un setup con 50 torres × 20 pisos × 10 unidades generaría 10.000 nodos. Sin paginación, la respuesta es inviable. Reutilizar la paginación existente evita inventar un mecanismo ad-hoc.

## UX contract from reference mockups

| Paso | Contrato observable |
| --- | --- |
| 1 | Formulario principal + panel "Resumen inicial" con tipo, ubicación, estimación y estado del flujo |
| 2 | Tres tarjetas de modo + formulario contextual + panel "Vista previa de estructura" con árbol y contadores |
| 3 | Barra de contexto de propiedad/estructura + selección de método + formulario + preview de unidades |
| 4 | Tarjetas resumen + secciones detalladas + aviso informativo + navegación a confirmación |
| 5 | Banner de listo, checklist, resumen final, panel de consecuencias, checkbox de confirmación y CTA final |

La implementación no debe prescribir colores o medidas exactas; sí debe preservar jerarquía, distribución principal/auxiliar, labels de acciones y comportamiento de preview.

## Risks / Trade-offs

| Riesgo | Mitigación |
| --- | --- |
| Borradores grandes por estructuras o unidades masivas | Limitar preview a muestras representativas; validar totales en servidor; considerar límites configurables |
| Tiempo de confirmación alto en setups grandes | Mostrar aviso de duración; ejecutar confirmación como operación explícita; evaluar job asíncrono solo si el producto lo requiere |
| Duplicación de reglas entre wizard y CRUD | Toda validación y persistencia pasa por servicios existentes |
| Bulk import acoplado a propiedad inexistente | Resuelto: la propiedad existe como `draft` desde Step 1; el bulk import puede vincularse directamente |
| Refresco o abandono del flujo | La propiedad draft persiste; el usuario puede retomar el wizard desde el catálogo. Cancel en draft muestra modal de elección; en configured/active vuelve al listado sin acción destructiva |
| Estado parcial si confirm falla | La propiedad permanece en `draft` con sus registros intactos; no hay rollback de records, solo la transición de status no se aplica |

## Migration Plan

1. Implementar wizard y eliminar o redirigir `Admin::ResidentialPropertiesController#new` y `#create` en la misma entrega; el wizard es la única entrada canónica desde el inicio.
2. Cambiar la entrada principal "Nueva propiedad" al wizard cuando esté estable.
3. Mantener rutas legacy temporalmente si hay dependencias internas.
4. Rollback: ocultar entrada al wizard y volver al flujo anterior; las propiedades en `draft` pueden limpiarse con una tarea de mantenimiento, ya que no tienen secciones ni unidades vinculadas a operaciones reales.

## Open Questions

* ~~¿El borrador debe persistirse en tabla dedicada (`property_setup_drafts`) o en JSON temporal asociado a sesión/usuario?~~ Resuelto: la propiedad se persiste como `draft` desde Step 1 en `residential_properties`; no se necesita tabla separada.
* ¿La confirmación de setups muy grandes debe ser síncrona o disparar un job con pantalla de progreso?
* ¿El alta tradicional de propiedad desaparece en la misma entrega o en un change posterior?
* ¿La estructura manual del wizard permite solo dos niveles actuales del dominio o una UX más profunda con validación del servicio?

## Validation approach

* Request tests por paso: autorización, validación, avance, retroceso y cancelación.
* Service tests para generación de preview, resumen y confirmación transaccional.
* Policy tests para acceso al wizard y confirmación.
* System/Inertia tests del flujo feliz y de errores visibles en pasos 3 y 4.
* Verificación manual contra las cinco mockups de referencia para layout y affordances.
