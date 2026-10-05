#!/usr/bin/env bash
# Sayfadaki örnekleri örnek bir proje klasöründe sırayla çalıştırır; beklenen sonuç çıkmazsa durur.
# Dockerfile'daki imajın içinde koşar: docker build -t gunluk-komutlar . && docker run --rm gunluk-komutlar
set -euo pipefail
export LC_ALL=C.UTF-8

section() { printf '\n=== %s ===\n' "$1"; }
# Komutu sayfada yazıldığı haliyle gösterir, sonra ayrı bir kabukta çalıştırır. Başarısız komut script'i durdurmaz.
show() { printf '$ %s\n' "$1"; bash -c "$1" || true; }
first_line() { "$@" 2>&1 | sed -n 1p; }
expect() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '[ok] %s\n' "$description"; else printf '[HATA] %s\n' "$description"; exit 1; fi
}

section "Hazırlık: örnek proje"
mkdir -p proje/src proje/logs proje/arsiv/2025 proje/veri proje/.cache proje/node_modules/kutuphane
cd proje
printf 'import util\n\n# TODO: girdi doğrulaması\ndef calistir(girdi):\n    return util.temizle(girdi)\n' > src/app.py
printf '# TODO: log seviyesi ayarlanabilir olsun\ndef temizle(metin):\n    return metin.strip()\n' > src/util.py
printf '// TODO: eski API\n// TODO: test\n// TODO: belge\n' > node_modules/kutuphane/index.js
printf '10:00:01 INFO servis başladı\n10:00:07 INFO istek /saglik 200\n10:02:13 ERROR veritabanı bağlantısı koptu\n10:02:14 INFO yeniden bağlanılıyor\n' > logs/app.log
printf '09:00:00 INFO dünkü kayıt\n' > logs/eski.log
printf 'ocak\n' > arsiv/ocak.log
printf 'aralık\n' > arsiv/2025/aralik.log
head -c 3145728 /dev/zero > veri/buyuk.bin
head -c 5242880 /dev/zero > .cache/indirme.bin
printf '#!/bin/sh\necho "betik çalıştı"\n' > betik.sh
cat > servis.sh <<'SERVIS'
#!/usr/bin/env bash
trap 'echo "servis: temizlik yapıldı, çıkıyorum"; exit 0' TERM
while true; do sleep 0.2; done
SERVIS
show 'find . -type f | sort'

section "1 · grep -rn: metni dosyalarda bul"
show 'grep -rn "TODO" .'
show 'grep -rn --exclude-dir=node_modules "TODO" .'
expect "node_modules dışında iki eşleşme var" test "$(grep -rn --exclude-dir=node_modules "TODO" . | wc -l)" -eq 2

section "2 · find: dosyayı adına göre bul"
show 'find . -name "*.log"'

section "Karşı örnek: tırnaksız desen"
cd arsiv
show 'find . -name *.log'
show 'find . -name "*.log"'
expect "tırnaksız desen alt klasördeki dosyayı sessizce kaçırır" test "$(find . -name *.log | wc -l)" -eq 1
cd ../logs
show 'find . -name *.log'
expect "iki eşleşme olunca find hata verir" bash -c '! find . -name *.log'
cd ..

section "3 · less: büyük dosyada gezin (etkileşimli; burada yalnız sürüm)"
show 'less --version | head -n 1'

section "4 · tail -f: log'u canlı izle"
show 'tail -n 2 logs/app.log'
# tail -f kendiliğinden bitmez; demo yarım saniye sonra bir satır ekler ve izlemeyi 3 saniyede keser.
(sleep 0.5; printf '10:02:15 INFO bağlantı kuruldu\n' >> logs/app.log) &
printf '$ tail -n 1 -f logs/app.log\n'
FOLLOWED=$(timeout 3 tail -n 1 -f logs/app.log || true)
printf '%s\n' "$FOLLOWED"
wait
expect "tail -f sonradan eklenen satırı gösterdi" grep -q "bağlantı kuruldu" <<< "$FOLLOWED"

section "5 · du -sh *: hangi klasör ne kadar yer kaplıyor"
show 'du -sh *'
show 'du -sh .[!.]* * | sort -h'
expect "du -sh * gizli .cache klasörünü atlar" bash -c '! du -sh * | grep -q cache'

section "6 · df -h: diskte ne kadar yer kaldı (değerler makineye göre değişir)"
show 'df -h .'

section "7-8 · pgrep ve kill: süreci bul, durdur"
service_is_gone() { ! pgrep -f servis.sh; }
# disown: kabuk, arka plandaki süreç ölünce kendi "Killed" bildirimini çıktıya karıştırmasın.
start_service() { bash servis.sh & disown; sleep 0.5; }
start_service
show 'pgrep -fl servis'
show 'pgrep -af servis'
PID=$(pgrep -f servis.sh)
show "kill $PID"
sleep 0.5
expect "süreç artık yok" service_is_gone

section "Karşı örnek: kill -9 temizliğe izin vermez"
start_service
PID=$(pgrep -f servis.sh)
show "kill -9 $PID"
sleep 0.5
expect "süreç yok, temizlik mesajı da yok" service_is_gone

section "9 · chmod +x: script'i çalıştırılabilir yap"
show "stat -c '%A %n' betik.sh"
show './betik.sh'
show 'chmod +x betik.sh'
show "stat -c '%A %n' betik.sh"
show './betik.sh'
expect "betik artık çalışıyor" ./betik.sh

section "10 · ssh: sunucuya bağlan (sunucu gerekir; burada yalnız sürüm)"
show 'ssh -V'

section "11 · rsync -av: yalnız değişenleri kopyala"
mkdir -p /tmp/yedek
show 'rsync -av src/ /tmp/yedek/'
show 'rsync -av src/ /tmp/yedek/'
printf '# değişti\n' >> src/util.py
show 'rsync -av src/ /tmp/yedek/'
expect "son kopyadan sonra iki klasör aynı" diff -r src /tmp/yedek

section "Karşı örnek: sondaki / klasörün kendisini mi, içini mi kopyalar"
mkdir -p /tmp/a /tmp/b
show 'rsync -a src /tmp/a/'
show 'ls /tmp/a'
show 'rsync -a src/ /tmp/b/'
show 'ls /tmp/b'
expect "src (/'sız) klasörün kendisini kopyaladı" test -d /tmp/a/src
expect "src/ (/'lı) içindekileri kopyaladı" test -f /tmp/b/app.py

section "12 · curl -I: HTTP başlıklarını gör (ağ gerekir)"
if curl -sI --max-time 10 https://example.com >/dev/null 2>&1; then
  show 'curl -sI https://example.com | head -n 1'
else
  echo "ağ yok: atlandı"
fi

section "Bonus · Ctrl+R: eski komutu ara"
show "bash -ic 'bind -q reverse-search-history' 2>/dev/null"

section "Sürümler"
printf 'Debian %s · %s\n' "$(cat /etc/debian_version)" "$(uname -m)"
for tool in grep find du less pgrep rsync curl; do first_line "$tool" --version; done
first_line ssh -V
first_line bash --version
