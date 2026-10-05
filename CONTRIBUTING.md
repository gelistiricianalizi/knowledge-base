# Katkı rehberi

Bilgi tabanına katkı verdiğiniz için teşekkürler. Küçük bir yazım düzeltmesi de, yeni bir rehber de değerlidir.

## Nasıl katkı verilir

| Katkı | Yol |
|---|---|
| Yazım hatası, kırık link, küçük düzeltme | Doğrudan pull request |
| Yanlış ya da eskimiş bilgi | Issue açın: hangi dosya, ne yanlış, doğrusunun kaynağı |
| Yeni içerik önerisi | Önce Discussions'ta konuyu önerin; kapsam netleşince pull request |
| Soru | Discussions |

## İçerik kuralları

- **Dil:** Türkçe. Yerleşik İngilizce teknik terimler çevrilmez (`framework`, `deploy`, `container`); Türkçe
  karşılığı yaygın olanlar Türkçe yazılır (*veritabanı*, *derleyici*). İngilizce terime ek kesme işaretiyle
  gelir: *framework'ü*.
- **Kod:** komut, dosya adı ve kod her zaman kod bloğu ya da `satır içi kod` olarak yazılır. Örnekler çalışır
  olmalı; hangi sürümle denendiği yazılır.
- **Kaynak:** başkasının verisi ya da iddiası kullanılıyorsa kaynağı linkiyle verilir.
- **Diyagram:** Mermaid kullanın; ASCII çizim yerine.
- **AI ile üretilen metin:** kullanılabilir, ama doğrudan eklenmez. Teknik doğruluğu, örneklerin çalıştığı ve
  kaynaklar kontrol edilmiş olmalıdır. Uydurma örnek ve desteksiz iddia kabul edilmez.
- **Yapı:** her içerik ilgili bilgi alanı klasörüne, küçük harf ve tire ile adlandırılmış bir Markdown dosyası
  olarak eklenir (`docker/multi-stage-build.md`). Çalıştırılabilir örnek dosyaları içerikle aynı adlı klasörde
  durur (`docker/multi-stage-build/`).
- **Ölçüm:** içerikte ölçülmüş bir sayı varsa, onu yeniden üreten komut ya da script de örnek klasöründe durur;
  ölçümün yapıldığı ortam ve tarih yazılır.

## Pull request

1. Repoyu fork'layın, değişikliğinizi ayrı bir branch'te yapın.
2. Pull request açıklamasında neyi neden değiştirdiğinizi yazın.
3. İnceleme sonrası birleştirilir; büyük içeriklerde birkaç tur geri bildirim olabilir.

Katkılarınız [CC BY 4.0](LICENSE) (yazı) ve [MIT](LICENSE-CODE) (kod) lisanslarıyla yayınlanır.

## Davranış

Saygı her tartışmadan önce gelir. Kişiye değil fikre itiraz edilir; yeni başlayanın sorusu da uzmanın sorusu
kadar meşrudur.
