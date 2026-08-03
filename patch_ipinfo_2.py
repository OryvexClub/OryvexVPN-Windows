with open("lib/services/ipinfo_service.dart", "r") as f:
    content = f.read()

new_clean_isp = """  String get cleanIsp {
    if (org == 'Unknown' || org == '-') {
      if (ip != 'Unknown' && ip != 'N/A') return ip;
      return 'OryvexVPN Secure Network';
    }
    return org.replaceFirst(RegExp(r'^AS\d+\s+'), '');
  }"""

import re
content = re.sub(r"  String get cleanIsp \{.*?\}", new_clean_isp, content, flags=re.DOTALL)

with open("lib/services/ipinfo_service.dart", "w") as f:
    f.write(content)
