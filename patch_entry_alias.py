import sys

file_path = r'c:\spydex\lib\main.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for idx, line in enumerate(lines):
    if line.startswith("import 'package:file_picker/file_picker.dart';"):
        new_lines.append("import 'package:file_picker/file_picker.dart' as fp;\n")
    elif 'FilePickerResult? result = await FilePicker.platform.pickFiles(' in line:
        new_lines.append(line.replace('FilePickerResult', 'fp.FilePickerResult').replace('FilePicker.platform', 'fp.FilePicker.platform').replace('FileType', 'fp.FileType'))
    else:
        new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Patched main.dart for FilePicker alias.")
