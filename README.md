# Turizm Takvim

Flutter mobil uygulaması + Node.js API + PostgreSQL rezervasyon takvimi.

Açılış ekranında ay takvimi, **Yeni Ekle** ve **Rezervasyonlar** butonları vardır. Rezervasyon türüne göre tarihler farklı renklerle işaretlenir:

- Konaklama: teal
- Tur: yeşil
- Transfer: turuncu
- Etkinlik: mor

İptal kayıtlar takvimde gösterilmez.

## Gereksinimler

- Node.js 20+
- Flutter 3.41+
- Android Studio / Xcode (cihaz veya emülatör çıktısı için)

## 1. API

```bash
cd backend
cp .env.example .env   # değerler zaten uzak PostgreSQL için ayarlı
npm install
npm run migrate
npm start
```

API `0.0.0.0:3000` üzerinde açılır. Sunucu başlarken bilgisayarın yerel IP adresi yazdırılır.

## 2. Mobil uygulama

```bash
cd mobile
flutter pub get
```

### iOS simülatör

```bash
flutter run -d ios
```

### Android emülatör

Emülatör, bilgisayardaki API'ye `10.0.2.2` üzerinden bağlanır:

```bash
flutter run -d android
```

### Fiziksel telefon / tablet

Bilgisayar ve telefon aynı Wi-Fi ağında olmalı. API'nin yazdırdığı IP'yi kullanın:

```bash
flutter run --dart-define=LAN_IP=192.168.1.20
```

### Çıktı alma

Android APK:

```bash
cd mobile
flutter build apk --release
```

Dosya: `mobile/build/app/outputs/flutter-apk/app-release.apk`

iOS (Xcode imzası gerekir):

```bash
cd mobile
flutter build ios --release
```

Ardından Xcode ile `mobile/ios/Runner.xcworkspace` üzerinden Archive alın.

## API uçları

- `GET /api/health`
- `GET /api/reservations`
- `POST /api/reservations`
- `PUT /api/reservations/:id`
- `DELETE /api/reservations/:id`
- `GET /api/calendar?year=2026&month=9`
