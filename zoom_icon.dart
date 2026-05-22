import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  File file = File('assets/icon_fixed.png');
  img.Image? image = img.decodeImage(file.readAsBytesSync());
  if (image == null) return;

  int minX = image.width;
  int minY = image.height;
  int maxX = 0;
  int maxY = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      // Let's assume some artifacts might exist, so > 20
      if (p.r > 20 || p.g > 20 || p.b > 20) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  int croppedWidth = maxX - minX + 1;
  int croppedHeight = maxY - minY + 1;

  // For Android adaptive safe zone masking, ~66% is safe.
  // We want the spider to fill the safe zone nicely. 
  // Let the square be 1.45 * the longest edge of the spider.
  int paddedSize = (max(croppedWidth, croppedHeight) * 1.2).toInt();
  
  img.Image finalImage = img.Image(width: paddedSize, height: paddedSize);
  
  for (int y = 0; y < paddedSize; y++) {
    for (int x = 0; x < paddedSize; x++) {
      finalImage.setPixelRgba(x, y, 0, 0, 0, 255);
    }
  }

  int dx = (paddedSize - croppedWidth) ~/ 2;
  int dy = (paddedSize - croppedHeight) ~/ 2 - 10;

  for (int y = 0; y < croppedHeight; y++) {
    for (int x = 0; x < croppedWidth; x++) {
      final p = image.getPixel(minX + x, minY + y);
      finalImage.setPixelRgba(dx + x, dy + y, p.r, p.g, p.b, 255);
    }
  }

  File('assets/icon_zoomed.png').writeAsBytesSync(img.encodePng(finalImage));
  print('Zoomed!');
}
