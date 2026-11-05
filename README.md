# U2 · Testing guiado — Secure Task Manager

Práctica completa del PDF **“Become a Better Application Tester: A Hands-On Task Manager Guide”** ([`Step-by-Step-Tutorial--Become-a-Good-Application-Tester.pdf`](Step-by-Step-Tutorial--Become-a-Good-Application-Tester.pdf)). La app bajo prueba es una copia de `u2/guardian_api`: Flutter + Node.js/Express + PostgreSQL + JWT con refresh tokens rotativos.

## Resultado en una mirada

| Qué | Resultado |
|---|---|
| Pruebas backend (Jest + Supertest, PostgreSQL **real** `_test`) | **78 / 78** ✅ · cobertura de líneas 99.1 %, de ramas 79.7 % |
| Pruebas Flutter (unitarias, widget, accesibilidad, pantallas, mocks) | **65 / 65** ✅ · `flutter analyze` sin problemas |
| E2E en emulador Android **Pixel 8** (Android 14) contra la API real | **1 recorrido de 9 pasos** ✅ · 9 capturas reales |
| Carga con k6 (5 VUs, 30 s, local) | p95 = **4.07 ms**, 0 % de errores ✅ |
| Bugs reales encontrados y corregidos | **8** (+1 problema de entorno) → [docs/03](docs/03-reportes-de-bugs.md) |
| CI | [`.github/workflows/tests.yml`](.github/workflows/tests.yml); práctica romper/restaurar verificada |

## Bugs encontrados (todos reproducidos con una prueba que falló antes del fix)

| ID | Qué pasaba | Cómo se encontró |
|---|---|---|
| BUG-001 | Si fallaba marcar una tarea como completada, **desaparecía toda la lista** (el caso exacto del ejercicio del PDF §2) | Prueba de widget con red caída simulada |
| BUG-002 | Doble tap en **Save** creaba 2 tareas | Prueba de widget con red lenta (`Completer`) |
| BUG-003 | bcrypt ignora todo después del byte 72: **dos contraseñas distintas abrían la misma cuenta** | Valores límite de la contraseña |
| BUG-004 | Contraseña incorrecta → “Your session has expired” | Prueba del cliente con mock |
| BUG-005 | Contraste del login 4.13:1 (< 4.5 WCAG) | `textContrastGuideline` |
| BUG-006 | Diálogo desbordado 128 px en teléfono pequeño con teclado | Prueba de tamaños de pantalla |
| BUG-007 | HTTP sin cifrar permitido también en builds de release | Revisión del manifest Android |
| BUG-008 | **Crear una tarea sin descripción fallaba con 400** (la app mandaba `null`) | **Solo el E2E** en el emulador; los mocks no lo veían |
| ENV-001 | Otro proceso del equipo respondía en `127.0.0.1:3000` | `curl /health` devolvió un campo que nuestra API no envía |

---

## Evidencia: la app en el emulador (capturas reales del E2E)

Tomadas por `binding.takeScreenshot()` durante `flutter drive` en el emulador Pixel 8 y guardadas en el PC por [`mobile/test_driver/integration_test.dart`](mobile/test_driver/integration_test.dart). Las imágenes salen de la propia app, así que no aparece ninguna otra ventana del escritorio.

| 01 · Login | 02 · Contraseña incorrecta (fix BUG-004) | 03 · Lista vacía |
|---|---|---|
| <img src="evidence/screenshots/01-login.png" width="230"> | <img src="evidence/screenshots/02-login-wrong-password.png" width="230"> | <img src="evidence/screenshots/03-empty-task-list.png" width="230"> |
| **04 · Nueva tarea** | **05 · Tarea creada (fix BUG-008)** | **06 · Título vacío rechazado** |
| <img src="evidence/screenshots/04-new-task-dialog.png" width="230"> | <img src="evidence/screenshots/05-task-created.png" width="230"> | <img src="evidence/screenshots/06-blank-title-rejected.png" width="230"> |
| **07 · `<script>` mostrado como texto** | **08 · Tarea completada (“Done”)** | **09 · Logout → login** |
| <img src="evidence/screenshots/07-markup-shown-as-text.png" width="230"> | <img src="evidence/screenshots/08-task-completed.png" width="230"> | <img src="evidence/screenshots/09-logged-out-login-screen.png" width="230"> |

### Primera corrida: el E2E encontró BUG-008

<img src="evidence/screenshots/run1-bug008/05-task-created.png" width="230" align="right">

En la primera corrida, la captura 05 debía mostrar la tarea creada. En su lugar quedó el diálogo abierto con **“Check the submitted values.”**: la API rechazaba `description: null`. La prueba no se detuvo ahí porque buscaba el texto de la tarea, y lo encontraba **dentro del campo del diálogo**. Eso fue un falso positivo, otra lección.
Capturas de esa corrida: [`evidence/screenshots/run1-bug008/`](evidence/screenshots/run1-bug008/).

<br clear="right">

---

## Evidencia: salidas reales de las pruebas

Cada imagen se generó con [`tools/render-terminal.js`](tools/render-terminal.js) a partir del log **sin editar** que está en [`evidence/logs/`](evidence/logs/). El script solo quita los códigos de color ANSI y recorta el rango de líneas.

### Suites en verde

| Backend: `npm run test:coverage` | Flutter: `flutter test` |
|---|---|
| <img src="evidence/terminal/01-backend-tests.png" width="420"> | <img src="evidence/terminal/02-flutter-tests.png" width="420"> |

**E2E en el emulador (`flutter drive`)**
<img src="evidence/terminal/03-e2e-android.png" width="760">

### Bugs: ejecución ANTES del fix

| BUG-001 y BUG-002 | BUG-003 (bcrypt) |
|---|---|
| <img src="evidence/terminal/04-bug001-002-before-fix.png" width="420"> | <img src="evidence/terminal/05-bug003-before-fix.png" width="420"> |
| **BUG-004 (mensajes de login)** | **BUG-005 y BUG-006 (a11y y pantalla pequeña)** |
| <img src="evidence/terminal/06-bug004-before-fix.png" width="420"> | <img src="evidence/terminal/07-bug005-006-before-fix.png" width="420"> |

**BUG-008 reproducido con curl**
<img src="evidence/terminal/08-bug008-curl-before-fix.png" width="760">

### Rendimiento (k6) y CI

| k6 con umbral p95 < 500 ms → pasa | k6 con umbral p95 < 2 ms → falla (exit 99) |
|---|---|
| <img src="evidence/terminal/09-k6-p95-500ms.png" width="420"> | <img src="evidence/terminal/10-k6-p95-2ms.png" width="420"> |
| **CI: límite de título roto a propósito → 2 fallos** | **CI: código restaurado → todo en verde** |
| <img src="evidence/terminal/11-ci-broken.png" width="420"> | <img src="evidence/terminal/12-ci-restored.png" width="420"> |

---

## Mapa: sección del PDF → dónde está resuelta

| § | Tema | Archivos |
|---|---|---|
| 1 | Mentalidad, criterios, plan | [docs/01](docs/01-plan-y-criterios.md) |
| 2 | Casos de prueba y reportes de bugs | [docs/02](docs/02-casos-de-prueba.md), [docs/03](docs/03-reportes-de-bugs.md) |
| 3 | Exploratorio con charter | [docs/04](docs/04-sesion-exploratoria.md) |
| 4 | Unitarias | `backend/tests/unit/validation.test.js`, `mobile/test/task_test.dart` |
| 5 | Widgets (+ botón Retry llamado una vez) | `mobile/test/task_list_view_test.dart` |
| 6 | API e integración | `backend/tests/api/tasks.test.js`, `auth.test.js` |
| 7 | Recorrido completo (+ completar y logout) | `mobile/integration_test/app_journey_test.dart` |
| 8 | Valores límite (título y contraseña) | [docs/05](docs/05-valores-limite-y-seguridad.md), `validation.test.js`, `auth.test.js`, `auth_page_test.dart` |
| 9 | Seguridad básica y OWASP (+ `ownerId`) | [docs/05](docs/05-valores-limite-y-seguridad.md), `tasks.test.js`, `auth.test.js`, `rate-limit.test.js` |
| 10 | Rendimiento k6 | `load-tests/health-test.js`, [docs/06](docs/06-rendimiento-accesibilidad-compatibilidad.md) |
| 11 | Accesibilidad | `mobile/test/accessibility_test.dart`, [docs/06](docs/06-rendimiento-accesibilidad-compatibilidad.md) |
| 12 | Compatibilidad (matriz) | `mobile/test/screen_size_test.dart`, [docs/06](docs/06-rendimiento-accesibilidad-compatibilidad.md) |
| 13 | Smoke, regresión, datos de prueba | [docs/07](docs/07-smoke-regresion-ci-mocks.md), `backend/scripts/seed-test.js` |
| 14 | CI y cobertura | `.github/workflows/tests.yml`, [docs/07](docs/07-smoke-regresion-ci-mocks.md) |
| 15 | Mocks vs integración, pruebas inestables | `mobile/test/task_repository_test.dart`, [docs/07](docs/07-smoke-regresion-ci-mocks.md) |

## Cómo ejecutarlo

Requisitos: Docker Desktop, Node 22, Flutter 3.47+, (opcional) emulador Android y k6.

```bash
# 1) Base de datos de pruebas desechable (PostgreSQL 16 en tmpfs, puerto 5434)
cd backend
cp .env.test.example .env.test
npm ci
npm run db:test:up
npm run db:test:migrate

# 2) Pruebas
npm test                        # backend (se niega a correr si la BD no termina en _test)
cd ../mobile && flutter test    # Flutter

# 3) Recorrido E2E en el emulador (API de pruebas en el puerto 3100)
cd ../backend && npm run seed:test && npm run start:test     # dejar corriendo
cd ../mobile
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_journey_test.dart -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:3100/api/v1

# 4) Carga (solo contra tu API local)
k6 run -e BASE_URL=http://127.0.0.1:3100 load-tests/health-test.js
```

## Estructura

```
backend/          API Express + Prisma (copia de guardian_api con fixes) y sus pruebas
  tests/unit/     unitarias puras (sin BD)
  tests/api/      Supertest contra PostgreSQL _test
mobile/           App Flutter
  test/           unitarias, widget, accesibilidad, pantallas, mocks, regresión de bugs
  integration_test/  recorrido E2E con capturas
  test_driver/    guarda en el PC las capturas del dispositivo
load-tests/       script k6
docs/             plan, casos, bugs, exploratorio, límites/OWASP, rendimiento/a11y/compat, CI/mocks
evidence/         screenshots/ (app), terminal/ (salidas), logs/ (texto completo)
tools/            render-terminal.js (log → PNG)
HANDOFF.md        prompt para que otra IA continúe el trabajo
```

## Lecciones principales

1. **Las pruebas con mocks no detectan contratos rotos.** BUG-008 pasaba todas las pruebas del cliente y de la API por separado; solo el E2E lo encontró.
2. **La cobertura alta no es calidad.** Con 99 % de líneas cubiertas seguían ocultos BUG-003 y BUG-008.
3. **Una prueba también puede estar mal.** El primer E2E tenía un falso positivo: hay que verificar el estado final, no solo que “aparezca un texto”.
4. **El entorno es parte de la prueba.** Otro servidor en el puerto 3000 habría hecho que las pruebas hablaran con la API equivocada (ENV-001).
5. **Los errores de una acción no deben borrar el estado ya cargado** (BUG-001), y los mensajes deben decir cómo recuperarse (BUG-004).
6. **Seguridad de los datos de prueba:** solo cuentas `@example.test`, BD en tmpfs y guardas que bloquean cualquier BD que no sea `_test`.

## Limitaciones honestas

- No se probó iOS (no hay Mac). La app de **Windows** necesita activar el *Modo desarrollador* (ajuste del sistema que no se cambió); evidencia en `evidence/logs/flutter-e2e-windows.txt`.
- La accesibilidad se verificó con las guías automáticas de Flutter; falta una pasada manual con TalkBack.
- El CI está configurado pero aún no se ha ejecutado en GitHub Actions; se replicó localmente con los mismos comandos.
- La sesión exploratoria se hizo con sondas automatizadas, no a mano en un teléfono (ver [docs/04](docs/04-sesion-exploratoria.md)).
