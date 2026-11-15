"""Genera index.html: video vertical (1080x1920) de promoción de Alero, en español o inglés.
Uso: python3 gen.py es   |   python3 gen.py en
"""
import sys
LANG = sys.argv[1] if len(sys.argv) > 1 else "es"

T = {
  "es": dict(
    hook=["Tu notch", "no hace", "nada."], hook2="Todavía.",
    c2=("Pasa el cursor<br>y se abre.", "Lo que suena, de cualquier app."),
    c3=("Batería y volumen<br>de un vistazo.", "Sin abrir nada."),
    c4=("Tus archivos,<br>a la mano.", "Arrástralos al notch."),
    c5=("Mira cuánto<br>trabaja tu Mac.", "CPU, memoria y procesos."),
    song="Marea baja", song_sub="Ejemplo de canción · Safari",
    files=["Informe.pdf", "Captura.png", "Notas.txt"], menu="Finder", date="9:41",
    mem="Memoria", mem_val="9.6 de 16 GB", procs=["Navegador", "Editor de código"],
    chip="Gratis para Mac", out_tag="El notch de tu Mac,<br>convertido en panel.", out_btn="Descárgala gratis", lang="es"),
  "en": dict(
    hook=["Your notch", "does", "nothing."], hook2="Yet.",
    c2=("Hover over it<br>and it opens.", "What's playing, from any app."),
    c3=("Battery and volume<br>at a glance.", "Without opening anything."),
    c4=("Your files,<br>close at hand.", "Drag them onto the notch."),
    c5=("See how hard<br>your Mac works.", "CPU, memory and processes."),
    song="Low Tide", song_sub="Sample song · Safari",
    files=["Report.pdf", "Screenshot.png", "Notes.txt"], menu="Finder", date="9:41",
    mem="Memory", mem_val="9.6 of 16 GB", procs=["Browser", "Code editor"],
    chip="Free for Mac", out_tag="Your Mac's notch,<br>turned into a panel.", out_btn="Get it free", lang="en"),
}[LANG]

FIN = '<svg viewBox="150 215 700 630" aria-hidden="true"><path d="M255 700Q370 350 665 235Q575 520 745 700Z"/><rect x="170" y="745" width="660" height="80" rx="40"/></svg>'
TOTAL = 20.0
SC = {"s1": (0.0, 2.8), "s2": (2.8, 3.8), "s3": (6.6, 2.9), "s4": (9.5, 3.0), "s5": (12.5, 3.0), "s6": (15.5, 4.5)}
TABS = '<div class="tabs"><i class="on"></i><i></i><i></i><i></i><i></i><i></i></div>'

def stage(inner, extra=""):
    return f'''
    <div class="screen">
      <div class="menubar"><span data-layout-ignore>{T["menu"]}</span><span data-layout-ignore>{T["date"]}</span></div>
      <div class="panel">{extra}<div class="inner">{inner}</div></div>
      <svg class="cursor" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 2l15 9-6.5 1.6L9 20z"/></svg>
    </div>'''

def cap(key):
    big, small = T[key]
    return f'''<div class="cap"><h2>{big}</h2><p>{small}</p></div>
    <div class="brand"><div class="blogo">{FIN}</div><b>Alero</b><span class="chip">{T["chip"]}</span></div>'''

player = f'''{TABS}
  <div class="player">
    <div class="cover">{FIN}</div>
    <div class="track"><b>{T["song"]}</b><span data-layout-ignore>{T["song_sub"]}</span><div class="progress"><i></i></div></div>
    <div class="wave"><i></i><i></i><i></i><i></i><i></i></div>
  </div>'''
wings = '''
  <div class="wing left"><svg class="ic bolt" viewBox="0 0 24 24"><path d="M13 2L5 13.5h5.5L9.5 22 19 9.5h-6z"/></svg>
    <svg class="ic vol" viewBox="0 0 24 24"><path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path class="stroke" d="M15.5 9a4.2 4.2 0 0 1 0 6M18 6.5a7.6 7.6 0 0 1 0 11"/></svg></div>
  <div class="wing right"><span class="pct bolt">87%</span><span class="pct vol">65%</span></div>'''
files = f'''{TABS}
  <div class="files">
    <div class="file"><div class="doc"><i></i><i></i><i></i></div><span>{T["files"][0]}</span></div>
    <div class="file"><div class="doc img"><b></b></div><span>{T["files"][1]}</span></div>
    <div class="file"><div class="doc"><i></i><i></i></div><span>{T["files"][2]}</span></div>
  </div>'''
monitor = f'''{TABS}
  <div class="gauges">
    <div class="gauge"><div class="gl"><em data-layout-ignore>CPU</em><b>38%</b></div><div class="bar"><i class="g1"></i></div></div>
    <div class="gauge"><div class="gl"><em data-layout-ignore>{T["mem"]}</em><b>{T["mem_val"]}</b></div><div class="bar"><i class="g2"></i></div></div>
  </div>
  <div class="procs">
    <div class="row proc"><b>{T["procs"][0]}</b><em data-layout-ignore>21.4%</em><em data-layout-ignore>1.8 GB</em></div>
    <div class="row proc"><b>{T["procs"][1]}</b><em data-layout-ignore>9.2%</em><em data-layout-ignore>1.1 GB</em></div>
  </div>'''

body = []
def clip(sid, html, cls=""):
    start, dur = SC[sid]
    body.append(f'<div id="{sid}" class="clip scene {cls}" data-start="{start}" data-duration="{dur}" data-track-index="0">{html}</div>')

clip("s1", f'''
  <div class="hook">
    <div class="hl"><span>{T["hook"][0]}</span></div>
    <div class="hl"><span>{T["hook"][1]}</span></div>
    <div class="hl last"><span>{T["hook"][2]}</span><i class="strike"></i></div>
    <div class="hl yet"><span>{T["hook2"]}</span></div>
  </div>''', "dark")
clip("s2", stage(player) + cap("c2"))
clip("s3", stage("", wings) + cap("c3"))
clip("s4", stage(files) + cap("c4"))
clip("s5", stage(monitor) + cap("c5"))
clip("s6", f'''
  <div class="outro">
    <div class="logo">{FIN}</div>
    <h1>Alero</h1>
    <p class="tag">{T["out_tag"]}</p>
    <div class="btn">{T["out_btn"]}</div>
    <p class="url">notch.samdev.space</p>
  </div>''')

CSS = '''
@font-face { font-family: "Bricolage"; font-weight: 700; src: url("assets/bricolage-grotesque-latin-700-normal.woff2") format("woff2"); }
@font-face { font-family: "Plex"; font-weight: 400; src: url("assets/ibm-plex-sans-latin-400-normal.woff2") format("woff2"); }
@font-face { font-family: "Plex"; font-weight: 500; src: url("assets/ibm-plex-sans-latin-500-normal.woff2") format("woff2"); }
@font-face { font-family: "Plex"; font-weight: 600; src: url("assets/ibm-plex-sans-latin-600-normal.woff2") format("woff2"); }
:root { --paper: #f1eee9; --surface: #fbfaf7; --ink: #111111; --muted: #66625b; --line: #d9d4cc; --notch: #050505; --on: #f4f2ee; --on-muted: #a9a6a0; --tile: #1c1c1c; }
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: 1080px; height: 1920px; overflow: hidden; background: var(--paper); }
#root { position: relative; width: 1080px; height: 1920px; background: var(--paper); color: var(--ink); font-family: "Plex", sans-serif; }
.scene { position: absolute; left: 0; top: 0; width: 1080px; height: 1920px; background: var(--paper); }
.scene.dark { background: var(--ink); color: var(--paper); }
svg { display: block; }

/* 1. Gancho: tipografía grande sobre negro */
.hook { position: absolute; left: 120px; top: 330px; width: 880px; }
.hl { position: relative; height: 186px; overflow: hidden; }
.hl span { display: inline-block; font: 700 170px/186px "Bricolage", sans-serif; letter-spacing: -6px; white-space: nowrap; }
.hl.last { display: inline-block; overflow: visible; }
.strike { position: absolute; left: -10px; right: -10px; top: 98px; height: 20px; border-radius: 10px; background: var(--paper); transform-origin: left center; }
.hl.yet { margin-top: 24px; }
.hl.yet span { font-size: 130px; letter-spacing: -4px; }

/* Pantalla con el notch */
.screen { position: absolute; left: 80px; top: 290px; width: 920px; height: 470px; border: 5px solid var(--ink); border-radius: 46px; overflow: hidden;
  background: repeating-linear-gradient(135deg, var(--surface) 0 22px, var(--line) 22px 24px); }
.menubar { position: absolute; left: 0; top: 0; width: 100%; height: 58px; padding: 0 30px; display: flex; align-items: center; justify-content: space-between;
  background: var(--surface); border-bottom: 2px solid var(--line); font-size: 25px; font-weight: 500; color: var(--muted); }
.panel { position: absolute; top: 0; left: 0; right: 0; margin: 0 auto; width: 290px; height: 58px; background: var(--notch); color: var(--on); border-radius: 0 0 40px 40px; overflow: hidden; }
.inner { position: absolute; top: 0; left: 50%; width: 840px; margin-left: -420px; height: 400px; padding: 20px 30px 0; opacity: 0; }
.cursor { position: absolute; left: 660px; top: 330px; width: 60px; height: 60px; }
.cursor path { fill: var(--ink); stroke: var(--surface); stroke-width: 1.6; stroke-linejoin: round; }
.tabs { display: flex; gap: 10px; height: 30px; align-items: center; }
.tabs i { width: 44px; height: 28px; border-radius: 14px; background: #2a2a2a; }
.tabs i.on { background: var(--on); }

.player { display: flex; align-items: center; gap: 26px; margin-top: 26px; }
.cover { flex: none; width: 160px; height: 160px; border-radius: 28px; background: var(--on); display: flex; align-items: center; justify-content: center; }
.cover svg { width: 100px; height: 100px; fill: var(--notch); }
.track { flex: 1; min-width: 0; }
.track b { display: block; font: 700 46px "Bricolage", sans-serif; white-space: nowrap; }
.track span { font-size: 27px; color: var(--on-muted); white-space: nowrap; }
.progress { height: 10px; border-radius: 10px; background: #2e2e2e; margin-top: 22px; overflow: hidden; }
.progress i { display: block; width: 100%; height: 100%; background: var(--on); transform-origin: left center; }
.wave { flex: none; display: flex; align-items: center; gap: 9px; height: 104px; }
.wave i { width: 12px; border-radius: 6px; background: var(--on); }
.wave i:nth-child(1) { height: 34px; } .wave i:nth-child(2) { height: 70px; } .wave i:nth-child(3) { height: 104px; }
.wave i:nth-child(4) { height: 56px; } .wave i:nth-child(5) { height: 40px; }

.wing { position: absolute; top: 0; height: 58px; width: 130px; display: flex; align-items: center; justify-content: center; opacity: 0; }
.wing.left { left: 4px; } .wing.right { right: 4px; }
.ic { width: 38px; height: 38px; fill: var(--on); position: absolute; }
.ic .stroke { fill: none; stroke: var(--on); stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round; }
.pct { position: absolute; font-size: 32px; font-weight: 600; }
.vol { opacity: 0; }

.files { display: flex; gap: 20px; margin-top: 24px; }
.file { flex: 1; height: 215px; border-radius: 26px; background: var(--tile); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 18px; font-size: 29px; }
.doc { width: 92px; height: 116px; border-radius: 12px; background: var(--on); padding: 22px 16px; display: flex; flex-direction: column; gap: 11px; }
.doc i { height: 8px; border-radius: 4px; background: #b9b5ad; } .doc i:last-child { width: 60%; }
.doc.img { padding: 0; align-items: center; justify-content: center; }
.doc.img b { width: 50px; height: 50px; border-radius: 50%; background: var(--notch); }

.gauges { display: flex; gap: 28px; margin-top: 26px; }
.gauge { flex: 1; }
.gl { display: flex; justify-content: space-between; align-items: baseline; font-size: 29px; white-space: nowrap; }
.gl em, .row em { font-style: normal; color: var(--on-muted); }
.gl b { font-weight: 600; }
.bar { height: 16px; border-radius: 8px; background: #2e2e2e; margin-top: 12px; overflow: hidden; }
.bar i { display: block; height: 100%; border-radius: 8px; background: var(--on); transform-origin: left center; }
.bar .g1 { width: 38%; } .bar .g2 { width: 60%; }
.procs { display: flex; flex-direction: column; gap: 12px; margin-top: 24px; }
.row { height: 64px; border-radius: 18px; background: var(--tile); display: flex; align-items: center; gap: 16px; padding: 0 22px; font-size: 30px; }
.row b { font-weight: 600; flex: 1; white-space: nowrap; }
.row em { font-size: 27px; width: 120px; text-align: right; white-space: nowrap; }

/* Rótulo y marca, dentro de la zona segura de Reels */
.cap { position: absolute; left: 120px; top: 800px; width: 880px; }
.cap h2 { font: 700 96px/1.03 "Bricolage", sans-serif; letter-spacing: -3px; }
.cap p { font-size: 44px; color: var(--muted); margin-top: 20px; }
.brand { position: absolute; left: 120px; top: 1158px; display: flex; align-items: center; gap: 18px; }
.blogo { width: 72px; height: 72px; border-radius: 18px; background: var(--ink); display: flex; align-items: center; justify-content: center; }
.blogo svg { width: 44px; height: 44px; fill: var(--paper); }
.brand b { font: 700 52px "Bricolage", sans-serif; letter-spacing: -1.5px; }
.chip { margin-left: 8px; border: 3px solid var(--ink); border-radius: 40px; padding: 6px 22px; font-size: 30px; font-weight: 600; }

/* Cierre */
.outro { position: absolute; left: 0; top: 300px; width: 1080px; display: flex; flex-direction: column; align-items: center; }
.logo { width: 220px; height: 220px; border-radius: 52px; background: var(--ink); display: flex; align-items: center; justify-content: center; }
.logo svg { width: 134px; height: 134px; fill: var(--paper); }
.outro h1 { font: 700 180px/1 "Bricolage", sans-serif; letter-spacing: -6px; margin-top: 26px; }
.tag { font-size: 46px; line-height: 1.25; text-align: center; color: var(--muted); margin-top: 18px; }
.btn { margin-top: 40px; background: var(--ink); color: var(--paper); border-radius: 70px; padding: 26px 60px; font: 700 56px "Bricolage", sans-serif; letter-spacing: -1px; }
.url { margin-top: 36px; font: 700 56px "Bricolage", sans-serif; letter-spacing: -1.5px; }
'''

JS = '''
const tl = gsap.timeline({ paused: true });
const NOTCH_W = 290, NOTCH_H = 58, OPEN_W = 840;

function scene(id, start, dur, fadeIn) {
  if (fadeIn !== false) tl.fromTo("#" + id, { opacity: 0 }, { opacity: 1, duration: 0.25, ease: "power2.out" }, start);
  tl.to("#" + id, { opacity: 0, duration: 0.22, ease: "power2.in" }, start + dur - 0.22);
}
function caption(id, at) {
  tl.fromTo("#" + id + " .cap h2", { opacity: 0, y: 60 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, at);
  tl.fromTo("#" + id + " .cap p", { opacity: 0, y: 36 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, at + 0.14);
}
function openPanel(id, at, height) {
  tl.fromTo("#" + id + " .cursor", { x: 0, y: 0, opacity: 0 }, { opacity: 1, duration: 0.15 }, at);
  tl.to("#" + id + " .cursor", { x: -215, y: -305, duration: 0.5, ease: "power2.inOut" }, at + 0.05);
  tl.fromTo("#" + id + " .panel", { width: NOTCH_W, height: NOTCH_H }, { width: OPEN_W, height: height, duration: 0.5, ease: "back.out(1.2)" }, at + 0.5);
  tl.fromTo("#" + id + " .inner", { opacity: 0 }, { opacity: 1, duration: 0.3 }, at + 0.7);
  tl.to("#" + id + " .cursor", { opacity: 0, duration: 0.2 }, at + 0.85);
}

// 1. Gancho (visible desde el primer fotograma, para la miniatura)
scene("s1", 0, 2.8, false);
document.querySelectorAll("#s1 .hl:not(.yet) span").forEach(function (el, i) {
  tl.fromTo(el, { y: 60 + i * 30 }, { y: 0, duration: 0.55, ease: "power4.out" }, 0);
});
tl.fromTo("#s1 .strike", { scaleX: 0 }, { scaleX: 1, duration: 0.3, ease: "power3.inOut" }, 1.25);
tl.fromTo("#s1 .yet span", { y: 200 }, { y: 0, duration: 0.45, ease: "back.out(1.5)" }, 1.6);

// 2. Abrir el panel: reproductor
scene("s2", 2.8, 3.8);
caption("s2", 2.95);
openPanel("s2", 3.15, 286);
tl.fromTo("#s2 .cover", { scale: 0.7, opacity: 0 }, { scale: 1, opacity: 1, duration: 0.4, ease: "back.out(1.5)" }, 3.95);
tl.fromTo("#s2 .track", { opacity: 0, x: 30 }, { opacity: 1, x: 0, duration: 0.4, ease: "power3.out" }, 4.05);
tl.fromTo("#s2 .progress i", { scaleX: 0.1 }, { scaleX: 0.6, duration: 2.4, ease: "none" }, 4.1);
document.querySelectorAll("#s2 .wave i").forEach(function (bar, i) {
  tl.fromTo(bar, { scaleY: 0.35 }, { scaleY: 1, duration: 0.28, repeat: 7, yoyo: true, ease: "sine.inOut" }, 4.1 + i * 0.08);
});

// 3. Batería y volumen
scene("s3", 6.6, 2.9);
caption("s3", 6.75);
tl.set("#s3 .cursor", { opacity: 0 }, 6.6);
tl.fromTo("#s3 .panel", { width: NOTCH_W }, { width: 560, duration: 0.45, ease: "back.out(1.7)" }, 6.95);
tl.fromTo("#s3 .wing", { opacity: 0 }, { opacity: 1, duration: 0.25 }, 7.1);
tl.fromTo("#s3 .bolt", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.3, ease: "back.out(2)" }, 7.1);
tl.to("#s3 .bolt", { opacity: 0, duration: 0.15 }, 8.05);
tl.to("#s3 .panel", { width: 522, duration: 0.15, ease: "power2.in" }, 8.05);
tl.to("#s3 .panel", { width: 560, duration: 0.3, ease: "back.out(2)" }, 8.2);
tl.fromTo("#s3 .vol", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.3, ease: "back.out(2)" }, 8.2);

// 4. Archivos
scene("s4", 9.5, 3.0);
caption("s4", 9.65);
openPanel("s4", 9.7, 312);
document.querySelectorAll("#s4 .file").forEach(function (el, i) {
  tl.fromTo(el, { opacity: 0, y: -100, scale: 0.8 }, { opacity: 1, y: 0, scale: 1, duration: 0.45, ease: "back.out(1.5)" }, 10.5 + i * 0.18);
});

// 5. Monitor
scene("s5", 12.5, 3.0);
caption("s5", 12.65);
openPanel("s5", 12.7, 372);
tl.fromTo("#s5 .g1", { scaleX: 0 }, { scaleX: 1, duration: 0.8, ease: "power3.out" }, 13.5);
tl.fromTo("#s5 .g2", { scaleX: 0 }, { scaleX: 1, duration: 0.8, ease: "power3.out" }, 13.62);
document.querySelectorAll("#s5 .proc").forEach(function (el, i) {
  tl.fromTo(el, { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.4, ease: "power3.out" }, 13.6 + i * 0.14);
});

// 6. Cierre
tl.fromTo("#s6", { opacity: 0 }, { opacity: 1, duration: 0.25 }, 15.5);
tl.fromTo("#s6 .logo", { scale: 0.5, opacity: 0 }, { scale: 1, opacity: 1, duration: 0.6, ease: "back.out(1.7)" }, 15.6);
tl.fromTo("#s6 h1", { opacity: 0, y: 60 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, 15.85);
tl.fromTo("#s6 .tag", { opacity: 0, y: 36 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, 16.1);
tl.fromTo("#s6 .btn", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.5, ease: "back.out(1.8)" }, 16.45);
tl.fromTo("#s6 .url", { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, 16.8);
tl.to("#s6 .btn", { scale: 1.06, duration: 0.35, repeat: 3, yoyo: true, ease: "sine.inOut" }, 17.6);

window.__timelines = window.__timelines || {};
window.__timelines["main"] = tl;
tl.seek(0);
'''

html = f'''<!doctype html>
<html lang="{T["lang"]}">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1080, height=1920" />
    <title>Alero · reel</title>
    <script src="assets/gsap.min.js"></script>
    <style>{CSS}</style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}" data-width="1080" data-height="1920">
      {"".join(body)}
    </div>
    <script>{JS}</script>
  </body>
</html>
'''
open("index.html", "w", encoding="utf-8").write(html)
print("index.html escrito:", LANG, len(html), "bytes")
