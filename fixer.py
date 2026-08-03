with open("lib/l10n/app_localizations.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "Your system clock is not synchronized" in line:
        new_lines.append("    'clock_out_of_sync': 'Your system clock is not synchronized.\n',\n")
    elif "ساعت سیستم شما تنظیم نیست." in line:
        new_lines.append("    'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',\n")
    elif line.strip() in ["'", "',"] and len(new_lines) > 0 and "'clock_out_of_sync'" in new_lines[-1]:
        # skip this garbage line
        pass
    else:
        new_lines.append(line)

with open("lib/l10n/app_localizations.dart", "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("done")
