with open("lib/l10n/app_localizations.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Let's brute force find the exact byte sequence of that line and the following line.
# "ساعت سیستم شما تنظیم نیست.\n'," 
# Wait, it looks like there's a literal carriage return or newline right after the period inside the string.

# Let's just rewrite the entire _persianValues dictionary from scratch safely.
start_marker = "  static final Map<String, String> _persianValues = {"
end_marker = "  };\n\n  String translate(String key) {"

start_idx = text.find(start_marker)
end_idx = text.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_persian = """  static final Map<String, String> _persianValues = {
    'app_name': 'OryvexVPN',
    'click_to_connect': 'برای اتصال کلیک کنید',
    'connected': 'متصل شد',
    'connecting': 'در حال اتصال...',
    'disconnecting': 'در حال قطع اتصال...',
    'disconnected': 'قطع شد',
    'connection_failed': 'اتصال ناموفق بود',
    'disconnect_failed': 'قطع اتصال ناموفق بود',
    'finding_fastest_server': 'در حال یافتن سریع‌ترین سرور...',
    'registering_with_warp': 'در حال ثبت‌نام با Cloudflare WARP...',
    'starting_secure_tunnel': 'در حال راه‌اندازی تونل امن...',
    'verifying_connection': 'در حال تایید اتصال...',
    'fetching_config': 'در حال دریافت تنظیمات...',
    'installing_tunnel': 'در حال نصب تونل...',
    'dns_configuring': 'در حال تنظیم DNS...',
    'retrying_standard': 'تلاش مجدد با تنظیمات استاندارد...',
    'connection_lost_retrying': 'اتصال قطع شد، در حال تلاش مجدد...',
    'ping': 'پینگ',
    'ip_address': 'آدرس IP',
    'download': 'دانلود',
    'upload': 'آپلود',
    'total_download': 'مجموع دانلود',
    'total_upload': 'مجموع آپلود',
    'duration': 'مدت اتصال',
    'unknown': 'ناشناخته',
    'wireguard_not_found': 'فایل‌های WireGuard یافت نشد',
    'registration_failed': 'ثبت‌نام ناموفق بود',
    'tunnel_not_active': 'تونل بعد از تنظیمات فعال نیست',
    'service_not_running': 'سرویس تونل در حال اجرا نیست',
    'connection_test_failed': 'تست اتصال ناموفق بود',
    'no_server': 'هیچ سروری در دسترس نیست. لطفا اینترنت را بررسی کنید.',
    'settings': 'تنظیمات',
    'general': 'عمومی',
    'advanced': 'پیشرفته',
    'about': 'درباره',
    'auto_connect': 'اتصال خودکار',
    'start_minimized': 'شروع به صورت کمینه',
    'close_to_tray': 'بستن به سینی',
    'language': 'زبان',
    'theme': 'پوسته',
    'network_status': 'وضعیت شبکه',
    'proxy_status': 'وضعیت پروکسی سیستم',
    'dns_status': 'وضعیت DNS',
    'proxy_active': 'تنظیم شده توسط اورایوکس',
    'proxy_default': 'پیش‌فرض سیستم',
    'dns_cloudflare': 'Cloudflare DNS (1.1.1.1)',
    'dns_default': 'پیش‌فرض شبکه',
    'version': 'نسخه',
    'auto_connect_desc': 'وصل شدن خودکار در هنگام باز شدن برنامه',
    'start_minimized_desc': 'اجرای برنامه در System Tray',
    'config_name': 'نام تنظیمات',
    'server_info': 'اطلاعات سرور',
    'protocol': 'پروتکل',
    'endpoint': 'نقطه پایانی',
    'import_config': 'وارد کردن تنظیمات',
    'export_config': 'خروجی گرفتن از تنظیمات',
    'save_config': 'ذخیره تنظیمات',
    'connect': 'اتصال',
    'disconnect': 'قطع اتصال',
    'cancel': 'لغو',
    'ok': 'تایید',
    'close': 'بستن',
    'minimize': 'کوچک‌سازی',
    'vpn_connected': 'VPN متصل شد',
    'vpn_disconnected': 'VPN قطع شد',
    'connection_restored': 'اتصال بازیابی شد',
    'connection_lost': 'اتصال قطع شد',
    'close_title': 'بستن برنامه',
    'close_message': 'آیا می‌خواهید برنامه به طور کامل بسته شود یا در پس‌زمینه (سینی سیستم) فعال بماند؟',
    'close_background': 'پنهان در پس‌زمینه',
    'close_exit': 'خروج کامل',
    'checking_internet': 'در حال بررسی اتصال اینترنت...',
    'youtube_check_failed': 'امکان اتصال به سرور وجود ندارد. لطفا دوباره تلاش کنید.',
    'sys_warning': 'هشدار سیستم',
    'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',
    'conflicting_procs': 'برنامه‌های متداخل یافت شد: ',
    'exit_app': 'خروج از برنامه',
    'kill_all': 'بستن برنامه‌های مزاحم',
"""
    
    text = text[:start_idx] + new_persian + text[end_idx:]
    with open("lib/l10n/app_localizations.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Rewrote _persianValues block")
else:
    print("Could not find markers")
