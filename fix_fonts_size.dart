import 'dart:io';

void main() {
  var f = File('lib/main.dart');
  var c = f.readAsStringSync();
  var regex = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
  c = c.replaceAllMapped(regex, (match) {
    double size = double.parse(match.group(1)!);
    double newSize = size - 2;
    if (newSize < 8) newSize = 8; // Prevent fonts from becoming too small
    
    // Format to remove .0 if it's an integer
    String newSizeStr = newSize == newSize.toInt() ? newSize.toInt().toString() : newSize.toStringAsFixed(1);
    
    return 'fontSize: $newSizeStr';
  });
  f.writeAsStringSync(c);
}
