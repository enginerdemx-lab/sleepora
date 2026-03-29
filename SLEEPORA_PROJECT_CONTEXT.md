# Sleepora — Flutter iOS Bebek Uyku Sesleri Uygulaması

> **Bu belge, yeni bir Claude oturumuna yapıştırılarak projenin tüm bağlamını aktarmak için hazırlanmıştır.**
> Son güncelleme: 29 Mart 2026

## Genel Bakış

Sleepora, bebeklerin uyumasına yardımcı olan bir iOS uygulamasıdır. 26 farklı uyku sesi, ses karıştırıcı (mixer), favori yönetimi, ses kaydı, mini oyunlar, zamanlayıcı, 5 dil desteği ve freemium abonelik modeli içerir.

- **Repo:** `https://github.com/enginerdemx-lab/bebek-uykusu-app`
- **Yerel dizin:** `/Users/enginerdem/sleepora`
- **Bundle ID:** `com.example.sleepora`
- **iOS Deployment Target:** 15.0
- **Flutter SDK:** ^3.11.3
- **Apple Developer Team ID:** `7483SK2P69`

---

## Dosya Yapısı

```
lib/
├── main.dart                          # Uygulama giriş noktası
├── screens/
│   ├── home_screen.dart               # Ana ekran — IndexedStack + MiniPlayer + LiquidGlassTabBar
│   ├── sounds_screen.dart             # 26 ses kartı, Sound sınıfı, allSounds listesi
│   ├── favorites_screen.dart          # 3 tab: Favoriler / Mixlerim / Karıştırıcı
│   ├── record_screen.dart             # Ses kaydı (mikrofon)
│   ├── games_screen.dart              # Oyun seçim ekranı
│   ├── settings_screen.dart           # Ayarlar + dil seçici + debug premium toggle
│   ├── paywall_screen.dart            # Premium satın alma ekranı (3 plan)
│   └── splash_screen.dart             # Açılış animasyonu (yıldızlı gece)
├── widgets/
│   ├── liquid_glass_tab_bar.dart      # Apple Liquid Glass tasarımlı tab bar
│   ├── mini_player.dart               # Küçültülebilir ses oynatıcı + marquee yazı
│   └── sound_card.dart                # Tekil ses kartı widget'ı
├── services/
│   ├── localization_service.dart      # 5 dil, ~115 çeviri anahtarı (Singleton + ChangeNotifier)
│   ├── subscription_service.dart      # IAP yönetimi + PremiumContent sınıfı (Singleton + ChangeNotifier)
│   ├── notification_service.dart      # Uyku hatırlatıcı bildirimleri
│   └── review_service.dart            # App Store değerlendirme istemi
├── models/
│   ├── shuffle_settings.dart          # Karışık çalma ayarları (süre, crossfade vb.)
│   └── mixer_state.dart               # Mixer durum modeli
├── games/
│   ├── quiz_game.dart                 # Bilgi yarışması (kategorili)
│   ├── game_2048.dart                 # 2048 oyunu
│   └── minesweeper_game.dart          # Mayın tarlası
└── theme/
    └── app_theme.dart                 # Koyu tema, renk sabitleri (AppColors)
```

```
ios/
├── Podfile                            # platform :ios, '15.0'
└── Runner.xcodeproj/                  # Xcode projesi (Automatic signing)

assets/
├── sounds/                            # 26 MP3 ses dosyası
└── images/
    └── logo.jpg                       # Uygulama logosu
```

---

## Ana Widget / Sınıf Haritası

### Ekranlar ve Navigasyon

| Index | Ekran | Widget | Açıklama |
|-------|-------|--------|----------|
| 0 | Sesler | `SoundsScreen` | 26 ses kartı grid, sürükle-bırak sıralama, son çalınanlar |
| 1 | Favoriler | `FavoritesScreen` | 3 tab: Favoriler / Mixlerim / Karıştırıcı |
| 2 | Kayıt | `RecordScreen` | Mikrofon kaydı, kayıt listesi |
| 3 | Oyunlar | `GamesScreen` | Quiz, 2048, Mayın Tarlası |
| 4 | Ayarlar | `SettingsScreen` | Dil, bildirim, bebek adı, premium |

### Navigasyon Bileşenleri

- **`HomeScreen`** — `IndexedStack` ile 5 ekranı bellekte tutar. `LiquidGlassTabBar` ile navigasyon.
- **`LiquidGlassTabBar`** — Apple Liquid Glass tasarım: backdrop blur, translucent tint, inner highlight, outer stroke, top reflection, floating shadow. Kapsül formunda, aktif item'da parlayan glass kapsül.
- **`MiniPlayer`** — Küçültülebilir/genişletilebilir ses oynatıcı. Uzun yazılar için `_MarqueeText` (kayan yazı) desteği.

### Ses Sistemi

- **`Sound`** sınıfı: `name`, `icon`, `assetPath`, `isFavorite`, `isPlaying`, `volume`
- **`localizedName`** getter: `LocalizationService().t('Sound_$name')` — dile göre ses adı
- **`allSounds`**: 26 ses listesi (sounds_screen.dart'ta tanımlı)
- **Crossfade Loop**: 2 `AudioPlayer` (just_audio) ile kesintisiz döngü, 2.5sn crossfade
- **Mixer**: Her ses için ayrı AudioPlayer, bağımsız volume kontrolü
- **Shuffle**: Favori sesler arasında otomatik geçiş, ayarlanabilir süre ve crossfade

### Ses Çalma Modları (`ActivePlayer` enum)

| Mod | Açıklama | MiniPlayer Görünümü |
|-----|----------|---------------------|
| `none` | Ses yok | MiniPlayer gizli |
| `single` | Tek ses | Ses adı + play/pause |
| `mixer` | Karıştırıcı | "Karıştırıcı (X ses)" + kaydet/temizle/volume butonları |
| `shuffle` | Karışık çalma | "X Favori Ses Çalınıyor" + marquee |

---

## Paketler (pubspec.yaml)

| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| `just_audio` | ^0.10.5 | Ses çalma motoru (crossfade, loop) |
| `audio_session` | ^0.2.3 | iOS ses oturumu yönetimi |
| `in_app_purchase` | ^3.2.0 | Apple StoreKit IAP (aylık/yıllık/ömür boyu) |
| `shared_preferences` | ^2.5.4 | Yerel veri depolama (dil, premium, ayarlar) |
| `path_provider` | ^2.1.5 | Dosya sistemi yolları (ses kaydı) |
| `flutter_local_notifications` | ^21.0.0 | Uyku hatırlatıcı bildirimleri |
| `timezone` | ^0.11.0 | Zaman dilimi desteği |
| `flutter_staggered_animations` | ^1.1.1 | Grid animasyonları |
| `reorderable_grid_view` | ^2.2.8 | Sürükle-bırak ses kartı sıralama |
| `url_launcher` | ^6.2.5 | Harici bağlantılar (gizlilik, destek) |
| `cupertino_icons` | ^1.0.8 | iOS ikonları |

---

## Lokalizasyon Sistemi

- **Singleton**: `LocalizationService` extends `ChangeNotifier`
- **5 Dil**: Türkçe (0), İngilizce (1), İspanyolca (2), Fransızca (3), Almanca (4)
- **~115 çeviri anahtarı**: UI metinleri + 26 ses adı (`Sound_*` prefix)
- **Kalıcılık**: `SharedPreferences` ile dil tercihi kaydedilir
- **Dinleme**: `HomeScreen` `_loc.addListener()` ile dil değişiminde `setState` çağırır — `IndexedStack` içindeki tüm ekranlar yeniden çizilir

### Kritik Çeviri Kategorileri

- Navigasyon: `NavSounds`, `NavFavorites`, `NavRecord`, `NavGames`, `NavSettings`
- Favoriler: `ShuffleFavoritesTitle`, `NoFavoritesTitle`, `NoFavoritesDesc`
- Mixler: `MyMixesHeader`, `MyMixesSub`, `BtnNewMix`, `NoMixesTitle`, `NoMixesDesc`, `soundsCount`
- Premium: `PremiumSoundTitle`, `PremiumSoundDesc`, `BtnGoPremium`, `FeatPremiumSounds`
- Timer: `TimerDialogTitle`, `sec`, `min`
- Ses adları: `Sound_Beyaz Gürültü`, `Sound_Yağmur` vb. (26 adet)

---

## Premium / Abonelik Sistemi

### SubscriptionService (Singleton + ChangeNotifier)

- **IAP Ürünleri**: `sleepora_premium_monthly`, `sleepora_premium_yearly`, `sleepora_premium_lifetime`
- **Başlatma**: `main.dart`'ta `Future.microtask` ile arka planda (UI'ı bloke etmez)
- **Offline destek**: `SharedPreferences` ile premium durumu saklanır
- **Debug test modu**: `toggleDebugPremium()` — Ayarlar'da logoya 5 kez tıklayarak aktifleşir

### PremiumContent Sınıfı

```dart
class PremiumContent {
  static const List<String> sounds = ['Kolik', 'Pış Pış 2', 'Yıldız Tozu', 'Konuşma'];
  static const List<String> premiumQuizCategories = ['Tarih', 'Coğrafya', 'Bilim & Teknoloji'];
  static const int freeMinesweeperHints = 0;
  static const int freeTimerMaxMinutes = 45;
  static const int freeRecordingMaxCount = 1;
  static const int freeFavoriteMaxCount = 3;
}
```

### Premium Kontrol Noktaları

| Kontrol | Dosya | Metod |
|---------|-------|-------|
| Ses çalma | sounds_screen.dart | `isSoundPremium(sound.name)` |
| Ses kartı elmas ikonu | sound_card.dart | `isPremiumLocked` prop |
| Karıştırıcıda elmas + kilit | favorites_screen.dart `_MixerCard` | `isSoundPremium()` |
| Karıştırıcıda seçim engeli | favorites_screen.dart `_toggle()` | Premium popup dialog |
| Favori limiti (3) | sounds_screen.dart | `isFavoriteLimitReached()` |
| Mix kayıt limiti (2) | favorites_screen.dart | Mix sayısı kontrolü |
| Kayıt limiti (1) | record_screen.dart | `isRecordingLimitReached()` |
| Timer limiti (45dk) | mini_player.dart | `isTimerPremium()` |
| Quiz kategorileri | quiz_game.dart | `premiumQuizCategories` |

### Debug Premium Toggle

Ayarlar ekranında sol üstteki logoya 3 saniye içinde 5 kez tıkla:
- `🔓 Test Premium: AÇIK` — tüm premium özellikler açılır
- `🔒 Test Premium: KAPALI` — ücretsiz moda döner
- Kalıcı değil, uygulama kapatılınca sıfırlanır

**Kritik**: Tüm premium kontrol metodları `isPremium` getter'ını kullanır (doğrudan `_isPremium` değil), böylece `_debugOverride` her yerde geçerlidir.

---

## Ses Listesi ve Sıralama

Premium sesler yan yana gelmeyecek şekilde dağıtılmıştır:

| # | Ses | Premium |
|---|-----|---------|
| 1 | Pış Pış | ❌ |
| 2 | Eee Eee | ❌ |
| 3 | Dandini | ❌ |
| 4 | Süpürge | ❌ |
| 5 | **Kolik** | ✅ |
| 6 | Kabin Sesi | ❌ |
| 7 | Uyusunda Büyüsün | ❌ |
| 8 | **Yıldız Tozu** | ✅ |
| 9 | Pış Pış + Süpürge | ❌ |
| 10 | Beyaz Gürültü | ❌ |
| 11 | **Konuşma** | ✅ |
| 12 | Yol Sesi | ❌ |
| 13 | Yağmur | ❌ |
| 14 | Saç Kurutma | ❌ |
| 15 | **Pış Pış 2** | ✅ |
| 16-26 | Rüzgar, Dalga, Duş, Helikopter, Tren, Vantilatör, Kalp Atışı, Kuş Sesi, Su Sesi, Çamaşır Makinesi, Trafik | ❌ |

---

## Tamamlanan Özellikler ve Düzeltmeler

### Kritik Düzeltmeler
1. **77 eksik çeviri anahtarı** — Gemini'nin eklediği `_loc.t()` çağrılarının çevirileri yoktu, hepsi eklendi
2. **IndexedStack dil güncelleme sorunu** — `HomeScreen.initState`'e `LocalizationService` listener eklendi
3. **PaywallScreen donma** — `loadProducts()` synchronous çağrı yerine `Future.microtask` + timeout
4. **Beyaz ekran / yavaş açılma** — `SubscriptionService.init()` arka plana alındı, `runApp` hemen çağrılır
5. **Premium kontrol bug** — Tüm `isSoundPremium` vb. metodlar `_isPremium` yerine `isPremium` getter kullanır
6. **Deprecated ColorScheme.background** — Kaldırıldı
7. **iOS deployment target** — 13.0 → 15.0 (in_app_purchase v3.2+ gereksinimi)
8. **Xcode kopya scheme dosyaları** — "Copy of Runner" x4 temizlendi

### Yeni Özellikler
1. **Ses adı lokalizasyonu** — `localizedName` getter, tüm UI noktalarında kullanılır
2. **Debug premium toggle** — Logoya 5 kez tıklayarak test modu
3. **Liquid Glass Tab Bar** — Apple tarzı backdrop blur, cam efekti, floating kapsül navigasyon
4. **Marquee (kayan yazı)** — MiniPlayer'da uzun isimler sola kayarak loop yapar
5. **Karıştırıcıda premium engel** — Elmas ikonu + popup dialog + PaywallScreen yönlendirme
6. **Shuffle yazısı** — "X Favori Ses Çalınıyor" formatı (eski uzun format yerine)

---

## Mimari Kararlar

| Karar | Neden |
|-------|-------|
| `IndexedStack` navigasyon | Ekranlar bellekte kalır, ses çalma kesilmez |
| Singleton servisler | Tek instance, her yerden erişim |
| `ChangeNotifier` + `ListenableBuilder` | Reaktif UI güncellemesi (dil, premium durum) |
| 2x `AudioPlayer` crossfade | Kesintisiz ses döngüsü |
| `Sound.name` internal key | Favoriler, play count, premium check'te sabit anahtar |
| `Sound.localizedName` display | UI'da dile göre değişen isim |
| IAP arka plan başlatma | `Future.microtask` ile UI bloklama önlenir |

---

## Bilinen Sorunlar / TODO

1. **App Store yönlendirme**: `review_service.dart` satır 90'da `// TODO: App Store'a yönlendir` — Rate App butonu henüz çalışmıyor
2. **Release build imzalama**: Apple Developer sertifika yapılandırması gerekebilir (`flutter run --release` için)
3. **StoreKit ürünleri**: App Store Connect'te henüz oluşturulmamış (`sleepora_premium_monthly/yearly/lifetime`)
4. **FlutterEngine assertion**: `sendOnChannel:message:binaryReply` uyarıları — IAP stream ile ilgili, işlevselliği etkilemiyor

---

## Hızlı Başlangıç Komutları

```bash
# Temiz build
cd /Users/enginerdem/sleepora && flutter clean && flutter pub get && cd ios && pod deintegrate && pod install && cd ..

# Debug modda çalıştır (kablolu)
flutter run

# Release modda çalıştır (kablosuz kalıcı)
flutter run --release

# Hot reload
# Terminal'de r tuşuna bas
```

---

## Renk Paleti (app_theme.dart)

| İsim | Hex | Kullanım |
|------|-----|----------|
| `background` | `#0A0A14` | Ana arka plan |
| `purple` | `#7C3AED` | Ana vurgu rengi |
| `purpleLight` | `#9D5FF3` | Açık mor |
| `purpleDark` | `#6D28D9` | Koyu mor |
| `purpleCard` | `#2D1B4E` | Kart arka planı |
| `grey` | `#6B7280` | Pasif metin |
| `greyLight` | `#9CA3AF` | Açık gri |
| `green` | — | Başarı/kaydet |
| `navBar` | — | Navigasyon (artık Liquid Glass) |
