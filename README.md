# OryvexVPN - داشبورد ویندوز

داشبورد اتصال به سرور WireGuard شخصی شما (VPS) - بدون کانفیگ ساختگی.

## قابلیت‌ها
- اتصال/قطع واقعی از طریق WireGuard for Windows
- دریافت کانفیگ از سرور VPS خودتان (نه یک کلید ساختگی محلی)
- وضعیت اتصال از سرویس واقعی ویندوز خوانده می‌شود، هرگز جعلی نیست
- تنظیمات سرور در برنامه (آدرس + توکن)

## نیازمندی‌ها
1. [WireGuard for Windows](https://www.wireguard.com/install/) نصب باشد.
2. برنامه با دسترسی Administrator اجرا شود (نصب/حذف تانل نیاز به ارتقای دسترسی دارد).
3. یک سرور (VPS) با WireGuard فعال که روی مسیر زیر کانفیگ برمی‌گرداند:

   ```
   POST {serverUrl}/api/wireguard/config
   Header: Authorization: Bearer <token>
   Response: { "config": "<متن کامل کانفیگ WireGuard>" }
   ```

## شروع سریع
```bash
flutter pub get
flutter run -d windows
```

## ساخت
```bash
flutter build windows --release
```

## GitHub Actions
با push به شاخه main، برنامه به صورت خودکار ساخته می‌شود.
