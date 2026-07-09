#!/usr/bin/env python3
"""
jfrog_metrics_viz.py — turn a JFrog OpenMetrics/Prometheus dump into an HTML report.

Usage:
    python jfrog_metrics_viz.py                       # reads metrics.txt -> metrics-report.html
    python jfrog_metrics_viz.py path/to/metrics.txt   # reads that file
    python jfrog_metrics_viz.py metrics.txt -o out.html
    python jfrog_metrics_viz.py metrics.txt --open     # open in browser when done

No third-party dependencies. Standard library only. Python 3.7+.
The parsing/charting happens in the generated HTML (client-side), so the report
is a single portable file you can open anywhere or email to someone.
"""

import argparse
import os
import sys
import webbrowser

# The metrics text is injected where __METRICS_DATA__ sits, inside a JS template
# literal. Everything else is the viewer you already saw.
HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>JFrog Metrics Reader</title>
<style>
  :root{
    --bg:#0d1014; --panel:#151a21; --panel-2:#1b212a; --line:#262e39;
    --line-soft:#1f2630; --ink:#e8eef4; --muted:#8a97a6; --faint:#5b6776;
    --accent:#46c156; --accent-dim:#46c1561a; --track:#222a34;
    --gauge:#5cc8d8; --counter:#46c156; --summary:#e0a93b;
    --histogram:#a779e0; --untyped:#8a97a6;
    --mono: ui-monospace,"SF Mono","JetBrains Mono",Menlo,Consolas,monospace;
    --sans: ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    --radius:10px;
  }
  *{box-sizing:border-box} html,body{margin:0}
  body{background:var(--bg);color:var(--ink);font-family:var(--sans);line-height:1.5;-webkit-font-smoothing:antialiased}
  .wrap{max-width:1320px;margin:0 auto;padding:28px 22px 80px}
  header.mast{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;flex-wrap:wrap;padding-bottom:18px;border-bottom:1px solid var(--line)}
  .brand{display:flex;align-items:center;gap:13px}
  .glyph{width:34px;height:34px;border-radius:8px;flex:none;background:radial-gradient(120% 120% at 30% 20%,#5fe06f,#2c9a3a);position:relative;box-shadow:0 0 0 1px #ffffff14,0 6px 20px #46c15633}
  .glyph::before,.glyph::after{content:"";position:absolute;width:6px;height:6px;border-radius:50%;background:#0d1014;top:9px}
  .glyph::before{left:9px}.glyph::after{right:9px}
  h1{font-size:20px;letter-spacing:-.01em;margin:0;font-weight:680}
  h1 span{color:var(--muted);font-weight:480}
  .sub{font-size:12.5px;color:var(--faint);margin-top:2px;font-family:var(--mono);letter-spacing:.02em}
  .scrape{font-family:var(--mono);font-size:12px;color:var(--muted);text-align:right;line-height:1.7}
  .scrape b{color:var(--ink);font-weight:600}
  .io{margin-top:18px;background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);overflow:hidden}
  .io-head{display:flex;align-items:center;gap:12px;padding:11px 14px;cursor:pointer;user-select:none}
  .io-head .lbl{font-size:12.5px;font-weight:600;letter-spacing:.02em}
  .io-head .hint{font-size:12px;color:var(--faint);font-family:var(--mono)}
  .chev{margin-left:auto;color:var(--muted);transition:transform .18s ease;font-size:13px}
  .io.collapsed .chev{transform:rotate(-90deg)}
  .io-body{border-top:1px solid var(--line-soft);padding:14px}
  .io.collapsed .io-body{display:none}
  textarea{width:100%;height:190px;resize:vertical;background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:12px 13px;font-family:var(--mono);font-size:12.5px;line-height:1.55;outline:none}
  textarea:focus{border-color:#384556}
  .io-actions{display:flex;gap:10px;margin-top:12px;flex-wrap:wrap}
  button{font-family:var(--sans);font-size:13px;font-weight:600;cursor:pointer;border-radius:8px;border:1px solid var(--line);padding:8px 16px;background:var(--panel-2);color:var(--ink);transition:.14s}
  button:hover{border-color:#3a4656}
  button.primary{background:var(--accent);border-color:var(--accent);color:#06210a}
  button.primary:hover{filter:brightness(1.08)}
  .err{color:#e0a93b;font-size:12.5px;font-family:var(--mono);align-self:center}
  .summary{display:flex;gap:10px;flex-wrap:wrap;margin-top:20px}
  .stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px 16px;min-width:118px}
  .stat .n{font-family:var(--mono);font-size:22px;font-weight:600;letter-spacing:-.02em}
  .stat .k{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.07em;margin-top:3px}
  .stat .n.g{color:var(--gauge)}.stat .n.c{color:var(--counter)}.stat .n.s{color:var(--summary)}.stat .n.h{color:var(--histogram)}
  .toolbar{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:24px 0 6px}
  .search{flex:1 1 240px;position:relative;min-width:200px}
  .search input{width:100%;background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:9px 12px 9px 34px;color:var(--ink);font-family:var(--mono);font-size:13px;outline:none}
  .search input:focus{border-color:#384556}
  .search svg{position:absolute;left:11px;top:50%;transform:translateY(-50%);width:14px;height:14px;stroke:var(--faint)}
  .pills{display:flex;gap:6px;flex-wrap:wrap}
  .pill{font-size:12px;font-family:var(--mono);padding:7px 11px;border-radius:7px;border:1px solid var(--line);background:var(--panel);color:var(--muted);cursor:pointer;transition:.13s;text-transform:lowercase}
  .pill:hover{color:var(--ink)}
  .pill.on{background:var(--panel-2);color:var(--ink);border-color:#3a4656}
  .pill .dot{display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:6px;vertical-align:middle}
  .toggle{font-size:12px;font-family:var(--mono);color:var(--muted);display:flex;align-items:center;gap:7px;cursor:pointer;user-select:none}
  .toggle input{accent-color:var(--accent);width:15px;height:15px}
  select{font-family:var(--mono);font-size:12px;background:var(--panel);color:var(--ink);border:1px solid var(--line);border-radius:7px;padding:7px 9px;outline:none}
  .count-line{font-size:12px;color:var(--faint);font-family:var(--mono);margin:14px 2px 4px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:14px;margin-top:8px}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);padding:16px 16px 15px;display:flex;flex-direction:column;min-width:0}
  .card-top{display:flex;align-items:flex-start;gap:10px;margin-bottom:4px}
  .mname{font-family:var(--mono);font-size:13px;font-weight:600;color:var(--ink);word-break:break-word;line-height:1.35;flex:1;min-width:0}
  .badge{font-family:var(--mono);font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;padding:3px 7px;border-radius:5px;flex:none;white-space:nowrap}
  .help{font-size:12px;color:var(--muted);margin:2px 0 13px;line-height:1.45}
  .bars{display:flex;flex-direction:column;gap:8px}
  .bar-row{display:grid;grid-template-columns:1fr auto;gap:4px 10px;align-items:center}
  .bar-lbl{font-family:var(--mono);font-size:11.5px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;grid-column:1}
  .bar-lbl .k{color:var(--faint)}
  .bar-val{font-family:var(--mono);font-size:12px;color:var(--ink);text-align:right;grid-column:2;font-variant-numeric:tabular-nums}
  .bar-track{grid-column:1 / -1;height:6px;background:var(--track);border-radius:4px;overflow:hidden}
  .bar-fill{height:100%;border-radius:4px;background:var(--accent);min-width:0;transition:width .5s cubic-bezier(.2,.7,.2,1)}
  .big{font-family:var(--mono);font-size:34px;font-weight:600;letter-spacing:-.02em;line-height:1.1;margin:6px 0 2px}
  .big small{font-size:14px;color:var(--muted);font-weight:500;margin-left:4px}
  .qchart{margin-top:4px}
  .qchart svg{width:100%;height:96px;display:block;overflow:visible}
  .qaxis{display:flex;justify-content:space-between;font-family:var(--mono);font-size:10.5px;color:var(--faint);margin-top:5px}
  .qaxis span b{color:var(--muted);font-weight:600}
  .divider{height:1px;background:var(--line-soft);margin:14px 0 12px}
  .other-lbl{font-family:var(--mono);font-size:10.5px;color:var(--faint);text-transform:uppercase;letter-spacing:.06em;margin-bottom:9px}
  .allzero{font-family:var(--mono);font-size:11px;color:var(--faint);margin-top:9px}
  .allzero::before{content:"\25CB  ";color:var(--accent)}
  .empty{text-align:center;color:var(--faint);font-family:var(--mono);font-size:13px;padding:60px 0}
  @media (max-width:560px){.grid{grid-template-columns:1fr}.scrape{text-align:left}header.mast{align-items:flex-start}}
</style>
</head>
<body>
<div class="wrap">
  <header class="mast">
    <div class="brand">
      <div class="glyph"></div>
      <div><h1>JFrog Metrics <span>/ reader</span></h1>
        <div class="sub">api/v1/metrics/application &middot; openmetrics</div></div>
    </div>
    <div class="scrape" id="scrape"></div>
  </header>
  <div class="io" id="io">
    <div class="io-head" id="ioHead">
      <span class="lbl">Metrics input</span>
      <span class="hint">paste a dump &amp; re-visualize</span>
      <span class="chev">&#9662;</span>
    </div>
    <div class="io-body">
      <textarea id="raw" spellcheck="false"></textarea>
      <div class="io-actions">
        <button class="primary" id="go">Visualize</button>
        <button id="clear">Clear</button>
        <span class="err" id="err"></span>
      </div>
    </div>
  </div>
  <div class="summary" id="summary"></div>
  <div class="toolbar" id="toolbar" style="display:none">
    <div class="search">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
      <input id="q" placeholder="filter by name or description&hellip;" />
    </div>
    <div class="pills" id="typePills"></div>
    <label class="toggle"><input type="checkbox" id="hideZero"> hide all-zero</label>
    <select id="sort">
      <option value="name">sort: name</option>
      <option value="series">sort: most series</option>
      <option value="max">sort: highest value</option>
    </select>
  </div>
  <div class="count-line" id="countLine" style="display:none"></div>
  <div class="grid" id="grid"></div>
</div>
<script>
const SAMPLE = `__METRICS_DATA__`;
const TYPE_COLORS = {gauge:'--gauge',counter:'--counter',summary:'--summary',histogram:'--histogram',untyped:'--untyped'};
function parseLabels(str){const out=[];const re=/([a-zA-Z_][\w]*)\s*=\s*"((?:\\.|[^"\\])*)"/g;let m;while((m=re.exec(str)))out.push([m[1],m[2].replace(/\\"/g,'"').replace(/\\\\/g,'\\')]);return out;}
function parseValue(v){if(v==null)return NaN;if(v==='+Inf'||v==='Inf')return Infinity;if(v==='-Inf')return -Infinity;if(v==='NaN')return NaN;return Number(v);}
function parseSample(line){const nm=line.match(/^([a-zA-Z_:][\w:]*)/);if(!nm)return null;const name=nm[1];let rest=line.slice(name.length).trim();let labels=[];if(rest.startsWith('{')){const end=rest.indexOf('}');if(end<0)return null;labels=parseLabels(rest.slice(1,end));rest=rest.slice(end+1).trim();}const parts=rest.split(/\s+/);return {name,labels,value:parseValue(parts[0]),ts:parts.length>1&&/^\d+$/.test(parts[1])?Number(parts[1]):null};}
function parse(text){const fams=new Map();const fam=n=>{if(!fams.has(n))fams.set(n,{name:n,type:'untyped',help:'',samples:[]});return fams.get(n);};let tsSeen=null;for(const raw of text.split(/\r?\n/)){const line=raw.trim();if(!line)continue;if(line[0]==='#'){const m=line.match(/^#\s*(HELP|TYPE)\s+(\S+)\s*(.*)$/i);if(m){if(m[1].toUpperCase()==='TYPE')fam(m[2]).type=m[3].trim().toLowerCase()||'untyped';else fam(m[2]).help=m[3].trim();}continue;}const s=parseSample(line);if(s){fam(s.name).samples.push(s);if(s.ts)tsSeen=s.ts;}}for(const f of fams.values())if(!f.samples.length)fams.delete(f.name);return {families:[...fams.values()],ts:tsSeen};}
function fmtNum(v,name){if(!isFinite(v))return v>0?'\u221e':(v<0?'-\u221e':'NaN');if(v===0)return '0';if(/bytes/.test(name))return fmtBytes(v);if(/seconds$/.test(name))return fmtSeconds(v);const a=Math.abs(v);if(a>=1e9)return (v/1e9).toFixed(2).replace(/\.?0+$/,'')+'B';if(a>=1e6)return (v/1e6).toFixed(2).replace(/\.?0+$/,'')+'M';if(a>=1e3)return (v/1e3).toFixed(2).replace(/\.?0+$/,'')+'K';if(Number.isInteger(v))return v.toLocaleString();return v.toPrecision(4).replace(/\.?0+$/,'');}
function fmtBytes(v){const u=['B','KB','MB','GB','TB','PB'];let i=0,n=Math.abs(v);while(n>=1024&&i<u.length-1){n/=1024;i++;}return (v<0?'-':'')+n.toFixed(n<10&&i>0?2:1).replace(/\.?0+$/,'')+' '+u[i];}
function fmtSeconds(v){const a=Math.abs(v);if(a<1e-3)return (v*1e6).toFixed(0)+' \u00b5s';if(a<1)return (v*1e3).toFixed(a<0.01?2:1).replace(/\.?0+$/,'')+' ms';if(a<60)return v.toFixed(2).replace(/\.?0+$/,'')+' s';if(a<3600)return (v/60).toFixed(1).replace(/\.?0+$/,'')+' m';return (v/3600).toFixed(1).replace(/\.?0+$/,'')+' h';}
function seriesLabel(labels){if(!labels.length)return '\u00b7';if(labels.length===1)return labels[0][1];return labels.map(([k,v])=>`<span class="k">${k}=</span>${v}`).join(' \u00b7 ');}
function quantileSplit(f){const q=[],other=[];for(const s of f.samples){const ql=s.labels.find(l=>l[0]==='quantile');if(ql)q.push({...s,q:parseFloat(ql[1])});else other.push(s);}q.sort((a,b)=>a.q-b.q);return {q,other};}
function familyMax(f){return Math.max(0,...f.samples.map(s=>isFinite(s.value)?Math.abs(s.value):0));}
function familyAllZero(f){return f.samples.every(s=>s.value===0);}
function quantileChartSVG(q,name){const W=300,H=80,pad=6;const vals=q.map(s=>isFinite(s.value)?s.value:0);const max=Math.max(...vals,0)||1;const n=q.length;const x=i=>n<2?W/2:pad+i*(W-2*pad)/(n-1);const y=v=>H-pad-(v/max)*(H-2*pad);const allZero=vals.every(v=>v===0);const pts=q.map((s,i)=>[x(i),allZero?H-pad-2:y(s.value)]);const line=pts.map((p,i)=>(i?'L':'M')+p[0].toFixed(1)+' '+p[1].toFixed(1)).join(' ');const area=`M ${pts[0][0]} ${H-pad} `+pts.map(p=>'L'+p[0].toFixed(1)+' '+p[1].toFixed(1)).join(' ')+` L ${pts[n-1][0]} ${H-pad} Z`;const dots=pts.map((p,i)=>`<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="3.2" fill="var(--accent)" stroke="var(--panel)" stroke-width="1.5"><title>p${(q[i].q*100)}: ${fmtNum(q[i].value,name)}</title></circle>`).join('');return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none"><path d="${area}" fill="var(--accent-dim)"/><path d="${line}" fill="none" stroke="var(--accent)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>${dots}</svg>`;}
function barsHTML(samples,max,name){return `<div class="bars">`+samples.map(s=>{const v=isFinite(s.value)?s.value:0;const pct=max>0?Math.max(v>0?2:0,(Math.abs(v)/max)*100):0;return `<div class="bar-row"><div class="bar-lbl" title="${seriesLabel(s.labels).replace(/<[^>]+>/g,'')}">${seriesLabel(s.labels)}</div><div class="bar-val">${fmtNum(s.value,name)}</div><div class="bar-track"><div class="bar-fill" style="width:${pct.toFixed(1)}%"></div></div></div>`;}).join('')+`</div>`;}
function renderCard(f){const col=`var(${TYPE_COLORS[f.type]||'--untyped'})`;const {q,other}=quantileSplit(f);let viz='';if(q.length){viz+=`<div class="qchart">${quantileChartSVG(q,f.name)}<div class="qaxis">${q.map(s=>`<span><b>p${(s.q*100)}</b><br>${fmtNum(s.value,f.name)}</span>`).join('')}</div></div>`;if(other.length){viz+=`<div class="divider"></div><div class="other-lbl">other series</div>`+barsHTML(other,familyMax(f),f.name);}}else if(f.samples.length===1&&f.samples[0].labels.length===0){viz+=`<div class="big">${fmtNum(f.samples[0].value,f.name)}</div>`;}else{const sorted=[...f.samples].sort((a,b)=>Math.abs(b.value)-Math.abs(a.value));viz+=barsHTML(sorted,familyMax(f),f.name);}if(familyAllZero(f))viz+=`<div class="allzero">all series at zero \u00b7 ${f.samples.length} tracked</div>`;return `<div class="card"><div class="card-top"><div class="mname">${f.name}</div><span class="badge" style="color:${col};background:${col}1a">${f.type}</span></div>${f.help?`<div class="help">${f.help}</div>`:''}${viz}</div>`;}
let STATE={families:[],ts:null};const els={};
['raw','go','clear','err','io','ioHead','summary','toolbar','q','typePills','hideZero','sort','grid','countLine','scrape'].forEach(id=>els[id]=document.getElementById(id));
let filter={text:'',type:'all',hideZero:false,sort:'name'};
function build(){const {families}=STATE;const counts={};families.forEach(f=>counts[f.type]=(counts[f.type]||0)+1);const totalSeries=families.reduce((a,f)=>a+f.samples.length,0);const cls={gauge:'g',counter:'c',summary:'s',histogram:'h'};els.summary.innerHTML=`<div class="stat"><div class="n">${families.length}</div><div class="k">families</div></div><div class="stat"><div class="n">${totalSeries}</div><div class="k">series</div></div>`+Object.entries(counts).sort().map(([t,c])=>`<div class="stat"><div class="n ${cls[t]||''}">${c}</div><div class="k">${t}</div></div>`).join('');if(STATE.ts){const d=new Date(STATE.ts);els.scrape.innerHTML=`scraped<br><b>${d.toLocaleString(undefined,{dateStyle:'medium',timeStyle:'medium'})}</b>`;}else els.scrape.innerHTML='';const types=['all',...Object.keys(counts).sort()];els.typePills.innerHTML=types.map(t=>{const col=t==='all'?'--muted':(TYPE_COLORS[t]||'--untyped');const dot=t==='all'?'':`<span class="dot" style="background:var(${col})"></span>`;return `<span class="pill ${filter.type===t?'on':''}" data-type="${t}">${dot}${t}</span>`;}).join('');els.typePills.querySelectorAll('.pill').forEach(p=>p.onclick=()=>{filter.type=p.dataset.type;build();});els.toolbar.style.display='flex';els.countLine.style.display='block';render();}
function render(){let list=STATE.families.slice();const t=filter.text.toLowerCase();if(t)list=list.filter(f=>f.name.toLowerCase().includes(t)||(f.help||'').toLowerCase().includes(t));if(filter.type!=='all')list=list.filter(f=>f.type===filter.type);if(filter.hideZero)list=list.filter(f=>!familyAllZero(f));if(filter.sort==='name')list.sort((a,b)=>a.name.localeCompare(b.name));else if(filter.sort==='series')list.sort((a,b)=>b.samples.length-a.samples.length||a.name.localeCompare(b.name));else if(filter.sort==='max')list.sort((a,b)=>familyMax(b)-familyMax(a)||a.name.localeCompare(b.name));els.countLine.textContent=`showing ${list.length} of ${STATE.families.length} metric families`;els.grid.innerHTML=list.length?list.map(renderCard).join(''):`<div class="empty" style="grid-column:1/-1">no metrics match this filter</div>`;}
function visualize(){const txt=els.raw.value.trim();if(!txt){els.err.textContent='paste some metrics first';return;}const res=parse(txt);if(!res.families.length){els.err.textContent='no valid metric lines found \u2014 check the format';return;}els.err.textContent='';STATE=res;els.io.classList.add('collapsed');build();}
els.go.onclick=visualize;els.clear.onclick=()=>{els.raw.value='';els.err.textContent='';els.raw.focus();};els.ioHead.onclick=()=>els.io.classList.toggle('collapsed');els.q.oninput=()=>{filter.text=els.q.value;render();};els.hideZero.onchange=()=>{filter.hideZero=els.hideZero.checked;render();};els.sort.onchange=()=>{filter.sort=els.sort.value;render();};
els.raw.value=SAMPLE;visualize();
</script>
</body>
</html>
"""


def js_escape(text: str) -> str:
    """Make text safe to drop inside a JS backtick template literal."""
    text = text.replace("\\", "\\\\")      # escape backslashes first
    text = text.replace("`", "\\`")        # escape backticks
    text = text.replace("${", "\\${")      # escape template interpolation
    text = text.replace("</script", "<\\/script")  # don't close the script tag early
    return text


def build_report(metrics_text: str) -> str:
    return HTML_TEMPLATE.replace("__METRICS_DATA__", js_escape(metrics_text))


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Generate an HTML report from a JFrog OpenMetrics/Prometheus dump.")
    ap.add_argument("input", nargs="?", default="metrics.txt",
                    help="path to the metrics file (default: metrics.txt)")
    ap.add_argument("-o", "--output", default=None,
                    help="output HTML path (default: <input>-report.html)")
    ap.add_argument("--open", action="store_true",
                    help="open the report in your browser when done")
    args = ap.parse_args(argv)

    if not os.path.isfile(args.input):
        sys.exit(f"error: input file not found: {args.input}")

    with open(args.input, "r", encoding="utf-8", errors="replace") as fh:
        metrics_text = fh.read()

    if not metrics_text.strip():
        sys.exit(f"error: {args.input} is empty")

    out = args.output or (os.path.splitext(args.input)[0] + "-report.html")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(build_report(metrics_text))

    # Quick stats for the console
    lines = [l.strip() for l in metrics_text.splitlines() if l.strip()]
    samples = [l for l in lines if not l.startswith("#")]
    families = {l.split("{")[0].split()[0] for l in samples}
    print(f"  read    {args.input}  ({len(samples)} series, ~{len(families)} families)")
    print(f"  wrote   {out}")
    if args.open:
        webbrowser.open("file://" + os.path.abspath(out))
        print("  opened in browser")


if __name__ == "__main__":
    main()
