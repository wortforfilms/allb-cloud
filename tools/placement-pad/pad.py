import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
glyphs = json.load(open(os.path.join(HERE, "glyphs.json")))
GLYPHS_JSON = json.dumps(glyphs, separators=(',', ':'))

CONS_ORDER = [f"{cp:05X}" for cp in range(0x11013, 0x11034)]
VIRAMA = "11046"

html = r"""<title>Conjunct Placement Pad</title>
<style>
:root{
  --bg:#EDEFF3; --panel:#FFFFFF; --panel-2:#F5F6F9; --border:#D6D9E1;
  --ink:#14161C; --ink-dim:#5B6070; --accent:#B8452F; --accent-ink:#FFFFFF;
  --base-color:#2E3A6B; --stack-color:#B8452F; --guide:#AEB3C2;
  --focus:#B8452F;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --bg:#14161C; --panel:#1B1E27; --panel-2:#20232D; --border:#33384A;
    --ink:#EDEEF3; --ink-dim:#9AA0B4; --accent:#E2694A; --accent-ink:#1B1E27;
    --base-color:#7C8FE0; --stack-color:#E2694A; --guide:#454B60;
  }
}
:root[data-theme="dark"]{
  --bg:#14161C; --panel:#1B1E27; --panel-2:#20232D; --border:#33384A;
  --ink:#EDEEF3; --ink-dim:#9AA0B4; --accent:#E2694A; --accent-ink:#1B1E27;
  --base-color:#7C8FE0; --stack-color:#E2694A; --guide:#454B60;
}
*{box-sizing:border-box;}
[hidden]{display:none !important;}
body{
  background:var(--bg); color:var(--ink); margin:0; padding-block:28px;
  padding-inline:20px; font-family:"IBM Plex Sans",system-ui,sans-serif;
}
h1,h2,h3{font-family:"Fraunces",Georgia,serif; font-weight:600; margin:0; text-wrap:balance;}
.mono{font-family:"IBM Plex Mono",ui-monospace,monospace;}
.wrap{max-width:1320px; margin:0 auto;}
header{margin-bottom:22px;}
header h1{font-size:1.7rem; letter-spacing:-0.01em;}
header p{color:var(--ink-dim); margin:6px 0 0; max-width:62ch; font-size:0.93rem; line-height:1.5;}
.layout{display:grid; grid-template-columns: 300px 1fr; gap:20px;}
@media (max-width:860px){ .layout{grid-template-columns:1fr;} }
.panel{
  background:var(--panel); border:1px solid var(--border); border-radius:10px;
  padding:18px;
}
.sidebar{display:flex; flex-direction:column; gap:16px;}
.field{display:flex; flex-direction:column; gap:6px;}
.field label{font-size:0.72rem; text-transform:uppercase; letter-spacing:0.06em; color:var(--ink-dim);}
select, button, input[type=text]{
  font-family:inherit; font-size:0.9rem; border-radius:7px; border:1px solid var(--border);
  background:var(--panel-2); color:var(--ink); padding:8px 10px;
}
select{width:100%;}
.glyph-option-char{font-size:1.1rem;}
.slider-row{display:flex; align-items:center; gap:10px;}
.slider-row input[type=range]{flex:1; accent-color:var(--accent);}
.slider-row .val{width:52px; text-align:right; font-size:0.82rem; color:var(--ink-dim); flex-shrink:0;}
.btn{cursor:pointer; transition:transform .08s ease;}
.btn:active{transform:scale(0.97);}
.btn-primary{background:var(--accent); color:var(--accent-ink); border-color:var(--accent); font-weight:600;}
.btn-row{display:flex; gap:8px; flex-wrap:wrap;}
.btn-row .btn{flex:1; min-width:0;}
.mode-row{display:flex; flex-direction:column; gap:6px;}
.mode-btn{width:100%; text-align:left; font-size:0.85rem;}
.mode-btn.active{background:var(--accent); color:var(--accent-ink); border-color:var(--accent); font-weight:600;}
.sheet-hint{margin:-4px 0 0; font-size:0.76rem; color:var(--ink-dim); font-style:italic; line-height:1.4;}
hr.sep{border:none; border-top:1px solid var(--border); margin:2px 0;}
.stage-wrap{display:flex; flex-direction:column; gap:16px;}
.stage-row{display:flex; gap:16px; align-items:stretch; flex-wrap:wrap;}
#stage-svg{flex:1 1 420px; min-width:280px; height:600px; touch-action:none; background:
  linear-gradient(var(--panel-2) 1px, transparent 1px) 0 0/100% 25%,
  var(--panel);
  border:1px solid var(--border); border-radius:10px; cursor:default;}
.dev-ref{
  flex:0 0 190px; display:flex; flex-direction:column; align-items:center; justify-content:center;
  gap:10px; background:var(--panel-2); border:1px solid var(--border); border-radius:10px; padding:16px;
  text-align:center;
}
.dev-ref-label{font-size:0.7rem; text-transform:uppercase; letter-spacing:0.06em; color:var(--ink-dim); line-height:1.3;}
.dev-ref-text{font-family:"Noto Sans Devanagari",system-ui,sans-serif; font-size:3.4rem; line-height:1; color:var(--ink);}
.dev-ref-note{font-size:0.72rem; color:var(--ink-dim); line-height:1.4;}
.handle{cursor:grab;}
.handle:active{cursor:grabbing;}
.legend{display:flex; gap:18px; font-size:0.8rem; color:var(--ink-dim); flex-wrap:wrap;}
.legend span{display:inline-flex; align-items:center; gap:6px;}
.swatch{width:10px; height:10px; border-radius:2px; display:inline-block;}
.readout{display:grid; grid-template-columns:repeat(auto-fit,minmax(108px,1fr)); gap:10px;}
.readout div{background:var(--panel-2); border:1px solid var(--border); border-radius:8px; padding:8px 10px;}
.readout div span.k{display:block; font-size:0.68rem; text-transform:uppercase; letter-spacing:0.05em; color:var(--ink-dim);}
.readout div span.v{font-size:1rem;}
.overrides-list{display:flex; flex-direction:column; gap:6px; max-height:220px; overflow-y:auto;}
.override-row{
  display:flex; align-items:center; justify-content:space-between; gap:8px;
  background:var(--panel-2); border:1px solid var(--border); border-radius:7px;
  padding:6px 10px; font-size:0.82rem; cursor:pointer;
}
.override-row:hover{border-color:var(--accent);}
.override-row .del{color:var(--ink-dim); background:none; border:none; cursor:pointer; padding:2px 6px; font-size:0.9rem;}
.override-row .del:hover{color:var(--accent);}
.empty-note{color:var(--ink-dim); font-size:0.82rem; font-style:italic;}
.sheet-grid{display:grid; grid-template-columns:repeat(auto-fill,minmax(120px,1fr)); gap:10px;}
.sheet-cell{background:var(--panel-2); border:1px solid var(--border); border-radius:8px; padding:8px; text-align:center;}
.sheet-cell.flag{border-color:var(--accent);}
.sheet-cell svg{width:100%; height:90px;}
.sheet-cell .dev{font-family:"Noto Sans Devanagari",system-ui,sans-serif; font-size:1.1rem; color:var(--ink-dim);}
.sheet-cell .lbl{font-size:0.68rem; color:var(--ink-dim); margin-top:2px;}
.sheet-cell .ratio{font-size:0.68rem; font-family:"IBM Plex Mono",ui-monospace,monospace; margin-top:1px;}
.words-grid{display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr)); gap:14px;}
.word-card{background:var(--panel-2); border:1px solid var(--border); border-radius:9px; padding:10px; text-align:center;}
.word-card svg{width:100%; height:70px;}
.word-card .dev{font-family:"Noto Sans Devanagari",system-ui,sans-serif; font-size:1.5rem; color:var(--ink-dim); margin-bottom:2px;}
.word-card .cap{font-size:0.78rem; color:var(--ink-dim); margin-top:4px;}
.status-dot{width:7px; height:7px; border-radius:50%; display:inline-block; margin-right:5px;}
.status-ok{background:#3E9B5C;} .status-off{background:var(--guide);}
footer{margin-top:26px; color:var(--ink-dim); font-size:0.8rem; line-height:1.6;}
footer a{color:var(--accent);}
</style>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:wght@500;600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&family=Noto+Sans+Devanagari:wght@400;600&display=swap" rel="stylesheet">

<div class="wrap">
  <header>
    <h1>Conjunct Placement Pad</h1>
    <p>Calibrate exactly where a below-base consonant sits under its base in <span class="mono">MAATAA Brahmi Stacked</span> — drag, resize and rotate the real Noto Sans Brahmi letterforms, then save the rule so <span class="mono">build_stacked.py</span> can pick it up. <span id="db-status"><span class="status-dot status-off"></span>connecting…</span></p>
  </header>

  <div class="layout">
    <div class="panel sidebar">
      <div class="field">
        <label>Mode</label>
        <div class="mode-row">
          <button class="btn mode-btn active" id="mode-single" data-mode="single">Single pair</button>
          <button class="btn mode-btn" id="mode-by-stack" data-mode="byStack">Sheet: fix stacked</button>
          <button class="btn mode-btn" id="mode-by-base" data-mode="byBase">Sheet: fix base</button>
        </div>
      </div>

      <div class="field" id="field-sel-base">
        <label for="sel-base" id="label-sel-base">Base consonant (fixed)</label>
        <select id="sel-base"></select>
      </div>
      <div class="field" id="field-sel-stack">
        <label for="sel-stack" id="label-sel-stack">Stacked consonant (movable)</label>
        <select id="sel-stack"></select>
      </div>
      <p class="sheet-hint" id="sheet-hint" hidden>
        Every consonant in the sheet grid on the right shares these controls —
        move a slider and all 33 update together, live.
      </p>

      <hr class="sep">

      <div class="field">
        <label>Base size</label>
        <div class="slider-row">
          <input type="range" id="r-base-scale" min="50" max="100" step="1">
          <span class="val mono" id="v-base-scale">85%</span>
        </div>
      </div>
      <div class="field">
        <label>Stacked size</label>
        <div class="slider-row">
          <input type="range" id="r-scale" min="20" max="95" step="1">
          <span class="val mono" id="v-scale">50%</span>
        </div>
      </div>
      <p style="margin:-4px 0 0; font-size:0.76rem; color:var(--ink-dim); font-style:italic; line-height:1.4;">
        Both letters a little smaller than full size; the pair together a little taller than one letter alone — watch "Combined" below.
      </p>
      <div class="field">
        <label>Rotation</label>
        <div class="slider-row">
          <input type="range" id="r-rot" min="-45" max="45" step="1">
          <span class="val mono" id="v-rot">0°</span>
        </div>
      </div>
      <div class="field">
        <label>Horizontal nudge</label>
        <div class="slider-row">
          <input type="range" id="r-dx" min="-250" max="250" step="2">
          <span class="val mono" id="v-dx">0</span>
        </div>
      </div>
      <div class="field">
        <label>Vertical nudge</label>
        <div class="slider-row">
          <input type="range" id="r-dy" min="-140" max="200" step="2">
          <span class="val mono" id="v-dy">0</span>
        </div>
      </div>

      <div class="btn-row">
        <button class="btn" id="btn-reset-formula">Reset to formula</button>
        <button class="btn" id="btn-reset-global">Reset to global</button>
      </div>
      <div class="btn-row" id="row-save-pair">
        <button class="btn btn-primary" id="btn-save-pair">Save this pair</button>
      </div>
      <div class="btn-row" id="row-save-sheet" hidden>
        <button class="btn btn-primary" id="btn-save-sheet">Save for all 33</button>
      </div>
      <div class="btn-row">
        <button class="btn" id="btn-save-global">Save as global default</button>
      </div>

      <hr class="sep">

      <div class="field">
        <label>Saved stacked-letter / base-letter defaults</label>
        <div class="overrides-list" id="sheet-overrides-list">
          <div class="empty-note">None yet.</div>
        </div>
      </div>

      <div class="field">
        <label>Saved pair overrides</label>
        <div class="overrides-list" id="overrides-list">
          <div class="empty-note">None yet — every pair uses the global default.</div>
        </div>
      </div>

      <button class="btn" id="btn-export">Export config JSON</button>
    </div>

    <div class="stage-wrap">
      <div class="panel" id="single-panel">
        <div class="stage-row">
          <svg id="stage-svg" viewBox="-50 -80 1550 1650" xmlns="http://www.w3.org/2000/svg"></svg>
          <div class="dev-ref">
            <span class="dev-ref-label">Devanagari<br>reference</span>
            <span class="dev-ref-text" id="dev-ref-text">स्थ</span>
            <span class="dev-ref-note">same two letters, real Devanagari shaping — compare the silhouette</span>
          </div>
        </div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin-top:12px; flex-wrap:wrap; gap:10px;">
          <div class="legend">
            <span><span class="swatch" style="background:var(--base-color)"></span>base (fixed)</span>
            <span><span class="swatch" style="background:var(--stack-color)"></span>stacked (drag body to move, corner to resize, top handle to rotate)</span>
          </div>
        </div>
        <div class="readout" style="margin-top:12px;">
          <div><span class="k">Base size</span><span class="v mono" id="ro-base-scale">85%</span></div>
          <div><span class="k">Stacked size</span><span class="v mono" id="ro-scale">50%</span></div>
          <div><span class="k">Rotation</span><span class="v mono" id="ro-rot">0°</span></div>
          <div><span class="k">X offset</span><span class="v mono" id="ro-dx">0</span></div>
          <div><span class="k">Y offset</span><span class="v mono" id="ro-dy">0</span></div>
          <div><span class="k">Combined vs 1 letter</span><span class="v mono" id="ro-combined">1.00×</span></div>
        </div>
      </div>

      <div class="panel" id="sheet-panel" hidden>
        <div style="display:flex; justify-content:space-between; align-items:baseline; margin-bottom:12px; flex-wrap:wrap; gap:8px;">
          <h3 style="font-size:1.05rem;" id="sheet-title">All 33 bases with this stacked letter</h3>
          <div class="legend"><span class="v mono" id="sheet-combined-summary"></span></div>
        </div>
        <div class="sheet-grid" id="sheet-grid"></div>
      </div>

      <div class="panel">
        <h3 style="font-size:1.05rem; margin-bottom:12px;">Real dhaatu, composed with the current saved rules</h3>
        <div class="words-grid" id="words-grid"></div>
      </div>
    </div>
  </div>

  <footer>
    Letterforms: real Noto Sans Brahmi outlines (SIL OFL 1.1) — nothing drawn here is invented.
    Values are font units at 1000 UPM, matching <span class="mono">build_stacked.py</span>'s coordinate space exactly, so an exported config drops straight into the font build.
  </footer>
</div>

<script>
const GLYPHS = __GLYPHS_JSON__;
const CONS_ORDER = __CONS_ORDER_JSON__;
const VIRAMA = "__VIRAMA__";
const DY_TOP_DEFAULT = -40;
// Starting point for "both letters a little smaller than full size, but the
// stacked pair together only a little taller than one letter alone": the
// base itself now also shrinks (baseScale) instead of staying at 100%, and
// dyOffset is nudged up so the stacked form tucks in closer to the
// baseline rather than hanging far below it. Tune per pair with the pad;
// the "Combined vs 1 letter" readout is the number this rule is about.
const DEFAULTS = { baseScale: 0.85, scale: 0.5, rotation: 0, dxOffset: 0, dyOffset: 60 };
const STAGE_X = 560, BASELINE_Y = 820;

// ---------- Devanagari reference ----------
// Brahmi's own classical consonant order (KA..HA) is the same order as
// Devanagari's, position-for-position -- both descend from the same
// Brahmic sequence -- so CONS_ORDER's index into this array gives the
// exact corresponding Devanagari letter. Mapping this way (not writing
// each word's Devanagari spelling by hand) keeps the reference and the
// Brahmi rendering provably in sync: change a cps array and both follow.
const DEV_CONS = ["क","ख","ग","घ","ङ","च","छ","ज","झ","ञ","ट","ठ","ड","ढ","ण","त","थ","द","ध","न","प","फ","ब","भ","म","य","र","ल","व","श","ष","स","ह"];
const DEV_VIRAMA = "्";           // ्
const DEV_VOWEL = { "11038": "ा", "1103A": "ि", "1103C": "ु" }; // ा ि ु
function devFor(hex){
  const idx = CONS_ORDER.indexOf(hex);
  if (idx >= 0) return DEV_CONS[idx];
  if (hex === VIRAMA) return DEV_VIRAMA;
  if (DEV_VOWEL[hex]) return DEV_VOWEL[hex];
  return "";
}
function devanagariWord(cps){ return cps.map(devFor).join(""); }

function shortName(hex){
  const n = GLYPHS[hex].name || "";
  return n.replace("BRAHMI LETTER ", "").replace("BRAHMI SIGN ", "").replace("BRAHMI VOWEL SIGN ", "V:");
}
function ch(hex){ return String.fromCodePoint(parseInt(hex,16)); }

// ---------- state ----------
let globalDefault = { ...DEFAULTS };
let pairOverrides = {};    // "base-stack" -> {baseScale,scale,rotation,dxOffset,dyOffset}
let stackDefaults = {};    // stackHex -> same shape -- applies to every base with this stacked letter
let baseDefaults = {};     // baseHex -> same shape -- applies to every stacked letter on this base
let state = { baseCp: "11032", stackCp: "11023", ...DEFAULTS }; // SA + THA (sthA) as the opening example

// precedence: an exact pair override wins; then a rule for "always this
// stacked letter" or "always this base letter" (whichever was saved);
// then the plain global default.
function paramsFor(baseCp, stackCp){
  const key = pairKey(baseCp, stackCp);
  if (pairOverrides[key]) return pairOverrides[key];
  if (stackDefaults[stackCp]) return stackDefaults[stackCp];
  if (baseDefaults[baseCp]) return baseDefaults[baseCp];
  return globalDefault;
}

function pairKey(b, s){ return b + "-" + s; }
function currentKey(){ return pairKey(state.baseCp, state.stackCp); }

function loadPairIntoState(baseCp, stackCp){
  state = { baseCp, stackCp, ...DEFAULTS, ...paramsFor(baseCp, stackCp) };
}

// ---------- sheet mode ----------
let mode = "single";        // "single" | "byStack" | "byBase"
let sheetHex = "11023";     // the fixed consonant (THA, matching the opening single-pair example)
let sheetParams = { ...DEFAULTS };

function activeParams(){ return mode === "single" ? state : sheetParams; }
function rebuild(){ if (mode === "single") buildStage(); else buildSheet(); }

function loadSheetIntoParams(){
  const src = mode === "byStack" ? (stackDefaults[sheetHex] || globalDefault)
                                  : (baseDefaults[sheetHex] || globalDefault);
  sheetParams = { ...DEFAULTS, ...src };
}

// ---------- populate selects ----------
const selBase = document.getElementById("sel-base");
const selStack = document.getElementById("sel-stack");
CONS_ORDER.forEach(hex => {
  const label = ch(hex) + "  " + shortName(hex);
  selBase.insertAdjacentHTML("beforeend", `<option value="${hex}">${label}</option>`);
  selStack.insertAdjacentHTML("beforeend", `<option value="${hex}">${label}</option>`);
});
selBase.value = state.baseCp;
selStack.value = state.stackCp;

// ---------- SVG stage ----------
const svg = document.getElementById("stage-svg");
const NS = "http://www.w3.org/2000/svg";
function svgEl(tag, attrs){
  const e = document.createElementNS(NS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  return e;
}

function localCenter(hex){
  const b = GLYPHS[hex].bounds;
  return { cx: (b[0]+b[2])/2, cy: (b[1]+b[3])/2, ymax: b[3] };
}

let dragMode = null; // 'move' | 'rotate' | 'resize'
let dragStart = null;
let combinedRatio = 1;

// Shared geometry math for one base+stacked pair under a given params
// object -- used by the single-pair stage AND every cell of the sheet
// grid, so the two can never silently drift onto different formulas.
function computeStackGeometry(baseCp, stackCp, params){
  const baseG = GLYPHS[baseCp];
  const c = localCenter(stackCp);
  const targetCx = baseG.width/2 + params.dxOffset;
  const targetCy = (DY_TOP_DEFAULT + params.dyOffset) - params.scale * (c.ymax - c.cy);
  const b = GLYPHS[stackCp].bounds;
  const corners = [[b[0],b[1]],[b[2],b[1]],[b[2],b[3]],[b[0],b[3]]].map(([x,y])=>{
    const lx = x - c.cx, ly = y - c.cy;
    const rad = -params.rotation * Math.PI/180;
    const rx = lx*Math.cos(rad) - ly*Math.sin(rad);
    const ry = lx*Math.sin(rad) + ly*Math.cos(rad);
    return [targetCx + rx*params.scale, targetCy + ry*params.scale];
  });
  const singleHeight = baseG.bounds[3] - baseG.bounds[1];
  const scaledBaseTop = params.baseScale * baseG.bounds[3];
  const stackBottom = Math.min(...corners.map(p => p[1]));
  const ratio = (scaledBaseTop - stackBottom) / singleHeight;
  return { c, targetCx, targetCy, corners, ratio };
}
function ratioIsOk(r){ return r >= 1.02 && r <= 1.4; }

function buildStage(){
  svg.innerHTML = "";
  const world = svgEl("g", { transform: `translate(${STAGE_X},${BASELINE_Y}) scale(1,-1)` });
  svg.appendChild(world);

  // baseline guide
  world.appendChild(svgEl("line", { x1:-500, x2:900, y1:0, y2:0, stroke:"var(--guide)", "stroke-width":2, "vector-effect":"non-scaling-stroke" }));

  const baseG = GLYPHS[state.baseCp];

  // ---- base glyph, scaled in place (shrinks toward its own baseline
  // center, so it stays sitting on the baseline and centered in its own
  // advance width -- doesn't shift surrounding spacing) ----
  const baseCx = (baseG.bounds[0] + baseG.bounds[2]) / 2;
  const baseGrp = svgEl("g", { transform: `translate(${baseCx},0) scale(${state.baseScale}) translate(${-baseCx},0)` });
  baseGrp.appendChild(svgEl("path", { d: baseG.path, fill: "var(--base-color)" }));
  world.appendChild(baseGrp);

  // ---- stacked glyph, self-centered then scaled/rotated/translated ----
  const geo = computeStackGeometry(state.baseCp, state.stackCp, state);
  const { c, targetCx, targetCy, corners } = geo;

  const posG = svgEl("g", { transform: `translate(${targetCx},${targetCy}) rotate(${-state.rotation}) scale(${state.scale}) translate(${-c.cx},${-c.cy})`, id:"stacked-glyph" });
  posG.appendChild(svgEl("path", { d: GLYPHS[state.stackCp].path, fill: "var(--stack-color)" }));
  world.appendChild(posG);

  // ---- handles (drawn in world space at the glyph's screen-space bbox) ----
  const centerWorld = [targetCx, targetCy];

  // bounding outline (visual affordance)
  const outline = svgEl("polygon", { points: corners.map(p=>p.join(",")).join(" "), fill:"none", stroke:"var(--stack-color)", "stroke-dasharray":"6 6", "stroke-width":2, "vector-effect":"non-scaling-stroke", opacity:"0.6" });
  world.appendChild(outline);

  // move handle = the glyph body itself
  posG.style.cursor = "grab";
  posG.addEventListener("pointerdown", e => startDrag(e, "move"));

  // resize handle at corner[2] (top-right-ish after rotation)
  const resizeHandle = svgEl("circle", { cx:corners[2][0], cy:corners[2][1], r:16, fill:"var(--panel)", stroke:"var(--stack-color)", "stroke-width":3, class:"handle" });
  resizeHandle.addEventListener("pointerdown", e => startDrag(e, "resize"));
  world.appendChild(resizeHandle);

  // rotate handle above the top edge midpoint (corners[2]=top-right, corners[3]=top-left
  // in font space, since b[3]=ymax is the visual top when y is up)
  const topMid = [(corners[2][0]+corners[3][0])/2, (corners[2][1]+corners[3][1])/2];
  const dirX = topMid[0]-centerWorld[0], dirY = topMid[1]-centerWorld[1];
  const dirLen = Math.hypot(dirX,dirY) || 1;
  const handlePos = [topMid[0] + dirX/dirLen*60, topMid[1] + dirY/dirLen*60];
  world.appendChild(svgEl("line", { x1:topMid[0], y1:topMid[1], x2:handlePos[0], y2:handlePos[1], stroke:"var(--stack-color)", "stroke-width":2, "vector-effect":"non-scaling-stroke" }));
  const rotateHandle = svgEl("circle", { cx:handlePos[0], cy:handlePos[1], r:16, fill:"var(--stack-color)", stroke:"var(--panel)", "stroke-width":3, class:"handle" });
  rotateHandle.addEventListener("pointerdown", e => startDrag(e, "rotate"));
  world.appendChild(rotateHandle);

  // ---- combined-height check: "both a little smaller, together a little
  // taller than one letter" -- compare the full vertical span (top of the
  // scaled base to the bottom of the scaled/rotated stacked form) against
  // this base letter's own normal (unscaled) height ----
  combinedRatio = geo.ratio;

  document.getElementById("dev-ref-text").textContent = devanagariWord([state.baseCp, VIRAMA, state.stackCp]);

  updateReadouts();
}

// ---------- sheet stage: this consonant against all 33 of the other kind ----------
function buildSheet(){
  const grid = document.getElementById("sheet-grid");
  grid.innerHTML = "";
  document.getElementById("sheet-title").textContent = mode === "byStack"
    ? `All 33 bases with ${ch(sheetHex)} ${shortName(sheetHex)} stacked below`
    : `All 33 stacked letters under ${ch(sheetHex)} ${shortName(sheetHex)}`;

  const params = sheetParams;
  const ratios = [];

  CONS_ORDER.forEach(varHex => {
    const baseCp = mode === "byStack" ? varHex : sheetHex;
    const stackCp = mode === "byStack" ? sheetHex : varHex;
    const baseG = GLYPHS[baseCp];
    const geo = computeStackGeometry(baseCp, stackCp, params);
    ratios.push(geo.ratio);

    const cell = document.createElement("div");
    cell.className = "sheet-cell" + (ratioIsOk(geo.ratio) ? "" : " flag");

    const svgC = document.createElementNS(NS, "svg");
    svgC.setAttribute("viewBox", "-40 -60 900 1000");
    const g = svgEl("g", { transform: `translate(60,760) scale(1,-1)` });
    svgC.appendChild(g);
    g.appendChild(svgEl("line", { x1:-40, x2:800, y1:0, y2:0, stroke:"var(--guide)", "stroke-width":2, "vector-effect":"non-scaling-stroke" }));

    const bcx = (baseG.bounds[0] + baseG.bounds[2]) / 2;
    const baseGrp = svgEl("g", { transform: `translate(${bcx},0) scale(${params.baseScale}) translate(${-bcx},0)` });
    baseGrp.appendChild(svgEl("path", { d: baseG.path, fill: "var(--base-color)" }));
    g.appendChild(baseGrp);

    const pg = svgEl("g", { transform: `translate(${geo.targetCx},${geo.targetCy}) rotate(${-params.rotation}) scale(${params.scale}) translate(${-geo.c.cx},${-geo.c.cy})` });
    pg.appendChild(svgEl("path", { d: GLYPHS[stackCp].path, fill: "var(--stack-color)" }));
    g.appendChild(pg);

    cell.appendChild(svgC);
    const devLine = document.createElement("div");
    devLine.className = "dev";
    devLine.textContent = devanagariWord([baseCp, VIRAMA, stackCp]);
    cell.appendChild(devLine);
    const lbl = document.createElement("div");
    lbl.className = "lbl";
    lbl.textContent = shortName(varHex);
    cell.appendChild(lbl);
    const ratioEl = document.createElement("div");
    ratioEl.className = "ratio";
    ratioEl.textContent = geo.ratio.toFixed(2) + "×";
    cell.appendChild(ratioEl);
    grid.appendChild(cell);
  });

  const min = Math.min(...ratios), max = Math.max(...ratios);
  const avg = ratios.reduce((a,b)=>a+b, 0) / ratios.length;
  const outCount = ratios.filter(r => !ratioIsOk(r)).length;
  document.getElementById("sheet-combined-summary").textContent =
    `avg ${avg.toFixed(2)}× · range ${min.toFixed(2)}–${max.toFixed(2)}×` + (outCount ? ` · ${outCount} outside band` : "");

  updateReadouts();
}

function svgPointFromEvent(e){
  const pt = svg.createSVGPoint();
  pt.x = e.clientX; pt.y = e.clientY;
  const ctm = svg.getScreenCTM().inverse();
  const p = pt.matrixTransform(ctm);
  // undo the world transform: translate(STAGE_X,BASELINE_Y) scale(1,-1)
  return { fx: p.x - STAGE_X, fy: BASELINE_Y - p.y };
}

function startDrag(e, dragKind){
  e.preventDefault(); e.stopPropagation();
  const p = svgPointFromEvent(e);
  dragMode = dragKind;
  const c = localCenter(state.stackCp);
  const baseW = GLYPHS[state.baseCp].width;
  const centerFont = { x: baseW/2 + state.dxOffset, y: (DY_TOP_DEFAULT + state.dyOffset) - state.scale*(c.ymax-c.cy) };
  dragStart = {
    p, state: { ...state },
    centerFont,
    startDist: Math.hypot(p.fx-centerFont.x, p.fy-centerFont.y),
    startAngle: Math.atan2(p.fy-centerFont.y, p.fx-centerFont.x) * 180/Math.PI,
  };
  window.addEventListener("pointermove", onDrag);
  window.addEventListener("pointerup", endDrag);
}
function onDrag(e){
  if (!dragMode) return;
  const p = svgPointFromEvent(e);
  if (dragMode === "move"){
    state.dxOffset = Math.max(-250, Math.min(250, dragStart.state.dxOffset + (p.fx - dragStart.p.fx)));
    state.dyOffset = Math.max(-140, Math.min(200, dragStart.state.dyOffset + (p.fy - dragStart.p.fy)));
  } else if (dragMode === "resize"){
    const dist = Math.hypot(p.fx-dragStart.centerFont.x, p.fy-dragStart.centerFont.y);
    const ratio = dist / (dragStart.startDist || 1);
    state.scale = Math.max(0.2, Math.min(0.95, dragStart.state.scale * ratio));
  } else if (dragMode === "rotate"){
    const angle = Math.atan2(p.fy-dragStart.centerFont.y, p.fx-dragStart.centerFont.x) * 180/Math.PI;
    state.rotation = Math.max(-45, Math.min(45, dragStart.state.rotation - (angle - dragStart.startAngle)));
  }
  syncControlsFromState();
  buildStage();
}
function endDrag(){
  dragMode = null;
  window.removeEventListener("pointermove", onDrag);
  window.removeEventListener("pointerup", endDrag);
}

// ---------- sliders <-> state ----------
const rBaseScale = document.getElementById("r-base-scale"), vBaseScale = document.getElementById("v-base-scale");
const rScale = document.getElementById("r-scale"), vScale = document.getElementById("v-scale");
const rRot = document.getElementById("r-rot"), vRot = document.getElementById("v-rot");
const rDx = document.getElementById("r-dx"), vDx = document.getElementById("v-dx");
const rDy = document.getElementById("r-dy"), vDy = document.getElementById("v-dy");

function syncControlsFromState(){
  const p = activeParams();
  rBaseScale.value = Math.round(p.baseScale*100);
  rScale.value = Math.round(p.scale*100);
  rRot.value = Math.round(p.rotation);
  rDx.value = Math.round(p.dxOffset);
  rDy.value = Math.round(p.dyOffset);
  vBaseScale.textContent = Math.round(p.baseScale*100) + "%";
  vScale.textContent = Math.round(p.scale*100) + "%";
  vRot.textContent = Math.round(p.rotation) + "°";
  vDx.textContent = Math.round(p.dxOffset);
  vDy.textContent = Math.round(p.dyOffset);
}
function updateReadouts(){
  const p = activeParams();
  document.getElementById("ro-base-scale").textContent = Math.round(p.baseScale*100) + "%";
  document.getElementById("ro-scale").textContent = Math.round(p.scale*100) + "%";
  document.getElementById("ro-rot").textContent = Math.round(p.rotation) + "°";
  document.getElementById("ro-dx").textContent = Math.round(p.dxOffset);
  document.getElementById("ro-dy").textContent = Math.round(p.dyOffset);
  if (mode === "single"){
    const roCombined = document.getElementById("ro-combined");
    roCombined.textContent = combinedRatio.toFixed(2) + "×";
    roCombined.style.color = ratioIsOk(combinedRatio) ? "var(--ink)" : "var(--accent)";
  }
}
[[rBaseScale,"baseScale",0.01],[rScale,"scale",0.01],[rRot,"rotation",1],[rDx,"dxOffset",1],[rDy,"dyOffset",1]].forEach(([el,key,mult])=>{
  el.addEventListener("input", ()=>{
    activeParams()[key] = parseFloat(el.value)*mult;
    syncControlsFromState();
    rebuild();
  });
});

selBase.addEventListener("change", ()=>{
  if (mode === "single") loadPairIntoState(selBase.value, state.stackCp);
  else { sheetHex = selBase.value; loadSheetIntoParams(); }
  syncControlsFromState(); rebuild(); renderOverridesList(); renderSheetOverridesList();
});
selStack.addEventListener("change", ()=>{
  if (mode === "single") loadPairIntoState(state.baseCp, selStack.value);
  else { sheetHex = selStack.value; loadSheetIntoParams(); }
  syncControlsFromState(); rebuild(); renderOverridesList(); renderSheetOverridesList();
});

document.getElementById("btn-reset-formula").addEventListener("click", ()=>{
  if (mode === "single") state = { baseCp: state.baseCp, stackCp: state.stackCp, ...DEFAULTS };
  else sheetParams = { ...DEFAULTS };
  syncControlsFromState(); rebuild();
});
document.getElementById("btn-reset-global").addEventListener("click", ()=>{
  if (mode === "single") state = { baseCp: state.baseCp, stackCp: state.stackCp, ...DEFAULTS, ...globalDefault };
  else sheetParams = { ...DEFAULTS, ...globalDefault };
  syncControlsFromState(); rebuild();
});

// ---------- mode switching ----------
const modeButtons = document.querySelectorAll(".mode-btn");
function setMode(newMode){
  mode = newMode;
  modeButtons.forEach(b => b.classList.toggle("active", b.dataset.mode === mode));
  document.getElementById("single-panel").hidden = mode !== "single";
  document.getElementById("sheet-panel").hidden = mode === "single";
  document.getElementById("row-save-pair").hidden = mode !== "single";
  document.getElementById("row-save-sheet").hidden = mode === "single";
  document.getElementById("sheet-hint").hidden = mode === "single";
  document.getElementById("field-sel-base").hidden = mode === "byStack";
  document.getElementById("field-sel-stack").hidden = mode === "byBase";
  const btnSaveSheet = document.getElementById("btn-save-sheet");
  const labelBase = document.getElementById("label-sel-base");
  const labelStack = document.getElementById("label-sel-stack");
  if (mode === "single"){
    labelBase.textContent = "Base consonant (fixed)";
    labelStack.textContent = "Stacked consonant (movable)";
    selBase.value = state.baseCp; selStack.value = state.stackCp;
  } else if (mode === "byStack"){
    labelStack.textContent = "Stacked consonant (fixed for the whole sheet)";
    selStack.value = sheetHex;
    btnSaveSheet.textContent = "Save for all 33 bases";
    loadSheetIntoParams();
  } else if (mode === "byBase"){
    labelBase.textContent = "Base consonant (fixed for the whole sheet)";
    selBase.value = sheetHex;
    btnSaveSheet.textContent = "Save for all 33 stacked letters";
    loadSheetIntoParams();
  }
  syncControlsFromState();
  rebuild();
}
modeButtons.forEach(b => b.addEventListener("click", () => setMode(b.dataset.mode)));

// ---------- db ----------
let dbApi = null, downloadsApi = null;
const dbStatus = document.getElementById("db-status");
function setDbStatus(ok, msg){
  dbStatus.innerHTML = `<span class="status-dot ${ok?'status-ok':'status-off'}"></span>${msg}`;
}

(async () => {
  if (!window.claude || !window.claude.use){ setDbStatus(false, "no save support in this preview"); return; }
  try {
    dbApi = await window.claude.use("db");
    downloadsApi = await window.claude.use("downloads");
  } catch(e) { dbApi = null; }
  if (!dbApi){ setDbStatus(false, "saving unavailable in this view"); return; }
  setDbStatus(true, "saved placements sync live");

  dbApi.doc("config/global").onSnapshot(snap => {
    if (snap.exists) globalDefault = { ...DEFAULTS, ...snap.data() };
    if (mode === "single" && !pairOverrides[currentKey()] && !stackDefaults[state.stackCp] && !baseDefaults[state.baseCp]) {
      state = { ...state, ...globalDefault }; syncControlsFromState(); buildStage();
    }
  }, ()=>{});

  dbApi.collection("pairs").onSnapshot(qsnap => {
    pairOverrides = {};
    qsnap.docs.forEach(d => pairOverrides[d.id] = d.data());
    renderOverridesList();
  }, ()=>{});

  dbApi.collection("stackDefaults").onSnapshot(qsnap => {
    stackDefaults = {};
    qsnap.docs.forEach(d => stackDefaults[d.id] = d.data());
    renderSheetOverridesList();
    if (mode === "byStack") { loadSheetIntoParams(); syncControlsFromState(); buildSheet(); }
  }, ()=>{});

  dbApi.collection("baseDefaults").onSnapshot(qsnap => {
    baseDefaults = {};
    qsnap.docs.forEach(d => baseDefaults[d.id] = d.data());
    renderSheetOverridesList();
    if (mode === "byBase") { loadSheetIntoParams(); syncControlsFromState(); buildSheet(); }
  }, ()=>{});
})();

document.getElementById("btn-save-pair").addEventListener("click", async ()=>{
  if (!dbApi) return;
  const key = currentKey();
  await dbApi.collection("pairs").doc(key).set({
    baseCp: state.baseCp, stackCp: state.stackCp,
    baseScale: state.baseScale, scale: state.scale, rotation: state.rotation, dxOffset: state.dxOffset, dyOffset: state.dyOffset,
    updatedAt: new Date().toISOString(),
  });
});
document.getElementById("btn-save-sheet").addEventListener("click", async ()=>{
  if (!dbApi) return;
  const collection = mode === "byStack" ? "stackDefaults" : "baseDefaults";
  await dbApi.collection(collection).doc(sheetHex).set({
    baseScale: sheetParams.baseScale, scale: sheetParams.scale, rotation: sheetParams.rotation,
    dxOffset: sheetParams.dxOffset, dyOffset: sheetParams.dyOffset,
    updatedAt: new Date().toISOString(),
  });
});
document.getElementById("btn-save-global").addEventListener("click", async ()=>{
  if (!dbApi) return;
  const p = activeParams();
  await dbApi.doc("config/global").set({
    baseScale: p.baseScale, scale: p.scale, rotation: p.rotation, dxOffset: p.dxOffset, dyOffset: p.dyOffset,
    updatedAt: new Date().toISOString(),
  });
});

function renderOverridesList(){
  const list = document.getElementById("overrides-list");
  const keys = Object.keys(pairOverrides);
  if (!keys.length){ list.innerHTML = `<div class="empty-note">None yet — every pair uses the global default.</div>`; renderWords(); return; }
  list.innerHTML = "";
  keys.sort().forEach(key => {
    const [b,s] = key.split("-");
    const row = document.createElement("div");
    row.className = "override-row";
    row.innerHTML = `<span>${ch(b)}${ch(s)}&nbsp; <span class="mono" style="color:var(--ink-dim)">${shortName(b)}→${shortName(s)}</span></span><button class="del" title="delete">✕</button>`;
    row.addEventListener("click", (e)=>{
      if (e.target.classList.contains("del")) return;
      setMode("single");
      loadPairIntoState(b, s);
      selBase.value = b; selStack.value = s;
      syncControlsFromState(); buildStage();
    });
    row.querySelector(".del").addEventListener("click", async (e)=>{
      e.stopPropagation();
      if (dbApi) await dbApi.collection("pairs").doc(key).delete();
    });
    list.appendChild(row);
  });
  renderWords();
}

function renderSheetOverridesList(){
  const list = document.getElementById("sheet-overrides-list");
  const entries = [
    ...Object.keys(stackDefaults).map(hex => ({ axis: "stack", hex })),
    ...Object.keys(baseDefaults).map(hex => ({ axis: "base", hex })),
  ];
  if (!entries.length){ list.innerHTML = `<div class="empty-note">None yet.</div>`; return; }
  list.innerHTML = "";
  entries.forEach(({ axis, hex }) => {
    const row = document.createElement("div");
    row.className = "override-row";
    const label = axis === "stack"
      ? `all bases + ${ch(hex)} ${shortName(hex)} below`
      : `${ch(hex)} ${shortName(hex)} + all 33 stacked`;
    row.innerHTML = `<span>${label}</span><button class="del" title="delete">✕</button>`;
    row.addEventListener("click", (e)=>{
      if (e.target.classList.contains("del")) return;
      sheetHex = hex;
      setMode(axis === "stack" ? "byStack" : "byBase");
    });
    row.querySelector(".del").addEventListener("click", async (e)=>{
      e.stopPropagation();
      if (dbApi) await dbApi.collection(axis === "stack" ? "stackDefaults" : "baseDefaults").doc(hex).delete();
    });
    list.appendChild(row);
  });
}

document.getElementById("btn-export").addEventListener("click", async ()=>{
  const cfg = { global: globalDefault, pairs: pairOverrides, stackDefaults, baseDefaults };
  const text = JSON.stringify(cfg, null, 2);
  if (downloadsApi){
    try { await downloadsApi.save({ filename: "brahmi-placement-config.json", data: text }); return; } catch(e) {}
  }
  const w = window.open("", "_blank");
  if (w) { w.document.write("<pre>"+text.replace(/</g,"&lt;")+"</pre>"); }
});

// ---------- preview words, composed with current saved rules ----------
const WORDS = [
  { iast: "gam",  cps: ["11015","1102B","11046"] },
  { iast: "paTh", cps: ["11027","1101E","11046"] },
  { iast: "likh", cps: ["1102E","1103A","11014","11046"] },
  { iast: "sthA", cps: ["11032","11046","11023","11038"] },
  { iast: "kram", cps: ["11013","11046","1102D","1102B","11046"] },
  { iast: "j~nA", cps: ["1101A","11046","1101C","11038"] },
];
function renderWords(){
  const grid = document.getElementById("words-grid");
  grid.innerHTML = "";
  WORDS.forEach(w => {
    const card = document.createElement("div");
    card.className = "word-card";
    const devLine = document.createElement("div");
    devLine.className = "dev";
    devLine.textContent = devanagariWord(w.cps);
    card.appendChild(devLine);
    const svgW = document.createElementNS(NS, "svg");
    svgW.setAttribute("viewBox", "-40 -60 900 1000");
    const g = svgEl("g", { transform: `translate(60,820) scale(1,-1)` });
    svgW.appendChild(g);
    g.appendChild(svgEl("line", { x1:-40, x2:800, y1:0, y2:0, stroke:"var(--guide)", "stroke-width":2, "vector-effect":"non-scaling-stroke" }));
    let cursor = 0;
    const cps = w.cps;
    for (let i=0;i<cps.length;i++){
      const cp = cps[i];
      const gl = GLYPHS[cp];
      const stackCp = cps[i+2];
      const isConjunctBase = CONS_ORDER.includes(cp) && cps[i+1] === VIRAMA && stackCp && CONS_ORDER.includes(stackCp);
      if (isConjunctBase){
        const baseX = cursor;
        const params = { ...DEFAULTS, ...paramsFor(cp, stackCp) };

        // base, scaled in place (same shrink-toward-baseline-center as the stage)
        const bcx = (gl.bounds[0] + gl.bounds[2]) / 2;
        const baseGrp = svgEl("g", { transform: `translate(${baseX},0)` });
        const scaledGrp = svgEl("g", { transform: `translate(${bcx},0) scale(${params.baseScale}) translate(${-bcx},0)` });
        scaledGrp.appendChild(svgEl("path", { d: gl.path, fill: "var(--base-color)" }));
        baseGrp.appendChild(scaledGrp);
        g.appendChild(baseGrp);

        // stacked, centered under the base's own (unscaled) advance width --
        // baseX + half its width, not baseX + full width (which was this
        // preview's own bug: it had been centering on the base's right edge)
        const c = localCenter(stackCp);
        const cx = baseX + gl.width/2 + params.dxOffset;
        const cy = (DY_TOP_DEFAULT + params.dyOffset) - params.scale*(c.ymax-c.cy);
        const pg = svgEl("g", { transform: `translate(${cx},${cy}) rotate(${-params.rotation}) scale(${params.scale}) translate(${-c.cx},${-c.cy})` });
        pg.appendChild(svgEl("path", { d: GLYPHS[stackCp].path, fill: "var(--stack-color)" }));
        g.appendChild(pg);

        cursor += gl.width;
        i += 2; // consumed the virama and the stacked consonant too
        continue;
      }
      g.appendChild(svgEl("path", { d: gl.path, fill: "var(--base-color)", transform: `translate(${cursor},0)` }));
      cursor += gl.width;
    }
    card.appendChild(svgW);
    const cap = document.createElement("div");
    cap.className = "cap";
    cap.textContent = "root " + w.iast;
    card.appendChild(cap);
    grid.appendChild(card);
  });
}

setMode("single");
renderWords();
</script>
"""

html = html.replace("__GLYPHS_JSON__", GLYPHS_JSON)
html = html.replace("__CONS_ORDER_JSON__", json.dumps(CONS_ORDER))
html = html.replace("__VIRAMA__", VIRAMA)

with open(os.path.join(HERE, "pad.html"), "w") as f:
    f.write(html)
print("wrote pad.html", len(html), "bytes")
