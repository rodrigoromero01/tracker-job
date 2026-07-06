---
name: git-simple
description: Flujo Git simple para este repo personal (NO gitflow) — rama actual o rama corta descriptiva, commit/push SOLO a pedido, mensajes claros en español, PR con gh si se pide. Cargá para cualquier operación git.
---
# Git — flujo simple

`tracker-job` es un repo personal chico: **flujo simple, no gitflow.** Nada de ramas largas por versión,
`develop`, `release/*` ni `hotfix/*` (eso es del enjambre Odoo y acá NO aplica).

Fuente de verdad: sección "Git" de `.claude/AGENTS.md` (repo personal, flujo simple, commit/push solo a
pedido) y el repo declarado en `.claude/workspace.md`. Las operaciones git las ejecuta **@git-flow**.

## Regla nº1: commit/push SOLO a pedido del usuario

Nunca commitees ni pushees por tu cuenta, ni "para no perder el trabajo". Escribís/editás los archivos y
listo; el commit lo dispara el usuario explícitamente. Al cerrar una tarea, reportá el **handoff git**:
en qué rama quedaron los cambios y que podés commitear/pushear si lo pide.

## Dónde trabajar: rama actual o rama corta descriptiva

- Por defecto, trabajá sobre la **rama actual**.
- Si el usuario quiere aislar un cambio, una **rama corta descriptiva** (y de vida corta):
  ```bash
  git checkout -b feature/scraper-linkedin
  git checkout -b fix/computrabajo-selector
  ```
  Se mergea a la principal y se borra. No se mantienen vivas en paralelo.

## Mensajes de commit: claros y en español

Formato simple, imperativo, en español (coherente con el idioma del proyecto). Prefijo tipo
`feat/fix/docs/chore` opcional pero útil:

```bash
git commit -m "feat: agregar scraper de LinkedIn Jobs"
git commit -m "fix: actualizar selector de Computrabajo (article.box_offer cambió)"
git commit -m "docs: actualizar portales.md con fecha de verificación de PyAr"
```

Un commit = un cambio coherente. Si tocaste el scraper y el `portales.md`, van juntos (son el mismo
cambio). No mezcles cosas no relacionadas en un commit.

## Chequeo antes de commitear (cuando el usuario lo pide)

```bash
git status                    # qué cambió
git diff                      # revisar el contenido antes de stagear
git add scraper.py references/portales.md   # explícito; NO 'git add -A' a ciegas
git commit -m "fix: ..."
```

- **Nunca** stagees `.env` ni `empleos.db` — están en `.gitignore` y contienen secretos / estado de
  runtime (skill `secrets-hygiene`). Si aparecen en `git status`, algo está mal con el `.gitignore`.
- Revisá el `diff` antes de commitear para no colar un secreto o un archivo de prueba.

## Push

```bash
git push                                  # rama ya trackeada
git push -u origin feature/scraper-linkedin   # primera vez de una rama nueva
```

## Abrir un PR con `gh` (si se pide)

Para un repo personal muchas veces alcanza con pushear a la rama principal. Si el usuario quiere un PR:

```bash
gh pr create --title "Agregar scraper de LinkedIn Jobs" \
             --body "Nuevo scrape_linkedin() con try/except, timeout y filtro es_relevante. Registrado en run() y portales.md."
```

## El origin: repo clonado de Rodrigo Romero

El `origin` es `https://github.com/rodrigoromero01/tracker-job.git` — el repo **original de Rodrigo
Romero**, clonado. Implicancias:
- Un `git push` a `origin` va contra el repo de Rodrigo (probablemente no tenés permiso, o no querés
  pushear ahí).
- Si Leandro va a seguir el proyecto como propio, conviene **crear su propio fork/repo** y apuntar el
  origin ahí (o agregar el suyo como remoto):
  ```bash
  # opción: renombrar el original y poner el tuyo como origin
  git remote rename origin upstream
  git remote add origin https://github.com/<usuario-leandro>/tracker-job.git
  git push -u origin main
  ```
- Esto es una **decisión del usuario**: no cambies remotes por tu cuenta. Mencionalo si el flujo git lo
  hace relevante.

## Do / Don't

- ✅ Trabajar sobre la rama actual o una rama corta descriptiva.
- ✅ Commit/push solo cuando el usuario lo pide; mensajes claros en español.
- ✅ `git add` explícito de los archivos del cambio; revisar `diff` antes.
- ❌ Gitflow: `develop`, `release/*`, `hotfix/*`, ramas largas por versión.
- ❌ Commitear/pushear por iniciativa propia.
- ❌ Stagear `.env` / `empleos.db`, o pushear al repo de Rodrigo sin que el usuario lo decida.
