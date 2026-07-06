---
name: data-dedup-sqlite
description: Dedup con sqlite3 de la stdlib (schema, uid md5, INSERT OR IGNORE, patrón es_nuevo/guardar, lifecycle) y el gotcha del filesystem efímero de Railway. Cargá al tocar el modelo, el uid o el schema.
---
# Deduplicación con SQLite (stdlib `sqlite3`)

La dedup evita mandar dos veces la misma oferta. Se hace con `sqlite3` de la stdlib (no sumes un ORM —
ver `minimal-footprint`). El código real es `init_db`, `es_nuevo`, `guardar` y `Empleo.uid()` en
`scraper.py`.

Fuentes de verdad: contrato del modelo de datos y de la dedup (`uid` = md5 de `url+titulo+empresa`) en
`.claude/AGENTS.md`; gotcha del **filesystem efímero de Railway** en `.claude/references/gotchas.md`.
Cambios al modelo/uid/schema los ejecuta **@data-model**. Esta skill es el "cómo".

## Schema (idempotente)

`CREATE TABLE IF NOT EXISTS` para que arrancar sea seguro corra o no exista la base:

```python
def init_db():
    con = sqlite3.connect(DB_PATH)
    con.execute("""
        CREATE TABLE IF NOT EXISTS empleos (
            uid       TEXT PRIMARY KEY,   -- clave de dedup (md5)
            titulo    TEXT,
            empresa   TEXT,
            ubicacion TEXT,
            url       TEXT,
            fuente    TEXT,
            fecha     TEXT,
            remoto    INTEGER,            -- SQLite no tiene bool: 0/1
            visto     INTEGER DEFAULT 0,
            creado    TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    con.commit()
    return con
```

- `uid TEXT PRIMARY KEY` → índice + unicidad gratis: `INSERT OR IGNORE` no duplica.
- SQLite **no tiene tipo bool**: `remoto` se guarda como `int(empleo.remoto)` (0/1).

## La clave de dedup: `uid`

```python
def uid(self) -> str:
    raw = f"{self.url}{self.titulo}{self.empresa}"
    return hashlib.md5(raw.encode()).hexdigest()
```

**Gotcha importante (AGENTS.md):** si cambiás qué compone el `uid`, todos los hashes históricos dejan
de coincidir → una corrida entera se ve como "todo nuevo" → email gigante. Si tenés que cambiarlo,
avisale al usuario del batch único de re-notificación. No lo cambies "por prolijidad".

## Patrón es_nuevo / guardar

```python
def es_nuevo(con, empleo: Empleo) -> bool:
    row = con.execute("SELECT uid FROM empleos WHERE uid = ?", (empleo.uid(),)).fetchone()
    return row is None

def guardar(con, empleo: Empleo):
    con.execute("""
        INSERT OR IGNORE INTO empleos
        (uid, titulo, empresa, ubicacion, url, fuente, fecha, remoto)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (empleo.uid(), empleo.titulo, empleo.empresa, empleo.ubicacion,
          empleo.url, empleo.fuente, empleo.fecha, int(empleo.remoto)))
    con.commit()
```

- **Siempre parámetros `?`**, nunca f-strings en el SQL (inyección / comillas rotas en títulos).
- `INSERT OR IGNORE` + PK hace la dedup a nivel base aunque `es_nuevo` tuviera una carrera: el chequeo
  previo es solo para saber si mandarlo en el email.
- Uso en `run()`: `if es_nuevo(con, e): guardar(con, e); nuevos.append(e)`.

## Lifecycle de la conexión

- Una conexión por corrida: `con = init_db()` al empezar `run()`, `con.close()` al final.
- `sqlite3` no es thread-safe entre hilos por defecto; acá corre en un solo hilo (el job del
  scheduler), así que alcanza. No compartas la `con` entre threads.
- `commit()` después de escribir. En este proyecto (volumen bajo, escrituras esporádicas) commitear
  por `guardar` está bien; no optimices con transacciones batch salvo que el volumen lo pida.

## 🔴 Gotcha: Railway borra la `.db` en cada deploy

El filesystem de Railway es **efímero**: cada build/redeploy arranca de cero → `empleos.db` se pierde →
la dedup "se olvida" → llegan de nuevo empleos ya vistos (gotcha verificado en `gotchas.md`).

Opciones de persistencia:
- **Railway Volume** montado: apuntá `DB_PATH` a la ruta del volumen (`os.getenv("DB_PATH", "empleos.db")`
  ya lo permite sin tocar código). Es lo más simple. Ver skill `railway-deploy`.
- **Postgres de Railway** u otro store persistente: más robusto, pero es cambiar de motor → decisión
  del usuario, no la tomes sola (sale del minimal-footprint del proyecto actual).
- **Mientras tanto**: asumir que tras un deploy puede repetirse un batch. No es un bug del scraper.

## Evolucionar el schema sin romper

`CREATE TABLE IF NOT EXISTS` **no** agrega columnas a una tabla que ya existe. Para sumar una columna
sin perder datos, `ALTER TABLE` idempotente:

```python
def _asegurar_columna(con, tabla, columna, tipo_def):
    cols = [r[1] for r in con.execute(f"PRAGMA table_info({tabla})")]
    if columna not in cols:
        con.execute(f"ALTER TABLE {tabla} ADD COLUMN {columna} {tipo_def}")
        con.commit()

# uso:
_asegurar_columna(con, "empleos", "salario", "TEXT")
```

- Agregar columna con `DEFAULT` → las filas viejas quedan con el default. No rompe.
- Nunca dropees/recrees la tabla para "migrar": perderías la dedup histórica.

## Do / Don't

- ✅ `sqlite3` stdlib, parámetros `?`, `INSERT OR IGNORE`, `CREATE TABLE IF NOT EXISTS`.
- ✅ `DB_PATH` por `os.getenv` (permite apuntar a un Volume sin tocar código).
- ✅ `ALTER TABLE ... ADD COLUMN` idempotente para evolucionar el schema.
- ❌ f-strings en el SQL con datos del scraper (inyección).
- ❌ Cambiar el `uid` sin avisar del batch de re-notificación.
- ❌ Sumar un ORM (SQLAlchemy) para esto: es sobre-ingeniería (minimal-footprint).
- ❌ Editar `empleos.db` a mano: el hook `protect.sh` lo bloquea; se regenera sola.
