---
description: Agregar un scraper nuevo para un portal de empleo (inspección → código → dry-run).
argument-hint: <portal|url>
---

Agregá un scraper nuevo para: **$ARGUMENTS**

Sos el orquestador. Coordiná este flujo (no escribís código vos mismo). Antes de arrancar, leé
`.claude/workspace.md`, `AGENTS.md` y `references/portales.md` para ubicarte.

1. **@researcher** (read-only): que traiga el HTML **vivo** de la URL/portal `$ARGUMENTS` (WebFetch o
   `curl`), entienda la estructura del DOM y proponga **selectores CSS estables** para las ofertas
   (contenedor, título, empresa, ubicación, link) más la URL de listado y si el sitio parece
   JS-rendered/anti-bot.
   - Si vuelve `BLOCKED` (ej. contenido JS-rendered inviable con requests+bs4) → **FRENÁ y consultá
     al usuario** antes de codear. No sigas.

2. **@scraper-dev**: pasale los selectores de @researcher en el handoff estándar. Que escriba
   `scrape_<portal>() -> list[Empleo]` cumpliendo el **contrato de scraper de AGENTS.md** (progreso con
   `print`, `timeout=` + `User-Agent` si es HTML, `try/except Exception as e` que no tumba la corrida,
   `es_relevante(titulo)`, normalización a `Empleo`, cierre con conteo). Que lo **registre en `run()`**
   (`todos += scrape_<portal>()`) y agregue la fila en `references/portales.md` (método, fragilidad,
   selectores, fecha de verificación). Inyectale como Project Standards las skills `scraping-patterns`,
   `anti-fragile-scrapers` y `minimal-footprint`.

3. **@testing**: dry-run (`/probar`) SIN mandar email; confirmá que el portal nuevo devuelve algo
   coherente (no 0 silencioso).

Cerrá con un resumen al usuario y el handoff git (commit/push vía @git-flow **solo a pedido**).
