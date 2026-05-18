#!/usr/bin/env python3
"""Generate STARRED_REPOS.md report — called by `crisp stars`"""
import json, subprocess, os, sys
from collections import defaultdict
from datetime import datetime

CRISP_DIR = os.path.expanduser("~/Documents/crisp")
STARS_FILE = os.path.join(CRISP_DIR, ".starred_repos")
REPORT_FILE = os.path.join(CRISP_DIR, "STARRED_REPOS.md")

def run(cmd, timeout=60, shell=False):
    if shell:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    if isinstance(cmd, str):
        cmd = cmd.split()
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)

# 1. Load stars
with open(STARS_FILE) as f:
    stars = sorted(set(l.strip().lower() for l in f if l.strip()))
print(f"Stars loaded: {len(stars)}")

# 2. Fetch metadata
result = run(["gh", "api", "user/starred", "--paginate", "--jq",
    '.[] | {name: .full_name, description: .description, language: .language, topics: .topics, html_url: .html_url}'])
repo_meta = {}
for line in result.stdout.strip().split('\n'):
    if line.strip():
        try: r = json.loads(line); repo_meta[r['name'].lower()] = r
        except: pass

# 3. Scan local git repos
result = run(r"""find ~ -maxdepth 6 -type d -name ".git" ! -path "*/node_modules/*" ! -path "*/.Trash/*" ! -path "*/.cache/*" ! -path "*/Library/*" ! -path "*/Caskroom/*" ! -path "*/__pycache__/*" ! -path "*/site-packages/*" 2>/dev/null | while read d; do dir=$(dirname "$d"); remote=$(cd "$dir" 2>/dev/null && git remote get-url origin 2>/dev/null); if [ -n "$remote" ]; then echo "$remote ||| $dir"; fi; done""", shell=True)
local_repos = defaultdict(list)
for line in result.stdout.strip().split('\n'):
    if ' ||| ' not in line: continue
    idx = line.index(' ||| ')
    remote, path = line[:idx].strip(), line[idx+4:].strip()
    norm = ""
    if 'github.com' in remote:
        if '://' in remote: norm = remote.split('github.com/')[-1].lower()
        elif 'git@' in remote: norm = remote.split('github.com:')[-1].lower()
        norm = norm.replace('.git', '')
    if norm: local_repos[norm].append(path)
print(f"Local git repos: {len(local_repos)}")

# 4. Scan Documents directories for name matches
result = run(r"""find ~/Documents ~/.hermes/skills ~/.claude ~/.openclaude -maxdepth 4 -type d ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | while read d; do echo "$(basename "$d" | tr '[:upper:]' '[:lower:]')"; done | sort -u""", shell=True)
doc_dirs = set(d.strip() for d in result.stdout.strip().split('\n') if d.strip())

# 5. Get pip/uv packages  
result = run("pip3 list --format=columns 2>/dev/null | tail -n +3 | awk '{print $1}' | tr '[:upper:]' '[:lower:]'", shell=True)
pip_pkgs = set(p.strip().replace('-','').replace('_','') for p in result.stdout.strip().split('\n') if p.strip())
result = run("uv tool list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '[:upper:]' '[:lower:]'", shell=True)
uv_pkgs = set(p.strip().replace('-','').replace('_','') for p in result.stdout.strip().split('\n') if p.strip())

# 4. Analyze
results = []
for star in stars:
    r = repo_meta.get(star, {})
    desc = (r.get('description') or '')[:120]
    topics = r.get('topics', [])
    lang = r.get('language') or ''
    is_own = star.startswith('enesdemir143/')
    url = r.get('html_url', f'https://github.com/{star}')
    found = []
    if star in local_repos:
        for p in local_repos[star]: found.append(('git clone', p))
    name_part = star.split('/')[1].lower()
    for norm, paths in local_repos.items():
        local_name = norm.split('/')[1] if '/' in norm else ""
        if local_name == name_part and norm != star:
            for p in paths: found.append((f"git ({norm})", p))
    if not found:
        if name_part in doc_dirs: found.append(('dizin', name_part))
    pkg_key = name_part.replace('-','').replace('_','')
    if pkg_key in pip_pkgs: found.append(('pip', ''))
    if pkg_key in uv_pkgs: found.append(('uv tool', ''))
    
    text = f"{desc} {' '.join(topics)} {lang}".lower()
    if is_own: cat = "Kendi Projesi"
    elif any(w in text for w in ['agent','claude','codex','skill','antigravity','copilot','hook','coding']): cat = "AI Agent & Coding"
    elif any(w in text for w in ['mcp','model-context']): cat = "MCP & Servis"
    elif any(w in text for w in ['llm','rag','pytorch','transformer','fine-tun','inference','gguf','mlx','deep-learning']): cat = "ML & LLM"
    elif any(w in text for w in ['research','paper','scientist','academic','arxiv']): cat = "Araştırma & Akademik"
    elif any(w in text for w in ['terminal','cli','shell','file-manager','editor']): cat = "Terminal & CLI"
    elif any(w in text for w in ['design','css','ui','front-end','figma']): cat = "Tasarım & UI"
    elif any(w in text for w in ['browser','scrape','crawl']): cat = "Browser & Web"
    elif any(w in text for w in ['database','memory','graph','vector']): cat = "DB & Bellek"
    elif any(w in text for w in ['finance','trading','stock']): cat = "Finans"
    elif any(w in text for w in ['macos','mac','apple']): cat = "macOS Araçları"
    elif any(w in text for w in ['pdf','document','markdown']): cat = "Döküman & PDF"
    else: cat = "Çeşitli"
    
    results.append({'star': star, 'desc': desc, 'cat': cat, 'found': found, 'url': url,
                    'status': 'MEVCUT' if (found or is_own) else ''})

# 5. Group
cats = defaultdict(list)
for r in results: cats[r['cat']].append(r)
total = len(results)
mevcut = sum(1 for r in results if r['status'])
kendi = sum(1 for r in results if r['star'].startswith('enesdemir143/'))

# 6. Generate markdown
cat_order = ["AI Agent & Coding", "ML & LLM", "MCP & Servis", "Browser & Web",
             "Araştırma & Akademik", "Terminal & CLI", "Döküman & PDF", "Tasarım & UI",
             "DB & Bellek", "Finans", "macOS Araçları", "Kendi Projesi", "Çeşitli"]

md = []
md.append("# ⭐ GitHub Starred Repos — EnesDemir143")
md.append("")
md.append(f"**Toplam:** {total} star | **Lokalda mevcut:** {mevcut} | **Kendi projeleri:** {kendi}")
md.append("")
md.append(f"> Son güncelleme: {datetime.now().strftime('%d.%m.%Y %H:%M')}")
md.append("")
md.append("---")
md.append("")
md.append("| İkon | Anlamı |")
md.append("|------|--------|")
md.append("| ⭐ | Kendi projen |")
md.append("| 📌 | Lokalde mevcut (git clone / fork / dizin) |")
md.append("| | Sadece star, lokalda yok |")
md.append("")

for cat in cat_order:
    items = cats.get(cat, [])
    if not items: continue
    local_in_cat = sum(1 for r in items if r['status'])
    md.append(f"## 📁 {cat} ({len(items)} repo, {local_in_cat} lokalda)")
    md.append("")
    md.append("| Repo | Açıklama | Durum |")
    md.append("|------|----------|-------|")
    for r in sorted(items, key=lambda x: (not x['status'], x['star'])):
        desc_short = (r['desc'] or '—')[:80].replace('|', '/')
        if r['star'].startswith('enesdemir143/'): icon, st = '⭐', 'Kendi'
        elif r['status']: icon, st = '📌', 'Mevcut'
        else: icon, st = '', 'Yok'
        md.append(f"| [{r['star']}]({r['url']}) | {desc_short} | {icon} {st} |")
    md.append("")

# Category distribution
md.append("## 📊 Kategori Dağılımı")
md.append("")
md.append("| Kategori | Adet | Lokalde |")
md.append("|----------|------|---------|")
for cat in cat_order:
    items = cats.get(cat, [])
    if not items: continue
    local_count = sum(1 for r in items if r['status'])
    md.append(f"| {cat} | {len(items)} | {local_count} |")
md.append(f"| **Toplam** | **{total}** | **{mevcut}** |")
md.append("")
md.append("---")
md.append("")
md.append("## Notlar")
md.append("")
md.append("- `crisp repos` ile git clone olan repolar otomatik güncellenir")
md.append("- `crisp stars` ile bu rapor yeniden oluşturulur")
md.append("- Yeni star eklediğinde `crisp stars` çalıştırman yeterli")

content = '\n'.join(md) + '\n'
with open(REPORT_FILE, 'w') as f:
    f.write(content)
print(f"✓ {REPORT_FILE}")
print(f"  {total} stars • {mevcut} local • {len(cat_order)} categories")
