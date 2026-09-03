#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Byg-soegeside.command
# ----------------------
# Lægges i samme mappe som dine singlefile-HTML-outputs (album, lydfortællinger,
# e-bøger m.fl. fra builder-værktøjskassen). Dobbeltklik på filen i Finder for at
# køre den, eller kør den fra Terminal: ./Byg-soegeside.command
#
# Scriptet scanner mappen for .html-filer, læser den indlejrede
# "builder-source-data"-JSON-blok (Dublin Core-felterne) ud af hver fil, og
# genererer derefter EN NY, selvstændig søgeside (soegeside.html) med alt data
# skrevet direkte ind i filen. Ingen server, ingen separat json-fil – søgesiden
# virker ved almindeligt dobbeltklik, ligesom dine øvrige builder-outputs.
#
# Kør scriptet igen, når du har lagt nye filer i mappen, for at opdatere søgesiden.
#
# Version 2 (aug. 2026): større tekst, højere kontrast, bedre mobilvisning og
# en A / A+ / A++ knap til tekststørrelse. Kun HTML_TEMPLATE er ændret.

import json
import re
import sys
import webbrowser
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_NAME = "soegeside.html"
OUTPUT_MARKER = "lokalt-soegeindeks-genereret"

SOURCE_BLOCK_RE = re.compile(
    r'<script[^>]*id="builder-source-data"[^>]*>(.*?)</script>', re.S
)

TYPE_ICON = {
    "Sound": "🎧",
    "Image": "🖼️",
    "Text": "📖",
    "Collection": "🗂️",
    "InteractiveResource": "🧩",
    "Event": "📌",
}

DC_FIELDS = [
    "title", "creator", "subject", "description", "publisher", "contributor",
    "date", "type", "format", "identifier", "source", "language", "relation",
    "coverage", "rights",
]


def find_html_files():
    files = []
    for p in sorted(SCRIPT_DIR.glob("*.html")):
        if p.name == OUTPUT_NAME:
            continue
        files.append(p)
    return files


def extract_record(path):
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except Exception as e:
        print(f"  ! Kunne ikke læse {path.name}: {e}")
        return None

    if OUTPUT_MARKER in text[:2000]:
        return None  # det er en tidligere genereret søgeside selv

    m = SOURCE_BLOCK_RE.search(text)
    if not m:
        print(f"  - Sprunget over (ingen builder-source-data): {path.name}")
        return None

    try:
        data = json.loads(m.group(1))
    except Exception as e:
        print(f"  ! Kunne ikke læse metadata i {path.name}: {e}")
        return None

    dc = data.get("dublinCore", {}) or {}
    record = {"filnavn": path.name, "appformat": data.get("format", "")}
    for felt in DC_FIELDS:
        record[felt] = (dc.get(felt) or "").strip()

    if not record["title"]:
        record["title"] = path.stem

    return record


def year_sort_key(dato):
    m = re.search(r"\d{4}", dato or "")
    return m.group(0) if m else "0000"


def build_html(records):
    data_json = json.dumps(records, ensure_ascii=False)
    data_json = data_json.replace("</script", "<\\/script")

    generated = datetime.now().strftime("%-d. %B %Y, %H:%M")

    return HTML_TEMPLATE.replace("__MARKER__", OUTPUT_MARKER) \
        .replace("__ANTAL__", str(len(records))) \
        .replace("__GENERERET__", generated) \
        .replace("__DATA_JSON__", data_json)


HTML_TEMPLATE = """<!-- __MARKER__ -->
<!DOCTYPE html>
<html lang="da">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lokalhistorisk søgeindeks</title>
<style>
/* Alle størrelser er i rem, så A/A+/A++ kan skalere hele siden på én gang. */
html{font-size:100%}
html[data-tekst="stor"]{font-size:112.5%}
html[data-tekst="storst"]{font-size:125%}

:root{
  --accent:#8E1F49;        /* 8,3:1 mod papir */
  --paper:#FAF9F5;
  --paper-dim:#F1E7EC;
  --ink:#241520;           /* 15,6:1 */
  --line:#D9C7CF;
  --muted:#58424D;         /* 8,0:1 mod papir, 7,5:1 mod zebra */
  --footer-strong:#33202B;
}
@media (prefers-contrast:more){
  :root{--accent:#6E1638;--ink:#000;--muted:#33202B;--line:#9C8A93}
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{
  background:var(--paper);color:var(--ink);
  font-family:Georgia,"Times New Roman",serif;
  font-size:1.25rem;line-height:1.6;
  -webkit-text-size-adjust:100%;
}
a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible{
  outline:3px solid var(--accent);outline-offset:2px;
}

header{max-width:1100px;margin:0 auto;padding:2rem 1.25rem .5rem}
.topbar{display:flex;gap:1rem;align-items:flex-start;justify-content:space-between;flex-wrap:wrap}
h1{font-size:2.1rem;line-height:1.2;margin:0 0 .25rem}
.sub{color:var(--muted);font-size:1.05rem;margin:0}

/* ---- tekststørrelse ---- */
.tekststr{display:flex;align-items:center;gap:.5rem;flex:0 0 auto}
.tekststr .lbl{font-size:.95rem;color:var(--muted)}
.tekststr button{
  font-family:inherit;background:#fff;color:var(--ink);
  border:2px solid var(--line);border-radius:8px;
  min-width:48px;min-height:48px;padding:0 .6rem;
  cursor:pointer;line-height:1;
}
.tekststr button:nth-of-type(1){font-size:1rem}
.tekststr button:nth-of-type(2){font-size:1.25rem}
.tekststr button:nth-of-type(3){font-size:1.5rem}
.tekststr button:hover{border-color:var(--accent)}
.tekststr button[aria-pressed="true"]{background:var(--accent);border-color:var(--accent);color:#fff}

.controls{max-width:1100px;margin:1.2rem auto .3rem;padding:0 1.25rem;display:flex;gap:.75rem;flex-wrap:wrap}
.controls input,.controls select{
  font-family:inherit;font-size:1.05rem;padding:.65rem .75rem;
  border:2px solid var(--line);border-radius:8px;background:#fff;color:var(--ink);
  min-height:48px;
}
.controls input{flex:1 1 16rem}
.controls select{flex:0 0 auto;max-width:100%}
.count{max-width:1100px;margin:.9rem auto 0;padding:0 1.25rem;color:var(--muted);font-size:1rem}
.list{max-width:1100px;margin:.6rem auto 3rem;padding:0 1.25rem}
a.row{
  display:flex;gap:1rem;align-items:flex-start;text-decoration:none;color:var(--ink);
  padding:1rem .9rem;border-radius:8px;
}
a.row:hover{outline:2px solid var(--accent)}
a.row:focus-visible{outline:3px solid var(--accent)}
.row--a{background:var(--paper)}
.row--b{background:var(--paper-dim)}
.icon{font-size:1.4rem;flex:0 0 1.9rem;line-height:1.4}
.col-main{flex:1 1 auto;min-width:0}
.col-main .t{font-size:1.25rem;font-weight:bold;color:var(--footer-strong);line-height:1.35}
.col-main .m{font-size:1rem;color:var(--muted);margin-top:.2rem;display:block}
.col-main .d{font-size:1.05rem;color:var(--ink);margin-top:.4rem;
  display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.col-type{flex:0 0 auto;font-size:.95rem;color:var(--muted);align-self:center;white-space:nowrap}
.empty{padding:2rem 0;color:var(--muted)}
footer{max-width:1100px;margin:0 auto;padding:.6rem 1.25rem 3rem;color:var(--muted);font-size:.95rem;line-height:1.7}
@media(max-width:640px){
  .col-type{display:none}
  header{padding:1.5rem 1rem .5rem}
  .controls{padding:0 1rem;gap:.6rem}
  .controls input,.controls select{flex:1 1 100%;width:100%}
  .count,.list,footer{padding-left:1rem;padding-right:1rem}
  a.row{padding:1rem .6rem;gap:.75rem}
  .icon{flex:0 0 1.6rem}
}
</style>
</head>
<body>
<header>
<div class="topbar">
  <div>
    <h1>Lokalhistorisk søgeindeks</h1>
    <p class="sub">__ANTAL__ poster · genereret __GENERERET__</p>
  </div>
  <div class="tekststr" role="group" aria-label="Tekststørrelse">
    <span class="lbl" aria-hidden="true">Tekst</span>
    <button type="button" data-str="normal" aria-pressed="true" aria-label="Normal tekststørrelse">A</button>
    <button type="button" data-str="stor" aria-pressed="false" aria-label="Større tekst">A+</button>
    <button type="button" data-str="storst" aria-pressed="false" aria-label="Størst tekst">A++</button>
  </div>
</div>
</header>

<div class="controls">
<input id="q" type="search" placeholder="Søg i titel, ophav, emne, udgiver, sted og beskrivelse …" aria-label="Søg">
<select id="omraadeFilter" aria-label="Filtrér på område"><option value="">Alle områder</option></select>
<select id="typeFilter" aria-label="Filtrér på type"><option value="">Alle typer</option></select>
<select id="sortBy" aria-label="Sortér">
<option value="title">Titel A–Å</option>
<option value="date-new">Dato, nyeste først</option>
<option value="date-old">Dato, ældste først</option>
<option value="type">Type</option>
<option value="omraade">Område</option>
</select>
</div>

<p class="count" id="count" role="status" aria-live="polite"></p>
<div class="list" id="list"></div>

<footer>
Denne side er selvstændig og indeholder alt indhold direkte i filen. Genkør
<em>Byg-soegeside.command</em> i mappen for at opdatere søgeindekset, når der er
lagt nye filer til.
</footer>

<script>
const DATA = __DATA_JSON__;
const ICONS = {Sound:"🎧",Image:"🖼️",Text:"📖",Collection:"🗂️",InteractiveResource:"🧩",Event:"📌"};

/* ---- tekststørrelse: A / A+ / A++ ---- */
(function(){
  const knapper = document.querySelectorAll(".tekststr button");
  function saet(v, gem){
    if(v && v!=="normal"){ document.documentElement.setAttribute("data-tekst", v); }
    else { document.documentElement.removeAttribute("data-tekst"); v="normal"; }
    knapper.forEach(k=>k.setAttribute("aria-pressed", String(k.dataset.str===v)));
    if(gem){ try{ localStorage.setItem("lokalhist-tekst", v); }catch(e){} }
  }
  let gemt = null;
  try{ gemt = localStorage.getItem("lokalhist-tekst"); }catch(e){}
  if(gemt) saet(gemt, false);
  knapper.forEach(k=>k.addEventListener("click", ()=>saet(k.dataset.str, true)));
})();

function yearOf(s){var m=(s||"").match(/\\d{4}/); return m?m[0]:"0000";}

const typeSel = document.getElementById("typeFilter");
const seen = new Set();
DATA.forEach(r=>{ if(r.type) seen.add(r.type); });
Array.from(seen).sort().forEach(t=>{
  const o=document.createElement("option"); o.value=t; o.textContent=t;
  typeSel.appendChild(o);
});

/* Område = dc.publisher. Listen bygges af de udgivere der faktisk findes i mappen. */
const omrSel = document.getElementById("omraadeFilter");
const omrSeen = new Set();
let udenOmraade = 0;
DATA.forEach(r=>{ if(r.publisher) omrSeen.add(r.publisher); else udenOmraade++; });
Array.from(omrSeen).sort((a,b)=>a.localeCompare(b,"da")).forEach(p=>{
  const o=document.createElement("option"); o.value=p; o.textContent=p;
  omrSel.appendChild(o);
});
if(udenOmraade){
  const o=document.createElement("option");
  o.value="__uden__"; o.textContent="(uden udgiver — " + udenOmraade + ")";
  omrSel.appendChild(o);
}

function render(){
  const q = document.getElementById("q").value.trim().toLowerCase();
  const type = typeSel.value;
  const omr = omrSel.value;
  const sortBy = document.getElementById("sortBy").value;

  let rows = DATA.filter(r=>{
    if(type && r.type!==type) return false;
    if(omr === "__uden__"){ if(r.publisher) return false; }
    else if(omr && r.publisher!==omr) return false;
    if(!q) return true;
    const hay = (r.title+" "+r.creator+" "+r.subject+" "+r.publisher+" "+
                 r.coverage+" "+r.description).toLowerCase();
    return hay.indexOf(q)!==-1;
  });

  rows = rows.slice().sort((a,b)=>{
    if(sortBy==="title") return a.title.localeCompare(b.title,"da");
    if(sortBy==="type") return (a.type||"").localeCompare(b.type||"","da");
    if(sortBy==="omraade"){
      const c=(a.publisher||"ÅÅÅ").localeCompare(b.publisher||"ÅÅÅ","da");
      return c!==0 ? c : a.title.localeCompare(b.title,"da");
    }
    const ya=yearOf(a.date), yb=yearOf(b.date);
    return sortBy==="date-new" ? yb.localeCompare(ya) : ya.localeCompare(yb);
  });

  const list = document.getElementById("list");
  list.innerHTML = "";
  document.getElementById("count").textContent =
    "Viser " + rows.length + " af " + DATA.length + " poster";

  if(rows.length===0){
    const p=document.createElement("p");
    p.className="empty"; p.textContent="Ingen poster matcher søgningen.";
    list.appendChild(p); return;
  }

  rows.forEach((r,i)=>{
    const a=document.createElement("a");
    a.className="row " + (i%2===0?"row--a":"row--b");
    a.href=encodeURI(r.filnavn); a.target="_blank"; a.rel="noopener";

    const icon=document.createElement("span");
    icon.className="icon"; icon.textContent = ICONS[r.type]||"📄";
    icon.setAttribute("aria-hidden","true");

    const main=document.createElement("span");
    main.className="col-main";
    const t=document.createElement("span"); t.className="t"; t.textContent=r.title;
    const m=document.createElement("span"); m.className="m";
    m.textContent=[r.creator,r.date,r.publisher].filter(Boolean).join(" · ");
    const d=document.createElement("span"); d.className="d"; d.textContent=r.description||"";
    main.appendChild(t); main.appendChild(document.createElement("br"));
    main.appendChild(m); main.appendChild(d);

    const typ=document.createElement("span");
    typ.className="col-type"; typ.textContent=r.type||"";

    a.appendChild(icon); a.appendChild(main); a.appendChild(typ);
    list.appendChild(a);
  });
}

document.getElementById("q").addEventListener("input", render);
omrSel.addEventListener("change", render);
typeSel.addEventListener("change", render);
document.getElementById("sortBy").addEventListener("change", render);
render();
</script>
</body>
</html>
"""


def main():
    print("Scanner mappen for singlefile-HTML-filer …")
    files = find_html_files()
    records = []
    for p in files:
        rec = extract_record(p)
        if rec:
            records.append(rec)

    if not records:
        print("\nFandt ingen indekserbare filer. Ligger scriptet i den rigtige mappe?")
        input("Tryk Enter for at afslutte …")
        sys.exit(1)

    out_path = SCRIPT_DIR / OUTPUT_NAME
    out_path.write_text(build_html(records), encoding="utf-8")

    print(f"\nFærdig. Indekserede {len(records)} af {len(files)} html-filer.")
    print(f"Søgesiden er gemt som: {out_path}")

    try:
        webbrowser.open(out_path.as_uri())
    except Exception:
        pass

    input("Tryk Enter for at lukke …")


if __name__ == "__main__":
    main()
