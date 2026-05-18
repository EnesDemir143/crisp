# crisp 🥒

**Keep everything crisp and up-to-date.**

crisp, GitHub star'ladığın repolardan yola çıkarak bilgisayarındaki tüm araçları güncel tutan bir TUI updater. brew/pip/npm gibi paket yöneticilerinin ötesinde, `curl | sh`, zip, go install, gh release download gibi yöntemlerle kurulmuş "yetim" araçları da tespit edip günceller.

## Felsefe

Sen GitHub'da bir repoyu star'lıyorsun — o repo bir aracı temsil ediyor. crisp o star'ı kullanarak:

1. **Nerede?** — Bu araç bilgisayarında kurulu mu, nereden kurulmuş?
2. **Güncel mi?** — Kurulu versiyon son release ile aynı mı?
3. **Güncelle** — Değilse, doğru yöntemle güncelle (brew/pip/git pull/Release binary indir...)

## Kullanım

```
crisp                  # interaktif menü
crisp all              # tüm modülleri çalıştır
crisp quick            # hızlı güncelleme (brew/pip/npm)
crisp stars            # STARRED_REPOS.md oluştur
crisp scan             # derin tarama + README analizi
crisp cron             # otomatik güncelleme zamanla
crisp <module>         # spesifik modülü çalıştır
crisp list             # modülleri listele
```

## Modüller

| Modül | Ne yapar? |
|-------|-----------|
| `brew` | `brew update + upgrade` |
| `pip` | pip self-upgrade + outdated |
| `npm` | npm global güncelleme |
| `pipx` | pipx upgrade-all |
| `npx` | npx cache temizliği |
| `uv` | uv self update + tool upgrade |
| `cargo` | cargo install-update -a |
| `hermes` | hermes agent update |
| `repos` | star'lı clone'ları git pull |
| `stars` | STARRED_REPOS.md oluştur |
| `scan` | README tarama + yerel tespit |
| `code` | VS Code extension güncelleme |
| `graphify` | graphify versiyon kontrolü |

## Yapılacaklar (Roadmap)

- [ ] **Orphan Manager** — brew/pip/npm/cargo dışında kurulmuş araçların tespiti
  - `strings` ile binary'lerde gömülü `github.com/owner/repo` tespiti
  - `--version` vs GitHub Releases API ile versiyon karşılaştırma
  - Otomatik güncelleme (Release binary indir / go install / curl-pipe tekrar)
- [ ] **Deprecation Radar** — 1+ yıldır güncellenmeyen star'ları tespit + alternatif öner
- [ ] **Release Notes Digest** — Güncelleme öncesi ne değişmiş özet gösterimi
- [ ] **Rollback Snapshots** — Binary yedekleme ve eski sürüme dönüş
