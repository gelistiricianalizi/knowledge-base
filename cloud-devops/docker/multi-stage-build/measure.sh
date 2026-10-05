#!/usr/bin/env bash
# Her varyantı build eder; imaj boyutunu ve `-check` sonucunu tek tabloda yazar.
# Kullanım: ./measure.sh   (Docker 23+ — BuildKit varsayılan builder olmalı)
set -euo pipefail
cd "$(dirname "$0")"

readonly IMAGE=multi-stage-demo

build_variant() {
  local tag="$1"; shift
  docker build --quiet --tag "$IMAGE:$tag" "$@" . >/dev/null
}

report_variant() {
  local tag="$1" bytes check
  bytes=$(docker image inspect --format '{{.Size}}' "$IMAGE:$tag")
  # Eksik dosya varsa -check sıfırdan farklı döner; tablo yine de yazılsın.
  check=$(docker run --rm --entrypoint /app "$IMAGE:$tag" -check 2>&1 | tr -s ' \n' ' ' || true)
  printf '%-24s %9s   %s\n' "$tag" "$(awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / 1e6 }')" "$check"
}

build_variant single                -f Dockerfile.single-stage --target single
build_variant single-cleanup        -f Dockerfile.single-stage --target single-cleanup
build_variant alpine                --target alpine
build_variant distroless-unstripped --target distroless --build-arg GO_LDFLAGS=
build_variant distroless            --target distroless
build_variant scratch-bare          --target scratch-bare
build_variant scratch               --target scratch

printf '%-24s %9s   %s\n' "varyant" "boyut" "-check"
for tag in single single-cleanup alpine distroless-unstripped distroless scratch-bare scratch; do
  report_variant "$tag"
done
