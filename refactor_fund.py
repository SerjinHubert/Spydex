import os

def replace_between(content, start_marker, end_marker, replacement):
    start_idx = content.find(start_marker)
    if start_idx == -1: return content
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1: return content
    return content[:start_idx] + replacement + content[end_idx:]

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

fund_margin_start = "class FundMarginScreen extends StatefulWidget {"

# We reconstruct the entire FundMarginScreen
new_fund_margin_code = '''class FundMarginScreen extends StatefulWidget {
  const FundMarginScreen({super.key});
  @override
  State<FundMarginScreen> createState() => _FundMarginScreenState();
}

class _FundMarginScreenState extends State<FundMarginScreen> {
  void _showTransactionDialog(String type) {
    TextEditingController amountController = TextEditingController();
    DateTime popupDate = DateTime.now();
    
    String titleStr = "Add Funds";
    String btnStr = "Add";
    Color btnColor = const Color(0xFF4CAF50);
    bool isCredit = true;
    
    if (type == "withdraw") {
       titleStr = "Withdraw Funds";
       btnStr = "Withdraw";
       btnColor = const Color(0xFF4285F4);
       isCredit = false;
    } else if (type == "penalty") {
       titleStr = "Apply Penalty";
       btnStr = "Apply";
       btnColor = Colors.deepOrange;
       isCredit = false;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161616), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(titleStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: btnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    double? val = double.tryParse(amountController.text);
                    if (val != null && val > 0) {
                      FirebaseFirestore.instance.collection('transactions').add({ 'amount': isCredit ? val : -val, 'time': Timestamp.fromDate(popupDate), 'type': type });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(btnStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    String tType = d['type'] ?? (amt > 0 ? 'add' : 'withdraw');
                    
                    if (tType == 'add' || amt > 0) {
                       items.add(LedgerItem(date: time, title: "Added Fund", subtitle: "Credited", amount: amt, isCredit: true));
                    } else if (tType == 'penalty') {
                       items.add(LedgerItem(date: time, title: "Penalty Applied", subtitle: "Debited", amount: amt.abs(), isCredit: false));
                    } else {
                       items.add(LedgerItem(date: time, title: "Payout Fund", subtitle: "Debited", amount: amt.abs(), isCredit: false));
                    }
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

                  // We need taxes that were entered on days with no trades (though our new logic blocks this, old ones or manual backend entries might exist). Let's safely ignore or we can include them. Our logic currently relies on dailyGross dates. Since we enforce trade > 0 to save tax, it's fine.

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
                            Text("₹${runningBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amber, fontSize: 41, fontWeight: FontWeight.w800, letterSpacing: -1)),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), onPressed: () => _showTransactionDialog("add"))),
                                const SizedBox(width: 12),
                                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.remove, size: 18), label: const Text("Withdraw", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), onPressed: () => _showTransactionDialog("withdraw"))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                                label: const Text("Penalty", style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                                onPressed: () => _showTransactionDialog("penalty")
                              ),
                            ),
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
                                  bool isPenalty = item.title.contains("Penalty");
                                  IconData iconData = isPenalty ? Icons.warning_amber_rounded : (item.title.contains("Fund") ? Icons.account_balance_wallet : Icons.show_chart);
                                  Color iconColor = isZero ? Colors.grey : (isPenalty ? Colors.deepOrange : (item.isCredit ? Colors.greenAccent : const Color(0xFFFF5252)));
                                  Color bgColor = isZero ? Colors.grey.withOpacity(0.1) : (isPenalty ? Colors.deepOrange.withOpacity(0.1) : (item.isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)));
                                  
                                  return Container(
                                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Icon(iconData, color: iconColor, size: 20)),
                                      title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text("${DateFormat('dd MMM hh:mm a').format(item.date)} · ${item.subtitle}", style: const TextStyle(color: Colors.white54, fontSize: 12))),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("${item.isCredit ? '+' : '-'}₹${item.amount.toStringAsFixed(2)}", style: TextStyle(color: iconColor, fontSize: 15, fontWeight: FontWeight.bold)),
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

new_text = text[:text.find(fund_margin_start)] + new_fund_margin_code
with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(new_text)

print("Update complete")
