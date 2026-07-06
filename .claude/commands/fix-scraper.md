---
description: Diagnosticar y arreglar un scraper que devuelve 0 o datos basura.
argument-hint: <portal>
---

Arreglá el scraper roto de: **$ARGUMENTS**

Sos el orquestador. Recordá la regla base: **0 resultados ≠ "no hay empleos"** (casi siempre es
selector muerto o anti-bot). Leé `.claude/workspace.md`, `references/gotchas.md` y la fila del portal en
`references/portales.md` antes de arrancar.

1. **@scraper-doctor** (read-only): que diagnostique `scrape_$ARGUMENTS()`. Debe distinguir **selector
   muerto** vs **anti-bot** (403/429/captcha) vs **JS-rendered** (bs4 no ve el DOM) vs **realmente no
   hay ofertas**. Entrega diagnóstico + plan de fix, no codea.

2. Según el diagnóstico:
   - **Selector muerto** → **@researcher** confirma el selector nuevo contra el HTML vivo → **@scraper-dev**
     lo aplica (inyectale `scraping-patterns`, `anti-fragile-scrapers`, `minimal-footprint`).
   - **Anti-bot** → **@scraper-dev** ajusta headers/`User-Agent`/rate-limit; si el límite es duro,
     documentalo en `references/portales.md`.
   - **JS-rendered / inviable con requests+bs4** → el agente devuelve `BLOCKED`: **FRENÁ y consultá al
     usuario** (cambiar de enfoque —API, headless o descartar el portal— es decisión suya). No codees.

3. **@testing**: dry-run (`/probar`) para validar que vuelve a traer resultados coherentes.

4. Actualizá `references/portales.md`: selector nuevo + **fecha de verificación** (y fragilidad si cambió).

Cerrá con resumen al usuario + handoff git (commit/push vía @git-flow **solo a pedido**).
