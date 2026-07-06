---
description: Traer el HTML vivo de una URL y proponer selectores estables (read-only, no toca código).
argument-hint: <url>
---

Inspeccioná: **$ARGUMENTS**

Sos el orquestador. Esto es **read-only**: no se escribe ni se edita código, no se registra nada en
`run()` ni en `portales.md`. Es el paso previo para decidir si vale la pena un scraper.

1. **@researcher**: que traiga el HTML **vivo** de `$ARGUMENTS` (WebFetch o `curl` vía Bash) y reporte:
   - Estructura del DOM de las ofertas y **selectores CSS estables** propuestos (contenedor de oferta,
     título, empresa, ubicación, link).
   - Si el contenido parece **JS-rendered** (bs4 no lo vería) o hay señales de **anti-bot** (403/429,
     captcha, muro de login) → dejalo explícito.
   - Nota de fragilidad esperada (RSS/API estable 🟢 vs HTML semántico 🟡 vs clases volátiles/JS 🔴).

Relevá al usuario el diagnóstico de @researcher tal cual, con la recomendación de si conviene seguir con
`/scraper $ARGUMENTS`. No invoques @scraper-dev ni edites archivos.
