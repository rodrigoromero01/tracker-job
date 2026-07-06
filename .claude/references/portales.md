# Catálogo de portales — tracker-job

> Fuente de verdad de **qué se scrapea y cómo**. El equivalente al "conocimiento por versión"
> del enjambre Odoo, pero acá el conocimiento es **por portal**. Cada vez que se agrega, arregla
> o rompe un scraper, esta tabla se actualiza (el hook `post_write.sh` lo recuerda).
>
> Los scrapers HTML son **frágiles por diseño**: dependen de selectores CSS que el sitio puede
> cambiar sin avisar. Cuando un scraper devuelve 0 resultados de golpe, empezá por acá:
> comparás los selectores documentados contra el HTML vivo (agente `scraper-doctor` + `researcher`).

## Estado rápido

| Portal | Método | Fragilidad | Últ. verificación | Función |
|--------|--------|-----------|-------------------|---------|
| PyAr | RSS (feedparser) | 🟢 Baja | (pendiente) | `scrape_pyar()` |
| Computrabajo | HTML (BeautifulSoup) | 🔴 Alta | (pendiente) | `scrape_computrabajo()` |
| BairesDev | HTML (BeautifulSoup) | 🔴 Alta | (pendiente) | `scrape_bairesdev()` |
| Wellfound | HTML (BeautifulSoup) | 🔴 Alta | (pendiente) | `scrape_wellfound()` |

Fragilidad: 🟢 RSS/API estable · 🟡 HTML con estructura semántica · 🔴 HTML con clases volátiles / JS-rendered.

---

## PyAr — python.org.ar

- **URL**: `https://www.python.org.ar/trabajo/rss/`
- **Método**: RSS oficial vía `feedparser.parse()`. **El más estable** — es un feed pensado para consumo automático.
- **Campos usados**: `entry.title`, `entry.author` (empresa), `entry.link`, `entry.published`.
- **Ubicación**: fija `"Argentina"`.
- **Remoto**: heurística por `"remoto"`/`"remote"` en el título.
- **Fragilidad**: baja. Si rompe, suele ser cambio de URL del feed o caída del sitio, no de estructura.
- **Notas**: no requiere User-Agent especial. Respeta el feed; no scrapees el HTML de PyAr si el RSS alcanza.

## Computrabajo — ar.computrabajo.com

- **URL**: `https://ar.computrabajo.com/trabajo-de-{query}` — queries: `desarrollador-python-junior`, `python-junior`, `analista-datos-junior`.
- **Método**: HTML con BeautifulSoup. Requiere `User-Agent` de navegador (bloquea clientes "bot").
- **Selectores** (verificar seguido): oferta `article.box_offer`; título `h2 a, .title a`; empresa `.fWeight500, .company`; ciudad `.fs13, .city`.
- **Fragilidad**: alta. Clases con sufijos que cambian. Toma solo los primeros 10 por query.
- **Notas**: enlaces relativos → prefijar `https://ar.computrabajo.com`. Puede requerir manejar paginado si se quiere más volumen.

## BairesDev — applicants.bairesdev.com

- **URL**: `https://applicants.bairesdev.com/jobs`
- **Método**: HTML con BeautifulSoup. Selectores múltiples defensivos: `.job-item, .job-card, li[class*='job']`; título `h2, h3, .job-title, a[href*='/job/']`.
- **Fragilidad**: alta — sitio corporativo, puede ser SPA (JS-rendered) → BeautifulSoup no ve el DOM final.
- **Fallback**: si no encuentra nada, inyecta 1 posición conocida hardcodeada (ver `scrape_bairesdev()`). Ojo: ese fallback puede quedar obsoleto.
- **Notas**: empresa/ubicación fijas ("BairesDev" / "Remoto", `remoto=True`).

## Wellfound — wellfound.com (ex-AngelList)

- **URL**: `https://wellfound.com/role/l/python-developer/argentina`
- **Método**: HTML con BeautifulSoup. Selectores por atributo: `[class*='job'] h2, [class*='listing'] h2`.
- **Fragilidad**: alta — Wellfound es fuertemente JS-rendered y suele requerir auth/anti-bot. Es el candidato más probable a devolver 0.
- **Notas**: empresa fija "Startup (Wellfound)"; `remoto=True`. Si consistentemente da 0, evaluar API/GraphQL o descartar el portal (documentarlo acá).

---

## Cómo agregar un portal nuevo

1. `researcher` trae el HTML vivo de la URL (WebFetch/curl) y propone selectores estables.
2. `scraper-dev` escribe `scrape_<portal>() -> list[Empleo]` siguiendo el contrato: try/except que no tumba la corrida, `timeout` en el request, filtrado con `es_relevante()`, normalización a `Empleo`.
3. Se registra en `run()` (`todos += scrape_<portal>()`) y en esta tabla.
4. `testing` corre un dry-run (`/probar`) y confirma que devuelve algo razonable.

## Cómo diagnosticar un portal roto

Ver skill `anti-fragile-scrapers` y agente `scraper-doctor`. Regla base: **0 resultados ≠ "no hay empleos"** — casi siempre es un selector muerto o anti-bot. Confirmá contra el HTML vivo antes de tocar código.
