---
name: anti-fragile-scrapers
description: Cómo hacer scrapers que degradan sin tumbar la corrida y cómo diagnosticar por qué uno devuelve 0 (selector muerto vs anti-bot vs JS-rendered vs de verdad no hay). Cargá al escribir o arreglar un scraper roto.
---
# Scrapers anti-frágiles y diagnóstico

Los scrapers HTML son **frágiles por diseño**: dependen de selectores que el sitio cambia sin avisar.
La meta no es que nunca fallen, sino que **cuando fallen, no arrastren al resto ni frenen el email**.

Fuentes de verdad: contrato de scraper y NO-negociable "todo scraper degrada" en `.claude/AGENTS.md`;
estado y fragilidad por portal en `.claude/references/portales.md`; gotcha "0 ≠ no hay" en
`.claude/references/gotchas.md`. Para diagnóstico profundo va el agente **@scraper-doctor** (distingue
las 4 causas, read-only) apoyado por **@researcher** (trae el HTML vivo). Esta skill es cómo blindar y
cómo diagnosticar paso a paso.

## 1. Degradar sin tumbar la corrida

Cada `scrape_*()` es una **isla**: su `try/except` no deja escapar nada. Si un portal revienta,
`run()` sigue con los demás y el email igual sale.

```python
def scrape_ejemplo() -> list[Empleo]:
    print("  → Ejemplo...")
    empleos = []
    try:
        soup = _get_soup("https://ejemplo.com/jobs")   # ver skill scraping-patterns
        for card in soup.select(".job-item, .job-card, li[class*='job']")[:20]:
            titulo_tag = card.select_one("h2 a, h3 a, .title a")
            if not titulo_tag:
                continue                                # tarjeta sin título → salteo, no exploto
            titulo = titulo_tag.text.strip()
            if not es_relevante(titulo):
                continue
            empleos.append(Empleo(titulo=titulo, ...))
    except Exception as e:
        print(f"    Error Ejemplo: {e}")                # logueo y sigo
    print(f"    {len(empleos)} encontrados")
    return empleos
```

Reglas:
- **`try/except Exception as e`** que loguea con contexto (nombre del portal + `e`). Nunca `except:`
  pelado (se traga `KeyboardInterrupt`; el hook `validate_py.sh` lo marca).
- El error se atrapa **dentro** del scraper. `run()` nunca ve la excepción.
- Si iterás varias queries/páginas, poné el `try/except` **por query** (como `scrape_computrabajo`),
  así una query rota no te tira las otras.

## 2. Selectores defensivos (múltiples fallbacks)

Un selector con coma prueba varias formas del markup: si el sitio renombró la clase pero mantuvo la
etiqueta semántica, seguís trayendo datos.

```python
# de menos frágil (semántico) a más frágil (clase volátil)
titulo_tag = card.select_one("h2 a, h3 a, .job-title, a[href*='/job/']")
empresa_tag = card.select_one(".company, .fWeight500, [class*='company']")
```

- Preferí **etiquetas semánticas** (`h2`, `article`) y **atributos parciales** (`[class*='job']`,
  `a[href*='/job/']`) por sobre clases exactas con sufijos (`.box_offer_a3f`) que cambian.
- Siempre `if not tag: continue` antes de `.text`. Un `None.text` es `AttributeError` que tumba todo.

## 3. El gotcha central: 0 resultados ≠ "no hay empleos"

Un `scrape_X()` que imprime "0 encontrados" de forma consistente casi nunca significa que no hay
ofertas. Las causas reales (gotcha verificado):

| Causa | Señal típica | Cómo confirmar |
|-------|--------------|----------------|
| **Selector muerto** | El sitio responde 200 con HTML lleno, pero `select()` da `[]`. | Comparar selector documentado vs HTML vivo (@researcher). |
| **Anti-bot** | `403` / `406` / `429`, o HTML de "acceso denegado" / captcha. | `raise_for_status()` lo vuelve excepción; mirar `resp.status_code`. |
| **JS-rendered** | 200, pero el HTML crudo casi no tiene contenido: es un cascarón `<div id="root"></div>` + `<script>`. Los datos llegan por JS/API. | Ver "detección de JS-rendered" abajo. |
| **De verdad no hay** | HTML con markup de resultados presente, pero el filtro `es_relevante()` descarta todo. | Contar antes del filtro: si hay tarjetas pero 0 pasan, es el filtro, no el scraper. |

## 4. Detectar JS-rendered

Si el HTML que ve BeautifulSoup no tiene el contenido pero el navegador sí, es una SPA. Señales:

```python
resp = requests.get(url, headers=HEADERS, timeout=10)
html = resp.text
# cascarón vacío + mucho JS = casi seguro JS-rendered
if len(soup.get_text(strip=True)) < 500 and html.count("<script") > 5:
    print("    Sospecha JS-rendered: el DOM final lo arma el navegador, no viene en el HTML.")
# o buscar el contenedor típico de SPA:
if soup.select_one("#root, #__next, [data-reactroot]"):
    print("    Marco de SPA detectado (React/Next).")
```

**requests+bs4 no ejecuta JS.** Si un portal es JS-rendered, no hay selector que lo salve.
Casos así en el proyecto: Wellfound (fuerte JS + anti-bot), BairesDev (posible SPA) — ver `portales.md`.

## 5. Fallbacks (con cuidado)

Cuando un portal es inestable, un fallback evita un email vacío, pero **puede quedar obsoleto y mentir**.
`scrape_bairesdev()` inyecta 1 posición hardcodeada si no encontró nada. Está bien como red de
seguridad temporal, pero:
- Documentalo en `portales.md` como fallback (no como dato real vivo).
- Es señal de que el scraper está roto → hay que arreglarlo, no dejar el fallback para siempre.

## 6. Diagnóstico paso a paso (cuando un scraper devuelve 0)

1. **¿Responde?** Mirá `resp.status_code`. `403/429` → anti-bot. `5xx` → sitio caído (esperá y
   reintentá más tarde, no toques el selector).
2. **¿Trae HTML con contenido?** `len(soup.get_text(strip=True))`. Muy chico + muchos `<script>` →
   JS-rendered → **FRENÁ y consultá al usuario** (cambiar de enfoque es decisión suya).
3. **¿El selector matchea?** `len(soup.select("<tu-selector>"))`. Si es 0 pero el HTML tiene ofertas
   → selector muerto → confirmá el nuevo selector contra el HTML vivo (@researcher) y aplicalo.
4. **¿El filtro descarta todo?** Contá tarjetas antes de `es_relevante()`. Si hay tarjetas y 0 pasan,
   revisá `KEYWORDS`/`EXCLUDE_KEYWORDS` (skill `data-dedup-sqlite`/@data-model), no el scraper.
5. Actualizá `references/portales.md` con el selector nuevo y la **fecha de verificación**.

## Do / Don't

- ✅ Un `try/except` por scraper (y por query si hay loop).
- ✅ Selectores con fallbacks: `"h2 a, .title a"`.
- ✅ Tratar `0 resultados` como sospecha de bug, no como "no hay".
- ❌ Cambiar el selector a ciegas sin ver el HTML vivo.
- ❌ Meter un headless browser / Selenium para "arreglar" un JS-rendered sin consultar (decisión del
  usuario; rompe minimal-footprint).
- ❌ Dejar un fallback hardcodeado sin documentarlo en `portales.md`.
