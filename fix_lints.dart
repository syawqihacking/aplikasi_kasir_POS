// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      String content = entity.readAsStringSync();
      bool modified = false;
      
      // Fix .withOpacity(X) to .withValues(alpha: X)
      final withOpacityRegex = RegExp(r'\.withOpacity\(([^)]+)\)');
      if (withOpacityRegex.hasMatch(content)) {
        content = content.replaceAllMapped(withOpacityRegex, (match) {
          return '.withValues(alpha: ${match.group(1)})';
        });
        modified = true;
      }
      
      // Fix print() to debugPrint()
      final printRegex = RegExp(r'\bprint\(');
      if (printRegex.hasMatch(content)) {
        content = content.replaceAll(printRegex, 'debugPrint(');
        
        // Ensure foundation is imported if not present
        if (!content.contains('package:flutter/foundation.dart')) {
          content = "import 'package:flutter/foundation.dart';\n$content";
        }
        modified = true;
      }
      
      if (modified) {
        entity.writeAsStringSync(content);
        count++;
        print('Fixed ${entity.path}');
      }
    }
  }
  
  print('Selesai! Berhasil memperbaiki $count file.');
}
