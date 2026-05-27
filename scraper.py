#!/usr/bin/env python3
"""
Job Tracker — Rastreador de empleos Python Junior
Corre diariamente y envía resumen por email
"""

import os
import requests
import sqlite3
import smtplib
import hashlib
import feedparser
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from bs4 import BeautifulSoup
from dataclasses import dataclass
from dotenv import load_dotenv

load_dotenv()  # carga .env en local; en Railway usa las vars del dashboard


# ─── Configuración ─────────────────────────────────────────────────────────────

KEYWORDS = [
    "python junior", "python jr", "desarrollador python",
    "developer python", "trainee python", "backend junior",
    "python backend", "fastapi junior", "analista datos junior",
    "data analyst junior", "power bi junior"
]

EXCLUDE_KEYWORDS = ["senior", "sr.", "ssr", "semi senior", "lead", "architect"]

EMAIL_FROM = os.getenv("EMAIL_FROM", "rodrigoromero01@gmail.com")
EMAIL_TO   = os.getenv("EMAIL_TO",   "rodrigoromero01@gmail.com")
EMAIL_PASS = os.getenv("pjuj djjm otss kxhp", "")
DB_PATH    = os.getenv("DB_PATH", "empleos.db")


# ─── Modelo de datos ─────────────────────────────────────────────────────────

@dataclass
class Empleo:
    titulo:    str
    empresa:   str
    ubicacion: str
    url:       str
    fuente:    str
    fecha:     str
    remoto:    bool = False

    def uid(self) -> str:
        """Genera ID único para deduplicar"""
        raw = f"{self.url}{self.titulo}{self.empresa}"
        return hashlib.md5(raw.encode()).hexdigest()


# ─── Base de datos ────────────────────────────────────────────────────────────

def init_db():
    con = sqlite3.connect(DB_PATH)
    con.execute("""
        CREATE TABLE IF NOT EXISTS empleos (
            uid       TEXT PRIMARY KEY,
            titulo    TEXT,
            empresa   TEXT,
            ubicacion TEXT,
            url       TEXT,
            fuente    TEXT,
            fecha     TEXT,
            remoto    INTEGER,
            visto     INTEGER DEFAULT 0,
            creado    TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    con.commit()
    return con


def es_nuevo(con, empleo: Empleo) -> bool:
    """True si el empleo no estaba en la DB"""
    row = con.execute("SELECT uid FROM empleos WHERE uid = ?", (empleo.uid(),)).fetchone()
    return row is None


def guardar(con, empleo: Empleo):
    con.execute("""
        INSERT OR IGNORE INTO empleos
        (uid, titulo, empresa, ubicacion, url, fuente, fecha, remoto)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        empleo.uid(), empleo.titulo, empleo.empresa,
        empleo.ubicacion, empleo.url, empleo.fuente,
        empleo.fecha, int(empleo.remoto)
    ))
    con.commit()


# ─── Scrapers ─────────────────────────────────────────────────────────────────

def es_relevante(titulo: str) -> bool:
    """Filtra por keywords y excluye seniority"""
    titulo_lower = titulo.lower()
    tiene_keyword = any(k in titulo_lower for k in KEYWORDS)
    es_senior = any(e in titulo_lower for e in EXCLUDE_KEYWORDS)
    return tiene_keyword and not es_senior


def scrape_pyar() -> list[Empleo]:
    """Scrapea PyAr — RSS oficial"""
    print("  → PyAr (RSS)...")
    empleos = []
    try:
        feed = feedparser.parse("https://www.python.org.ar/trabajo/rss/")
        for entry in feed.entries:
            titulo = entry.get("title", "")
            if not es_relevante(titulo):
                continue
            empleos.append(Empleo(
                titulo    = titulo,
                empresa   = entry.get("author", "No especificado"),
                ubicacion = "Argentina",
                url       = entry.get("link", ""),
                fuente    = "PyAr",
                fecha     = entry.get("published", datetime.now().isoformat()),
                remoto    = "remoto" in titulo.lower() or "remote" in titulo.lower()
            ))
    except Exception as e:
        print(f"    Error PyAr: {e}")
    print(f"    {len(empleos)} encontrados")
    return empleos


def scrape_computrabajo() -> list[Empleo]:
    """Scrapea Computrabajo Argentina"""
    print("  → Computrabajo...")
    empleos = []
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

    queries = [
        "desarrollador-python-junior",
        "python-junior",
        "analista-datos-junior",
    ]

    for query in queries:
        try:
            url = f"https://ar.computrabajo.com/trabajo-de-{query}"
            resp = requests.get(url, headers=headers, timeout=10)
            soup = BeautifulSoup(resp.text, "html.parser")

            for article in soup.select("article.box_offer")[:10]:
                titulo_tag = article.select_one("h2 a, .title a")
                if not titulo_tag:
                    continue
                titulo = titulo_tag.text.strip()
                if not es_relevante(titulo):
                    continue

                empresa_tag = article.select_one(".fWeight500, .company")
                empresa = empresa_tag.text.strip() if empresa_tag else "No especificado"

                ciudad_tag = article.select_one(".fs13, .city")
                ciudad = ciudad_tag.text.strip() if ciudad_tag else "Argentina"

                link = titulo_tag.get("href", "")
                if link and not link.startswith("http"):
                    link = "https://ar.computrabajo.com" + link

                empleos.append(Empleo(
                    titulo    = titulo,
                    empresa   = empresa,
                    ubicacion = ciudad,
                    url       = link,
                    fuente    = "Computrabajo",
                    fecha     = datetime.now().strftime("%Y-%m-%d"),
                    remoto    = "remoto" in ciudad.lower() or "remoto" in titulo.lower()
                ))

        except Exception as e:
            print(f"    Error Computrabajo ({query}): {e}")

    print(f"    {len(empleos)} encontrados")
    return empleos


def scrape_bairesdev() -> list[Empleo]:
    """Scrapea BairesDev — portal de aplicaciones"""
    print("  → BairesDev...")
    empleos = []
    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        # BairesDev tiene una página de jobs pública
        url = "https://applicants.bairesdev.com/jobs"
        resp = requests.get(url, headers=headers, timeout=10)
        soup = BeautifulSoup(resp.text, "html.parser")

        for job in soup.select(".job-item, .job-card, li[class*='job']")[:20]:
            titulo_tag = job.select_one("h2, h3, .job-title, a[href*='/job/']")
            if not titulo_tag:
                continue
            titulo = titulo_tag.text.strip()
            if not es_relevante(titulo):
                continue

            link_tag = job.select_one("a")
            link = link_tag.get("href", "") if link_tag else ""
            if link and not link.startswith("http"):
                link = "https://applicants.bairesdev.com" + link

            empleos.append(Empleo(
                titulo    = titulo,
                empresa   = "BairesDev",
                ubicacion = "Remoto",
                url       = link or "https://applicants.bairesdev.com",
                fuente    = "BairesDev",
                fecha     = datetime.now().strftime("%Y-%m-%d"),
                remoto    = True
            ))

    except Exception as e:
        print(f"    Error BairesDev: {e}")

    # Fallback: agregar posición conocida si no encontró nada
    if not empleos:
        empleos.append(Empleo(
            titulo    = "Junior Python Developer - Remote Work",
            empresa   = "BairesDev",
            ubicacion = "Remoto",
            url       = "https://applicants.bairesdev.com/job/71/279633/apply",
            fuente    = "BairesDev",
            fecha     = datetime.now().strftime("%Y-%m-%d"),
            remoto    = True
        ))

    print(f"    {len(empleos)} encontrados")
    return empleos


def scrape_wellfound() -> list[Empleo]:
    """Scrapea Wellfound (AngelList) — startups Argentina"""
    print("  → Wellfound...")
    empleos = []
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json"
    }
    try:
        # Wellfound tiene una API pública parcial
        url = "https://wellfound.com/role/l/python-developer/argentina"
        resp = requests.get(url, headers=headers, timeout=10)
        soup = BeautifulSoup(resp.text, "html.parser")

        for job in soup.select("[class*='job'] h2, [class*='listing'] h2")[:10]:
            titulo = job.text.strip()
            if not es_relevante(titulo):
                continue

            parent = job.find_parent("a")
            link = parent.get("href", "") if parent else ""
            if link and not link.startswith("http"):
                link = "https://wellfound.com" + link

            empleos.append(Empleo(
                titulo    = titulo,
                empresa   = "Startup (Wellfound)",
                ubicacion = "Argentina / Remoto",
                url       = link or "https://wellfound.com/location/argentina",
                fuente    = "Wellfound",
                fecha     = datetime.now().strftime("%Y-%m-%d"),
                remoto    = True
            ))

    except Exception as e:
        print(f"    Error Wellfound: {e}")

    print(f"    {len(empleos)} encontrados")
    return empleos


# ─── Email ────────────────────────────────────────────────────────────────────

def armar_email_html(nuevos: list[Empleo]) -> str:
    fecha = datetime.now().strftime("%d/%m/%Y")
    remotos = [e for e in nuevos if e.remoto]
    presenciales = [e for e in nuevos if not e.remoto]

    def tarjetas(lista):
        if not lista:
            return "<p style='color:#888'>Ninguno en esta categoría hoy.</p>"
        html = ""
        for e in lista:
            html += f"""
            <div style="border:1px solid #e0e0e0;border-radius:8px;padding:14px;margin-bottom:12px;background:#fff;">
                <div style="font-weight:600;font-size:15px;color:#1a1a1a">{e.titulo}</div>
                <div style="color:#555;font-size:13px;margin:4px 0">{e.empresa} · {e.ubicacion}</div>
                <div style="font-size:12px;color:#888;margin-bottom:8px">Fuente: {e.fuente} · {e.fecha}</div>
                <a href="{e.url}" style="background:#2E75B6;color:#fff;padding:6px 14px;border-radius:5px;text-decoration:none;font-size:13px">Ver oferta →</a>
            </div>"""
        return html

    return f"""
    <html><body style="font-family:Arial,sans-serif;max-width:620px;margin:auto;background:#f5f5f5;padding:20px">
    <div style="background:#1F4E78;color:#fff;padding:20px;border-radius:8px 8px 0 0">
        <h2 style="margin:0">🐍 Empleos Python Junior</h2>
        <p style="margin:4px 0;opacity:.8">Resumen del {fecha} · {len(nuevos)} nuevos encontrados</p>
    </div>
    <div style="background:#fff;padding:20px;border-radius:0 0 8px 8px">
        <h3 style="color:#2E75B6;border-bottom:1px solid #eee;padding-bottom:8px">
            🌐 Remotos ({len(remotos)})
        </h3>
        {tarjetas(remotos)}
        <h3 style="color:#2E75B6;border-bottom:1px solid #eee;padding-bottom:8px;margin-top:24px">
            📍 Presenciales / Híbridos ({len(presenciales)})
        </h3>
        {tarjetas(presenciales)}
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0">
        <p style="font-size:12px;color:#aaa;text-align:center">
            Job Tracker · Python · Rodrigo Romero · {fecha}
        </p>
    </div>
    </body></html>
    """


def enviar_email(nuevos: list[Empleo]):
    if not nuevos:
        print("  Sin nuevos empleos, no se envía email.")
        return

    print(f"  Enviando email con {len(nuevos)} empleos nuevos...")
    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"🐍 {len(nuevos)} empleos Python Junior — {datetime.now().strftime('%d/%m/%Y')}"
    msg["From"]    = EMAIL_FROM
    msg["To"]      = EMAIL_TO

    html = armar_email_html(nuevos)
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(EMAIL_FROM, EMAIL_PASS)
            server.sendmail(EMAIL_FROM, EMAIL_TO, msg.as_string())
        print("  Email enviado correctamente.")
    except Exception as e:
        print(f"  Error enviando email: {e}")
        print("  Verificá que usás una App Password de Google, no tu contraseña.")


# ─── Main ─────────────────────────────────────────────────────────────────────

def run():
    print(f"\n{'='*50}")
    print(f"Job Tracker — {datetime.now().strftime('%d/%m/%Y %H:%M')}")
    print(f"{'='*50}")

    con = init_db()

    print("\nRastreando portales...")
    todos = []
    todos += scrape_pyar()
    todos += scrape_computrabajo()
    todos += scrape_bairesdev()
    todos += scrape_wellfound()

    print(f"\nTotal encontrados: {len(todos)}")

    # Filtrar solo los nuevos
    nuevos = []
    for empleo in todos:
        if es_nuevo(con, empleo):
            guardar(con, empleo)
            nuevos.append(empleo)

    print(f"Nuevos (no vistos antes): {len(nuevos)}")

    # Ordenar: remotos primero
    nuevos.sort(key=lambda e: (not e.remoto, e.fuente))

    enviar_email(nuevos)

    print(f"\nDone. Total en DB: {con.execute('SELECT COUNT(*) FROM empleos').fetchone()[0]}")
    con.close()


if __name__ == "__main__":
    run()
