#!/usr/bin/env bash
# Üç düzeni (naive · ignore · mount) beş değişiklikle (tekrar · mtime · not · yeni · kod) build eder; süreyi,
# derleme adımının cache'ten gelip gelmediğini, gönderilen build context'ini ve imaj boyutunu yazar.
# Kullanım: ./measure.sh   (Docker 23+ ve golang:1.26-alpine; birkaç dakika sürer)
# Disk: naive ve ignore düzenlerindeki yeniden derlemeler builder'da yaklaşık 2 GB build cache bırakır.
# Geri almak için: docker image rm build-cache-demo:naive build-cache-demo:ignore build-cache-demo:mount
# ve docker builder prune (kullanılmayan bütün build cache'i siler).
set -euo pipefail
# Süreler her makinede noktalı ondalıkla yazılsın ve doğru sıralansın.
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd)
readonly HERE
readonly IMAGE=build-cache-demo
readonly REPEATS=3
readonly DUMP_BYTES=52428800
WORK=$(mktemp -d)
readonly WORK
# Ölçüm klasörleri 150 MB'tan fazla yer tutar; script bitince silinir.
trap 'rm -rf "${WORK:?}"' EXIT
TIMEFORMAT=%R

# Her düzen kendi yeni klasöründe ölçülür: BuildKit önceki context'i klasöre göre hatırlar,
# yeni klasörde ilk build bütün context'i yeniden gönderir (CI'daki durum).
new_project() {
  local dir="$1"
  mkdir -p "$dir/docs" "$dir/veri"
  cp "$HERE/go.mod" "$HERE/main.go" "$HERE/Dockerfile" "$HERE/Dockerfile.mount" "$dir/"
  printf '# Notlar\n' > "$dir/docs/NOTLAR.md"
  head -c "$DUMP_BYTES" /dev/urandom > "$dir/veri/dump.bin"
}

# build <etiket> <Dockerfile> → süre $ELAPSED, çıktı $LOG
build() {
  LOG="$WORK/build.log"
  { time docker build --progress=plain --tag "$IMAGE:$1" --file "$2" . > "$LOG" 2>&1; } 2> "$WORK/time.txt"
  ELAPSED=$(cat "$WORK/time.txt")
}

# BuildKit çıktısında adımın numarasını bulur, sonra o numaranın sonucunu okur.
step_id() { grep -m 1 -F -- "$1" "$LOG" | cut -d' ' -f1; }
compile_state() {
  local id
  id=$(step_id "go build")
  if grep -q "^$id CACHED" "$LOG"; then echo "cache"; else echo "yeniden"; fi
}
context_size() {
  local id
  id=$(step_id "[internal] load build context")
  grep "^$id transferring context:" "$LOG" | tail -n 1 | awk '{ print $4 }'
}

median() { sort -n | sed -n "$(( (REPEATS + 1) / 2 ))p"; }

change_nothing() { :; }
change_mtime() { touch main.go; }
change_notes() { printf -- '- not %s\n' "$1" >> docs/NOTLAR.md; }
change_new_file() { printf 'geçici %s\n' "$(date +%s)-$1" > "gecici-$1.txt"; }
change_code() { printf '// değişiklik %s-%s\n' "$(date +%s)" "$1" >> main.go; }

# measure <düzen> <Dockerfile> <değişiklik adı> <değişiklik fonksiyonu>
measure() {
  local variant="$1" dockerfile="$2" label="$3" change="$4" times="" repeat
  for repeat in $(seq "$REPEATS"); do
    "$change" "$repeat"
    build "$variant" "$dockerfile"
    times="$times$ELAPSED"$'\n'
  done
  printf '%-8s %-8s %8s s   %-8s %s\n' "$variant" "$label" "$(printf '%s' "$times" | median)" "$(compile_state)" "$(context_size)"
}

# variant <düzen> <Dockerfile> <.dockerignore var mı>
variant() {
  local name="$1" dockerfile="$2" has_ignore="$3" bytes
  new_project "$WORK/$name"
  cd "$WORK/$name"
  if [ "$has_ignore" = yes ]; then cp "$HERE/dockerignore.example" .dockerignore; fi
  build "$name" "$dockerfile"
  bytes=$(docker image inspect --format '{{.Size}}' "$IMAGE:$name")
  printf '%-8s %-8s %8s     %-8s %-10s imaj %s\n' "$name" "ilk" "-" "-" "$(context_size)" \
    "$(awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / 1e6 }')"
  measure "$name" "$dockerfile" tekrar change_nothing
  measure "$name" "$dockerfile" mtime change_mtime
  measure "$name" "$dockerfile" not change_notes
  measure "$name" "$dockerfile" yeni change_new_file
  measure "$name" "$dockerfile" kod change_code
}

echo "düzen    değişen      süre     derleme  context"
variant naive Dockerfile no
variant ignore Dockerfile yes
variant mount Dockerfile.mount yes

echo
echo "katmanlar (boyut · komut)"
for name in naive ignore mount; do
  docker history --format "$name  {{.Size}}  {{.CreatedBy}}" "$IMAGE:$name" | sed -n '1,3p' | grep -v WORKDIR | cut -c1-72
done
