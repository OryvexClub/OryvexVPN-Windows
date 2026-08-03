with open("lib/l10n/app_localizations.dart", "r", encoding="utf-8") as f:
    text = f.read()

start_marker = "  static final Map<String, String> _englishValues = {"
end_marker = "  static final Map<String, String> _persianValues = {"

start_idx = text.find(start_marker)
end_idx = text.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_english = """  static final Map<String, String> _englishValues = {
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
    'clock_out_of_sync': 'Your system clock is not synchronized.\n',
    'conflicting_procs': 'Conflicting programs found: ',
    'exit_app': 'Exit app',
    'kill_all': 'Kill All',
  };

"""
    
    text = text[:start_idx] + new_english + text[end_idx:]
    with open("lib/l10n/app_localizations.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Rewrote _englishValues block")
else:
    print("Could not find markers")
