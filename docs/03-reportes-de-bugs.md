# 03 · Reportes de bugs

> PDF §2 — plantilla de reporte de bug, y su práctica: *“Write a report for a task that disappears after being marked complete.”* (ese es **BUG-001**, y resultó ser un defecto real de esta app).
>
> **Severidad** = impacto del defecto. **Prioridad** = qué tan pronto hay que arreglarlo.
> Cada bug se reprodujo primero con una prueba automática que **falló**; la salida de esa ejecución está en `evidence/logs/*before-fix*.txt`. Después se corrigió y la misma prueba quedó como prueba de regresión.

| ID | Resumen | Severidad | Prioridad | Estado |
|---|---|---|---|---|
| BUG-001 | La lista de tareas desaparece si falla marcar una como completada | Alta | Alta | Corregido |
| BUG-002 | Doble tap en **Save** crea tareas duplicadas | Media | Media | Corregido |
| BUG-003 | Contraseñas que difieren después del byte 72 abren la misma cuenta | Alta | Alta | Corregido |
| BUG-004 | Contraseña incorrecta muestra “Your session has expired” | Media | Alta | Corregido |
| BUG-005 | Subtítulo del login con contraste 4.13:1 (< 4.5:1 WCAG AA) | Baja | Media | Corregido |
| BUG-006 | Diálogo **New Task** se desborda 128 px en teléfono pequeño con teclado | Media | Media | Corregido |
| BUG-007 | `usesCleartextTraffic="true"` también en builds de release | Media | Alta | Corregido |
| ENV-001 | Otro proceso local escuchaba en `127.0.0.1:3000` y respondía `/health` | — (entorno) | — | Mitigado: API de pruebas en 3100 |

---

## BUG-001 · La lista de tareas desaparece al fallar “marcar como completada”

| Campo | Contenido |
|---|---|
| **Resumen** | Si la petición `PATCH /tasks/:id {completed:true}` falla (p. ej. sin conexión), la pantalla reemplaza **toda** la lista por la vista de error. El usuario cree que perdió sus tareas. |
| **Entorno** | Flutter 3.47.2, app 1.0.0+1, prueba de widget (`flutter_test`); reproducible en cualquier dispositivo. |
| **Precondiciones** | Usuario con 2 tareas (“Buy milk”, “Plan tests”). Red caída al momento de marcar. |
| **Pasos** | 1. Abrir la lista. 2. Desactivar la red. 3. Pulsar la casilla de “Buy milk”. |
| **Esperado** | Ambas tareas siguen visibles; la casilla no cambia; se muestra un aviso del error con opción a descartarlo. |
| **Obtenido** | La lista se vacía y solo se ve “Could not connect to the server…” con botón **Retry**. `find.text("Buy milk")` → *Found 0 widgets*. |
| **Evidencia** | `evidence/logs/flutter-bugs-before-fix.txt`, `evidence/terminal/bugs-before-fix.png` |
| **Causa raíz** | `TaskListNotifier.toggleCompleted` guardaba el error en `errorMessage`, el mismo campo que usa una carga fallida; `TaskListView` muestra la vista de error en vez de la lista cuando ese campo no es nulo. |
| **Corrección** | Nuevo campo `actionError` en `TaskListState` mostrado como `MaterialBanner` encima de la lista (`task_controller.dart`, `task_page.dart`). |
| **Severidad** | **Alta** — el usuario percibe pérdida de datos. |
| **Prioridad** | **Alta** — ocurre con cualquier corte de red en un flujo principal. |
| **Prueba de regresión** | `mobile/test/task_page_bugs_test.dart` → “BUG-001: tasks stay visible…” |

## BUG-002 · Doble tap en Save crea tareas duplicadas

| Campo | Contenido |
|---|---|
| **Resumen** | El botón **Save** sigue activo mientras la creación está en curso; un segundo tap envía otra petición. |
| **Entorno** | Prueba de widget con repositorio lento simulado (`Completer`). |
| **Pasos** | 1. **New Task**. 2. Escribir “Only once”. 3. Pulsar **Save** dos veces rápido. |
| **Esperado** | 1 llamada a `create`. |
| **Obtenido** | `Expected: <1>  Actual: <2>` |
| **Evidencia** | `evidence/logs/flutter-bugs-before-fix.txt` |
| **Corrección** | Diálogo extraído a `CreateTaskDialog` con estado `_saving`: el botón se deshabilita y muestra un indicador mientras guarda. |
| **Severidad / Prioridad** | Media / Media — datos duplicados, fácil de limpiar. |
| **Regresión** | “BUG-002: tapping Save twice quickly creates only one task” |

## BUG-003 · bcrypt ignora todo después del byte 72

| Campo | Contenido |
|---|---|
| **Resumen** | El esquema aceptaba contraseñas de hasta 128 caracteres, pero bcrypt solo usa los primeros 72 bytes. Dos contraseñas con el mismo prefijo de 72 bytes son intercambiables. |
| **Entorno** | API local, `bcrypt@6`, PostgreSQL `task_manager_test`. |
| **Pasos** | 1. `POST /auth/register` con `"b"×72+"X"`. 2. `POST /auth/login` con `"b"×72+"Y"`. |
| **Esperado** | Registro rechazado (`400`) o login fallido (`401`). |
| **Obtenido** | Registro **201** y login con contraseña distinta **200**. |
| **Evidencia** | `evidence/logs/backend-bug003-before-fix.txt` (`Expected: 401 · Received: 200`) |
| **Corrección** | `auth.schema.js`: límite de **72 bytes UTF-8** (no caracteres) en registro y login; mismo límite en el formulario Flutter. |
| **Severidad / Prioridad** | Alta / Alta — debilita la autenticación. |
| **Regresión** | `auth.test.js` → “passwords that differ only after byte 72…”, “multi-byte characters count as bytes…” |

## BUG-004 · Contraseña incorrecta muestra “Your session has expired”

| Campo | Contenido |
|---|---|
| **Resumen** | `ApiClient` traducía **cualquier** 401 a “Your session has expired”, incluso en `/auth/login`. Además 409 y 429 mostraban un genérico “The request could not be completed”, sin decir cómo recuperarse. |
| **Pasos** | 1. Login con email válido y contraseña incorrecta. |
| **Esperado** | “Invalid email or password.” |
| **Obtenido** | “Your session has expired. Please sign in again.” |
| **Evidencia** | `evidence/logs/flutter-auth-before-fix.txt` |
| **Corrección** | 401 en rutas de auth usa el mensaje del servidor; los 4xx muestran el mensaje seguro de la API; los 5xx nunca se muestran (evita filtrar detalles internos). |
| **Severidad / Prioridad** | Media / **Alta** — ejemplo del PDF: impacto moderado pero confunde a todos los usuarios que se equivocan de contraseña. |
| **Regresión** | `mobile/test/auth_repository_test.dart`; E2E paso 02. |

## BUG-005 · Contraste insuficiente en el login

| Campo | Contenido |
|---|---|
| **Resumen** | “Sign in to access your secure tasks” usa `colorScheme.outline`: contraste 4.13:1, por debajo del 4.5:1 de WCAG AA para texto de 14 px. |
| **Evidencia** | `evidence/logs/flutter-a11y-compat-before-fix.txt` → `Expected contrast ratio of at least 4.5 but found 4.13` |
| **Corrección** | Color `onSurfaceVariant`. |
| **Severidad / Prioridad** | Baja / Media. |
| **Regresión** | `mobile/test/accessibility_test.dart` (`textContrastGuideline`). |

## BUG-006 · Diálogo “New Task” se desborda en pantallas pequeñas

| Campo | Contenido |
|---|---|
| **Resumen** | En 320×568 con teclado abierto (~260 px), el contenido del diálogo no cabe: `A RenderFlex overflowed by 128 pixels on the bottom`. El botón Save puede quedar inaccesible. |
| **Evidencia** | `evidence/logs/flutter-a11y-compat-before-fix.txt` |
| **Corrección** | Contenido envuelto en `SingleChildScrollView`. |
| **Severidad / Prioridad** | Media / Media — afecta teléfonos pequeños (fila 1 de la matriz de dispositivos). |
| **Regresión** | `mobile/test/screen_size_test.dart` → “create dialog fits a small phone with the keyboard open”. |

## BUG-007 · Tráfico HTTP sin cifrar permitido en release

| Campo | Contenido |
|---|---|
| **Resumen** | `android/app/src/main/AndroidManifest.xml` declaraba `android:usesCleartextTraffic="true"`, lo que aplica a **todas** las builds, incluida la de producción (OWASP API8 “Security misconfiguration”). |
| **Encontrado** | Revisando la configuración antes de ejecutar el E2E en Android. |
| **Corrección** | El atributo se movió a `android/app/src/debug/AndroidManifest.xml`: solo las builds de depuración pueden hablar HTTP con la API local `10.0.2.2`. |
| **Severidad / Prioridad** | Media / Alta. |
| **Verificación** | Build de depuración del E2E funciona contra `http://10.0.2.2:3100`. |

## ENV-001 · Puerto 3000 compartido con otro proyecto (problema de entorno)

No es un bug de la app, pero es una lección del apartado *Troubleshooting* del PDF (“Confirm the test API URL”):
`curl http://127.0.0.1:3000/health` devolvía `{"status":"ok","timestamp":…}` — un campo que **nuestra** API no envía. Otro proceso del equipo (`node dist/main.js`) escuchaba en `127.0.0.1:3000`, mientras nuestra API escuchaba en `[::]:3000`. Según si el cliente usaba IPv4 o IPv6, las pruebas habrían hablado con un servidor distinto. Solución: API de pruebas en el puerto **3100** (`.env.test`), sin tocar el otro proceso.
