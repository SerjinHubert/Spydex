import os

def replace_between(content, start_marker, end_marker, replacement):
    start_idx = content.find(start_marker)
    if start_idx == -1: return content
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1: return content
    return content[:start_idx] + replacement + content[end_idx:]

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

calendar_code = '''class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? selectedDate;

  void nextMonth() { setState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1); }); }
  void prevMonth() { setState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1); }); }

  Map<String, List<QueryDocumentSnapshot>> getDailyTrades(List<QueryDocumentSnapshot> trades) {
    Map<String, List<QueryDocumentSnapshot>> data = {};
    for (var doc in trades) {
      var t = doc.data() as Map<String, dynamic>;
      DateTime date = (t['time'] as Timestamp).toDate();
      String key = DateFormat("yyyy-MM-dd").format(date);
      if (data[key] == null) data[key] = [];
      data[key]!.add(doc);
    }
    return data;
  }

  Map<String, double> getDailyTaxes(List<QueryDocumentSnapshot> taxes) {
    Map<String, double> data = {};
    for (var doc in taxes) {
      var t = doc.data() as Map<String, dynamic>;
      String key = t['dateString'];
      data[key] = (t['taxAmount'] ?? 0).toDouble();
    }
    return data;
  }

  Map<String, double> getDailyNetProfit(Map<String, List<QueryDocumentSnapshot>> dailyTrades, Map<String, double> dailyTaxesMap) {
    Map<String, double> data = {};
    dailyTrades.forEach((key, list) {
      double gross = 0;
      for (var doc in list) {
        gross += ((doc.data() as Map<String, dynamic>)['gross'] ?? 0).toDouble();
      }
      double tax = dailyTaxesMap[key] ?? 0.0;
      data[key] = gross - tax;
    });
    return data;
  }

  Widget tradeRow(String label, String value, {Color valueColor = Colors.white, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.grey, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('trades_v2').orderBy('time').snapshots(),
      builder: (context, snapshotTrades) {
         return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('daily_taxes').snapshots(),
            builder: (context, snapshotTaxes) {
                if (!snapshotTrades.hasData || !snapshotTaxes.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var trades = snapshotTrades.data!.docs;
                var taxes = snapshotTaxes.data!.docs;

                var dailyTrades = getDailyTrades(trades);
                var dailyTaxesMap = getDailyTaxes(taxes);
                var dailyNetProfit = getDailyNetProfit(dailyTrades, dailyTaxesMap);

                DateTime firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
                int startWeekday = firstDay.weekday;
                int emptyCells = startWeekday - 1;
                int daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text("Calendar", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(onTap: prevMonth, child: Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF161616)), child: const Center(child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14)))),
                              Text(DateFormat("MMMM yyyy").format(currentMonth), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              GestureDetector(onTap: nextMonth, child: Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF161616)), child: const Center(child: Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14)))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: GridView.builder(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 1, crossAxisSpacing: 1, childAspectRatio: 1.0),
                                itemCount: 7 + emptyCells + daysInMonth,
                                itemBuilder: (context, index) {
                                  if (index < 7) {
                                    List<String> headers = ["M", "T", "W", "T", "F", "S", "S"];
                                    return Container(color: const Color(0xFF121212), alignment: Alignment.center, child: Text(headers[index], style: const TextStyle(color: Colors.grey, fontSize: 12)));
                                  }
                                  int dayIndex = index - 7;
                                  if (dayIndex < emptyCells) return Container(color: const Color(0xFF161616));
                                  
                                  int day = dayIndex - emptyCells + 1;
                                  DateTime date = DateTime(currentMonth.year, currentMonth.month, day);
                                  String key = DateFormat("yyyy-MM-dd").format(date);
                                  
                                  double? profit = dailyNetProfit[key];
                                  bool isSelected = selectedDate != null && DateFormat("yyyy-MM-dd").format(selectedDate!) == key;
                                  Color bgColor = const Color(0xFF161616);
                                  if (profit != null) bgColor = profit >= 0 ? const Color(0xFF183321) : const Color(0xFF3B1E1E);

                                  return GestureDetector(
                                    onTap: () => setState(() => selectedDate = date),
                                    child: Container(
                                      color: bgColor,
                                      child: Container(
                                         decoration: BoxDecoration(border: isSelected ? Border.all(color: Colors.amber, width: 1.5) : null),
                                         child: Column(
                                           mainAxisAlignment: MainAxisAlignment.center,
                                           children: [
                                             Text("$day", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                             if (profit != null) const SizedBox(height: 4),
                                             if (profit != null)
                                               Padding(
                                                 padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                                 child: FittedBox(
                                                   fit: BoxFit.scaleDown,
                                                   child: Text("${profit >= 0 ? "+" : "-"}₹${profit.abs().toStringAsFixed(2)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.greenAccent : const Color(0xFFFF5252))),
                                                 ),
                                               ),
                                           ],
                                         ),
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.radio_button_unchecked, color: const Color(0xFF183321).withOpacity(0.8), size: 18), const SizedBox(width: 6), const Text("Profit day", style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(width: 24),
                              Icon(Icons.radio_button_unchecked, color: const Color(0xFF3B1E1E).withOpacity(0.8), size: 18), const SizedBox(width: 6), const Text("Loss day", style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 32),

                          if (selectedDate != null) ...[
                             Builder(
                               builder: (context) {
                                 String key = DateFormat("yyyy-MM-dd").format(selectedDate!);
                                 List<QueryDocumentSnapshot> dayTrades = dailyTrades[key] ?? [];
                                 double dayNet = dailyNetProfit[key] ?? 0;
                                 double taxAmount = dailyTaxesMap[key] ?? 0;

                                 if (dayTrades.isEmpty) {
                                   return Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Text(DateFormat("EEEE, d MMMM yyyy").format(selectedDate!), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                                           GestureDetector(onTap: () => setState(()=>selectedDate=null), child: const Icon(Icons.close, color: Colors.grey, size: 18)),
                                         ]
                                       ),
                                       const SizedBox(height: 12),
                                       Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40), decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: const Center(child: Text("No trade on this date.", style: TextStyle(color: Colors.grey)))),
                                       const SizedBox(height: 40),
                                     ]
                                   );
                                 }

                                 return Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Text(DateFormat("EEEE, d MMMM yyyy").format(selectedDate!), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                                         GestureDetector(onTap: () => setState(()=>selectedDate=null), child: const Icon(Icons.close, color: Colors.grey, size: 18)),
                                       ]
                                     ),
                                     const SizedBox(height: 4),
                                     Row(
                                       children: [
                                         Text("${dayTrades.length} trade${dayTrades.length > 1 ? 's' : ''} · ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                         Text("Day Net: ${dayNet >= 0 ? '+' : '-'}₹${dayNet.abs().toStringAsFixed(2)}", style: TextStyle(color: dayNet >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontSize: 13, fontWeight: FontWeight.bold)),
                                       ]
                                     ),
                                     const SizedBox(height: 16),
                                     ...dayTrades.asMap().entries.map((entry) {
                                        int index = entry.key + 1;
                                        var t = entry.value.data() as Map<String, dynamic>;
                                        double gross = (t['gross'] ?? 0).toDouble();
                                        bool isProfit = gross >= 0;
                                        Color themeColor = isProfit ? Colors.greenAccent : const Color(0xFFFF5252);
                                        
                                        return Container(
                                           margin: const EdgeInsets.only(bottom: 16),
                                           padding: const EdgeInsets.all(16),
                                           decoration: BoxDecoration(color: themeColor.withOpacity(0.04), border: Border.all(color: themeColor.withOpacity(0.4), width: 1.0), borderRadius: BorderRadius.circular(16)),
                                           child: Column(
                                             children: [
                                               Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Row(children: [Icon(isProfit ? Icons.trending_up : Icons.trending_down, color: themeColor, size: 18), const SizedBox(width: 8), Text("Trade #$index", style: const TextStyle(color: Colors.grey))]),
                                                   Text("${isProfit ? '+' : '-'}₹${gross.abs().toStringAsFixed(2)}", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                                 ],
                                               ),
                                               const SizedBox(height: 16),
                                               if (t['stock'] != null && t['stock'].toString().isNotEmpty) tradeRow("Stock", t['stock'], valueColor: Colors.amber),
                                               tradeRow("Buy Price", "₹${(t['buy'] ?? 0).toStringAsFixed(2)}"),
                                               tradeRow("Sell Price", "₹${(t['sell'] ?? 0).toStringAsFixed(2)}"),
                                               tradeRow("Quantity", "${t['qty']}"),
                                             ]
                                           )
                                        );
                                     }).toList(),
                                     if(taxAmount > 0) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(color: const Color(0x1AFF5252), border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4)), borderRadius: BorderRadius.circular(16)),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text("Day's Tax Applied", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              Text("-₹${taxAmount.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 16)),
                                            ]
                                          )
                                        ),
                                     ],
                                     const SizedBox(height: 40),
                                   ]
                                 );
                               }
                             )
                          ]
                        ],
                      ),
                    ),
                  ),
                );
            }
         );
      },
    );
  }
}'''

text = replace_between(text, "class CalendarScreen extends StatefulWidget {", "//////////////// ENTRY //////////////////", calendar_code + "\n")

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(text)
print("Updated CalendarScreen successfully!")
