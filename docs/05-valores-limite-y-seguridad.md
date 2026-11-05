# 05 · Valores límite, partición de equivalencia y seguridad básica

> PDF §8 “Use boundary values and equivalence partitions” y §9 “Test negative behavior and security basics” (+ checklist OWASP API Security).

## 1. Título de tarea (1–120 caracteres)

| Partición o límite | Entrada | Esperado | Obtenido | Dónde |
|---|---|---|---|---|
| Vacío | `""` | Rechazar | ✅ Rechaza | `validation.test.js` |
| Solo espacios | `"   "` | Rechazar | ✅ | unit + API + E2E |
| Mínimo válido | `"a"` | Aceptar | ✅ | unit + `task_test.dart` |
| Típico | `"Plan tests"` | Aceptar | ✅ | unit |
| Máximo válido | 120 caracteres | Aceptar | ✅ | unit + API + Dart |
| Justo sobre el máximo | 121 caracteres | Rechazar | ✅ | unit + API + Dart |
| 120 + espacios alrededor | `"  "+120+"  "` | Aceptar (se recorta) | ✅ | unit |
| Tipo incorrecto | `title: 42`, `null`, `[...]`, `{}`, `true` | Rechazar con 400 seguro | ✅ | unit + API |

## 2. Contraseña (práctica del §8, solo contraseñas sintéticas)

Política final: **12 a 72 bytes UTF-8** (72 por el límite de bcrypt, ver BUG-003).

| Partición o límite | Entrada | Esperado | API | App |
|---|---|---|---|---|
| Vacía | `""` | Rechazar | ✅ 400 | ✅ “Password is required” |
| Justo bajo el mínimo | 11 chars | Rechazar | ✅ 400 | ✅ |
| Mínimo válido | 12 chars | Aceptar | ✅ 201 | ✅ |
| Típica | `correct-horse-battery` | Aceptar | ✅ 201 | ✅ |
| Máximo válido | 72 bytes | Aceptar | ✅ 201 | ✅ |
| Justo sobre el máximo | 73 bytes | Rechazar | ✅ 400 (antes 201 ❌) | ✅ |
| Multibyte | `"ñ"×37` = 37 chars / **74 bytes** | Rechazar | ✅ 400 | ✅ |
| Tipo incorrecto | número | Rechazar | ✅ 400 | n/a |

## 3. Comportamiento negativo y seguridad (§9, pasos 1-6)

| Paso del PDF | Qué se probó | Resultado |
|---|---|---|
| 1. Tipos inválidos, campos faltantes, tamaños excesivos | título numérico/null/array, sin título, descripción de 2001, cuerpo de 25 KB (`413`), JSON mal formado (`400`), `limit=0/101/-1`, PATCH vacío | ✅ errores 4xx seguros, sin stack traces |
| 2. Cadenas tipo inyección SQL | título `' OR '1'='1`, `limit=1' OR '1'='1`, ID `1' OR '1'='1` | ✅ se guarda como texto / 400; el atacante sigue viendo 1 sola tarea |
| 3. Markup en la UI | `<script>alert(1)</script>` | ✅ API lo devuelve como JSON; Flutter lo pinta como texto (widget + E2E) |
| 4. Token de B con tarea de A | GET/PATCH/DELETE cruzados | ✅ 404 idéntico al de “no existe”; la tarea queda intacta |
| 5. Rate limit (corrida pequeña autorizada, 4 peticiones) | login y refresh | ✅ `429 RATE_LIMITED` + cabecera `RateLimit` |
| 6. Tokens expirados, rotación, reúso, logout, logout-all | expirado, firma falsa, `alg:none`, tipo incorrecto, otra audiencia, cabecera mal formada; rotación; reúso revoca familia; logout; logout-all no afecta a otros usuarios | ✅ todos 401 / comportamiento esperado |

Práctica del §9: actualizar una tarea enviando `ownerId`. La API **ignora** el campo y conserva el dueño calculado en el servidor, tanto en `POST` como en `PATCH`. Lo cubren las pruebas “ownerId sent on create/update is ignored”.

## 4. Checklist OWASP API Security Top 10 aplicado

| Riesgo | Verificación en Task Manager | Estado | Evidencia |
|---|---|---|---|
| API1 Broken object-level authorization | Toda consulta filtra por `ownerId` del token | ✅ | 7 pruebas cruzadas A/B |
| API2 Broken authentication | Tokens inválidos, expirados, revocados, `alg:none` rechazados; bcrypt 72 bytes | ✅ (tras BUG-003) | `auth.test.js` |
| API3 Broken object property-level authorization | El cliente no puede fijar `ownerId` | ✅ | `tasks.test.js` |
| API4 Unrestricted resource consumption | Cuerpo ≤ 20 KB, `limit` ≤ 100, título ≤ 120, descripción ≤ 2000 | ✅ | `tasks.test.js` |
| API5 Broken function-level authorization | Rutas de tareas y `logout-all` exigen identidad | ✅ | 401 sin token |
| API6 Unrestricted access to sensitive flows | Login/registro/refresh con rate limit | ✅ | `rate-limit.test.js` |
| API7 SSRF | La API no acepta URLs controladas por el usuario | ✅ (por diseño) | revisión de código |
| API8 Security misconfiguration | Helmet (`nosniff`), sin `x-powered-by`, CORS restringido; HTTP solo en debug | ✅ (tras BUG-007) | `health.test.js`, manifest |
| API9 Improper inventory management | Solo existe `/api/v1`; OpenAPI en `backend/openapi.yaml` | ✅ `GET /tasks/{taskId}` añadido al OpenAPI | `backend/openapi.yaml` |
| API10 Unsafe consumption of APIs | La app valida el JSON (`Task.fromJson` → `FormatException`) y nunca muestra mensajes 5xx | ✅ | `task_test.dart`, `auth_repository_test.dart` |

> Una prueba en verde **no prueba** que algo sea seguro (error común del PDF). Estas pruebas cubren los casos que se nos ocurrieron; no sustituyen una revisión de seguridad profesional.
