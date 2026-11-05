# 04 · Sesión exploratoria con charter

> PDF §3 “Explore the app with a charter” + práctica: explorar creación y edición 15 min con título largo, título vacío, taps rápidos y conectividad interrumpida.

**Charter:** *Explorar la creación, edición y completado de tareas para encontrar problemas de pérdida de datos y mensajes confusos.*
**Duración planeada:** 20 min · **Cuenta:** usuario de prueba sintético · **Entorno:** API local de pruebas + app Flutter.

**Nota de honestidad:** la sesión la hizo un asistente sin manos en un teléfono real. Por eso cada idea se probó con una sonda reproducible: una prueba de widget con dependencias inyectadas, una llamada a la API con Supertest o la lectura dirigida del código. Esta es la variante “exploración asistida por herramientas”. Lo que no se pudo explorar así está al final.

## Notas de sesión (plantilla del PDF)

| Tiempo | Acción o condición | Observación | Seguimiento |
|---|---|---|---|
| 00:00 | Login como usuario A sintético, lista vacía | Se ve “No tasks yet. Add your first task.” | ✔ estado vacío cubierto por prueba de widget |
| 00:02 | Título de 120 caracteres | Se acepta; en 320 px se envuelve en varias líneas sin cortarse | ✔ `screen_size_test.dart` |
| 00:03 | Título de 121 caracteres | La app muestra “Maximum 120 characters”; la API responde 400 | ✔ cubierto en ambas capas |
| 00:04 | Título solo con espacios | “Title is required” | ✔ E2E paso 06 |
| 00:05 | **Taps rápidos repetidos en Save** con red lenta | **Se crean 2 tareas** | ❗ **BUG-002** |
| 00:08 | Marcar completada **sin conexión** | **Desaparece toda la lista** | ❗ **BUG-001** (justo el caso del ejercicio del §2) |
| 00:10 | Login con contraseña incorrecta | Mensaje “Your session has expired” | ❗ **BUG-004** |
| 00:11 | Registrar un email ya existente | “The request could not be completed. Try again.” (no dice que el email ya existe) | ❗ añadido a BUG-004 |
| 00:12 | Contraseña de 73+ bytes (posible por diseño: máx. 128) | Pregunta: ¿qué hace bcrypt con más de 72 bytes? | ❗ confirmado **BUG-003** en API |
| 00:14 | Título `<script>alert(1)</script>` | Se muestra como texto literal | ✔ E2E paso 07 |
| 00:15 | Título `' OR '1'='1` | Se guarda tal cual, no afecta otras filas (Prisma parametriza) | ✔ `tasks.test.js` |
| 00:16 | `GET /tasks/{id}` de otro usuario | No existía la ruta `GET /tasks/:id` | Añadida para cumplir la prueba del §6; responde 404 idéntico al “no existe” |
| 00:17 | Teclado abierto en pantalla de 320×568 | Diálogo desbordado 128 px | ❗ **BUG-006** |
| 00:19 | Revisar manifest antes de correr en Android | `usesCleartextTraffic` en el manifest principal | ❗ **BUG-007** |
| 00:20 | Primera corrida E2E real en el emulador | Crear una tarea sin descripción → “Check the submitted values.” | ❗ **BUG-008** (lo encontró el E2E, no la exploración) |

## Qué me sorprendió

1. El bug del ejercicio del PDF (*“una tarea desaparece al marcarla completada”*) existía de verdad, y no en el servidor sino en el manejo de estado de la UI.
2. Una cobertura del ~99 % en el backend no evitó BUG-003. El código se ejecutaba en las pruebas, pero nadie había preguntado por el límite de bcrypt.
3. Un problema del **entorno** (ENV-001: otro servidor en el puerto 3000) pudo haber hecho que las pruebas “pasaran” hablando con la API equivocada.

## No cubierto en esta sesión

- Interrupción de red real a mitad de una petición, con radio apagada en el dispositivo.
- Rotación de pantalla y app en segundo plano durante un guardado.
- Uso con TalkBack, manejado por una persona.
