import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, String> _englishValues = {
    'app_name': 'OryvexVPN',
    'click_to_connect': 'Click to connect',
    'connected': 'Connected',
    'connecting': 'Connecting...',
    'disconnecting': 'Disconnecting...',
    'disconnected': 'Disconnected',
    'connection_failed': 'Connection failed',
    'disconnect_failed': 'Disconnect failed',
    'finding_fastest_server': 'Finding fastest server...',
    'registering_with_warp': 'Registering with Cloudflare WARP...',
    'starting_secure_tunnel': 'Starting secure tunnel...',
    'verifying_connection': 'Verifying connection...',
    'fetching_config': 'Fetching config...',
    'installing_tunnel': 'Installing tunnel...',
    'dns_configuring': 'Configuring DNS...',
    'retrying_standard': 'Retrying with standard config...',
    'connection_lost_retrying': 'Connection lost, retrying...',
    'ping': 'Ping',
    'ip_address': 'IP Address',
    'download': 'Download',
    'upload': 'Upload',
    'total_download': 'Total Download',
    'total_upload': 'Total Upload',
    'duration': 'Duration',
    'unknown': 'Unknown',
    'wireguard_not_found': 'WireGuard files not found',
    'registration_failed': 'Registration failed',
    'tunnel_not_active': 'Tunnel is not active',
    'service_not_running': 'Tunnel service is not running',
    'connection_test_failed': 'Connection test failed',
    'no_server': 'No server available. Please check your internet.',
    'settings': 'Settings',
    'general': 'General',
    'advanced': 'Advanced',
    'about': 'About',
    'auto_connect': 'Auto Connect',
    'start_minimized': 'Start Minimized',
    'close_to_tray': 'Close to Tray',
    'language': 'Language',
    'theme': 'Theme',
    'network_status': 'Network Status',
    'proxy_status': 'System Proxy Status',
    'dns_status': 'DNS Status',
    'proxy_active': 'Set by Oryvex',
    'proxy_default': 'System Default',
    'dns_cloudflare': 'Cloudflare DNS (1.1.1.1)',
    'dns_default': 'Network Default',
    'version': 'Version',
    'auto_connect_desc': 'Connect automatically on app start',
    'start_minimized_desc': 'Run app in System Tray',
    'config_name': 'Config Name',
    'server_info': 'Server Info',
    'protocol': 'Protocol',
    'endpoint': 'Endpoint',
    'import_config': 'Import Config',
    'export_config': 'Export Config',
    'save_config': 'Save Config',
    'connect': 'Connect',
    'disconnect': 'Disconnect',
    'cancel': 'Cancel',
    'ok': 'OK',
    'close': 'Close',
    'minimize': 'Minimize',
    'vpn_connected': 'VPN Connected',
    'vpn_disconnected': 'VPN Disconnected',
    'connection_restored': 'Connection Restored',
    'connection_lost': 'Connection Lost',
    'close_title': 'Close App',
    'close_message': 'Do you want to exit the app completely or keep it running in the background (system tray)?',
    'close_background': 'Run in Background',
    'close_exit': 'Exit Completely',
    'checking_internet': 'Checking internet connection...',
    'youtube_check_failed': 'Cannot connect to server. Please try again.',
    'sys_warning': 'System Warning',
    'clock_out_of_sync': 'Your system clock is not synchronized.
',
    'conflicting_procs': 'Conflicting programs found: ',
    'exit_app': 'Exit app',
    'kill_all': 'Kill All',
  };

  static final Map<String, String> _persianValues = {
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
    'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.
',
    'conflicting_procs': 'برنامه‌های متداخل یافت شد: ',
    'exit_app': 'خروج از برنامه',
    'kill_all': 'بستن برنامه‌های مزاحم',
  };

  String translate(String key) {
    if (locale.languageCode == 'en') return _englishValues[key] ?? key;
    return locale.languageCode == 'fa' ? (_persianValues[key] ?? key) : (_englishValues[key] ?? key);
  }

  // Convenience getters
  String get appName => translate('app_name');
  String get clickToConnect => translate('click_to_connect');
  String get connected => translate('connected');
  String get connecting => translate('connecting');
  String get disconnecting => translate('disconnecting');
  String get disconnected => translate('disconnected');
  String get connectionFailed => translate('connection_failed');
  String get disconnectFailed => translate('disconnect_failed');

  String get findingFastestServer => translate('finding_fastest_server');
  String get registeringWithWarp => translate('registering_with_warp');
  String get startingSecureTunnel => translate('starting_secure_tunnel');
  String get verifyingConnection => translate('verifying_connection');
  String get fetchingConfig => translate('fetching_config');
  String get installingTunnel => translate('installing_tunnel');

  String get ping => translate('ping');
  String get ipAddress => translate('ip_address');
  String get download => translate('download');
  String get upload => translate('upload');
  String get totalDownload => translate('total_download');
  String get totalUpload => translate('total_upload');
  String get duration => translate('duration');
  String get unknown => translate('unknown');

  String get settings => translate('settings');
  String get general => translate('general');
  String get advanced => translate('advanced');
  String get about => translate('about');
  String get autoConnect => translate('auto_connect');
  String get startMinimized => translate('start_minimized');
  String get closeToTray => translate('close_to_tray');
  String get language => translate('language');
  String get theme => translate('theme');
  String get networkStatus => translate('network_status');
  String get proxyStatus => translate('proxy_status');
  String get dnsStatus => translate('dns_status');
  String get proxyActive => translate('proxy_active');
  String get proxyDefault => translate('proxy_default');
  String get dnsCloudflare => translate('dns_cloudflare');
  String get dnsDefault => translate('dns_default');
  String get version => translate('version');
  String get autoConnectDesc => translate('auto_connect_desc');
  String get startMinimizedDesc => translate('start_minimized_desc');

  String get configName => translate('config_name');
  String get serverInfo => translate('server_info');
  String get protocol => translate('protocol');
  String get endpoint => translate('endpoint');
  String get importConfig => translate('import_config');
  String get exportConfig => translate('export_config');
  String get saveConfig => translate('save_config');

  String get connect => translate('connect');
  String get disconnect => translate('disconnect');
  String get cancel => translate('cancel');
  String get ok => translate('ok');
  String get close => translate('close');
  String get minimize => translate('minimize');

  String get closeTitle => translate('close_title');
  String get closeMessage => translate('close_message');
  String get closeBackground => translate('close_background');
  String get closeExit => translate('close_exit');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fa'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
