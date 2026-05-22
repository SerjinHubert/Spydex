import os

def replace_between(content, start_marker, end_marker, replacement):
    start_idx = content.find(start_marker)
    if start_idx == -1: return content
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1: return content
    return content[:start_idx] + replacement + content[end_idx:]

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

dash_code = '''class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> filteredTradesData = [];
  List<Map<String, dynamic>> allTradesForExport = [];
  Map<String, double> filteredDailyTaxes = {};

  double totalProfit = 0;
  int totalTrades = 0;
  int winTrades = 0;
  int lossTrades = 0;
  double winRate = 0;
  double avgProfit = 0;
  double totalTax = 0;

  FilterType currentFilter = FilterType.allTime;
  String? selectedStockFilter;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int weekOffset = 0;

  final List<String> monthNames = [
    "January", "February", "March", "April", "May", "June", 
    "July", "August", "September", "October", "November", "December"
  ];

  void calculateStats(List<QueryDocumentSnapshot> trades, List<QueryDocumentSnapshot> taxes) {
    allTradesForExport = trades.map((doc) => doc.data() as Map<String, dynamic>).toList();
    filteredTradesData = List.from(allTradesForExport);
    filteredDailyTaxes = {};

    var allTaxes = taxes.map((doc) => doc.data() as Map<String, dynamic>).toList();

    if (currentFilter == FilterType.month) {
      filteredTradesData = filteredTradesData.where((t) {
        DateTime date = (t['time'] as Timestamp).toDate();
        return date.month == selectedMonth && date.year == selectedYear;
      }).toList();
      
      for (var tax in allTaxes) {
        DateTime d = (tax['time'] as Timestamp).toDate();
        if (d.month == selectedMonth && d.year == selectedYear) {
          filteredDailyTaxes[tax['dateString']] = (tax['taxAmount'] ?? 0).toDouble();
        }
      }
    } else if (currentFilter == FilterType.stock && selectedStockFilter != null) {
      filteredTradesData = filteredTradesData.where((t) {
        return t['stock'] == selectedStockFilter;
      }).toList();
      // No taxes considered when filtering by stock
    } else {
      for (var tax in allTaxes) {
        filteredDailyTaxes[tax['dateString']] = (tax['taxAmount'] ?? 0).toDouble();
      }
    }

    totalTrades = filteredTradesData.length;
    double grossOverall = 0;
    totalTax = 0;
    winTrades = 0;
    lossTrades = 0;

    for (var t in filteredTradesData) {
      double gr = (t['gross'] ?? 0).toDouble();
      grossOverall += gr;
      if (gr >= 0) {
        winTrades++;
      } else {
        lossTrades++;
      }
    }

    filteredDailyTaxes.forEach((k, v) { totalTax += v; });
    totalProfit = grossOverall - totalTax;

    avgProfit = totalTrades == 0 ? 0 : grossOverall / totalTrades;
    winRate = totalTrades == 0 ? 0 : (winTrades / totalTrades) * 100;
  }

  Future<void> exportCSV(BuildContext context) async {
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
  }

  void _showStockPicker() async {
    var qs = await FirebaseFirestore.instance.collection('stocks').orderBy('name').get();
    List<String> stockNames = qs.docs.map((e) => e.data()['name'] as String).toList();
    if(stockNames.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No stocks added yet.")));
        return;
    }
    if(!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
         return DraggableScrollableSheet(
           initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9,
           builder: (_, controller) {
             return Container(
               decoration: const BoxDecoration(color: Color(0xFF161616), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
               padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).padding.bottom + 16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text("Select Stock", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                       GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white54, size: 20))
                     ],
                   ),
                   const SizedBox(height: 16),
                   Expanded(
                     child: ListView.builder(
                       controller: controller,
                       itemCount: stockNames.length,
                       itemBuilder: (context, index) {
                         String s = stockNames[index];
                         bool isSelected = (currentFilter == FilterType.stock && selectedStockFilter == s);
                         return ListTile(
                           contentPadding: const EdgeInsets.symmetric(vertical: 4),
                           title: Text(s, style: TextStyle(color: isSelected ? Colors.amber : Colors.white, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                           trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.amber, size: 20) : null,
                           onTap: () {
                               setState(() { currentFilter = FilterType.stock; selectedStockFilter = s; });
                               Navigator.pop(context);
                           }
                         );
                       }
                     ),
                   ),
                 ]
               )
             );
           }
         );
      }
    );
  }

  void _showMonthYearPicker() {
    int tempMonth = selectedMonth;
    int tempYear = selectedYear;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).padding.bottom + 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Month & Year", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: tempMonth, dropdownColor: const Color(0xFF222222), isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                              items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(monthNames[index], style: const TextStyle(color: Colors.white)))),
                              onChanged: (val) { if (val != null) setModalState(() => tempMonth = val); },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: tempYear, dropdownColor: const Color(0xFF222222), isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                              items: List.generate(10, (index) {
                                int year = DateTime.now().year - 5 + index;
                                return DropdownMenuItem(value: year, child: Text("$year", style: const TextStyle(color: Colors.white)));
                              }),
                              onChanged: (val) { if (val != null) setModalState(() => tempYear = val); },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        setState(() { selectedMonth = tempMonth; selectedYear = tempYear; currentFilter = FilterType.month; });
                        Navigator.pop(context);
                      },
                      child: const Text("Apply Filter", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildEquityGraph(List<Map<String, dynamic>> tradesData, Map<String, double> taxesData) {
    if (tradesData.isEmpty) return const SizedBox();
    
    tradesData.sort((a, b) => (a['time'] as Timestamp).compareTo(b['time'] as Timestamp));

    double cumulative = 0;
    List<FlSpot> spots = [];
    List<DateTime> dates = [];
    
    // Group trades by date to accurately subtract tax per date
    Map<String, double> dailyGross = {};
    List<DateTime> uniqueDates = [];
    
    for (var t in tradesData) {
       DateTime d = (t['time'] as Timestamp).toDate();
       String dStr = DateFormat("yyyy-MM-dd").format(d);
       if (!dailyGross.containsKey(dStr)) {
          dailyGross[dStr] = 0;
          uniqueDates.add(d);
       }
       dailyGross[dStr] = dailyGross[dStr]! + (t['gross'] ?? 0).toDouble();
    }
    
    uniqueDates.sort((a,b)=>a.compareTo(b));
    
    for (int i=0; i<uniqueDates.length; i++) {
        String dStr = DateFormat("yyyy-MM-dd").format(uniqueDates[i]);
        double tax = taxesData[dStr] ?? 0.0;
        double dayNet = dailyGross[dStr]! - tax;
        cumulative += dayNet;
        spots.add(FlSpot(i.toDouble(), cumulative));
        dates.add(uniqueDates[i]);
    }

    if (spots.length < 2) return const SizedBox();

    double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Equity Curve", style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text("${cumulative >= 0 ? "" : "-"}₹${cumulative.abs().toStringAsFixed(2)}", style: TextStyle(color: cumulative >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Cumulative net P&L over time", style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY - 50, maxY: maxY + 50, gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 22,
                      interval: spots.length < 2 ? 1 : ((spots.length / 2).floorToDouble() == 0 ? 1 : (spots.length / 2).floorToDouble()),
                      getTitlesWidget: (value, meta) {
                        int i = value.toInt();
                        if (i >= dates.length || i < 0) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("${dates[i].month.toString().padLeft(2, '0')}-${dates[i].day.toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.grey, fontSize: 10)));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF222222),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        int i = spot.x.toInt();
                        DateTime d = dates[i];
                        return LineTooltipItem("${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}\\n₹${spot.y.toStringAsFixed(2)}", TextStyle(color: spot.y >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontWeight: FontWeight.bold));
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true, barWidth: 2, color: cumulative >= 0 ? Colors.greenAccent : const Color(0xFFFF5252),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [(cumulative >= 0 ? Colors.greenAccent : const Color(0xFFFF5252)).withOpacity(0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWeekdayPnL(List<Map<String, dynamic>> tradesData, Map<String, double> taxesData) {
    DateTime now = DateTime.now();
    int currentWeekday = now.weekday;
    DateTime startOfWeek = now.subtract(Duration(days: currentWeekday - 1)).subtract(Duration(days: -weekOffset * 7));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 4, hours: 23, minutes: 59, seconds: 59));
    
    Map<String, double> dailyGross = {};
    for (var t in tradesData) {
      DateTime d = (t['time'] as Timestamp).toDate();
      if (d.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && d.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
        int wd = d.weekday;
        if (wd >= 1 && wd <= 5) {
           String dStr = DateFormat("yyyy-MM-dd").format(d);
           dailyGross[dStr] = (dailyGross[dStr] ?? 0) + (t['gross'] ?? 0).toDouble();
        }
      }
    }
    
    Map<int, double> dailyNetPnL = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    
    dailyGross.forEach((dStr, gross) {
        DateTime d = DateTime.parse(dStr);
        double tax = taxesData[dStr] ?? 0.0;
        dailyNetPnL[d.weekday] = gross - tax;
    });
    
    double maxProfit = 0; int bestDay = 0; double maxAbs = 0;
    for (int i = 1; i <= 5; i++) {
       double val = dailyNetPnL[i]!;
       if (val > maxProfit) { maxProfit = val; bestDay = i; }
       if (val.abs() > maxAbs) maxAbs = val.abs();
    }
    
    List<String> shortDays = ["", "Mon", "Tue", "Wed", "Thu", "Fri"];
    String formatDateShort(DateTime d) => "${d.day} ${monthNames[d.month-1].substring(0,3)}";
    String dateRange = "${formatDateShort(startOfWeek)} - ${formatDateShort(endOfWeek)}";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Weekday PnL", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4), Text("The analysis based on the filtered trades", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bestDay != 0 ? Colors.greenAccent.withOpacity(0.1) : const Color(0xFFFF5252).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: bestDay != 0 ? Colors.greenAccent : const Color(0xFFFF5252))),
                child: Text(bestDay != 0 ? "Best: ${shortDays[bestDay]} (${maxProfit.toStringAsFixed(1)})" : "No Best Trades", style: TextStyle(color: bestDay != 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(onTap: () => setState(() => weekOffset--), child: Container(padding: const EdgeInsets.all(4), color: Colors.transparent, child: const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 16))),
              Text(dateRange, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
              GestureDetector(onTap: () => setState(() => weekOffset++), child: Container(padding: const EdgeInsets.all(4), color: Colors.transparent, child: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (index) {
              int day = index + 1;
              double val = dailyNetPnL[day]!;
              double h = 0;
              if (maxAbs > 0) h = (val.abs() / maxAbs) * 120;
              if (h < 4 && val != 0) h = 4;
              bool isPositive = val >= 0;
              Color c = isPositive ? Colors.greenAccent : const Color(0xFFFF5252);
              if (val == 0) c = Colors.transparent;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(val == 0 ? "0.0" : val.toStringAsFixed(1), style: TextStyle(color: val == 0 ? Colors.grey : c, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(width: 24, height: h > 0 ? h : 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Text(shortDays[day], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              );
            }),
          )
        ],
      )
    );
  }

  Widget toggleBox(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: active ? Colors.transparent : const Color(0xFF222222), borderRadius: BorderRadius.circular(24), border: Border.all(color: active ? Colors.amber.withOpacity(0.6) : Colors.transparent, width: 1)),
      child: Center(child: Text(text, style: TextStyle(color: active ? Colors.amber : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 14))),
    );
  }

  Widget statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
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
                calculateStats(trades, taxes);

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("SPYDEX", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              GestureDetector(
                                onTap: () => exportCSV(context),
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(20)), child: const Text("Export CSV", style: TextStyle(color: Colors.grey, fontSize: 12))),
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: GestureDetector(onTap: () => setState(() => currentFilter = FilterType.allTime), child: toggleBox("All Time", currentFilter == FilterType.allTime))),
                              const SizedBox(width: 8),
                              Expanded(child: GestureDetector(onTap: () => _showMonthYearPicker(), child: toggleBox(currentFilter == FilterType.month ? "${monthNames[selectedMonth - 1].substring(0, 3)} $selectedYear" : "Month", currentFilter == FilterType.month))),
                              const SizedBox(width: 8),
                              Expanded(child: GestureDetector(onTap: () => _showStockPicker(), child: toggleBox(currentFilter == FilterType.stock && selectedStockFilter != null ? selectedStockFilter! : "Stocks", currentFilter == FilterType.stock))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28),
                            decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                const Text("Total Profit / Loss", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 8),
                                Text("${totalProfit >= 0 ? "" : "-"}₹${totalProfit.abs().toStringAsFixed(2)}", style: TextStyle(color: totalProfit >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252), fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [Expanded(child: statCard("Total Trades", "$totalTrades", Colors.white)), const SizedBox(width: 12), Expanded(child: statCard("Win Rate", "${winRate.toStringAsFixed(1)}%", Colors.white))]),
                          const SizedBox(height: 12),
                          Row(children: [Expanded(child: statCard("Win Trades", "$winTrades", Colors.greenAccent)), const SizedBox(width: 12), Expanded(child: statCard("Loss Trades", "$lossTrades", const Color(0xFFFF5252)))]),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Avg. Gross / Trade", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 12), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${avgProfit >= 0 ? "" : "-"}₹${avgProfit.abs().toStringAsFixed(2)}", style: TextStyle(color: avgProfit >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontSize: 20, fontWeight: FontWeight.bold)))]))),
                              const SizedBox(width: 12),
                              Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Total Tax", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 12), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("-₹${totalTax.abs().toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFFF5252), fontSize: 20, fontWeight: FontWeight.bold)))]))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          buildEquityGraph(filteredTradesData, filteredDailyTaxes),
                          const SizedBox(height: 24),
                          buildWeekdayPnL(filteredTradesData, filteredDailyTaxes),
                          const SizedBox(height: 24),
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

text = replace_between(text, "class DashboardScreen extends StatefulWidget {", "//////////////// CALENDAR //////////////////", dash_code + "\n")

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(text)
print("Updated DashboardScreen successfully!")
