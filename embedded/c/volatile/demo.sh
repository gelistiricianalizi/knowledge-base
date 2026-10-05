#!/usr/bin/env bash
# Sayfadaki örnekleri derler ve çalıştırır; beklenen sonuç çıkmazsa durur.
# Dockerfile'daki imajın içinde koşar: docker build -t volatile-ornek . && docker run --rm volatile-ornek
set -euo pipefail
export LC_ALL=C.UTF-8
cd "$(dirname "$0")"

BUILD_DIR="$(mktemp -d)"
LEVELS="O0 Og O1 Os O2 O3"
FLAG_TIMEOUT_SECONDS=3
COUNTER_RUNS=3

section() { printf '\n=== %s ===\n' "$1"; }
expect() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '[ok] %s\n' "$description"; else printf '[HATA] %s\n' "$description"; exit 1; fi
}

# arm_function <dosya> <fonksiyon> <seviye> <nitelik> [işlemci]
# Fonksiyonun Cortex-M assembly'si: komutlar ve etiketler kalır; yönergeler, yorumlar ve sondaki sabit havuzu etiketleri atılır.
arm_function() {
  arm-none-eabi-gcc -mcpu="${5:-cortex-m4}" -mthumb -ffreestanding "-$3" "-DQUALIFIER=$4" -S -o - "$1" \
    | awk -v name="$2" '$0 ~ "^" name ":" { inside = 1 } inside { print } $0 ~ "\\.size[ \t]+" name "," { inside = 0 }' \
    | sed -E 's/[[:space:]]*@.*$//' \
    | grep -Ev '^[[:space:]]+\.|^[[:space:]]*$' \
    | awk '{ lines[NR] = $0 } END { last = NR; while (last > 0 && lines[last] ~ /^\.L[0-9]+:$/) last--; for (i = 1; i <= last; i++) print lines[i] }'
}

# Standart girdideki fonksiyonda bayrak, geriye dallanan bir döngünün içinde mi yükleniyor?
loads_inside_loop() {
  awk '
    /^\.L[0-9]+:$/ { label[substr($0, 1, length($0) - 1)] = NR }
    /ldrb/ { load[NR] = 1 }
    $1 ~ /^(b|beq|bne|cbz|cbnz)$/ { target = $NF; if (target in label) { for (line = label[target]; line < NR; line++) if (line in load) found = 1 } }
    END { exit found ? 0 : 1 }'
}
count() { grep -cE "$1" || true; }

section "1 · Kesme bayrağı: aynı döngü, -O2, volatile olmadan ve volatile ile"
plain="$(arm_function isr_flag.c wait_for_ready O2 "")"
qualified="$(arm_function isr_flag.c wait_for_ready O2 volatile)"
printf -- '--- volatile yok\n%s\n--- volatile\n%s\n' "$plain" "$qualified"
expect "volatile olmadan bayrak döngüden önce bir kez okunur" bash -c '! loads_inside_loop' <<<"$plain"
expect "volatile ile bayrak her turda yeniden okunur" loads_inside_loop <<<"$qualified"

section "2 · Hangi optimizasyon seviyesinde?"
reads_flag() { if arm_function isr_flag.c wait_for_ready "$1" "$2" | loads_inside_loop; then echo "her turda okur"; else echo "bir kez okur"; fi; }
printf '%-8s %-16s %s\n' "seviye" "volatile yok" "volatile"
for level in $LEVELS; do
  printf '%-8s %-16s %s\n' "-$level" "$(reads_flag "$level" "")" "$(reads_flag "$level" volatile)"
done
expect "-O0 volatile olmadan da her turda okur" loads_inside_loop <<<"$(arm_function isr_flag.c wait_for_ready O0 "")"

section "3 · Yazmaç: üç yazma, iki okuma"
for qualifier in "" volatile; do
  writes="$(arm_function mmio.c send_abc O2 "$qualifier")"
  reads="$(arm_function mmio.c changed_status_bits O2 "$qualifier")"
  printf -- '--- QUALIFIER=%s\n%s\n%s\n' "${qualifier:-(boş)}" "$writes" "$reads"
  printf 'yazma: %s · okuma: %s\n' "$(count '^[[:space:]]+str[[:space:]]' <<<"$writes")" "$(count '^[[:space:]]+ldr[[:space:]]+r[0-9]+, \[' <<<"$reads")"
done
expect "volatile olmadan üç yazmadan biri kalır" test "$(arm_function mmio.c send_abc O2 "" | count '^[[:space:]]+str[[:space:]]')" -eq 1
expect "volatile ile üç yazma da kalır" test "$(arm_function mmio.c send_abc O2 volatile | count '^[[:space:]]+str[[:space:]]')" -eq 3
expect "volatile olmadan yazmaç hiç okunmaz" test "$(arm_function mmio.c changed_status_bits O2 "" | count '^[[:space:]]+ldr[[:space:]]+r[0-9]+, \[')" -eq 0
expect "volatile ile yazmaç iki kez okunur" test "$(arm_function mmio.c changed_status_bits O2 volatile | count '^[[:space:]]+ldr[[:space:]]+r[0-9]+, \[')" -eq 2

section "4 · Gecikme döngüsü"
for qualifier in "" volatile; do
  printf -- '--- QUALIFIER=%s\n%s\n' "${qualifier:-(boş)}" "$(arm_function delay.c delay O2 "$qualifier")"
done
expect "volatile olmadan döngüden geriye yalnız dönüş komutu kalır" test "$(arm_function delay.c delay O2 "" | count '^[[:space:]]')" -eq 1

section "5 · Sayaç: volatile üç adım, atomik tek işlem"
printf -- '--- ticks++ (Cortex-M4)\n%s\n' "$(arm_function counter.c count_volatile O2 "")"
printf -- '--- atomic_fetch_add (Cortex-M4)\n%s\n' "$(arm_function counter.c count_atomic O2 "")"
printf -- '--- atomic_fetch_add (Cortex-M0)\n%s\n' "$(arm_function counter.c count_atomic O2 "" cortex-m0)"
expect "Cortex-M4'te atomik artış ldrex/strex ile derlenir" grep -q strex <<<"$(arm_function counter.c count_atomic O2 "")"
expect "Cortex-M0'da atomik artış kütüphane çağrısına döner" grep -q __atomic_fetch_add_4 <<<"$(arm_function counter.c count_atomic O2 "" cortex-m0)"

section "6 · Çalıştır: bayrağı bir saniye sonra sinyal kaldırır ($(uname -m), $(gcc -dumpfullversion))"
printf '%-8s %-12s %s\n' "seviye" "nitelik" "sonuç"
for level in O0 O2; do
  for qualifier in "" volatile; do
    binary="$BUILD_DIR/flag-$level-${qualifier:-plain}"
    gcc "-$level" "-DQUALIFIER=$qualifier" -o "$binary" signal_flag.c
    started="$(date +%s.%N)"
    if timeout "$FLAG_TIMEOUT_SECONDS" "$binary"; then outcome="çıktı"; else outcome="çıkmadı, $FLAG_TIMEOUT_SECONDS s sonra durduruldu"; fi
    elapsed="$(awk -v a="$started" -v b="$(date +%s.%N)" 'BEGIN { printf "%.2f", b - a }')"
    printf '%-8s %-12s %s (%s s)\n' "-$level" "${qualifier:-yok}" "$outcome" "$elapsed"
  done
done
expect "-O2 ve volatile olmadan program bayrağı görmez" bash -c "! timeout $FLAG_TIMEOUT_SECONDS '$BUILD_DIR/flag-O2-plain'"
expect "-O2 ve volatile ile program çıkar" timeout "$FLAG_TIMEOUT_SECONDS" "$BUILD_DIR/flag-O2-volatile"

section "7 · Çalıştır: ana döngü ve sinyal işleyicisi aynı sayacı artırır"
gcc -O2 -o "$BUILD_DIR/counter-volatile" signal_counter.c
gcc -O2 -DATOMIC -o "$BUILD_DIR/counter-atomic" signal_counter.c
for variant in volatile atomic; do
  for _ in $(seq "$COUNTER_RUNS"); do printf '%-9s %s\n' "$variant" "$("$BUILD_DIR/counter-$variant")"; done
done
lost() { "$1" | sed -E 's/.*kayıp ([0-9]+)$/\1/'; }
expect "volatile sayaçta güncelleme kaybolur" test "$(lost "$BUILD_DIR/counter-volatile")" -gt 0
expect "atomik sayaçta güncelleme kaybolmaz" test "$(lost "$BUILD_DIR/counter-atomic")" -eq 0

section "8 · Niteliğin düşmesi: derleyici uyarır"
warning="$(arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -ffreestanding -O2 -c discard.c -o /dev/null 2>&1 | grep 'warning:' || true)"
printf '%s\n' "$warning"
expect "volatile işaretçi sıradan parametreye verilince uyarı çıkar" grep -q "discards 'volatile' qualifier" <<<"$warning"

printf '\nBütün beklentiler tuttu.\n'
