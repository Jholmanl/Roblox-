import json, sys, os
mode = sys.argv[1]  # local | cdn
files = sys.argv[2:]
maps = [json.load(open(f)) for f in files]
if mode == "local":
    three = "./node_modules/three/build/three.module.js"; addons = "./node_modules/three/examples/jsm/"
    js = '<script type="module" src="./viewer.js"></script>'
else:
    three = "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js"; addons = "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"
    js = '<script type="module">' + open("viewer.js").read() + '</script>'
html = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Neon Strike Map Preview</title>
<style>
:root {{ --bg:#0b0d12; --panel:rgba(14,17,24,.82); --text:#fff; --sub:#9aa2b4; --accent:#ffc61a; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#0b0d12; }} }}
:root[data-theme="dark"] {{ --bg:#0b0d12; }}
html,body {{ margin:0; height:100%; background:var(--bg); color:var(--text); font-family: "Inter", system-ui, sans-serif; overflow:hidden; }}
#view {{ position:fixed; inset:0; }}
.hud {{ position:fixed; left:16px; top:16px; right:16px; display:flex; flex-wrap:wrap; gap:8px; align-items:center; pointer-events:none; }}
.hud > * {{ pointer-events:auto; }}
.brand {{ background:var(--panel); padding:10px 14px; border-radius:10px; }}
.brand b {{ font-weight:900; letter-spacing:.04em; color:var(--accent); }}
#title {{ font-weight:900; font-size:20px; letter-spacing:.03em; }}
#stats {{ color:var(--sub); font-size:12px; }}
button {{ font:inherit; font-weight:800; font-size:12px; letter-spacing:.04em; background:var(--panel); color:var(--text); border:1px solid rgba(255,255,255,.15); border-radius:8px; padding:9px 12px; cursor:pointer; }}
button.on {{ background:var(--accent); color:#000; border-color:var(--accent); }}
#maps-bar, .views {{ display:flex; gap:6px; flex-wrap:wrap; }}
.hint {{ position:fixed; left:16px; bottom:14px; color:var(--sub); font-size:12px; background:var(--panel); padding:6px 10px; border-radius:8px; }}
</style>
<script type="importmap">{{"imports":{{"three":"{three}","three/addons/":"{addons}"}}}}</script>
</head><body>
<div id="view"></div>
<div class="hud">
 <div class="brand"><b>NEON STRIKE</b> · map preview<div id="title"></div><div id="stats"></div></div>
 <div id="maps-bar"></div>
 <div class="views"><button data-view="0">OVERVIEW</button><button data-view="1">TOP DOWN</button><button data-view="2">STREET LEVEL</button><button data-view="3">STREET 2</button></div>
</div>
<div class="hint">Drag to orbit · scroll to zoom · right-drag to pan. Rendered from the game's actual map code.</div>
<script id="maps" type="application/json">{json.dumps(maps, separators=(",",":"))}</script>
{js}
</body></html>'''
out = "preview_local.html" if mode == "local" else "preview.html"
open(out, "w").write(html)
print(out, os.path.getsize(out))
