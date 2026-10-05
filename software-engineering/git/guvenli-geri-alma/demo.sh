#!/usr/bin/env bash
# Sayfadaki örnekleri geçici bir repoda sırayla çalıştırır; beklenen sonuç çıkmazsa durur.
# Kullanım: ./demo.sh   (Git 2.32+)
set -euo pipefail

# Çıktı her makinede aynı olsun: kişisel Git ayarları devre dışı, yazar ve tarih sabit (commit hash'leri de sabitlenir).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_PAGER=cat LC_ALL=C
export GIT_AUTHOR_NAME=Demo GIT_AUTHOR_EMAIL=demo@example.com
export GIT_COMMITTER_NAME=Demo GIT_COMMITTER_EMAIL=demo@example.com
export GIT_AUTHOR_DATE="2026-10-04T12:00:00+03:00" GIT_COMMITTER_DATE="2026-10-04T12:00:00+03:00"

REPO=$(mktemp -d)
cd "$REPO"

section() { printf '\n=== %s ===\n' "$1"; }
run() { printf '$ %s\n' "$*"; "$@"; }
expect() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '[ok] %s\n' "$description"; else printf '[HATA] %s\n' "$description"; exit 1; fi
}
contains() { grep -qF -- "$2" "$1"; }
missing() { ! grep -qF -- "$2" "$1"; }

section "Hazırlık: iki commit'li repo"
git init --quiet --initial-branch=main .
printf 'def selamla():\n    return "merhaba"\n' > app.py
printf '# Notlar\n' > notlar.md
git add app.py notlar.md
git commit --quiet -m "ilk sürüm"
printf 'def veda():\n    return "görüşürüz"\n' >> app.py
git commit --quiet -am "veda fonksiyonunu ekle"
run git log --oneline

section "1-3 · Durumu gör: status, diff --staged, log --graph"
printf 'print(selamla())\n' >> app.py
printf -- '- stash denenecek\n' >> notlar.md
git add notlar.md
printf 'geçici\n' > deneme.txt
run git status
run git diff --staged
run git log --oneline --graph

section "4 · restore --staged: stage'den çıkar, değişiklik kalır"
run git restore --staged notlar.md
run git status --short
expect "notlar.md'deki değişiklik duruyor" contains notlar.md "stash denenecek"

section "5 · restore: dosyadaki değişikliği at (geri alınamaz)"
run git restore app.py
run git status --short
expect "app.py son commit'teki haline döndü" missing app.py "print(selamla())"

section "6-7 · stash ve stash pop: yarım işi kenara koy, geri getir"
run git stash
run git status --short
expect "takip edilmeyen deneme.txt stash'e girmedi" test -f deneme.txt
expect "notlar.md temiz" missing notlar.md "stash denenecek"
run git stash list
run git stash pop
expect "değişiklik geri geldi" contains notlar.md "stash denenecek"

section "Karşı örnek: silinen stash yine de bulunur"
git stash --quiet
DROPPED=$(git stash drop | sed -E 's/.*\(([0-9a-f]+)\)$/\1/')
printf '$ git stash drop\nDropped refs/stash@{0} (%s)\n' "$DROPPED"
run git stash apply --quiet "$DROPPED"
expect "silinen stash hash'iyle geri geldi" contains notlar.md "stash denenecek"

section "8 · commit --amend: son commit'i düzelt (hash değişir)"
git add notlar.md
git commit --quiet -m "notlari guncelle"
BEFORE=$(git rev-parse --short HEAD)
printf '$ git commit --amend -m "notları güncelle"\n'
git commit --quiet --amend -m "notları güncelle"
AFTER=$(git rev-parse --short HEAD)
printf 'önce: %s  sonra: %s\n' "$BEFORE" "$AFTER"
expect "amend yeni bir commit üretti" test "$BEFORE" != "$AFTER"
expect "eski commit hâlâ erişilebilir" git cat-file -e "$BEFORE"

section "9 · revert: commit'i yeni bir commit'le geri al (geçmiş değişmez)"
run git revert --no-edit HEAD
run git log --oneline
expect "notlar.md'deki satır geri alındı" missing notlar.md "stash denenecek"

section "10 · reflog: reset --hard ile silinen commit'i bul"
LOST=$(git rev-parse --short HEAD)
run git reset --hard HEAD~2
run git log --oneline
run git reflog -4
run git reset --hard "HEAD@{1}"
expect "silinen iki commit geri geldi" test "$(git rev-parse --short HEAD)" = "$LOST"

section "Karşı örnek: reflog'un kurtaramadığı"
printf 'print(veda())\n' >> app.py
printf 'yarım taslak\n' > taslak.md
git add taslak.md
run git status --short
run git reset --hard
run git status --short
expect "app.py'deki commit'lenmemiş satır gitti" missing app.py "print(veda())"
expect "stage'deki taslak.md çalışma dizininden silindi" test ! -e taslak.md
expect "takip edilmeyen deneme.txt yerinde" test -f deneme.txt
run git fsck --lost-found
BLOB=$(git fsck --lost-found 2>/dev/null | awk '$2 == "blob" { print $3 }')
run git cat-file -p "$BLOB"
expect "stage'e alınmış içerik blob olarak duruyor" test "$(git cat-file -p "$BLOB")" = "yarım taslak"

section "Karşı örnek: pop çakışırsa stash silinmez"
printf -- '- yerel not\n' >> notlar.md
git stash --quiet
printf -- '- başka not\n' >> notlar.md
git commit --quiet -am "notlara satır ekle"
printf '$ git stash pop\n'
git stash pop || true
run git stash list
expect "çakışan stash listede duruyor" test "$(git stash list | wc -l)" -eq 1

section "Bitti"
printf 'Git %s · repo çakışma ortasında bırakıldı, alıştırma için: %s\n' "$(git version | cut -d" " -f3)" "$REPO"
