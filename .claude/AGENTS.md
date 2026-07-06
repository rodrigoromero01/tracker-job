# Convenciones — tracker-job

> Fuente única de convenciones del proyecto. La importa `CLAUDE.md` (con `@AGENTS.md`) y la leen
> todos los subagentes antes de escribir. No se duplica en otros archivos para no driftear.
>
> **Contexto del proyecto**: agente Python que rastrea portales de empleo (Python Junior),
> deduplica en SQLite y manda un resumen por email. Corre diario vía scheduler (APScheduler),
> pensado para la nube (Railway) o local. Archivos núcleo: `scraper.py`, `scheduler.py`.

## Idioma y estilo

- **Comentarios y salida al usuario en español** (incluye `print()` de progreso y mensajes de log).
- **Identificadores de dominio en español**, como ya está el código: `Empleo`, `titulo`, `empresa`,
  `es_relevante()`, `scrape_pyar()`, `guardar()`. No los renombres a inglés "por prolijidad".
- Llamadas a librerías quedan como son (`requests.get`, `BeautifulSoup`, `feedparser.parse`).
- Estilo: `@dataclass` para modelos, funciones cortas con una responsabilidad, secciones separadas
  por comentarios de banner (`# ─── Sección ───`). Seguí el estilo que ya existe en `scraper.py`.
- Formato: 4 espacios, sin tabs. No hace falta type-checker estricto, pero poné type hints donde
  ayuden (el código ya usa `-> list[Empleo]`, `titulo: str`).

## NO-negociables (nunca se recortan, ni en un fix chico)

1. **Secretos solo por variable de entorno.** `os.getenv("EMAIL_PASS", "")`. **Jamás** un secreto
   como string literal en el código (queda en el historial de git). El hook lo **bloquea**. Ver skill
   `secrets-hygiene`.
2. **Todo scraper degrada sin tumbar la corrida.** Cada `scrape_*()` va envuelto en `try/except`
   que loguea el error y devuelve lo que haya (lista vacía en el peor caso). Un portal caído **no**
   puede impedir que se procesen los demás ni que se mande el email. Ver skill `anti-fragile-scrapers`.
3. **Todo request de red lleva `timeout`.** Sin `timeout`, un server que no responde cuelga el worker
   entero (el scheduler es bloqueante). El hook lo avisa. Ver skill `scraping-patterns`.
4. **Sin `except:` pelado.** Capturá `Exception as e` y logueá `e`. Nunca te tragues el error mudo.
5. **`.env` y `*.db` no se editan desde el enjambre.** `.env` tiene secretos reales; `empleos.db` se
   regenera sola. El hook `protect.sh` los bloquea. El contrato de variables se cambia en `.env.example`.
6. **Documentación sincronizada.** Si cambiás scrapers → actualizá `references/portales.md`. Si cambiás
   comportamiento visible (portales, filtros, formato de email, variables, deploy) → actualizá `README.md`.

## Contrato del modelo de datos

- Toda oferta se normaliza a un `Empleo` (dataclass) con: `titulo, empresa, ubicacion, url, fuente,
  fecha, remoto`. Un scraper nuevo **debe** devolver `list[Empleo]`, no dicts sueltos.
- La **deduplicación** es por `Empleo.uid()` (md5 de `url+titulo+empresa`). Si cambiás qué compone el
  `uid`, tené en cuenta que invalida la dedup histórica (todo se verá como "nuevo"). Ver skill
  `data-dedup-sqlite`.
- El **filtro de relevancia** (`es_relevante()`) usa `KEYWORDS` (incluir) y `EXCLUDE_KEYWORDS`
  (excluir seniority). Ajustes de criterio se hacen ahí, en un solo lugar.

## Contrato de un scraper

Un `scrape_<portal>() -> list[Empleo]` debe:
1. Imprimir su progreso (`print("  → <Portal>...")`) — estilo actual.
2. Hacer el fetch con `timeout=` y (si es HTML) `User-Agent` de navegador.
3. Envolver todo en `try/except Exception as e` que loguea y no propaga.
4. Filtrar con `es_relevante(titulo)` antes de agregar.
5. Normalizar cada resultado a `Empleo(...)`.
6. Cerrar con `print(f"    {len(empleos)} encontrados")` y `return empleos`.
7. Registrarse en `run()` (`todos += scrape_<portal>()`) y en `references/portales.md`.

## Dependencias (minimal-footprint)

- Antes de sumar una dependencia a `requirements.txt`, verificá que la stdlib o una dep ya presente
  (`requests`, `beautifulsoup4`, `feedparser`, `apscheduler`, `python-dotenv`) no lo resuelva.
- Una dep nueva se justifica explícitamente o no entra. Ver skill `minimal-footprint`.

## Testing

- **No escribas tests salvo que se pidan** (igual que la validación real es correr el scraper).
  La verificación por defecto es el **dry-run** (`/probar`): correr `run()` sin mandar el email y
  mirar la salida. Ver agente `testing`.

## Git

- Repo personal, flujo **simple** (no gitflow): trabajar sobre la rama actual o una rama corta
  descriptiva; **commit/push solo a pedido del usuario**. Ver skill `git-simple` y agente `git-flow`.

## Breaking / trampas del entorno

- No se listan acá (evita drift). Viven en `references/gotchas.md` (Railway efímero, Gmail App
  Password, CSS inline en email, anti-bot, timeouts) y `references/portales.md` (estado por portal).
