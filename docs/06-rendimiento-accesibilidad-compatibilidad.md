# 06 · Rendimiento, accesibilidad y compatibilidad

> PDF §10 “Check performance and load safely”, §11 “Check usability and accessibility”, §12 “Test device and platform compatibility”.

## 1. Rendimiento con k6 (§10)

**Autorización y alcance:** solo la API local de pruebas (`http://127.0.0.1:3100`), en una máquina propia. 5 usuarios virtuales durante 30 s, solo `GET /health`.
**Condición de parada:** los umbrales `http_req_failed < 1 %` y `p(95) < 500 ms` marcan la corrida como fallida si se cruzan.

```bash
k6 run -e BASE_URL=http://127.0.0.1:3100 load-tests/health-test.js
```

| Corrida | Umbral p95 | p95 medido | Errores | Peticiones | Resultado | Evidencia |
|---|---|---|---|---|---|---|
| 1 | < 500 ms | **4.07 ms** | 0 % | 150 (≈5/s) | ✅ pasa, exit 0 | `evidence/terminal/09-k6-p95-500ms.png` |
| 2 (práctica) | < **2 ms** | **8.06 ms** | 0 % | 150 | ❌ “thresholds … have been crossed”, **exit 99** | `evidence/terminal/10-k6-p95-2ms.png` |

**Qué dice el reporte (práctica del §10):**
- `http_req_duration p(95)` es la latencia por debajo de la cual queda el 95 % de las peticiones. Con 2 ms el umbral es más estricto que el comportamiento real del servidor, así que k6 marca la corrida como fallida y sale con código 99. Ese código es el que haría fallar un pipeline de CI.
- `checks 100 %`: aunque la corrida “falló”, todas las respuestas fueron 200. Un umbral de rendimiento no es lo mismo que un error funcional.
- En la corrida 2 el p95 subió de 4 a 8 ms porque se estaba compilando la app Android al mismo tiempo. Las mediciones de rendimiento necesitan un entorno estable y dedicado (PDF: *“use a dedicated environment”*).
- Para medirlo de verdad faltaría observar CPU, memoria y conexiones de BD durante la corrida; aquí solo se midieron métricas del cliente.

## 2. Accesibilidad (§11)

Verificación automática con las guías de Flutter (`mobile/test/accessibility_test.dart`):

| Punto del checklist del PDF | Cómo se verificó | Resultado |
|---|---|---|
| Contraste suficiente | `textContrastGuideline` (WCAG 4.5:1) en login y lista | ❌ → ✅ **BUG-005** corregido |
| Botones y campos con nombres accesibles | `labeledTapTargetGuideline`; etiquetas semánticas en checkbox (“Mark "Plan tests" as done”) y tooltip de borrar con el nombre de la tarea | ✅ |
| Lector de pantalla anuncia títulos, estado y errores | `find.bySemanticsLabel` para checkbox y errores de validación | ✅ |
| Usable con texto grande | Escala de texto 1.5× y 2.0× sin overflow en login y lista | ✅ |
| Objetivos táctiles fáciles | `androidTapTargetGuideline` (48×48) e `iOSTapTargetGuideline` (44×44) | ✅ |
| Los errores explican cómo recuperarse | “An account with this email already exists.”, “Too many requests. Try again later.” | ❌ → ✅ (parte de **BUG-004**) |
| El color no es la única señal de estado | Se añadió el texto “Done” / “Pending” además del tachado y el color | ✅ (mejora) |
| Teclado / switch | No aplica en el emulador; sin verificar | ⚠️ pendiente |

**Práctica del §11** (lector de pantalla + texto grande + error de validación): se automatizó como se describe arriba. Falta una pasada manual con TalkBack por una persona: las guías automáticas no evalúan si el orden de lectura “tiene sentido”.

## 3. Compatibilidad (§12)

### Matriz de dispositivos (representativa, no exhaustiva)

| Plataforma | Perfil | SO | Qué se revisó | Cómo | Resultado |
|---|---|---|---|---|---|
| Android | Teléfono pequeño 320×568 | mínimo soportado (simulado) | Lista, login, diálogo con teclado | `screen_size_test.dart` | ❌ → ✅ **BUG-006** |
| Android | Teléfono actual 393×852 | actual | Lista, login | `screen_size_test.dart` | ✅ |
| Android | **Pixel 8 (emulador real)** | Android 14 (API 34) | Login, CRUD, completar, logout | E2E `flutter drive` | ✅ 9 capturas |
| Tablet | 820×1180 | — | Lista, login | `screen_size_test.dart` | ✅ |
| Escritorio | 1280×800 | — | Lista, login | `screen_size_test.dart` | ✅ |
| Windows desktop | App nativa | Windows 11 | — | `flutter test -d windows` | ⛔ bloqueado: requiere *Modo desarrollador* (`evidence/logs/flutter-e2e-windows.txt`) |
| iOS | — | — | — | — | ⛔ no hay Mac en este entorno |

**Práctica del §12:** en pantalla pequeña y grande se buscaron desbordes (`tester.takeException()`), texto cortado (el título de 120 caracteres se envuelve completo) y controles difíciles de tocar (FAB y logout ≥ 48 px). El único problema fue BUG-006.
