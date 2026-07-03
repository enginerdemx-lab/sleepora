# Sleepora — App Store Yeniden Gönderim Rehberi

**Konu:** Guideline 2.1(b) reddi (IAP satın alma sayfası sonsuz yükleniyor)
**Tarih:** 1 Temmuz 2026

---

## 1. Kodda ne düzeltildi

| Sorun | Düzeltme | Dosya |
|---|---|---|
| Paywall başarısız/iptal satın almada sonsuz dönüyordu | Spinner artık sıfırlanıyor + hata mesajı; 60 sn watchdog ile takılma imkânsız | `lib/screens/paywall_screen.dart` |
| IAP satın alması admin panele yansımıyordu | Satın alma başarılı olunca Firestore'a da yazılıyor | `lib/services/subscription_service.dart` |
| Açılışta uzun süre boş ekran | Tüm servisler `runApp`'tan sonra arka planda; splash kritik servisler hazır olunca geçiyor | `lib/main.dart`, `lib/screens/splash_screen.dart` |
| Mayın tarlası tek tıkla "0 saniyede bitti" | Zorluk artışı + ilk tık tüm tahtayı açarsa yeniden dağıtma | `lib/games/minesweeper_game.dart`, `.../minesweeper_config.dart` |
| "Eee Eee" vb. seslerde cırlama | İnsan sesi/ninnilerde crossfade kapalı, gapless loop | `lib/screens/sounds_screen.dart`, `lib/screens/home_screen.dart` |

> Asıl ret sebebi (2.1b) ilk iki satırdaki paywall takılmasıydı; o giderildi. Diğerleri ekstra iyileştirme.

## 2. App Store Connect durumu — KONTROL EDİLDİ, TAMAM

- **Paid Apps Agreement:** Active (20 May 2026'dan beri — yani inceleme sırasında da aktifti, sebep bu değildi)
- **Banka + Vergi (W-8BEN):** Active
- **Ürünler — 3'ü de tanımlı, ID'ler kodla birebir, versiyona ekli (Waiting for Review):**
  - `sleepora_premium_monthly` — Auto-Renewable Subscription
  - `sleepora_premium_yearly` — Auto-Renewable Subscription
  - `sleepora_premium_lifetime` — Non-Consumable

Bu taraf eksiksiz. Sorun konfigürasyonda değil, koddaydı (giderildi).

## 3. Sürüm / Build numarası

- `pubspec.yaml` → **`1.0.0+29`** olarak güncellendi.
- **Neden:** iOS sürüm adını pubspec'ten alıyor; eski hâliyle (1.3.0) build alsan App Store Connect'teki **"1.0"** kaydına eklenemezdi. İlk gönderim reddi olduğu için doğrusu aynı "1.0" kaydına düzeltilmiş build yüklemek.
- **Önemli:** Build numarası (29) son TestFlight yüklemenden yüksek olmalı. Daha yüksek bir build yüklediysen pubspec'te `+29`'u artır.
- 1.3.0 olarak çıkmak istersen: App Store Connect'te yeni bir "1.3.0" versiyonu aç ve pubspec'i `1.3.0+29` yap.

## 4. Gönderim adımları (senin yapman gerekenler — Mac)

1. `flutter pub get`
2. `flutter analyze` → hata olmamalı.
3. (Önerilir) Bir kez cihazda/simülatörde aç, paywall + 3 planı dene.
4. `flutter build ipa` **veya** Xcode > Product > Archive.
5. Xcode Organizer / Transporter ile App Store Connect'e yükle.
6. App Store Connect > Sleepora > **versiyon sayfası** > "In-App Purchases and Subscriptions" bölümünde **3 ürünü de seç** (rejection sonrası tekrar seçmen gerekebilir).
7. **App Review Information > Notes** kısmına aşağıdaki notu yapıştır.
8. Yeni build'i versiyona ata > **Submit for Review**.

## 5. Göndermeden önce SON test (sandbox) — kritik

iPhone'da: Ayarlar > Developer > Sandbox Apple Account ile giriş yap, sonra:

1. Paywall'ı aç, bir plan seç, satın almayı **İPTAL et** → buton **artık sonsuz dönmemeli**, "Satın alma hatası" göstermeli. *(Reddin asıl sebebi buydu; bunu doğrula.)*
2. Sonra gerçekten satın al → premium aktif olmalı, ekran kapanmalı.
3. **3 planı da** (Aylık / Yıllık / Ömür Boyu) dene — özellikle Ömür Boyu'nu.

## 6. App Review'a yapıştırılacak not (İngilizce, kopyala-yapıştır)

```
Hello, and thank you for reviewing Sleepora.

Regarding Guideline 2.1(b) (the In-App Purchase page loading indefinitely):

We identified and fixed the issue. The purchase flow now always resolves:
- On success, Premium is unlocked and the paywall closes.
- On cancellation or failure, the loading indicator stops immediately and a
  clear error message is shown.
- A 60-second safeguard guarantees the screen can never stay in a loading state.

All three In-App Purchase products are configured and included with this version:
- sleepora_premium_monthly  (auto-renewable subscription)
- sleepora_premium_yearly   (auto-renewable subscription)
- sleepora_premium_lifetime (non-consumable)

The Paid Applications Agreement is active and all three products have been
tested successfully in the sandbox. Please let us know if anything else is
needed. Thank you!
```
