import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  File file = File('assets/icon.jpg');
  img.Image? image = img.decodeImage(file.readAsBytesSync());
  if (image == null) return;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.r > 240 && pixel.g > 240 && pixel.b > 240) {
        image.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
  }

  File('assets/icon_fixed.png').writeAsBytesSync(img.encodePng(image));
  print('Fixed!');
}
