#!/usr/bin/env python3
"""
crisp scan engine — reads READMEs of all starred repos, detects install methods,
cross-references with local machine, updates STARRED_REPOS.md, suggests new crisp modules.
"""
import json, subprocess, os, re, base64
from collections import defaultdict
from datetime import datetime

CRISP_DIR = os.path.expanduser("~/Documents/crisp")
STARS_FILE = os.path.join(CRISP_DIR, ".starred_repos")
REPORT_FILE = os.path.join(CRISP_DIR, "STARRED_REPOS.md")
AUTO_CONF = os.path.join(CRISP_DIR, ".auto_modules")

HOME = os.path.expanduser("~")

# Ensure full PATH for subprocess calls (Homebrew, pipx, etc.)
ENV = os.environ.copy()
ENV["PATH"] = f"/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:{ENV.get('PATH', '')}"

# ── helpers ──────────────────────────────────────────────
def run(cmd, timeout=60, shell=False):
    if shell:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout, env=ENV)
    if isinstance(cmd, str):
        cmd = cmd.split()
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=ENV)

def inform(msg):
    print(f"  ℹ {msg}")

def ok(msg):
    print(f"  ✓ {msg}")

def warn(msg):
    print(f"  ⚠ {msg}")

def err(msg):
    print(f"  ✗ {msg}")

def gh_api(endpoint, jq=None):
    """Call gh api with optional jq filter. Returns stdout."""
    cmd = ["gh", "api", endpoint]
    if jq:
        cmd.extend(["--jq", jq])
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env=ENV)
    if r.returncode != 0:
        return ""
    return r.stdout.strip()

# ── local system checkers ────────────────────────────────
def check_tool(prog):
    return run(f"command -v {prog} 2>/dev/null", shell=True, timeout=5).returncode == 0

def check_pip(pkg):
    r = run(f"pip3 list --format=columns 2>/dev/null | grep -qi '^{pkg.replace('-','').replace('_','.')}'", shell=True, timeout=5)
    return r.returncode == 0

def check_brew(pkg):
    r = run(f"brew list {pkg} 2>/dev/null", timeout=10)
    return r.returncode == 0

def check_npm(pkg):
    r = run(f"npm list -g --depth=0 2>/dev/null | grep -qi '{pkg}'", shell=True, timeout=10)
    return r.returncode == 0

def check_cargo(pkg):
    r = run(f"cargo install --list 2>/dev/null | grep -qi '{pkg}'", shell=True, timeout=10)
    return r.returncode == 0

def check_uv_tool(pkg):
    r = run(f"uv tool list 2>/dev/null | grep -qi '{pkg}'", shell=True, timeout=5)
    return r.returncode == 0

def check_pipx(pkg):
    r = run(f"pipx list 2>/dev/null | grep -qi '{pkg}'", shell=True, timeout=5)
    return r.returncode == 0

def check_dir(path):
    return os.path.isdir(os.path.expanduser(path))

def check_git_clone(repo_full):
    """Check if this repo is cloned anywhere under HOME (cached)."""
    # Use a subprocess to find - already cached in local_repos
    return None  # Will be filled by calling code

# ── parse README for install methods ─────────────────────
INSTALL_PATTERNS = [
    # (pattern_regex, method_name, check_function, param_group)
    (r'pip\s+install\s+(\S+)', 'pip', check_pip, 1),
    (r'pip3\s+install\s+(\S+)', 'pip', check_pip, 1),
    (r'brew\s+(install|reinstall)\s+(\S+)', 'brew', check_brew, 2),
    (r'brew tap.*\n.*brew\s+install\s+(\S+)', 'brew', check_brew, 1),
    (r'npm\s+(install|i|add)\s+-g\s+(\S+)', 'npm', check_npm, 2),
    (r'npm\s+(install|i)\s+-g\s+(\S+)', 'npm', check_npm, 2),
    (r'cargo\s+install\s+(\S+)', 'cargo', check_cargo, 1),
    (r'uv\s+tool\s+install\s+(\S+)', 'uv', check_uv_tool, 1),
    (r'uv\s+install\s+(\S+)', 'uv', check_uv_tool, 1),
    (r'pipx\s+install\s+(\S+)', 'pipx', check_pipx, 1),
    (r'go\s+install\s+(\S+)', 'go', lambda p: check_tool(p.split('/')[-1]), 1),
    (r'git\s+clone\s+.*github\.com[/:](\S+)', 'git clone', None, 1),
    (r'curl.*\|\s*(?:sh|bash)', 'curl-pipe', lambda p: True, 0),
    (r'make\s+install', 'make install', lambda p: True, 0),
    (r'snap\s+install\s+(\S+)', 'snap', check_tool, 1),
]

def fetch_readme(repo_full):
    """Fetch README content from GitHub API."""
    r = gh_api(f"repos/{repo_full}/readme", "--jq .content")
    if not r:
        return ""
    try:
        return base64.b64decode(r).decode('utf-8', errors='replace')
    except:
        return ""

def detect_install_methods(readme, name_lower):
    """Parse README for install methods. Returns list of (method, pkg_name, check_fn, satisfied)."""
    results = []
    if not readme:
        return results
    
    readme_lower = readme.lower()
    seen = set()
    
    for pattern, method, check_fn, param_group in INSTALL_PATTERNS:
        for m in re.finditer(pattern, readme_lower, re.MULTILINE):
            pkg_name = m.group(param_group) if param_group else name_lower
            # Clean up
            pkg_name = pkg_name.strip('"\'`,').split('/')[-1].split('@')[0].split('>')[0].split(' ')[0]
            if not pkg_name or pkg_name in seen:
                continue
            seen.add(pkg_name)
            
            # Check if satisfied locally
            if check_fn and pkg_name:
                satisfied = check_fn(pkg_name)
            else:
                satisfied = False
            
            results.append((method, pkg_name, satisfied))
    
    # Also check for binary name == repo name (most common case)
    if check_tool(name_lower):
        results.append(('binary', name_lower, True))
    
    return results

# ── main ─────────────────────────────────────────────────
def main():
    print()
    inform("crisp scan başlıyor — star'lar taranıyor...")
    print()

    # ── 1. Check gh CLI ──
    if not check_tool("gh"):
        print()
        err("gh CLI bulunamadı!")
        print()
        print("  Kurulum için:")
        print("    brew install gh")
        print("    gh auth login")
        print()
        print("  Veya: https://cli.github.com/")
        print()
        return 1

    # Check gh auth
    auth = run(["gh", "auth", "status"], timeout=10)
    if auth.returncode != 0:
        print()
        err("GitHub CLI oturumu açık değil!")
        print()
        print("  Giriş yapmak için:")
        print("    gh auth login")
        print()
        print("  Bu komut:")
        print("    1. Browser'da GitHub'a giriş yapmanı ister")
        print("    2. Gerekli token'ları otomatik oluşturur")
        print("    3. Sonra tekrar çalıştır: crisp scan")
        print()
        return 1

    ok("gh CLI hazır, oturum açık")

    # ── 2. Fetch stars ──
    inform("Star listesi çekiliyor...")
    gh_api("user/starred", "--jq '.[].full_name'") or ""
    # Use paginated version
    stars_raw = run(
        ["gh", "api", "user/starred", "--paginate", "--jq", ".[].full_name"],
        timeout=30
    )
    stars = sorted(set(s.strip().lower() for s in stars_raw.stdout.strip().split('\n') if s.strip()))
    
    with open(STARS_FILE, 'w') as f:
        for s in stars:
            f.write(s + '\n')
    ok(f"{len(stars)} star bulundu")
    print()

    # ── 3. Fetch repo metadata ──
    inform("Repo metadata çekiliyor...")
    meta_raw = run(
        ["gh", "api", "user/starred", "--paginate", "--jq",
         ".[] | {name: .full_name, description: .description, language: .language, topics: .topics, html_url: .html_url}"],
        timeout=30
    )
    repo_meta = {}
    for line in meta_raw.stdout.strip().split('\n'):
        if line.strip():
            try:
                r = json.loads(line)
                repo_meta[r['name'].lower()] = r
            except:
                pass
    ok(f"{len(repo_meta)} repo metadata alındı")

    # ── 4. Pre-scan local git repos ──
    inform("Lokal git repoları taranıyor...")
    git_out = run(r"""find ~ -maxdepth 6 -type d -name ".git" ! -path "*/node_modules/*" ! -path "*/.Trash/*" ! -path "*/.cache/*" ! -path "*/Library/*" ! -path "*/Caskroom/*" ! -path "*/__pycache__/*" ! -path "*/site-packages/*" 2>/dev/null | while read d; do dir=$(dirname "$d"); remote=$(cd "$dir" 2>/dev/null && git remote get-url origin 2>/dev/null); if [ -n "$remote" ]; then echo "$remote ||| $dir"; fi; done""", shell=True, timeout=60)
    local_repos = defaultdict(list)
    for line in git_out.stdout.strip().split('\n'):
        if ' ||| ' not in line: continue
        idx = line.index(' ||| ')
        remote, path = line[:idx].strip(), line[idx+4:].strip()
        norm = ""
        if 'github.com' in remote:
            if '://' in remote: norm = remote.split('github.com/')[-1].lower()
            elif 'git@' in remote: norm = remote.split('github.com:')[-1].lower()
            norm = norm.replace('.git', '')
        if norm: local_repos[norm].append(path)
    ok(f"{len(local_repos)} lokal git repo bulundu")

    # ── 5. Scan Docs directories for name matches ──
    inform("Documents/skills dizinleri taranıyor...")
    doc_out = run(r"""find ~/Documents ~/.hermes/skills ~/.claude ~/.openclaude -maxdepth 4 -type d ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null | while read d; do echo "$(basename "$d" | tr '[:upper:]' '[:lower:]')"; done | sort -u""", shell=True, timeout=30)
    doc_dirs = set(d.strip() for d in doc_out.stdout.strip().split('\n') if d.strip())

    # ── 6. Install brew/formulae list ──
    brew_out = run("brew leaves 2>/dev/null", timeout=15)
    brew_pkgs = set(p.strip().lower() for p in brew_out.stdout.strip().split('\n') if p.strip())

    # ── 7. Process each starred repo ──
    print()
    inform("README'ler taranıyor... (bu biraz sürebilir)")
    print()

    scan_results = []
    new_auto_modules = []
    existing_auto = set()
    if os.path.exists(AUTO_CONF):
        with open(AUTO_CONF) as f:
            existing_auto = set(l.strip() for l in f if l.strip())

    total = len(stars)
    for idx, star in enumerate(stars):
        r = repo_meta.get(star, {})
        desc = (r.get('description') or '')[:150]
        topics = r.get('topics', [])
        lang = r.get('language') or ''
        is_own = star.startswith('enesdemir143/')
        url = r.get('html_url', f'https://github.com/{star}')
        
        # Progress
        if (idx + 1) % 10 == 0:
            inform(f"... {idx+1}/{total} repo işlendi")

        # ── Local presence check ──
        found = []

        # a) Git clone
        if star in local_repos:
            for p in local_repos[star]:
                found.append(('git clone', p))

        # b) Fork match
        name_part = star.split('/')[1].lower()
        if not found:
            for norm, paths in local_repos.items():
                local_name = norm.split('/')[1] if '/' in norm else ""
                if local_name == name_part and norm != star:
                    for p in paths:
                        found.append((f"fork: {norm}", p))
                    break

        # c) Directory name match
        if not found and name_part in doc_dirs:
            found.append(('dizin', name_part))

        # d) Pip package check
        pkg_key = name_part.replace('-', '').replace('_', '')
        if check_pip(name_part) or check_pip(name_part.replace('-', '_')) or check_pip(pkg_key):
            found.append(('pip', ''))

        # e) Brew
        if name_part in brew_pkgs:
            found.append(('brew', ''))

        # f) Npm global
        if check_npm(name_part):
            found.append(('npm', ''))

        # g) Cargo
        if check_cargo(name_part):
            found.append(('cargo', ''))

        # h) UV tool
        if check_uv_tool(name_part):
            found.append(('uv tool', ''))

        # i) Pipx
        if check_pipx(name_part):
            found.append(('pipx', ''))

        # j) Binary
        if check_tool(name_part):
            found.append(('binary', ''))

        # ── Fetch README for install methods ──
        readme_methods = []
        if not is_own:
            readme = fetch_readme(star)
            if readme:
                readme_methods = detect_install_methods(readme, name_part)
            if readme_methods:
                # Check each method against what we already found
                for method, pkg, satisfied in readme_methods:
                    if method == 'git clone':
                        if star in local_repos:
                            satisfied = True
                    elif method == 'brew' and pkg in brew_pkgs:
                        satisfied = True
                    elif method == 'binary' and check_tool(pkg):
                        satisfied = True

        # ── Category ──
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

        # ── Auto-detect new modules ──
        auto_mod = None
        if found and not is_own:
            # Check if this is already covered by existing crisp modules
            if star not in existing_auto:
                for typ, path in found:
                    mod_name = ""
                    if typ == 'brew':
                        mod_name = "brew"  # already covered
                    elif typ == 'pip':
                        mod_name = "pip"   # already covered
                    elif typ == 'npm':
                        mod_name = "npm"   # already covered
                    elif typ == 'uv tool':
                        mod_name = "uv"    # already covered
                    elif typ == 'pipx':
                        mod_name = "pipx"  # already covered
                    elif typ == 'cargo':
                        mod_name = "cargo" # already covered
                    elif typ == 'git clone':
                        mod_name = "repos"  # already covered
                    elif typ.startswith('fork:'):
                        mod_name = "repos"  # already covered
                
                # Everything is covered by existing modules!
                # But we'll note it was auto-detected
                existing_auto.add(star)

        scan_results.append({
            'star': star, 'desc': desc, 'cat': cat,
            'found': found, 'readme_methods': readme_methods,
            'url': url, 'is_own': is_own,
            'lang': lang, 'topics': topics,
        })

    # ── 8. Generate report ──
    print()
    inform("Rapor oluşturuluyor...")

    cats = defaultdict(list)
    for r in scan_results:
        cats[r['cat']].append(r)

    total_found = sum(1 for r in scan_results if r['found'] or r['is_own'])
    total_kendi = sum(1 for r in scan_results if r['is_own'])
    total_installed = sum(1 for r in scan_results if r['found'] and not r['is_own'])

    md = []
    md.append("# ⭐ GitHub Starred Repos — EnesDemir143")
    md.append("")
    md.append(f"**Toplam:** {len(scan_results)} star | **Lokalda mevcut:** {total_found} | **Kendi projeleri:** {total_kendi} | **Sadece star:** {len(scan_results) - total_found}")
    md.append("")
    md.append(f"> Son güncelleme: {datetime.now().strftime('%d.%m.%Y %H:%M')} | `crisp scan` ile oluşturuldu")
    md.append("")
    md.append("---")
    md.append("")
    md.append("| İkon | Anlamı |")
    md.append("|------|--------|")
    md.append("| ⭐ | Kendi projen |")
    md.append("| 📌 | Lokalde mevcut (git / brew / pip / npm / uv / cargo) |")
    md.append("| 📦 | README'de belirtilen kurulum yöntemi |")
    md.append("| | Sadece star, lokalda yok |")
    md.append("")
    md.append("## 📊 İstatistikler")
    md.append("")
    md.append(f"- **{len(scan_results)}** toplam star")
    md.append(f"- **{total_installed}** üçüncü parti repo cihazda kurulu")
    md.append(f"- **{total_kendi}** kendi projen")
    md.append(f"- **{len(scan_results) - total_found}** henüz denenmemiş / kurulmamış")
    md.append("")

    cat_order = ["AI Agent & Coding", "ML & LLM", "MCP & Servis", "Browser & Web",
                 "Araştırma & Akademik", "Terminal & CLI", "Döküman & PDF", "Tasarım & UI",
                 "DB & Bellek", "Finans", "macOS Araçları", "Kendi Projesi", "Çeşitli"]

    for cat in cat_order:
        items = cats.get(cat, [])
        if not items: continue
        local_count = sum(1 for r in items if r['found'] or r['is_own'])
        
        md.append(f"## 📁 {cat} ({len(items)} repo, {local_count} lokalda)")
        md.append("")
        md.append("| # | Repo | Açıklama | Lokal | README'den Kurulum |")
        md.append("|---|------|----------|-------|--------------------|")
        
        for i, r in enumerate(sorted(items, key=lambda x: (not x['found'] and not x['is_own'], x['star'])), 1):
            desc_short = (r['desc'] or '—')[:70].replace('|', '/')
            
            # Status icon + text
            if r['is_own']:
                status_icon = "⭐"
                status_text = "Kendi"
            elif r['found']:
                status_icon = "📌"
                loc_types = []
                for typ, _ in r['found'][:3]:
                    t = typ.split()[0] if typ.split() else typ
                    loc_types.append(t)
                status_text = ", ".join(loc_types) if loc_types else "Mevcut"
            else:
                status_icon = " "
                status_text = "Yok"
            
            # README install methods
            readme_col = ""
            if r['readme_methods']:
                methods = []
                satisfied_count = sum(1 for _, _, sat in r['readme_methods'] if sat)
                for method, pkg, sat in r['readme_methods'][:4]:
                    icon = "✓" if sat else "○"
                    methods.append(f"{icon} {method}")
                readme_col = ", ".join(methods)
                if satisfied_count > 0 and not r['found']:
                    status_text = f"⚠ Kurulumu var ama kurulu değil"
                    status_icon = "📦"
            else:
                readme_col = "—"
            
            md.append(f"| {i} | [{r['star']}]({r['url']}) | {desc_short} | {status_icon} {status_text} | {readme_col} |")
        
        md.append("")

    # Category table
    md.append("## 📊 Kategori Dağılımı")
    md.append("")
    md.append("| Kategori | Adet | Lokalde |")
    md.append("|----------|------|---------|")
    for cat in cat_order:
        items = cats.get(cat, [])
        if not items: continue
        lc = sum(1 for r in items if r['found'] or r['is_own'])
        md.append(f"| {cat} | {len(items)} | {lc} |")
    md.append(f"| **Toplam** | **{len(scan_results)}** | **{total_found}** |")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## Notlar")
    md.append("")
    md.append("- `crisp scan` ile bu rapor otomatik oluşturulur")
    md.append("- `crisp repos` ile git clone olan repolar güncellenir")
    md.append("- `crisp` ile tüm paket yöneticileri (brew/pip/npm/uv/cargo) güncellenir")
    md.append("- 📦 = README'de kurulum yöntemi var ama cihazda kurulu değil")
    md.append("- Yeni repo kurduğunda `crisp scan` çalıştırman yeterli")

    with open(REPORT_FILE, 'w') as f:
        f.write('\n'.join(md) + '\n')

    ok(f"Rapor kaydedildi: {REPORT_FILE}")
    inform(f"{len(scan_results)} star • {total_found} lokalda • {total_installed} kurulu")
    print()
    inform("İpucu: README'sinde kurulum talimatı olup da cihazında olmayanları 📦 ile görebilirsin")
    print()

if __name__ == '__main__':
    main()
