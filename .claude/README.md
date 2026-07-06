# Enjambre `.claude/` — tracker-job

Este directorio es el **enjambre de Claude Code** de tracker-job: un orquestador + subagentes
especializados + skills + comandos que asisten el desarrollo del agente de scraping de empleos
(scrapers → dedup SQLite → email → scheduler, deploy Railway/local).

El orquestador vive en `CLAUDE.md` (importa `AGENTS.md`) y coordina todo; **los subagentes no se hablan
entre sí**. La arquitectura completa (roles, flujos, decisiones de diseño) está en **`ENJAMBRE.md`** —
este README es solo el arranque rápido.

## Arranque rápido

1. **Configurá tu entorno**: copiá la plantilla y ajustala a tu máquina.
   ```
   cp .claude/workspace.example.md .claude/workspace.md
   ```
   `workspace.md` es por-dev y está gitignored (ver `.claude/.gitignore`). Es la **única fuente de
   verdad del entorno** (Python, deploy target, timezone, DB, secretos): ningún agente/skill/hook
   hardcodea eso.
2. **Chequeá que todo está sano**: corré `/salud`.
3. **Orientate**: `/contexto` muestra deploy target, timezone, portales y su fragilidad, estado git.

## Comandos (`commands/`)

| Comando | Qué hace |
|---------|----------|
| `/scraper <portal\|url>` | Agrega un scraper nuevo (researcher → scraper-dev → testing). |
| `/fix-scraper <portal>` | Diagnostica y arregla un scraper roto (scraper-doctor → …). |
| `/inspeccionar <url>` | Trae el HTML vivo y propone selectores. Read-only. |
| `/probar` | Dry-run: empleos por portal, nuevos, roturas. **No manda email.** |
| `/deploy` | Checklist guiado de deploy a Railway (no ejecuta). |
| `/contexto` | Banner de orientación extendido. |
| `/salud` | Health check del entorno (OK/WARN por ítem). |

## Subagentes (`agents/`)

`researcher` · `scraper-doctor` · `scraper-dev` · `data-model` · `notifier` · `scaffold` · `testing` ·
`reviewer` · `git-flow`. Se invocan con la tool **Task** (`subagent_type = <nombre>`). Detalle de cada
uno y cuándo usarlos: `CLAUDE.md`.

## Skills (`skills/`)

`scraping-patterns` · `anti-fragile-scrapers` · `data-dedup-sqlite` · `email-html` ·
`scheduling-apscheduler` · `railway-deploy` · `secrets-hygiene` · `minimal-footprint` · `git-simple`.
Se cargan con la tool **Skill**; el orquestador las inyecta como Project Standards al agente de cada fase.

## Otras piezas

- `references/portales.md` — catálogo de portales (qué se scrapea, selectores, fragilidad, fechas).
- `references/gotchas.md` — trampas verificadas del entorno (Railway efímero, Gmail App Password, CSS
  inline, anti-bot, timeouts).
- `assets/email-template.html` — maqueta de referencia del email (el generador real es
  `armar_email_html()` en `scraper.py`).
- `hooks/`, `settings.json`, `statusline.sh` — automatización del entorno.

Convenciones del proyecto: `AGENTS.md`. Arquitectura completa: `ENJAMBRE.md`.
