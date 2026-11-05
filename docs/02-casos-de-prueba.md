# 02 · Casos de prueba

> PDF §2 “Write useful test cases and bug reports” — plantilla de caso de prueba.
> Entorno común: Windows 11 · API build local (`npm run start:test`, puerto 3100) · PostgreSQL 16 `task_manager_test` · App Flutter 1.0.0+1 en emulador Pixel 8 (Android) · Fecha de ejecución: 2026-11-04.

---

### TC-01 · Crear una tarea con título válido

| Campo | Valor |
|---|---|
| **Precondiciones** | Cuenta sintética `tester@example.test` sembrada sin tareas (`npm run seed:test`). App en la pantalla de login. |
| **Pasos** | 1. Escribir el email. 2. Escribir la contraseña de prueba. 3. Pulsar **Sign In**. 4. Pulsar **New Task**. 5. Escribir “Check release flow”. 6. Pulsar **Save**. |
| **Datos** | Título `Check release flow` (sintético). |
| **Resultado esperado** | El diálogo se cierra y “Check release flow” aparece una sola vez en la lista, con estado “Pending”. |
| **Resultado obtenido** | ✅ Igual al esperado (captura `evidence/screenshots/05-task-created.png`). |
| **Automatizado en** | `mobile/integration_test/app_journey_test.dart` |

### TC-02 · Rechazar un título con solo espacios

| Campo | Valor |
|---|---|
| **Precondiciones** | Sesión iniciada; diálogo **New Task** abierto. |
| **Pasos** | 1. Escribir `"   "` en el título. 2. Pulsar **Save**. |
| **Datos** | Tres espacios. |
| **Resultado esperado** | No se envía nada al servidor; aparece “Title is required” bajo el campo. Por API directa, `POST /api/v1/tasks {"title":"   "}` → `400 VALIDATION_ERROR`. |
| **Resultado obtenido** | ✅ App: captura `06-blank-title-rejected.png`. API: prueba “rejects an empty title” en verde. |
| **Automatizado en** | E2E + `backend/tests/api/tasks.test.js` |

### TC-03 · Un usuario no puede leer la tarea de otro cambiando el ID

| Campo | Valor |
|---|---|
| **Precondiciones** | Usuario A (dueño) y usuario B (extraño), ambos sintéticos. A creó la tarea “Private task”. |
| **Pasos** | 1. Con el token de B, `GET /api/v1/tasks/{idDeA}`. 2. Con el token de B, `GET /api/v1/tasks/{idInexistente}`. 3. Comparar ambas respuestas. |
| **Datos** | IDs cuid reales generados en la BD de pruebas. |
| **Resultado esperado** | Ambas devuelven `404 {"error":{"code":"NOT_FOUND","message":"Task not found."}}` — idénticas, para no revelar que la tarea existe. |
| **Resultado obtenido** | ✅ Idénticas. |
| **Automatizado en** | `tasks.test.js` → “foreign and missing tasks get the identical response” |

### TC-04 · Marcar una tarea como completada sin conexión

| Campo | Valor |
|---|---|
| **Precondiciones** | Lista con “Buy milk” y “Plan tests”. Red simulada caída (`FakeTaskRepository.failUpdates = true`). |
| **Pasos** | 1. Pulsar la casilla de “Buy milk”. |
| **Resultado esperado** | Las dos tareas siguen visibles, la casilla sigue sin marcar y aparece un aviso “Could not connect to the server…”. |
| **Resultado obtenido (antes del fix)** | ❌ Desaparecía toda la lista → **BUG-001**. |
| **Resultado obtenido (después)** | ✅ |
| **Automatizado en** | `mobile/test/task_page_bugs_test.dart` |

### TC-05 · Reúso de un refresh token ya rotado

| Campo | Valor |
|---|---|
| **Precondiciones** | Usuario sintético recién registrado (token R1). |
| **Pasos** | 1. `POST /auth/refresh {R1}` → obtiene R2. 2. Reenviar R1. 3. Enviar R2. |
| **Resultado esperado** | Paso 1 → 200; paso 2 → 401 (reúso detectado); paso 3 → 401 (se revocó toda la familia). |
| **Resultado obtenido** | ✅ |
| **Automatizado en** | `backend/tests/api/auth.test.js` |

### TC-06 · Contraseña en el límite de bcrypt (72 bytes)

| Campo | Valor |
|---|---|
| **Precondiciones** | Ninguna. |
| **Pasos** | 1. Registrar con `"b"×72 + "X"` (73 bytes). 2. Si se acepta, hacer login con `"b"×72 + "Y"`. |
| **Resultado esperado** | El registro se rechaza (`400`) o el login con otra contraseña falla (`401`). |
| **Resultado obtenido (antes)** | ❌ Registro 201 y login con la contraseña equivocada **200** → **BUG-003**. |
| **Resultado obtenido (después)** | ✅ Registro `400 "Password must be at most 72 bytes."` |
| **Automatizado en** | `auth.test.js` → “passwords that differ only after byte 72…” |

### TC-07 · Cerrar sesión y volver al login (práctica del §7)

| Campo | Valor |
|---|---|
| **Precondiciones** | TC-01 ejecutado, tarea completada. |
| **Pasos** | 1. Pulsar el icono **Log out**. |
| **Resultado esperado** | Aparece “Welcome Back” con el botón **Sign In**; la lista ya no es visible; el refresh token queda revocado en el servidor. |
| **Resultado obtenido** | ✅ Captura `09-logged-out-login-screen.png`. |
| **Automatizado en** | E2E |
