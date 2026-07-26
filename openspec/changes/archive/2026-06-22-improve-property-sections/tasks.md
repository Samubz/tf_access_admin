# Improve Property Sections Tasks

> Estas tareas corresponden a implementación futura. Ninguna está completada.

## 1. Modelo y migraciones

* [x] 1.1 Auditar jerarquías, nombres duplicados, tipos y posiciones existentes
* [x] 1.2 Añadir `normalized_name` y backfill tenant-safe
* [x] 1.3 Añadir `status` con `active`, `inactive`, `archived`
* [x] 1.4 Definir constraints de tipo y status
* [x] 1.5 Añadir índice único de nombre normalizado por property y parent context
* [x] 1.6 Resolver correctamente unicidad de nodos raíz con `parent_id = NULL`
* [x] 1.7 Añadir índices para traversal y orden por property/parent/position
* [x] 1.8 Revisar `dependent: :destroy` para children, units y visits
* [x] 1.9 Definir auditoría de parent, position, type y status

## 2. Validaciones y normalización

* [x] 2.1 Normalizar nombre con trim, whitespace, Unicode y case folding
* [x] 2.2 Validar organización y property obligatorias/coherentes
* [x] 2.3 Hacer organization y property inmutables
* [x] 2.4 Validar nombre único entre siblings
* [x] 2.5 Permitir mismo nombre bajo parents distintos
* [x] 2.6 Validar `position` como orden entre hermanos; si no se entrega, asignarla de forma controlada
* [x] 2.7 Normalizar y validar `section_type`
* [x] 2.8 Definir `block`, `tower` y `floor` como únicos `section_type` elegibles para contener unidades
* [x] 2.9 Normalizar y validar `status`
* [x] 2.10 Convertir conflictos DB concurrentes en errores de dominio

## 3. Jerarquía y prevención de ciclos

* [x] 3.1 Unificar reglas de `parent_is_valid` y `PropertySectionHierarchy`
* [x] 3.2 Formalizar límite máximo de dos niveles: sección raíz y subsección
* [x] 3.3 Validar parent de misma organization y property
* [x] 3.4 Rechazar auto-parent
* [x] 3.5 Rechazar creación o movimiento de secciones bajo una subsección
* [x] 3.6 Rechazar parent descendiente y ciclos indirectos
* [x] 3.7 Preservar subárbol durante movimientos
* [x] 3.8 Definir estado efectivo desde property y ancestors
* [x] 3.9 Rechazar creación/movimiento bajo parent no operativo
* [x] 3.910 Proteger movimientos concurrentes incompatibles

## 4. Servicios de dominio

* [x] 4.1 Implementar `PropertySections::Create`
* [x] 4.2 Implementar `PropertySections::Update`
* [x] 4.3 Implementar `PropertySections::Move`
* [x] 4.4 Implementar `PropertySections::Archive`
* [x] 4.5 Derivar organization desde property
* [x] 4.6 Separar cambios descriptivos, movimiento y lifecycle
* [x] 4.7 Mantener archive atómico, no destructivo e idempotente
* [x] 4.8 Definir resultados y errores estructurados

## 5. TreeBuilder

* [x] 5.1 Evolucionar a `PropertySections::TreeBuilder` property-scoped
* [x] 5.2 Construir múltiples raíces y subsecciones respetando el límite de dos niveles
* [x] 5.3 Ordenar por position, normalized name e id
* [x] 5.4 Calcular depth y path
* [x] 5.5 Calcular status efectivo
* [x] 5.6 Incluir permissions/actions backend-driven por nodo
* [x] 5.7 Calcular `add_child` como `false` para subsecciones
* [x] 5.8 Entregar parent options válidas: raíz o sin parent; nunca subsecciones como parent para crear nietos
* [x] 5.9 Detectar huérfanos/ciclos defensivamente
* [x] 5.10 Permitir inclusión opcional de units con eager loading
* [x] 5.11 Definir serializer/DTO estable para Inertia/Vue

## 6. Policy y scopes

* [x] 6.1 Evaluar `manage_sections` con property context en todas las acciones
* [x] 6.2 Mantener scopes organization/property-safe
* [x] 6.3 Autorizar tenant admin dentro de su organización
* [x] 6.4 Autorizar property admin solo con assignment activo en la property
* [x] 6.5 Denegar assignment inactivo, futuro o vencido
* [x] 6.6 Denegar cross-property y cross-organization
* [x] 6.7 Denegar mutaciones bajo property archivada
* [x] 6.8 Definir acciones `move?` y `archive?`
* [x] 6.9 No introducir roles globales

## 7. Controllers y props

* [x] 7.1 Definir un controller/canal canónico para mutaciones
* [x] 7.2 Delegar create/update/move/archive a servicios
* [x] 7.3 Eliminar duplicación entre controllers anidado y plano
* [x] 7.4 Cargar property, section y parent mediante policy scopes
* [x] 7.5 Reemplazar destroy ordinario por archive explícito
* [x] 7.6 Exponer tree DTO, catálogos y permissions
* [x] 7.7 Unificar errores Inertia por campo/base
* [x] 7.8 No aceptar organization/property arbitrarias del cliente

## 8. UI árbol de secciones

* [x] 8.1 Mantener route page como superficie de composición
* [x] 8.2 Renderizar árbol de máximo dos niveles; puede implementarse recursivamente, pero no debe permitir nietos
* [x] 8.3 Extraer selección, expansión y búsqueda a composable tipado
* [x] 8.4 Renderizar acciones desde permissions backend
* [x] 8.5 Añadir flujo explícito de move con parent options válidas entregadas por backend
* [x] 8.6 Bloquear en UI la creación o movimiento que genere un tercer nivel
* [x] 8.7 Reemplazar delete por archive con confirmación
* [x] 8.8 Mostrar status persistido y efectivo
* [x] 8.9 Deshabilitar operaciones bajo property/ancestor no operativo
* [x] 8.10 Alinear schema frontend con tipos y estados
* [x] 8.11 Mantener props down/events up entre página, árbol y formularios
* [x] 8.12 Definir loading, empty, error y forbidden

## 9. Tests

* [x] 9.1 Testear creación de sección raíz y subsección
* [x] 9.2 Testear rechazo de creación de tercer nivel
* [x] 9.3 Testear organización/property obligatorias
* [x] 9.4 Testear parent cross-property y cross-organization
* [x] 9.5 Testear auto-parent y ciclos directos/indirectos
* [x] 9.6 Testear normalización y duplicados entre siblings
* [x] 9.7 Testear mismo nombre bajo otro parent
* [x] 9.8 Testear unicidad entre raíces
* [x] 9.9 Testear tipos y status válidos/inválidos
* [x] 9.10 Testear orden por position/nombre
* [x] 9.11 Testear movimientos permitidos entre raíz y subsección sin superar dos niveles
* [x] 9.12 Testear rechazo de movimiento que genere tercer nivel
* [x] 9.13 Testear rechazo de movimiento cross-property y hacia descendant
* [x] 9.14 Testear archive con subsecciones y units sin hard delete
* [x] 9.15 Testear estado efectivo por ancestor/property
* [x] 9.16 Testear TreeBuilder scope, depth máximo de dos niveles, path, order, permissions y units opcionales
* [x] 9.17 Testear que solo `block`, `tower` y `floor` quedan marcados como elegibles para contener unidades
* [x] 9.18 Testear tenant admin y property admin asignado
* [x] 9.19 Testear assignment inactivo/futuro/vencido
* [x] 9.20 Testear cross-property, cross-organization y usuario sin permisos
* [x] 9.21 Testear controllers delegando a servicios
* [x] 9.22 Testear props mínimas y acciones backend-driven
* [x] 9.23 Testear conflictos concurrentes de create/move/position

## 10. Cierre

* [x] 10.1 Ejecutar suite de modelos, servicios, policies, requests y frontend
* [x] 10.2 Ejecutar RuboCop y chequeos TypeScript/Vue
* [~] 10.3 Verificar manualmente árbol de máximo dos niveles, create, edit, move y archive (cubierto por tests de request/servicio; verificación manual UI pendiente del operador)
* [~] 10.4 Verificar que la UI no permite crear ni mover secciones hacia un tercer nivel (bloqueado por backend/policy + tests; verificación manual UI pendiente)
* [x] 10.5 Verificar que archive preserva subárbol y units
* [x] 10.6 Ejecutar `openspec validate improve-property-sections --type change --strict`
* [x] 10.7 Ejecutar Graphify solo después de implementación futura
* [x] 10.8 Registrar decisiones resueltas y dependencias para el change de Unit
