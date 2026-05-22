import os

def replace_between(content, start_marker, end_marker, replacement):
    start_idx = content.find(start_marker)
    if start_idx == -1: return content
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1: return content
    return content[:start_idx] + replacement + content[end_idx:]

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Update ProfileScreen start and FundMarginScreen.
# For ProfileScreen, listen to trades_v2 and daily_taxes.
# For FundMarginScreen, listen to trades_v2 and daily_taxes, transactions.

profile_start = "class ProfileScreen extends StatefulWidget {"
profile_end = "//////////////// FUND MARGIN SCREEN //////////////////"

profile_code = '''class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { profileImagePath = prefs.getString('profileImagePath'); });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImagePath', pickedFile.path);
      setState(() { profileImagePath = pickedFile.path; });
    }
  }

  Map<String, dynamic> calculateStats(List<QueryDocumentSnapshot> trades, List<QueryDocumentSnapshot> taxes) {
    int totalTrades = trades.length;
    int winTrades = 0;
    int lossTrades = 0;
    double totalGross = 0;
    double totalTax = 0;

    for (var doc in trades) {
      var t = doc.data() as Map<String, dynamic>;
      double gr = (t['gross'] ?? 0).toDouble();
      totalGross += gr;
      if (gr >= 0) winTrades++; else lossTrades++;
    }
    for (var doc in taxes) totalTax += ((doc.data() as Map<String, dynamic>)['taxAmount'] ?? 0).toDouble();

    double totalProfit = totalGross - totalTax;
    double winRate = totalTrades == 0 ? 0 : (winTrades / totalTrades) * 100;

    return { "totalTrades": totalTrades, "winTrades": winTrades, "lossTrades": lossTrades, "totalProfit": totalProfit, "winRate": winRate };
  }

  Future<void> exportCSV(BuildContext context, List<QueryDocumentSnapshot> trades) async {
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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('trades_v2').orderBy('time', descending: true).snapshots(),
      builder: (context, snapshotTrades) {
         return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('daily_taxes').snapshots(),
            builder: (context, snapshotTaxes) {
                if (!snapshotTrades.hasData || !snapshotTaxes.hasData) return const Center(child: CircularProgressIndicator());

                var trades = snapshotTrades.data!.docs;
                var taxes = snapshotTaxes.data!.docs;
                var stats = calculateStats(trades, taxes);

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        const Align(alignment: Alignment.centerLeft, child: Text("Profile", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10, width: 0.5)),
                          child: Column(
                             children: [
                                Stack(
                                   alignment: Alignment.bottomRight,
                                   children: [
                                      Container(
                                         height: 120, width: 120,
                                         decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 2.0), color: const Color(0xFF1A1A1A), image: profileImagePath != null ? DecorationImage(image: FileImage(File(profileImagePath!)), fit: BoxFit.cover) : null),
                                         child: profileImagePath == null ? const Icon(Icons.person, color: Colors.amber, size: 60) : null,
                                      ),
                                      GestureDetector(onTap: _pickImage, child: Container(height: 38, width: 38, decoration: BoxDecoration(color: const Color(0xFF222222), shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 1.5)), child: const Icon(Icons.edit, color: Colors.amber, size: 18)))
                                   ]
                                ),
                                const SizedBox(height: 24),
                                const Text("SHAMINI HUBERT", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                const SizedBox(height: 6),
                                const Text("SPYDEX Founder", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(height: 36),
                                Row(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                      Expanded(child: stat("Trades", stats["totalTrades"].toString(), Colors.amber)),
                                      Container(width: 1, height: 36, color: Colors.white10),
                                      Expanded(child: stat("Win Rate", "${stats["winRate"].toStringAsFixed(0)}%", stats["winRate"] >= 50 ? Colors.greenAccent : const Color(0xFFFF5252))),
                                      Container(width: 1, height: 36, color: Colors.white10),
                                      Expanded(child: stat("P&L", "${stats["totalProfit"] >= 0 ? "" : "-"}₹${stats["totalProfit"].abs().toStringAsFixed(2)}", stats["totalProfit"] >= 0 ? Colors.greenAccent : const Color(0xFFFF5252))),
                                   ]
                                )
                             ]
                          )
                        ),
                        const SizedBox(height: 20),
                        // Fund Margin Tile
                        GestureDetector(
                          onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const FundMarginScreen())); },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 22),
                                const SizedBox(width: 16),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text("Fund Margin", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text("Manage your trading capital", style: TextStyle(color: Colors.grey, fontSize: 13))])
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Export CSV
                        GestureDetector(
                          onTap: () => exportCSV(context, trades),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
                            child: Row(
                              children: [
                                const Icon(Icons.download, color: Colors.amber, size: 22),
                                const SizedBox(width: 16),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Export CSV", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text("Download all ${stats['totalTrades']} trades", style: const TextStyle(color: Colors.grey, fontSize: 13))])
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Settings
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
                          child: Row(
                            children: [
                              const Icon(Icons.settings, color: Colors.white38, size: 22),
                              const SizedBox(width: 16),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text("Settings", style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text("Coming soon", style: TextStyle(color: Colors.white38, fontSize: 13))])
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Info
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
                          child: const Text("More features coming soon — broker integrations, strategy tagging, and more.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                        ),
                        const SizedBox(height: 30),
                        const Center(child: Text("SPYDEX v1.0 — Your Premium Trading Journal", style: TextStyle(color: Colors.white38, fontSize: 12))),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
            }
         );
      },
    );
  }

  Widget stat(String title, String value, Color color) {
    return Column(children: [Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13))]);
  }
}

class LedgerItem {
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  double balance;
  LedgerItem({required this.date, required this.title, required this.subtitle, required this.amount, required this.isCredit, this.balance = 0.0});
}
'''

text = replace_between(text, profile_start, profile_end, profile_code + "\n")

fund_margin_start = "class FundMarginScreen extends StatefulWidget {"

# To get the rest of the file we replace from fund_margin_start to end of file, assuming there are no other screens.
if fund_margin_start in text:
    old_fund = text[text.find(fund_margin_start):]
    fund_margin_new = old_fund.replace("stream: FirebaseFirestore.instance.collection('trades').snapshots()", "stream: FirebaseFirestore.instance.collection('trades_v2').snapshots()")
    
    # Needs to also subtract taxes. Rather than write a very complex parser for Fund Margin, I will just do simple text replacement.
    fund_margin_new = fund_margin_new.replace("double net = (t['net'] ?? 0).toDouble();", "double net = (t['gross'] ?? 0).toDouble();")
    
    # Wait, taxes are missed here if we only read trades.
    # To fix Fund Margin to include taxes, it requires rewriting build method heavily.
    # Let's replace the whole FundMarginScreen instead.
    
    pass

fund_margin_code = '''class FundMarginScreen extends StatefulWidget {
  const FundMarginScreen({super.key});
  @override
  State<FundMarginScreen> createState() => _FundMarginScreenState();
}

class _FundMarginScreenState extends State<FundMarginScreen> {
  void _showTransactionDialog(bool isAdd) {
    TextEditingController amountController = TextEditingController();
    DateTime popupDate = DateTime.now();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161616), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isAdd ? "Add Funds" : "Withdraw Funds", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(context: context, initialDate: popupDate, firstDate: DateTime(2000), lastDate: DateTime.now(), builder: (context, child) { return Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.amber, onPrimary: Colors.black, surface: Color(0xFF1A1A1A), onSurface: Colors.white), dialogBackgroundColor: const Color(0xFF161616)), child: child!); });
                      if (picked != null) setDialogState(() { popupDate = picked; });
                    },
                    child: Container(
                      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('dd MMM yyyy').format(popupDate), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const Icon(Icons.calendar_today, color: Colors.grey, size: 18)]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 48, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "Enter amount", hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isAdd ? const Color(0xFF4CAF50) : const Color(0xFF4285F4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    double? val = double.tryParse(amountController.text);
                    if (val != null && val > 0) {
                      FirebaseFirestore.instance.collection('transactions').add({ 'amount': isAdd ? val : -val, 'time': Timestamp.fromDate(popupDate), 'type': isAdd ? 'add' : 'withdraw' });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(isAdd ? "Add" : "Withdraw", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text("Fund Margin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: Colors.white)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('trades_v2').snapshots(),
        builder: (context, tradesSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('daily_taxes').snapshots(),
            builder: (context, taxesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
                builder: (context, transSnapshot) {
                  if (!tradesSnapshot.hasData || !transSnapshot.hasData || !taxesSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var trades = tradesSnapshot.data!.docs;
                  var transactions = transSnapshot.data!.docs;
                  var taxes = taxesSnapshot.data!.docs;

                  List<LedgerItem> items = [];
                  for (var doc in transactions) {
                    var d = doc.data() as Map<String, dynamic>;
                    double amt = (d['amount'] ?? 0).toDouble();
                    if (amt == 0) continue;
                    Timestamp? ts = d['time'] as Timestamp?;
                    if (ts == null) continue;
                    DateTime time = ts.toDate();
                    if (amt > 0) items.add(LedgerItem(date: time, title: "Added Fund", subtitle: "Credited", amount: amt, isCredit: true));
                    else items.add(LedgerItem(date: time, title: "Payout Fund", subtitle: "Debited", amount: amt.abs(), isCredit: false));
                  }

                  Map<String, double> dailyGross = {};
                  Map<String, DateTime> dailyDates = {};
                  for (var doc in trades) {
                    var t = doc.data() as Map<String, dynamic>;
                    Timestamp? ts = t['time'] as Timestamp?;
                    if (ts == null) continue;
                    DateTime time = ts.toDate();
                    String dateKey = DateFormat('yyyy-MM-dd').format(time);
                    double gross = (t['gross'] ?? 0).toDouble();
                    dailyGross[dateKey] = (dailyGross[dateKey] ?? 0) + gross;
                    dailyDates[dateKey] = time;
                  }

                  Map<String, double> dailyTaxesMap = {};
                  for (var doc in taxes) {
                     var t = doc.data() as Map<String, dynamic>;
                     dailyTaxesMap[t['dateString']] = (t['taxAmount'] ?? 0).toDouble();
                  }

                  dailyGross.forEach((dateKey, grossValue) {
                     double tax = dailyTaxesMap[dateKey] ?? 0.0;
                     double netValue = grossValue - tax;
                     if (netValue.abs() > 0.01) {
                        if (netValue > 0) items.add(LedgerItem(date: dailyDates[dateKey]!, title: "Trading Profit", subtitle: "Credited", amount: netValue, isCredit: true));
                        else items.add(LedgerItem(date: dailyDates[dateKey]!, title: "Trading Loss", subtitle: "Debited", amount: netValue.abs(), isCredit: false));
                     }
                  });

                  items.sort((a, b) => a.date.compareTo(b.date));
                  double runningBalance = 0;
                  for (var item in items) {
                    if (item.isCredit) runningBalance += item.amount;
                    else runningBalance -= item.amount;
                    item.balance = runningBalance;
                  }
                  items = items.reversed.toList();

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(color: Color(0xFF161616), border: Border(bottom: BorderSide(color: Colors.white10))),
                        child: Column(
                          children: [
                            const Text("Available Margin", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Text("₹${runningBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), onPressed: () => _showTransactionDialog(true))),
                                const SizedBox(width: 12),
                                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.remove, size: 18), label: const Text("Withdraw", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), onPressed: () => _showTransactionDialog(false))),
                              ],
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.white54)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  var item = items[index];
                                  bool isZero = item.amount == 0;
                                  return Container(
                                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: isZero ? Colors.grey.withOpacity(0.1) : (item.isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)), borderRadius: BorderRadius.circular(10)), child: Icon(item.title.contains("Fund") ? Icons.account_balance_wallet : Icons.show_chart, color: isZero ? Colors.grey : (item.isCredit ? Colors.greenAccent : const Color(0xFFFF5252)), size: 20)),
                                      title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text("${DateFormat('dd MMM hh:mm a').format(item.date)} · ${item.subtitle}", style: const TextStyle(color: Colors.white54, fontSize: 12))),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("${item.isCredit ? '+' : '-'}₹${item.amount.toStringAsFixed(2)}", style: TextStyle(color: isZero ? Colors.white : (item.isCredit ? Colors.greenAccent : const Color(0xFFFF5252)), fontSize: 15, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text("₹${item.balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                }
              );
            }
          );
        }
      )
    );
  }
}
'''

text = text[:text.find(fund_margin_start)] + fund_margin_code

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(text)
print("Updated ProfileScreen and FundMarginScreen successfully!")
