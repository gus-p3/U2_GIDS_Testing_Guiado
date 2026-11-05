# 01 · Mentalidad de tester, criterios de aceptación y plan de pruebas

> PDF §1 “Start with a tester mindset and a plan” + plantilla “Test plan template”.

## 1. Mentalidad: investigar, no solo confirmar

Antes de escribir una prueba me hice cinco preguntas por funcionalidad (PDF §1, pasos 1-5):

| Pregunta | Ejemplo aplicado a “crear tarea” |
|---|---|
| ¿Quién la usa? | Un usuario autenticado desde la app Flutter. |
| ¿Qué debe observarse? | La tarea aparece en la lista y en `GET /api/v1/tasks`. |
| ¿Qué puede salir mal? | Título vacío, demasiado largo, tipo incorrecto, doble tap, red caída, token expirado, otro usuario intentando leerla. |
| ¿Qué es más grave? | Fuga de datos entre usuarios > pérdida de datos > mensaje confuso > detalle visual. |
| ¿Qué quedó sin probar? | Se registra al final de este documento. |

### Pirámide de pruebas usada en este ejercicio

```
            ┌──────────────────────────────┐
            │ E2E: 1 recorrido de 9 pasos  │  lento, frágil → pocos
            │ en emulador Pixel 8          │
            ├──────────────────────────────┤
            │ API/integración: Jest +      │
            │ Supertest + PostgreSQL _test │  medio
            ├──────────────────────────────┤
            │ Unitarias + widget:          │
            │ Jest + flutter_test (65)     │  rápidas → muchas
            └──────────────────────────────┘
```

## 2. Criterios de aceptación (práctica del §1)

Funcionalidad elegida: **creación de tareas**.

| # | Tipo | Criterio | Prueba que lo verifica |
|---|---|---|---|
| AC-1 | Éxito típico | Una tarea con título válido se guarda y aparece en la lista. | `backend/tests/api/tasks.test.js` (“owner can complete…”), E2E paso 05 |
| AC-2 | Entrada inválida | Un título con solo espacios se rechaza con un mensaje claro (`400` en API, “Title is required” en la app). | `tasks.test.js` “rejects an empty title”, E2E paso 06 |
| AC-3 | Límite de permisos | Un usuario no puede ver la tarea de otra cuenta cambiando el ID; la respuesta no revela si existe. | `tasks.test.js` “does not let one user read another user task” y “identical response” |

## 3. Plan de pruebas (plantilla del PDF, rellenada)

| Campo | Contenido |
|---|---|
| **Funcionalidad / release** | Secure Task Manager (copia de `u2/guardian_api`): registro, login, CRUD de tareas, refresh/logout/logout-all. |
| **Alcance (incluido)** | API REST `/api/v1/auth/*`, `/api/v1/tasks/*`, `/health`; app Flutter (login, lista, crear, completar, borrar, logout). |
| **Alcance (excluido)** | iOS real, despliegue en producción, escaneos de seguridad automáticos (ZAP, etc.), pruebas de carga sostenidas. |
| **Riesgos** | Fuga entre usuarios (BOLA), tokens robados/reutilizados, pérdida de datos en la UI, mensajes que no explican cómo recuperarse, contraseñas mal hasheadas. |
| **Entorno** | Windows 11, Node 22.23, Flutter 3.47.2 / Dart 3.13.2, PostgreSQL 16 en Docker (`ejercicio-test-db-test-1`, puerto 5434, tmpfs), emulador Android Pixel 8 (Android 14 / API 34), API de pruebas en puerto 3100, k6 v2.3.0. |
| **Datos de prueba** | Solo cuentas sintéticas `*@example.test`. Se borran tras cada archivo de pruebas (`cleanupTestUsers`). La cuenta E2E `tester@example.test` se reinicia con `npm run seed:test`. |
| **Tipos de prueba** | Unitarias, widget, API/integración, E2E, exploratorias, valores límite, seguridad básica, rendimiento (k6), accesibilidad, compatibilidad, smoke/regresión, CI. |
| **Criterios de entrada** | Contenedor de BD sano, migraciones aplicadas, `.env.test` presente, la guarda `tests/setup-env.js` confirma que la BD termina en `_test`. |
| **Criterios de salida** | 100 % de pruebas automáticas en verde, cero bugs abiertos de severidad alta, evidencia guardada en `evidence/`. |
| **Responsables** | Ejecución y reporte: el estudiante (con Claude). Corrección: mismo equipo. Aprobación: docente. |
| **Evidencia** | `evidence/screenshots/` (app), `evidence/terminal/` (salidas), `evidence/logs/` (texto completo). Sin tokens ni contraseñas reales. |

## 4. Qué queda sin probar (honestidad del tester)

- iOS (no hay Mac en este entorno).
- La app de escritorio Windows: compilarla requiere activar el *Modo desarrollador* de Windows (ajuste del sistema que no se cambió).
- Lector de pantalla real (TalkBack) operado por una persona: solo hay verificación automática de etiquetas y contraste.
- Comportamiento con red intermitente real (se simuló con un repositorio falso).
- Cargas mayores a 5 usuarios virtuales.
