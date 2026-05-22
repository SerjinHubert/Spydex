import os
import re

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Add import
if "import 'package:share_plus/share_plus.dart';" not in text:
    text = text.replace("import 'package:path_provider/path_provider.dart';", "import 'package:path_provider/path_provider.dart';\nimport 'package:share_plus/share_plus.dart';")

# 1. Dashboard Export
dash_target = """  Future<void> exportCSV(BuildContext context) async {
    List<List<dynamic>> rows = [];
    rows.add(["Date", "Stock", "Buy", "Sell", "Qty", "Gross"]);

    for (var t in allTradesForExport) {
      rows.add([
        DateFormat('dd-MM-yyyy').format((t['time'] as Timestamp).toDate()),
        t['stock'] ?? '',
        t['buy'],
        t['sell'],
        t['qty'],
        t['gross']
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/spydex_trades.csv");
    await file.writeAsString(csvData);
    if(context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CSV saved: ${file.path}")));
    }
  }"""

dash_rep = """  Future<void> exportCSV(BuildContext context) async {
    List<List<dynamic>> rows = [];
    rows.add(["SPYDEX"]);
    rows.add(["Intraday Ledger"]);
    rows.add([]);
    rows.add(["Date", "Stock", "Buy Price", "Sell Price", "Qty", "Gross P/L"]);

    for (var t in allTradesForExport) {
      rows.add([
        DateFormat('dd-MM-yyyy').format((t['time'] as Timestamp).toDate()),
        t['stock'] ?? '',
        t['buy'],
        t['sell'],
        t['qty'],
        t['gross']
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/spydex_intraday_ledger.csv");
    await file.writeAsString(csvData);
    
    if (mounted) {
       await Share.shareXFiles([XFile(file.path)], text: 'SPYDEX Intraday Ledger');
    }
  }"""

# 2. Profile Export
prof_target = """  Future<void> exportCSV(BuildContext context, List<QueryDocumentSnapshot> trades) async {
    List<List<dynamic>> rows = [];
    rows.add(["Date", "Buy", "Sell", "Qty", "Gross"]);
    for (var doc in trades) {
      var t = doc.data() as Map<String, dynamic>;
      rows.add([DateFormat('dd-MM-yyyy').format((t['time'] as Timestamp).toDate()), t['buy'], t['sell'], t['qty'], t['gross']]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/spydex_trades.csv");
    await file.writeAsString(csvData);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CSV saved: ${file.path}")));
  }"""

prof_rep = """  Future<void> exportCSV(BuildContext context, List<QueryDocumentSnapshot> trades) async {
    List<List<dynamic>> rows = [];
    rows.add(["SPYDEX"]);
    rows.add(["Intraday Ledger"]);
    rows.add([]);
    rows.add(["Date", "Stock", "Buy Price", "Sell Price", "Qty", "Gross P/L"]);
    
    for (var doc in trades) {
      var t = doc.data() as Map<String, dynamic>;
      rows.add([
        DateFormat('dd-MM-yyyy').format((t['time'] as Timestamp).toDate()), 
        t['stock'] ?? '', 
        t['buy'], 
        t['sell'], 
        t['qty'], 
        t['gross']
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/spydex_intraday_ledger.csv");
    await file.writeAsString(csvData);
    
    if (mounted) {
       await Share.shareXFiles([XFile(file.path)], text: 'SPYDEX Intraday Ledger');
    }
  }"""

if dash_target in text and prof_target in text:
    text = text.replace(dash_target, dash_rep)
    text = text.replace(prof_target, prof_rep)
    with open("lib/main.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("CSV replacements applied!")
else:
    print("Export targets not found")
