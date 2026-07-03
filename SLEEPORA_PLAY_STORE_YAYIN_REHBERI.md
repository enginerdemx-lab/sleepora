# Sleepora — Play Store Native Sürüme Geçiş Rehberi

**Hedef:** Play Store'daki mevcut web tabanlı `com.bebekuyku.app` listesini (5,0 puan · 15 yorum · 44 indirme) **koruyarak** yeni Flutter native uygulamayla güncellemek + Apple ile aynı ödeme sistemini açmak.

**Karar:** Seçenek A — mevcut liste korunuyor. Android paket adı `com.bebekuyku.app` olur, kullanıcılar native sürüme otomatik güncellenir.

---

## Tespit edilen durum

| | Değer | Durum |
|---|---|---|
| Play Store canlı uygulama | `com.bebekuyku.app` | Korunacak liste |
| Yeni Android `applicationId` | ~~`com.example.sleepora`~~ → `com.bebekuyku.app` | ✅ Düzeltildi |
| iOS bundle ID | `com.enginerdem.sleepora` | App Store sürümü (farklı olması sorun değil) |
| Android release imza | ~~debug~~ → key.properties tabanlı | ✅ Düzeltildi |
| Firebase Android | `firebase_options.dart` yalnızca iOS içeriyor | ❌ **Sen yapacaksın (Adım 2)** |
| AdMob App ID | Google test ID'si | ❌ **Sen yapacaksın (Adım 3)** |
| Sürüm | `1.0.0+15` | Canlı sürümden yüksek olmalı (Adım 4) |

---

## ✅ Kod tarafında YAPILDI

`android/app/build.gradle.kts`:
- `applicationId = "com.bebekuyku.app"`
- Release `signingConfig` eklendi (`android/key.properties`'ten okur; dosya yoksa debug'a düşer, böylece `flutter run` bozulmaz)
- `namespace` `com.example.sleepora` olarak kaldı — bu yalnızca iç kod paketidir, **store kimliği `applicationId`'dir**, dokunmaya gerek yok.

`.gitignore`: `key.properties`, `*.jks`, `*.keystore` artık git'e girmiyor.

---

## Senin yapacakların (sırayla)

### 1. İmza anahtarı (keystore)

Play, `com.bebekuyku.app`'i **kayıtlı upload anahtarıyla** imzalanmış bekler.

**Eğer eski uygulamanın upload keystore'u elindeyse** → doğrudan onu kullan, Adım 1b'ye geç.

**Elinde yoksa (web tabanlı eski uygulamada büyük ihtimalle yok)** → yeni bir upload anahtarı üret, sonra Adım 6'da Play'den *upload key reset* talep et:

```bash
keytool -genkey -v -keystore ~/sleepora-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
(Sorulan şifreleri ve alias'ı not et. Bu dosyayı ve şifreleri **kaybetme + yedekle**.)

**1b. `android/key.properties` oluştur** (proje içinde `android/` klasörüne):

```properties
storePassword=KEYSTORE_SIFREN
keyPassword=ANAHTAR_SIFREN
keyAlias=upload
storeFile=/Users/enginerdem/sleepora-upload.jks
```

### 2. Firebase Android yapılandırması — ZORUNLU

Şu an `firebase_options.dart` yalnızca iOS içeriyor; bu yüzden uygulama **Android'de açılışta çöker**. FlutterFire CLI ile Android'i ekle:

```bash
dart pub global activate flutterfire_cli      # ilk kez
cd /Users/enginerdem/sleepora
flutterfire configure \
  --project=SENIN_FIREBASE_PROJE_ID \
  --platforms=android,ios \
  --android-package-name=com.bebekuyku.app \
  --ios-bundle-id=com.enginerdem.sleepora
```
Bu, `firebase_options.dart`'a `android` bloğunu ekler, Firebase'de yeni Android uygulaması (`com.bebekuyku.app`) oluşturur ve `google-services.json`'u yerleştirir.

**Google Sign-In için** (uygulama `google_sign_in` kullanıyor) SHA parmak izlerini Firebase'e ekle:
```bash
keytool -list -v -keystore ~/sleepora-upload.jks -alias upload
```
Çıkan **SHA-1** ve **SHA-256**'yı Firebase Console → Proje ayarları → Android uygulaması → "Parmak izi ekle" altına gir. **Ayrıca** Play App Signing devreye girince Play Console → Uygulama bütünlüğü'ndeki Google üretim imza SHA'sını da ekle (yoksa canlıda Google ile giriş çalışmaz).

### 3. AdMob gerçek App ID

`android/app/src/main/AndroidManifest.xml` (satır ~36) şu an Google'ın **test** ID'sini içeriyor:
```
ca-app-pub-3940256099942544~3347511713
```
Bunu AdMob hesabındaki **gerçek** uygulama ID'nle değiştir (iOS tarafında da `ios/Runner/Info.plist` → `GADApplicationIdentifier`). Test ID'siyle üretimde reklam geliri olmaz ve AdMob politikasına aykırıdır.

### 4. versionCode kontrolü

Play Console → Production'da canlı web uygulamanın en yüksek **versionCode**'una bak. `pubspec.yaml`'daki yapı numarası (`+15`) bundan **yüksek** olmalı. Gerekirse yükselt:
```yaml
version: 1.0.0+16
```

### 5. Build (AAB)

```bash
cd /Users/enginerdem/sleepora
flutter clean
flutter pub get
flutter build appbundle --release
# Çıktı: build/app/outputs/bundle/release/app-release.aab
```

### 6. Play Console'a yükleme

**Upload anahtarın kayıptıysa (Adım 1)**, önce sıfırlama gerekir:
1. Play Console → Test ve yayınlama → **Uygulama bütünlüğü** → Uygulama imzalama → **Upload key sıfırlama talep et**.
2. Yeni anahtarının sertifikasını çıkar ve yükle:
   ```bash
   keytool -export -rfc -keystore ~/sleepora-upload.jks -alias upload -file upload_certificate.pem
   ```
3. Google onayı genelde 1–2 iş günü.

Sonra: Play Console → Sleepora → **Test ve yayınlama → Production → Yeni sürüm oluştur** → `app-release.aab` yükle → incelemeye gönder. (Önce **Internal testing** track'inde denemen önerilir.)

### 7. Ödeme sistemi (Apple ile aynı)

Kod zaten hazır (`in_app_purchase` + `subscription_service.dart` + `paywall_screen.dart`). Yalnızca ürünleri store'larda oluştur — **ID'ler kodla birebir aynı olmalı:**

| Ürün | ID | Tip (Google Play) |
|---|---|---|
| Aylık | `sleepora_premium_monthly` | Subscription |
| Yıllık | `sleepora_premium_yearly` | Subscription |
| Lifetime | `sleepora_premium_lifetime` | In-app product (tek seferlik) |

**Google Play Console:**
1. **Para kazanma kurulumu → Satıcı (payments) hesabı oluştur** (vergi + banka bilgisi).
2. Monetize → Products → **Subscriptions**: `monthly` ve `yearly`'yi base plan + fiyatla oluştur.
3. Monetize → Products → **In-app products**: `lifetime`'ı oluştur.
4. Test için **License testers** ekle (internal testing track'inde gerçek ödeme almadan dener).

**App Store Connect:** Aynı 3 ID'yi oluştur (monthly/yearly bir Subscription Group içinde, lifetime non-consumable). Proje notuna göre bunlar Apple tarafında da henüz oluşturulmamış.

---

## Hatırlatmalar

- **Keystore'u kaybetme.** Play App Signing açık olduğundan Google üretim anahtarını tutar; ama upload anahtarını kaybedersen her seferinde reset gerekir.
- Android paket adı (`com.bebekuyku.app`) ile iOS bundle (`com.enginerdem.sleepora`) farklı — sorun değil; Firebase ve ödeme ürünleri her platformda ayrı tanımlı.
- 2026 hedef API: bugün min **API 35 (Android 15)**; **31 Ağustos 2026'dan sonra API 36 (Android 16)** zorunlu. Flutter'ı güncel tut, `flutter.targetSdkVersion` otomatik karşılar.
