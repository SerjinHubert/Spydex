import os

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

target = 'const Text("Available Margin", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),'

replacement = '''Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text("Available margin (Cash + Collateral)", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                SizedBox(width: 6),
                                Icon(Icons.info_outline, color: Colors.grey, size: 14),
                              ],
                            ),'''

if target in text:
    text = text.replace(target, replacement)
    with open("lib/main.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Replacement successful")
else:
    print("Target block not found, check formatting.")
