import os

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

target = 'inputField(taxController),'
replacement = 'inputField(taxController, onChanged: () => setState(() {})),'

if target in text:
    text = text.replace(target, replacement)
    with open("lib/main.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Replacement successful")
else:
    print("Target not found")
