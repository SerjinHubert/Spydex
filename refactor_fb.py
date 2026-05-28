import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add getCollection helper and import
if 'firebase_auth.dart' not in content:
    content = content.replace("import 'package:firebase_core/firebase_core.dart';", "import 'package:firebase_core/firebase_core.dart';\nimport 'package:firebase_auth/firebase_auth.dart';")

if 'CollectionReference<Map<String, dynamic>> getCollection' not in content:
    helper = '''
CollectionReference<Map<String, dynamic>> getCollection(String path) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return FirebaseFirestore.instance.collection(path);
  // TODO: Add legacy email check here once provided
  // if (user.email == 'LEGACY_EMAIL') return FirebaseFirestore.instance.collection(path);
  return FirebaseFirestore.instance.collection('users').doc(user.uid).collection(path);
}
'''
    content = content.replace('void main() async {', helper + '\nvoid main() async {')

# Replace FirebaseFirestore.instance.collection('...') with getCollection('...')
content = re.sub(r"FirebaseFirestore\.instance\.collection\('([^']+)'\)", r"getCollection('\1')", content)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
