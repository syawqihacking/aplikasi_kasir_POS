import 'dart:io';

void main() {
  final oldFile = File('assets/logo/Minimalist Red Shopping Cart Logo.svg');
  if (oldFile.existsSync()) {
    oldFile.renameSync('assets/logo/logo.svg');
    print('Renamed successfully');
  } else {
    print('File not found');
  }
}
