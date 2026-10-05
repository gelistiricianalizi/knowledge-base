#!/usr/bin/env python3
"""GitHub profilini sayfadaki checklist'in otomatik denetlenebilen maddelerine göre kontrol eder.

Yalnız herkese açık bilgiyi okur (GitHub REST API, token'sız: saatte 60 istek, bir çalıştırma en çok 9 istek yapar)
ve hiçbir şeyi değiştirmez. Yalnız standart kütüphaneyi kullanır.
Kullanım: python3 profil_kontrol.py <kullanıcı-adı>
"""
import json
import sys
import urllib.error
import urllib.request

API = "https://api.github.com"
# Profilde en çok altı öğe sabitlenir; sabitlenenler token'sız okunamadığı için en son güncellenen altı repoya bakılır.
SHOWCASE_COUNT = 6
MANUAL_CHECKS = (
    "Sabitlenen repolar: 3-5 tane, en iyi işleriniz (profil sayfasında 'Customize your pins')",
    "Katkı grafiği: commit'lerdeki e-posta hesabınıza bağlı mı (git config user.email)",
    "Sabitlenen repoların README'si: ne yapar, nasıl çalıştırılır, örnek ya da ekran görüntüsü",
)


def fetch(path):
    """(bulundu mu, JSON) döndürür. 404 hata değil, 'yok' cevabıdır."""
    request = urllib.request.Request(API + path, headers={"Accept": "application/vnd.github+json",
                                                          "User-Agent": "profil-kontrol"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return True, json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False, None
        raise SystemExit(f"GitHub API hatası: {error.code} {error.reason}")


def check(is_ok, label, detail=""):
    print(f"{'[x]' if is_ok else '[ ]'} {label}" + (f": {detail}" if detail else ""))
    return is_ok


def check_profile(user):
    return [
        check(bool(user["name"]), "Ad", user["name"] or "boş"),
        check(bool(user["bio"]), "Bio", user["bio"] or "boş"),
        check(bool(user["blog"]), "Website ya da portföy bağlantısı", user["blog"] or "boş"),
        check(fetch(f"/repos/{user['login']}/{user['login']}/readme")[0], "Profil README",
              f"{user['login']}/{user['login']} reposunda README.md"),
    ]


def check_repo(login, repo):
    print(f"\n{repo['name']} (son push {repo['pushed_at'][:10]})")
    return [
        check(bool(repo["description"]), "  Açıklama"),
        check(bool(repo["topics"]), "  Konu etiketleri (topics)", ", ".join(repo["topics"])),
        check(fetch(f"/repos/{login}/{repo['name']}/readme")[0], "  README"),
        check(bool(repo["license"]), "  Lisans", (repo["license"] or {}).get("spdx_id") or ""),
    ]


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    found, user = fetch(f"/users/{sys.argv[1]}")
    if not found:
        raise SystemExit(f"Kullanıcı bulunamadı: {sys.argv[1]}")
    login = user["login"]
    print(f"Profil: github.com/{login}\n")
    results = check_profile(user)

    repos = fetch(f"/users/{login}/repos?per_page=100&type=owner&sort=pushed")[1]
    forks = [repo for repo in repos if repo["fork"]]
    sources = [repo for repo in repos if not repo["fork"] and not repo["archived"]]
    for repo in sources[:SHOWCASE_COUNT]:
        results += check_repo(login, repo)

    print(f"\nÖzet: {sum(results)} / {len(results)} madde tamam")
    print(f"Açık repolar: {len(repos)} (fork: {len(forks)}, arşivli: {sum(repo['archived'] for repo in repos)})")
    print("\nElle bakılacaklar:")
    for item in MANUAL_CHECKS:
        print(f"- {item}")


if __name__ == "__main__":
    main()
