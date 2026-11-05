# 07 · Smoke, regresión, CI, cobertura y mocks

> PDF §13 “Run smoke tests, regression tests, and manage test data”, §14 “Automate tests in CI and understand coverage”, §15 “Choose mocks carefully and manage flaky tests”.

## 1. Suite smoke (§13)

Se corre tras cada build o despliegue; debe tardar poco.

| # | Comprobación | Prueba automática |
|---|---|---|
| S1 | La API responde | `backend/tests/api/health.test.js` |
| S2 | La app abre en el login | E2E paso 01 |
| S3 | El login funciona | E2E paso 03 |
| S4 | La lista carga | E2E paso 03 |
| S5 | Se puede crear una tarea | E2E paso 05 |
| S6 | El logout funciona | E2E paso 09 |

## 2. Checklist de regresión (práctica del §13)

| Área | Casos a repetir tras un cambio | Cubierto por |
|---|---|---|
| **Creación** | título válido; vacío/espacios; 120 vs 121; sin descripción (`null`, BUG-008); doble tap (BUG-002); `ownerId` ignorado | `tasks.test.js`, `task_repository_test.dart`, `task_page_bugs_test.dart`, E2E |
| **Edición** | PATCH vacío → 400; título inválido; `ownerId` ignorado; ajeno → 404 sin cambios | `tasks.test.js` |
| **Completado** | marcar/desmarcar; fallo de red conserva la lista (BUG-001); estado en texto “Done” | `task_page_bugs_test.dart`, `task_list_view_test.dart`, E2E 08 |
| **Borrado** | propio → 204; ajeno → 404 y la tarea sigue existiendo | `tasks.test.js` |
| **Acceso cruzado** | GET/PATCH/DELETE con token de otro usuario; respuesta idéntica a “no existe”; lista solo propia | `tasks.test.js` (7 pruebas A/B) |
| **Sesión** | rotación, reúso, logout, logout-all, token expirado/falsificado | `auth.test.js` |

## 3. Gestión de datos de prueba

- Solo cuentas sintéticas `*@example.test`. Cada archivo de pruebas borra lo que creó (`cleanupTestUsers`).
- La BD vive en un contenedor con **tmpfs**: al apagarlo desaparece todo. Es imposible “contaminar” datos reales.
- `tests/setup-env.js` y `scripts/seed-test.js` se niegan a correr si la BD no termina en `_test`.
- La cuenta del E2E se reinicia con `npm run seed:test` antes de cada corrida (se borran sus tareas y tokens).
- Se registra el entorno de cada ejecución en `docs/01` y en los logs de `evidence/logs/`.

## 4. CI y cobertura (§14)

Workflow: [`.github/workflows/tests.yml`](../.github/workflows/tests.yml). Tiene dos jobs:
- **backend**: levanta un servicio PostgreSQL 16, copia `.env.test.example`, migra y corre `npm run test:coverage`.
- **flutter**: corre `flutter analyze` y `flutter test --coverage`.

**Práctica del §14 (romper → ver fallar → restaurar), hecha localmente con los mismos comandos del CI:**

| Paso | Cambio | Resultado | Evidencia |
|---|---|---|---|
| 1 | `MAX_TITLE_LENGTH = 200` en `src/tasks/validation.js` | **2 pruebas fallan** (unitaria del límite 121 y API “121-char title”) | `evidence/terminal/11-ci-broken.png` |
| 2 | Restaurar `120` | 77/77 en verde | `evidence/terminal/12-ci-restored.png` |

### Cobertura del backend

| Métrica | Valor |
|---|---|
| Sentencias | 98.76 % |
| Ramas | 79.72 % |
| Funciones | 100 % |
| Líneas | 99.13 % |

**Lección:** la cobertura dice qué código se *ejecutó*, no si se verificó el comportamiento correcto. BUG-003 (bcrypt 72 bytes) vivía en líneas cubiertas al 100 %, y BUG-008 también: la ruta `POST /tasks` estaba cubierta, pero ninguna prueba enviaba `description: null`, que es lo que manda la app real.

## 5. Mocks vs. integración (§15)

Práctica: comparar una prueba de cliente con mock contra una prueba de integración con BD dedicada.

| | Prueba con mock (`mobile/test/task_repository_test.dart`) | Prueba de integración (`backend/tests/api/tasks.test.js`) | E2E (`integration_test/app_journey_test.dart`) |
|---|---|---|---|
| Velocidad | ~ms, sin red | ~segundos, PostgreSQL real | ~1 min, emulador + API + BD |
| Detecta | URL, cabeceras, cuerpo que arma la app, parseo, manejo de errores | validación, autorización, persistencia, transacciones | que las piezas **encajan** de verdad |
| **No** detecta | si la API real acepta ese cuerpo, si filtra por dueño | qué envía realmente la app | detalles finos (son pocas y lentas) |
| Ejemplo real | Pasaba con `description: null` | Aceptaba solo `string` u omitido | **Encontró BUG-008** en la primera corrida |

**BUG-008 es la lección del §15 hecha realidad.** Cada lado tenía razón según sus propias pruebas, pero el contrato entre ellos estaba roto. Ahora hay una prueba de contrato en cada lado: el cliente omite la clave y el servidor acepta `null`.

### Pruebas inestables (flaky) y cómo se evitaron

| Riesgo | Control aplicado |
|---|---|
| Red real | Repositorios falsos (`FakeTaskRepository`) y `MockClient` en pruebas de widget/cliente |
| Tiempo | `Completer` para simular una red lenta de forma determinista (BUG-002); tokens expirados firmados con `exp` en el pasado |
| Datos compartidos | Usuarios únicos por prueba (`crypto.randomUUID()`), limpieza al final, `--runInBand` |
| Rate limit entre archivos | Límite configurable; la prueba de rate limit usa su propia instancia de app |
| `pumpAndSettle` antes de que responda la API | `waitFor()` que hace pump hasta encontrar el widget, con un timeout |
| **Falso positivo** | La primera versión del E2E buscaba el texto de la tarea y lo encontraba **en el campo del diálogo**, así que no veía que el guardado había fallado. Ahora busca la tarea dentro de un `ListTile` y verifica que el diálogo se cerró. |
| No se mockea lo que se verifica | Las pruebas de propiedad entre usuarios usan la API y la BD reales, nunca mocks |
