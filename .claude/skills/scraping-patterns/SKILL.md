---
name: scraping-patterns
description: Cómo hacer fetch robusto con requests/BeautifulSoup/feedparser (timeout, User-Agent, status codes, encoding, selectores CSS, RSS, links absolutos, etiqueta). Cargá antes de escribir o tocar un scraper.
---
# Scraping — requests + BeautifulSoup + feedparser

Fuentes de verdad (no las re-declaro, las remito): contrato de scraper y NO-negociables en
`.claude/AGENTS.md`; estado por portal y selectores vigentes en `.claude/references/portales.md`;
trampas (403 sin UA, timeout, 0≠"no hay") en `.claude/references/gotchas.md`. El código real de
referencia es `scraper.py` (`scrape_pyar`, `scrape_computrabajo`, …). Esta skill es el "cómo".

## Reglas de oro (NO-negociables — AGENTS.md §NO-negociables)

- **`timeout=` en TODO request.** Sin él, un server que no responde cuelga el `BlockingScheduler`
  entero. El hook `validate_py.sh` te avisa. 10s es el valor que ya usa el proyecto.
- **`try/except Exception as e` por scraper**, que loguea y devuelve lo que haya. Nunca `except:`
  pelado (ver skill `anti-fragile-scrapers`).
- **`User-Agent` de navegador** en HTML (no en RSS). El default `python-requests/x.y` cobra 403 en
  muchos sitios (gotcha verificado).

## Fetch HTML robusto (patrón base)

```python
import requests
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
    ),
    "Accept-Language": "es-AR,es;q=0.9",
}

def _get_soup(url: str) -> BeautifulSoup | None:
    """Fetch HTML con timeout y UA de navegador. Devuelve None si el fetch falla."""
    resp = requests.get(url, headers=HEADERS, timeout=10)
    resp.raise_for_status()          # 4xx/5xx -> excepción (la atrapa el scraper)
    resp.encoding = resp.apparent_encoding  # evita mojibake si el server miente el charset
    return BeautifulSoup(resp.text, "html.parser")
```

Notas:
- `raise_for_status()` convierte 403/404/429/5xx en excepción, así el `try/except` del scraper la
  loguea en vez de parsear una página de error como si fuera resultado (y devolver 0 en silencio).
- **Encoding**: los portales AR a veces declaran mal el charset → acentos rotos. `apparent_encoding`
  (chardet) lo corrige. Si ya viene bien, no molesta.
- `"html.parser"` es stdlib (no sumes `lxml` salvo que haga falta de verdad — ver `minimal-footprint`).

## Parseo con selectores CSS

Usá `select` (lista) y `select_one` (uno o `None`). Nunca asumas que un tag existe.

```python
for article in soup.select("article.box_offer")[:10]:      # tope: no barras el sitio entero
    titulo_tag = article.select_one("h2 a, .title a")      # coma = fallback (ver anti-fragile)
    if not titulo_tag:
        continue
    titulo = titulo_tag.text.strip()
    empresa_tag = article.select_one(".fWeight500, .company")
    empresa = empresa_tag.text.strip() if empresa_tag else "No especificado"
```

## Enlaces relativos → absolutos

Los `href` suelen venir relativos (`/trabajo/123`). Prefijá el dominio o usá `urljoin`:

```python
link = titulo_tag.get("href", "")
if link and not link.startswith("http"):
    link = "https://ar.computrabajo.com" + link
# alternativa stdlib robusta:
# from urllib.parse import urljoin;  link = urljoin(base_url, link)
```

## RSS con feedparser (preferilo cuando exista)

Un feed RSS es un contrato estable pensado para consumo automático → mucho menos frágil que scrapear
HTML. Es el caso de PyAr. `feedparser` no lanza excepción por HTTP: revisá `feed.bozo`.

```python
import feedparser

feed = feedparser.parse("https://www.python.org.ar/trabajo/rss/")
if feed.bozo:                                  # feed mal formado o error de red
    print(f"    Feed con problemas: {feed.get('bozo_exception')}")
for entry in feed.entries:
    titulo = entry.get("title", "")            # .get siempre: los campos pueden faltar
    empresa = entry.get("author", "No especificado")
    url = entry.get("link", "")
    fecha = entry.get("published", "")
```

## Etiqueta (buenas prácticas de scraping)

- **No martilles.** Topeá resultados (`[:10]`, `[:20]`) y, si iterás varias queries/páginas, no
  dispares decenas de requests en un loop apretado.
- **Respetá `robots.txt`** y los rate-limits. Si un sitio te da 429, no reintentes en caliente:
  documentá el límite en `references/portales.md`.
- **Preferí RSS/API a HTML** cuando exista (más estable, menos carga para el sitio).
- **Un solo `User-Agent` de navegador real**, coherente. No rotes UAs para evadir anti-bot: si el
  sitio te bloquea a propósito, es decisión del usuario cambiar de enfoque (ver `anti-fragile-scrapers`).

## Do / Don't

- ✅ `requests.get(url, headers=HEADERS, timeout=10)` — siempre timeout.
- ✅ `select_one(...)` + chequeo `if not tag` antes de `.text`.
- ✅ `.get("campo", default)` en entries de feedparser.
- ❌ `requests.get(url)` sin `timeout` (cuelga el worker — gotcha).
- ❌ `tag.text` sin verificar que `tag` no sea `None` (`AttributeError` tumba el scraper).
- ❌ Scrapear el HTML de un sitio que ofrece RSS/API.
