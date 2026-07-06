---
name: minimal-footprint
description: Disciplina anti-over-engineering para tracker-job — escalera YAGNI → stdlib → dep ya presente → dep nueva justificada, qué NO-negociables nunca se recortan, y cómo marcar un atajo deliberado. Cargá como lente en cambios de lógica.
---
# Minimal footprint — el menor cambio que cumpla

Este proyecto es chico y personal: un scraper + dedup + email + scheduler. La disciplina es **hacer lo
mínimo que resuelva el problema real, sin recortar robustez**. Sesgá siempre hacia reusar lo que ya
está y el diff más chico.

Fuente de verdad: sección "Dependencias" y los NO-negociables de `.claude/AGENTS.md`. Esta skill es
cómo aplicar ese criterio. (Nada de esto tiene que ver con Odoo; es específico de tracker-job.)

## La escalera de decisión (parar en el primer escalón que resuelva)

1. **¿Necesita existir? (YAGNI).** ¿Lo pidió el usuario o es una necesidad real hoy? Si es "por si
   algún día...", no lo hagas. No agregues un portal, una columna, un canal de notificación o una
   opción de config "para el futuro".
2. **¿Lo resuelve la stdlib?** `sqlite3`, `hashlib`, `smtplib`, `email.mime`, `urllib.parse`, `datetime`,
   `os`, `logging` ya cubren casi todo. Preferí la stdlib antes que cualquier dep.
3. **¿Lo resuelve una dep YA presente?** Están en `requirements.txt`: `requests`, `beautifulsoup4`,
   `feedparser`, `apscheduler`, `python-dotenv`. Si una de estas lo hace, usala — no sumes otra.
4. **Recién ahí, una dep nueva — y justificada.** Solo si 1-3 no alcanzan. Justificá explícitamente por
   qué la stdlib y las deps presentes no sirven, y sumala a `requirements.txt`. Si no la podés
   justificar en una frase, no entra.

Ejemplos de cómo se aplica:
- Parseo HTML → `beautifulsoup4` (presente). **No** sumes `lxml`/`scrapy`.
- Dedup → `sqlite3` + `hashlib` (stdlib). **No** sumes SQLAlchemy ni Redis para esto.
- Cliente HTTP → `requests` (presente). **No** sumes `httpx`/`aiohttp`.
- URLs relativas → `urllib.parse.urljoin` (stdlib). **No** sumes una lib de URLs.
- Scheduling → `apscheduler` (presente) o el cron del sistema. **No** sumes Celery para un job diario.
- Portal JS-rendered → **FRENÁ y consultá** (Selenium/Playwright es un salto grande de footprint y
  decisión del usuario), no lo metas de una (ver skill `anti-fragile-scrapers`).

## Los NO-negociables NUNCA se recortan (ni "para simplificar")

Minimal footprint significa menos código, **no menos robustez**. Estos son piso, no opcionales
(AGENTS.md): 
- `timeout` en cada request.
- `try/except Exception as e` por scraper (degrada sin tumbar la corrida).
- Secretos por `os.getenv`, nunca literales.
- Sin `except:` pelado.
- Documentación sincronizada (`portales.md` / `README.md`) cuando cambia comportamiento visible.

"Menos es más" jamás justifica sacar un `timeout` o tragarse un error. Si dudás entre agregar
complejidad o recortar un NO-negociable: no hacés ninguna de las dos — buscás el camino simple **con**
la robustez puesta.

## Preferí el menor cambio

- Reusá funciones existentes (`es_relevante`, `Empleo`, `_get_soup`, `guardar`) antes de escribir
  paralelas.
- Un scraper nuevo sigue el molde del contrato de AGENTS.md; no inventes una arquitectura de plugins
  para 5 portales.
- Config nueva → una env var con `os.getenv(..., default)` (como `RUN_HOUR`, `DB_PATH`), no un archivo
  de settings ni una clase Config.
- Cambio de filtro → tocá `KEYWORDS`/`EXCLUDE_KEYWORDS`/`es_relevante` en un solo lugar, no repartas la
  lógica.

## Cómo marcar un atajo deliberado

A veces el atajo es lo correcto (proyecto chico). Si tomás uno que alguien podría cuestionar,
**dejalo explícito** para que no se lea como olvido:

```python
# ATAJO DELIBERADO: dedup en SQLite local. En Railway sin Volume la .db se borra en
# cada deploy (ver gotchas.md). Aceptable mientras deployemos poco; si molesta -> Volume.
```

Así el reviewer (@reviewer usa esta skill como lente) sabe que fue una decisión, no un descuido. Un
fallback hardcodeado (como en `scrape_bairesdev`) también se marca así y se documenta en `portales.md`.

## Do / Don't

- ✅ Parar en el primer escalón de la escalera que resuelva el problema.
- ✅ Reusar stdlib y deps presentes; menor diff que cumpla.
- ✅ Marcar los atajos deliberados con un comentario que explique el porqué.
- ❌ Sumar una dep que la stdlib o `requests/bs4/feedparser/apscheduler/dotenv` ya cubren.
- ❌ Construir para un futuro hipotético (YAGNI).
- ❌ Recortar un NO-negociable en nombre de "simplificar".
