import re
import os
import glob

def clean_stray_scripts():
    # Clean up all those stray fix_tool*.py files
    for f in glob.glob("fix_tool*.py"):
        try:
            os.remove(f)
            print(f"Removed {f}")
        except:
            pass

def fix_app_localizations():
    file_path = "lib/l10n/app_localizations.dart"
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        # The issue is on line 191/192 where a string was split across lines with a raw newline
        # Let's fix the entire block by doing a precise regex replacement
        # First, let's fix any occurrences of the literal newline in the middle of the string
        
        # This regex looks for 'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست. followed by a real newline, then ',
        pattern1 = r"'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست\.\n',"
        replacement1 = r"'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',"
        
        # Another possible broken state
        pattern2 = r"'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست\.\n'\n,"
        replacement2 = r"'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',"
        
        # Another possible broken state with multiple quotes
        pattern3 = r"'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست\.\n',\n',\n"
        replacement3 = r"'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',\n"

        content = re.sub(pattern3, replacement3, content)
        content = re.sub(pattern2, replacement2, content)
        content = re.sub(pattern1, replacement1, content)
        
        # Let's just find the exact block and replace it cleanly
        block_to_find = "'sys_warning': 'هشدار سیستم',\n    'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',\n    'conflicting_procs': 'برنامه‌های متداخل یافت شد: ',"
        block_to_replace = "'sys_warning': 'هشدار سیستم',\n    'clock_out_of_sync': 'ساعت سیستم شما تنظیم نیست.\n',\n    'conflicting_procs': 'برنامه‌های متداخل یافت شد: ',"
        content = content.replace(block_to_find, block_to_replace)

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("Fixed lib/l10n/app_localizations.dart")
    except Exception as e:
        print(f"Error fixing app_localizations.dart: {e}")

def fix_home_screen():
    file_path = "lib/screens/home_screen.dart"
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # The analyzer complains about directives after declarations
        # This usually means an import is in the middle of the file.
        # Let's look for "import 'dart:async';" which we added earlier and move it to the top.
        if "import 'dart:async';" in content and content.find("import 'dart:async';") > content.find("class HomeScreen"):
            content = content.replace("import 'dart:async';\nclass _HomeScreenState", "class _HomeScreenState")
            content = "import 'dart:async';\n" + content
            
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("Fixed lib/screens/home_screen.dart directives")
    except Exception as e:
        print(f"Error fixing home_screen.dart: {e}")

if __name__ == "__main__":
    clean_stray_scripts()
    fix_app_localizations()
    fix_home_screen()
