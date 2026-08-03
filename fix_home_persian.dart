import 'dart:io';

void main() {
  final file = File('lib/screens/home_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    "child: const Text('Exit app'",
    "child: const Text('خروج از برنامه'"
  );
  
  content = content.replaceAll(
    "child: const Text('Kill All'",
    "child: const Text('بستن برنامه‌های مزاحم'"
  );

  file.writeAsStringSync(content);
}
