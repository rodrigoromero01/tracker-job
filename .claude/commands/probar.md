---
description: Dry-run del scraper sin mandar email; reporta empleos por portal, nuevos y roturas.
argument-hint:
---

Corré un dry-run del tracker. **No se manda ningún correo.**

Sos el orquestador. Leé `.claude/workspace.md` (para el `PYTHON_BIN`) antes de arrancar.

1. **@testing**: que ejecute la corrida **sin enviar email**. Opciones válidas:
   - Correr `run()` con `enviar_email` neutralizado (o llamando directo a los `scrape_*()` +
     dedup), o
   - Generar el HTML con `armar_email_html(nuevos)` e inspeccionarlo, sin llamar a `enviar_email`.

   Que reporte:
   - **Empleos por portal** (PyAr, Computrabajo, BairesDev, Wellfound y los que haya): cuántos trajo cada
     `scrape_*()`.
   - **Nuevos** (no vistos antes, tras la dedup por `uid`).
   - **Portales en 0**: marcalos como **posible rotura** (0 ≠ "no hay empleos"; ver `references/gotchas.md`).

2. Si algún portal dio 0 de forma sospechosa, sugerí `/fix-scraper <portal>` (no lo ejecutes acá).

Confirmá siempre que **no se envió correo**. No commitees nada.
