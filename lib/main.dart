import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'data/trade_data.dart';

enum FilterType { allTime, month, stock }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SpydexApp());
}

class AdaptiveScaleWrapper extends StatelessWidget {
  final Widget child;
  const AdaptiveScaleWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Base design width (iPhone 12/13/14 Pro)
    double baseWidth = 390.0;
    
    // Calculate the precise scale factor needed to match the current screen width.
    double scale = media.size.width / baseWidth;

    // Constrain scale to prevent extreme zoom on tablets/web
    if (scale > 1.35) scale = 1.35;
    if (scale < 0.85) scale = 0.85;

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: media.size.width / scale,
        height: media.size.height / scale,
        child: MediaQuery(
          // Pass down the simulated dimensions to all children
          data: media.copyWith(
            size: Size(media.size.width / scale, media.size.height / scale),
            viewInsets: media.viewInsets / scale,
            viewPadding: media.viewPadding / scale,
            padding: media.padding / scale,
            // Lock TextScaler because the Transform.scale already physically scales the text!
            // This prevents "fatten numbers" on large accessibility settings without shrinking the UI.
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SpydexApp extends StatelessWidget {
  const SpydexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      builder: (context, child) {
        return AdaptiveScaleWrapper(child: child!);
      },
      home: const LockScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  List<int> enteredPasscode = [];
  bool isError = false;
  String? profileImagePath;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profileImagePath = prefs.getString('profileImagePath');
    });
  }

  void _onNumberPress(int number) {
    if (enteredPasscode.length >= 4) return;
    setState(() {
      isError = false;
      enteredPasscode.add(number);
    });

    if (enteredPasscode.length == 4) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (enteredPasscode.join() == "0000") {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else {
          setState(() {
            isError = true;
            enteredPasscode.clear();
          });
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0.0);
        }
      });
    }
  }

  void _onBackspace() {
    if (enteredPasscode.isNotEmpty) {
      setState(() {
        isError = false;
        enteredPasscode.removeLast();
      });
    }
  }

  Widget _numBtn(int number, double btnHeight) {
    return GestureDetector(
      onTap: () => _onNumberPress(number),
      child: Container(
        width: 85,
        height: btnHeight,
        decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
        child: Center(
            child: Text(number.toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double h = constraints.maxHeight;
            bool isSmall = h < 700;
            double avatarSize = isSmall ? 90 : 130;
            double titleSize = isSmall ? 35 : 45;
            double btnHeight = isSmall ? 52 : 60;
            double btnGap = isSmall ? 10 : 14;

            return SizedBox(
              width: double.infinity,
              height: h,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text("SPYDEX", style: TextStyle(color: Colors.amber, fontSize: titleSize, fontWeight: FontWeight.bold, letterSpacing: 3)),
                  const SizedBox(height: 6),
                  const Text("Focus. Discipline. Trade.", style: TextStyle(color: Colors.amber, fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.w400)),
                  const Spacer(flex: 3),
                  Container(
                    height: avatarSize,
                    width: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
                      color: const Color(0xFF1A1A1A),
                      image: profileImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(profileImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: profileImagePath == null ? const Icon(Icons.person, color: Colors.amber, size: 40) : null,
                  ),
                  const Spacer(flex: 2),
                  const Text("Welcome Trader", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  const Text("Enter Passcode", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = index < enteredPasscode.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                        color: isError ? Colors.red.withOpacity(0.05) : (isFilled ? Colors.transparent : const Color(0xFF0F0F0F)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isError ? const Color(0xFFFF5252) : (isFilled ? Colors.amber : Colors.white10),
                          width: isFilled ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: isFilled ? Icon(Icons.circle, color: isError ? const Color(0xFFFF5252) : Colors.amber, size: 14) : null,
                      ),
                    );
                  }),
                ),
              ),
            ),
                  if (isError) ...[
                    const Spacer(),
                    const Text("Wrong passcode. Try again.", style: TextStyle(color: Color(0xFFFF5252), fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                  ] else ...[
                    const Spacer(flex: 2),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_numBtn(1, btnHeight), _numBtn(2, btnHeight), _numBtn(3, btnHeight)]),
                        SizedBox(height: btnGap),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_numBtn(4, btnHeight), _numBtn(5, btnHeight), _numBtn(6, btnHeight)]),
                        SizedBox(height: btnGap),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_numBtn(7, btnHeight), _numBtn(8, btnHeight), _numBtn(9, btnHeight)]),
                        SizedBox(height: btnGap),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(width: 85, height: btnHeight),
                            _numBtn(0, btnHeight),
                            GestureDetector(
                              onTap: _onBackspace,
                              child: Container(
                                width: 85,
                                height: btnHeight,
                                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
                                child: const Center(child: Icon(Icons.backspace_outlined, color: Colors.grey, size: 22)),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const EntryScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: screens[currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Calendar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "Entry",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

//////////////// DASHBOARD //////////////////

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> filteredTradesData = [];
  List<Map<String, dynamic>> allTradesForExport = [];
  Map<String, double> filteredDailyTaxes = {};
  int _touchedCapitalPieIndex = -1;

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
    if (tradesData.isEmpty && taxesData.isEmpty) return const SizedBox();
    
    tradesData.sort((a, b) => (a['time'] as Timestamp).compareTo(b['time'] as Timestamp));

    double cumulative = 0;
    List<FlSpot> spots = [];
    List<DateTime> dates = [];
    
    // Group trades and taxes by date to accurately plot net daily changes
    Map<String, double> dailyGross = {};
    Map<String, DateTime> stringToDate = {};
    
    for (var t in tradesData) {
       DateTime d = (t['time'] as Timestamp).toDate();
       String dStr = DateFormat("yyyy-MM-dd").format(d);
       if (!stringToDate.containsKey(dStr)) {
          dailyGross[dStr] = 0;
          stringToDate[dStr] = d;
       }
       dailyGross[dStr] = dailyGross[dStr]! + (t['gross'] ?? 0).toDouble();
    }
    
    taxesData.forEach((dStr, taxVal) {
       if (!stringToDate.containsKey(dStr)) {
          stringToDate[dStr] = DateTime.parse(dStr);
          dailyGross[dStr] = 0;
       }
    });

    List<DateTime> uniqueDates = stringToDate.values.toList();
    uniqueDates.sort((a,b) => a.compareTo(b));
    
    for (int i=0; i<uniqueDates.length; i++) {
        String dStr = DateFormat("yyyy-MM-dd").format(uniqueDates[i]);
        double tax = taxesData[dStr] ?? 0.0;
        double dayNet = (dailyGross[dStr] ?? 0.0) - tax;
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
            height: 260,
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
                        return LineTooltipItem("${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}\n₹${spot.y.toStringAsFixed(2)}", TextStyle(color: spot.y >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontWeight: FontWeight.bold));
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
                    Text("Weekday P&L", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget buildCapitalCompositionPieChart(List<QueryDocumentSnapshot> trades, List<QueryDocumentSnapshot> taxes) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snapshotTrans) {
        if (!snapshotTrans.hasData) return const SizedBox();

        List<LedgerItem> items = [];
        for (var doc in snapshotTrans.data!.docs) {
          var d = doc.data() as Map<String, dynamic>;
          double amt = (d['amount'] ?? 0).toDouble();
          if (amt == 0) continue;
          Timestamp? ts = d['time'] as Timestamp?;
          if (ts == null) continue;
          DateTime time = ts.toDate();
          String tType = d['type'] ?? (amt > 0 ? 'add' : 'withdraw');
          if (tType == 'add' || amt > 0) {
             items.add(LedgerItem(date: time, title: "Added Fund", subtitle: "Credited", amount: amt, isCredit: true, docId: doc.id));
          } else if (tType == 'penalty') {
             items.add(LedgerItem(date: time, title: "Penalty Applied", subtitle: "Debited", amount: amt.abs(), isCredit: false, docId: doc.id));
          } else {
             items.add(LedgerItem(date: time, title: "Payout Fund", subtitle: "Debited", amount: amt.abs(), isCredit: false, docId: doc.id));
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

        items.sort((a, b) => a.date.compareTo(b.date));

        double runningBalance = 0;
        double activeMargin = 0;
        for (var item in items) {
           if (item.title == "Added Fund") {
               activeMargin += item.amount;
               runningBalance += item.amount;
           } else if (item.title == "Payout Fund" || item.title == "Penalty Applied") {
               activeMargin -= item.amount;
               runningBalance -= item.amount;
           } else if (item.title == "Trading Profit") {
               runningBalance += item.amount;
           } else if (item.title == "Trading Loss") {
               runningBalance -= item.amount;
           }
           
           if (activeMargin < 0) activeMargin = 0;
           if (runningBalance <= 0.01) activeMargin = 0;
        }

        bool isProfit = runningBalance >= activeMargin;
        double pieCapital = activeMargin > 0 ? activeMargin : 0;
        double piePnL = (runningBalance - activeMargin).abs();
        
        // Ensure PnL slice is always visible (at least 5% of pie) if it exists
        double visualCapital = pieCapital;
        double visualPnL = piePnL;
        if (piePnL > 0) {
           double total = pieCapital + piePnL;
           if (piePnL / total < 0.05) {
               visualPnL = visualCapital * 0.05 / 0.95; 
           }
        }
        
        // If everything is 0, provide a default
        if (visualCapital == 0 && visualPnL == 0) visualCapital = 1;

        double totalVisual = visualCapital + visualPnL;
        double pnlAngle = (visualPnL / totalVisual) * 360;
        // 315 degrees is 1:30 o'clock. To center the PnL slice at 1:30 o'clock:
        double startDegree = 315 - (pnlAngle / 2);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Capital Composition", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("True financial state of your margin", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: SizedBox(
                              height: 220,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedCapitalPieIndex = -1;
                                          return;
                                        }
                                        _touchedCapitalPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 0,
                                  startDegreeOffset: startDegree,
                                  sections: [
                                    if (piePnL > 0)
                                      PieChartSectionData(
                                        color: isProfit ? Colors.greenAccent : const Color(0xFFFF5252),
                                        value: visualPnL,
                                        showTitle: false,
                                        radius: _touchedCapitalPieIndex == 0 ? 70 : 65,
                                      ),
                                    PieChartSectionData(
                                      color: Colors.white,
                                      value: visualCapital,
                                      showTitle: false,
                                      radius: _touchedCapitalPieIndex == (piePnL > 0 ? 1 : 0) ? 70 : 65,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegendItem(
                                  color: Colors.white, 
                                  label: "Active Margin", 
                                  value: activeMargin
                                ),
                                const SizedBox(height: 16),
                                _buildLegendItem(
                                  color: isProfit ? Colors.greenAccent : const Color(0xFFFF5252), 
                                  label: isProfit ? "Profit Fund" : "Loss Fund", 
                                  value: piePnL,
                                  isNegative: !isProfit
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_touchedCapitalPieIndex != -1)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CalloutPainter(
                              touchedIndex: _touchedCapitalPieIndex,
                              isPnLOnlySlice: piePnL == 0,
                              containerWidth: constraints.maxWidth,
                              containerHeight: 180,
                              text: _touchedCapitalPieIndex == 0 && piePnL > 0 ? "₹${piePnL.toStringAsFixed(2)}" : "₹${pieCapital.toStringAsFixed(2)}",
                              color: _touchedCapitalPieIndex == 0 && piePnL > 0 ? (isProfit ? Colors.greenAccent : const Color(0xFFFF5252)) : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  );
                }
              ),
            ],
          ),
        );
      }
    );
  }



  Widget _buildLegendItem({required Color color, required String label, required double value, bool isNegative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 4),
        Text("${isNegative && value > 0 ? '-' : ''}₹${value.abs().toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
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
                if (snapshotTrades.hasError) {
                  return Center(child: Text("Error (Trades): ${snapshotTrades.error}", style: const TextStyle(color: Colors.red)));
                }
                if (snapshotTaxes.hasError) {
                  return Center(child: Text("Error (Taxes): ${snapshotTaxes.error}", style: const TextStyle(color: Colors.red)));
                }
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
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 36),
                            decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                const Text("Total Profit / Loss", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(height: 12),
                                Text("${totalProfit >= 0 ? "" : "-"}₹${totalProfit.abs().toStringAsFixed(2)}", style: TextStyle(color: totalProfit >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252), fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(child: statCard("Total Trades", "$totalTrades", Colors.white)), const SizedBox(width: 16), Expanded(child: statCard("Win Rate", "${winRate.toStringAsFixed(1)}%", Colors.white))]),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(child: statCard("Win Trades", "$winTrades", Colors.greenAccent)), const SizedBox(width: 16), Expanded(child: statCard("Loss Trades", "$lossTrades", const Color(0xFFFF5252)))]),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Avg. P&L / Trade", style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 16), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${avgProfit >= 0 ? "" : "-"}₹${avgProfit.abs().toStringAsFixed(2)}", style: TextStyle(color: avgProfit >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontSize: 24, fontWeight: FontWeight.bold)))]))),
                              const SizedBox(width: 16),
                              Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Total Tax", style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 16), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("-₹${totalTax.abs().toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFFF5252), fontSize: 24, fontWeight: FontWeight.bold)))]))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          buildEquityGraph(filteredTradesData, filteredDailyTaxes),
                          const SizedBox(height: 24),
                          buildWeekdayPnL(filteredTradesData, filteredDailyTaxes),
                          const SizedBox(height: 24),
                          if (currentFilter == FilterType.allTime)
                            buildCapitalCompositionPieChart(trades, taxes),
                          if (currentFilter == FilterType.allTime)
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
}
//////////////// CALENDAR //////////////////

class CalendarScreen extends StatefulWidget {
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
                if (snapshotTrades.hasError) {
                  return Center(child: Text("Error (Trades): ${snapshotTrades.error}", style: const TextStyle(color: Colors.red)));
                }
                if (snapshotTaxes.hasError) {
                  return Center(child: Text("Error (Taxes): ${snapshotTaxes.error}", style: const TextStyle(color: Colors.red)));
                }
                if (!snapshotTrades.hasData || !snapshotTaxes.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var trades = snapshotTrades.data!.docs;
                var taxes = snapshotTaxes.data!.docs;

                var dailyTrades = getDailyTrades(trades);
                var dailyTaxesMap = getDailyTaxes(taxes);
                var dailyNetProfit = getDailyNetProfit(dailyTrades, dailyTaxesMap);

                DateTime firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
                int startWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
                int emptyCells = startWeekday;
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
                                    List<String> headers = ["S", "M", "T", "W", "T", "F", "S"];
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
}

class CalloutPainter extends CustomPainter {
  final int touchedIndex;
  final bool isPnLOnlySlice;
  final double containerWidth;
  final double containerHeight;
  final String text;
  final Color color;

  CalloutPainter({
    required this.touchedIndex,
    required this.isPnLOnlySlice,
    required this.containerWidth,
    required this.containerHeight,
    required this.text,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (touchedIndex == -1) return;

    Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    Path path = Path();
    
    TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    double pieWidth = containerWidth * 5 / 9;
    double centerX = pieWidth / 2;
    double centerY = containerHeight / 2;

    if (touchedIndex == 0 && !isPnLOnlySlice) {
      // Right slice (PnL centered at 1:30 o'clock)
      double startX = centerX + 49.5; // 70 * cos(45deg)
      double startY = centerY - 49.5; // 70 * sin(45deg)
      double elbowX = startX + 25;
      double elbowY = centerY - 85; // Completely above the pie
      double endX = elbowX + 15;
      
      path.moveTo(startX, startY);
      path.lineTo(elbowX, elbowY);
      path.lineTo(endX, elbowY);
      canvas.drawPath(path, linePaint);
      
      Rect textRect = Rect.fromLTWH(endX + 5, elbowY - textPainter.height / 2 - 6, textPainter.width + 16, textPainter.height + 12);
      canvas.drawRRect(RRect.fromRectAndRadius(textRect, const Radius.circular(6)), Paint()..color = const Color(0xFF2C2C2E));
      canvas.drawRRect(RRect.fromRectAndRadius(textRect, const Radius.circular(6)), Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke);
      textPainter.paint(canvas, Offset(endX + 13, elbowY - textPainter.height / 2));
    } else {
      // Left slice (Capital)
      double startX = centerX - 40;
      double startY = centerY - 55; // Anchor at top-left of pie curve
      double elbowX = startX + 30;  // Go UP-RIGHT to center it over the pie
      double elbowY = centerY - 85; // Completely above the pie
      double endX = elbowX + 20;    // Horizontal segment
      
      path.moveTo(startX, startY);
      path.lineTo(elbowX, elbowY);
      path.lineTo(endX, elbowY);
      canvas.drawPath(path, linePaint);
      
      Rect textRect = Rect.fromLTWH(endX + 5, elbowY - textPainter.height / 2 - 6, textPainter.width + 16, textPainter.height + 12);
      canvas.drawRRect(RRect.fromRectAndRadius(textRect, const Radius.circular(6)), Paint()..color = const Color(0xFF2C2C2E));
      canvas.drawRRect(RRect.fromRectAndRadius(textRect, const Radius.circular(6)), Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke);
      textPainter.paint(canvas, Offset(endX + 13, elbowY - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CalloutPainter oldDelegate) {
    return oldDelegate.touchedIndex != touchedIndex || oldDelegate.text != text;
  }
}
//////////////// ENTRY //////////////////

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  bool isTradeEntry = true; // Toggle state: true = Trade, false = Tax

  // Trade fields
  final TextEditingController buyController = TextEditingController();
  final TextEditingController sellController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  double gross = 0;
  String? selectedStock;

  // Tax fields
  final TextEditingController taxController = TextEditingController();

  bool _isSaving = false;
  bool _hasAttemptedSave = false;
  DateTime selectedDate = DateTime.now();
  Key autocompleteKey = UniqueKey();
  String? uploadedFileName;
  List<Map<String, dynamic>> pendingTrades = [];

  bool get showTradeWarning => buyController.text.isEmpty || sellController.text.isEmpty || qtyController.text.isEmpty;
  bool get showTaxWarning => taxController.text.isEmpty;

  void calculateTrade() {
    double buy = double.tryParse(buyController.text) ?? 0;
    double sell = double.tryParse(sellController.text) ?? 0;
    setState(() {
      gross = sell - buy; // Formula specified
    });
  }


  Future<void> _pickAndParseCSV() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        String fileName = result.files.single.name;
        
        List<List<dynamic>> rows = [];
        
        if (path.toLowerCase().endsWith('.csv')) {
            String input = File(path).readAsStringSync();
            rows = const CsvToListConverter(eol: '\n').convert(input);
        } else {
            var bytes = File(path).readAsBytesSync();
            var excel = ex.Excel.decodeBytes(bytes);
            for (var table in excel.tables.keys) {
                for (var row in excel.tables[table]!.rows) {
                    rows.add(row.map((e) => e?.value?.toString() ?? '').toList());
                }
            }
        }

        double parsedTax = 0;
        DateTime? parsedDate;
        
        bool isParsingTrades = false;
        List<Map<String, dynamic>> extractedTrades = [];
        
        int symbolIdx = -1, qtyIdx = -1, buyIdx = -1, sellIdx = -1;

        for (int i = 0; i < rows.length; i++) {
          var row = rows[i];
          if (row.isEmpty) {
              isParsingTrades = false; continue;
          }
          
          if (!isParsingTrades) {
              symbolIdx = -1; qtyIdx = -1; buyIdx = -1; sellIdx = -1;
              for (int j = 0; j < row.length; j++) {
                  String cell = row[j].toString().trim().toLowerCase();
                  
                  if (cell == 'charges' && j + 1 < row.length && parsedTax == 0) {
                      String taxStr = row[j+1].toString().replaceAll(',', '').trim();
                      if (taxStr.isEmpty && j + 2 < row.length) taxStr = row[j+2].toString().replaceAll(',', '').trim();
                      double pt = double.tryParse(taxStr) ?? 0;
                      if (pt > 0) parsedTax = pt;
                  }
                  
                  if (cell.contains('from ') && parsedDate == null) {
                      RegExp exp = RegExp(r'from (\d{4}-\d{2}-\d{2})');
                      var match = exp.firstMatch(cell);
                      if (match != null) {
                          parsedDate = DateTime.tryParse(match.group(1)!);
                      }
                  }
                  
                  if (cell == 'symbol') symbolIdx = j;
                  if (cell == 'quantity' || cell == 'qty' || cell == 'qty.') qtyIdx = j;
                  if (cell == 'buy value' || cell == 'buy average') buyIdx = j;
                  if (cell == 'sell value' || cell == 'sell average') sellIdx = j;
              }
              
              if (symbolIdx != -1 && buyIdx != -1 && sellIdx != -1) {
                  if (qtyIdx == -1) qtyIdx = symbolIdx + 2; // Fallback
                  isParsingTrades = true;
                  continue;
              }
          }
          
          if (isParsingTrades) {
             String s = symbolIdx < row.length ? row[symbolIdx].toString().trim() : '';
             
             if (s.isEmpty) continue; // Skip blank rows
             if (s.toLowerCase().contains('total')) {
                 isParsingTrades = false; 
                 symbolIdx = -1; qtyIdx = -1; buyIdx = -1; sellIdx = -1;
                 continue;
             }
             
             String qStr = qtyIdx < row.length ? row[qtyIdx].toString().replaceAll(',', '').trim() : '';
             String bStr = buyIdx < row.length ? row[buyIdx].toString().replaceAll(',', '').trim() : '';
             String slStr = sellIdx < row.length ? row[sellIdx].toString().replaceAll(',', '').trim() : '';
             
             double q = double.tryParse(qStr) ?? 0;
             double b = double.tryParse(bStr) ?? 0;
             double sl = double.tryParse(slStr) ?? 0;
             
             if (s.isNotEmpty && (b > 0 || sl > 0)) {
                extractedTrades.add({ 'stock': s, 'qty': q, 'buy': b, 'sell': sl });
             }
          }
        }
        
        List<Map<String, dynamic>> unsavedTrades = [];
        List<Map<String, dynamic>> savedTrades = [];

        if (parsedDate != null && extractedTrades.isNotEmpty) {
            DateTime start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
            DateTime end = start.add(const Duration(days: 1));
            var qs = await FirebaseFirestore.instance.collection('trades_v2')
               .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
               .where('time', isLessThan: Timestamp.fromDate(end))
               .get();
               
            for (var et in extractedTrades) {
                bool isSaved = false;
                for (var doc in qs.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['stock'] == et['stock'] && (data['qty'] == et['qty'] || data['qty'] == et['qty'].toInt())) {
                        isSaved = true; break;
                    }
                }
                if (isSaved) savedTrades.add(et);
                else unsavedTrades.add(et);
            }
        } else {
            unsavedTrades = List.from(extractedTrades);
        }

        setState(() {
          uploadedFileName = fileName;
          pendingTrades = unsavedTrades;
          if (parsedDate != null) selectedDate = parsedDate;
          taxController.text = parsedTax > 0 ? parsedTax.toString() : "";
        });
        
        if (mounted) {
           if (savedTrades.isNotEmpty && unsavedTrades.isEmpty) {
               showDialog(context: context, builder: (_) => AlertDialog(
                   backgroundColor: const Color(0xFF161616),
                   title: const Text("Notice", style: TextStyle(color: Colors.white)),
                   content: const Text("This trade is already saved.", style: TextStyle(color: Colors.white70)),
                   actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.amber)))],
               ));
           } else if (unsavedTrades.isNotEmpty) {
               if (savedTrades.isNotEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${unsavedTrades.length} new trade(s) to save. (${savedTrades.length} already saved)")));
               } else {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Found ${unsavedTrades.length} trade(s) from the file.")));
               }
               _populateNextPendingTrade();
           } else {
               showDialog(context: context, builder: (_) => AlertDialog(
                   backgroundColor: const Color(0xFF161616),
                   title: const Text("Notice", style: TextStyle(color: Colors.white)),
                   content: const Text("No trade found in the selected file.", style: TextStyle(color: Colors.white70)),
                   actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.amber)))],
               ));
           }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error parsing file: $e")));
    }
  }

  void _populateNextPendingTrade() {
      if (pendingTrades.isNotEmpty) {
          var t = pendingTrades[0];
          setState(() {
              selectedStock = t['stock'];
              buyController.text = t['buy'].toString();
              sellController.text = t['sell'].toString();
              qtyController.text = t['qty'].toString();
              autocompleteKey = UniqueKey();
              calculateTrade();
          });
      }
  }

  void _addStock() {
    TextEditingController addController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          title: const Text("Add a Stock", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: addController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: "Stock Name (e.g. AAPL)", hintStyle: TextStyle(color: Colors.grey)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (addController.text.trim().isNotEmpty) {
                  String newStock = addController.text.trim().toUpperCase();
                  var existing = await FirebaseFirestore.instance.collection('stocks').where('name', isEqualTo: newStock).get();
                  if (existing.docs.isEmpty) {
                    await FirebaseFirestore.instance.collection('stocks').add({'name': newStock});
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock already exists!")));
                  }
                  setState(() {
                    selectedStock = newStock;
                    autocompleteKey = UniqueKey();
                  });
                }
                if(mounted) Navigator.pop(context);
              },
              child: const Text("Add", style: TextStyle(color: Colors.amber)),
            )
          ],
        );
      }
    );
  }

  Future<void> pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.amber, onPrimary: Colors.black, surface: Color(0xFF1A1A1A), onSurface: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
                  SizedBox(height: 20),
                  Text("Saved!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<void> saveTrade() async {
    if (showTradeWarning) return;
    setState(() { _isSaving = true; _hasAttemptedSave = false; });

    double buy = double.tryParse(buyController.text) ?? 0;
    double sell = double.tryParse(sellController.text) ?? 0;
    double qty = double.tryParse(qtyController.text) ?? 0;

    if (selectedStock != null && selectedStock!.isNotEmpty) {
       var qs = await FirebaseFirestore.instance.collection('stocks').where('name', isEqualTo: selectedStock).get();
       if (qs.docs.isEmpty) {
           await FirebaseFirestore.instance.collection('stocks').add({'name': selectedStock});
       }
    }

    await FirebaseFirestore.instance.collection('trades_v2').add({
      "buy": buy,
      "sell": sell,
      "qty": qty,
      "gross": gross,
      "time": Timestamp.fromDate(selectedDate),
      "stock": selectedStock,
    });

    double taxAmount = double.tryParse(taxController.text) ?? 0;
    if (taxAmount > 0) {
      String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      await FirebaseFirestore.instance.collection('daily_taxes').doc(dateStr).set({
        "taxAmount": taxAmount,
        "time": Timestamp.fromDate(selectedDate),
        "dateString": dateStr
      });
    }

    buyController.clear(); sellController.clear(); qtyController.clear(); taxController.clear();
    if (mounted) {
      setState(() {
        if (pendingTrades.isNotEmpty) {
           pendingTrades.removeAt(0);
        }
        gross = 0; 
        autocompleteKey = UniqueKey(); 
        _isSaving = false;
        
        if (pendingTrades.isEmpty) {
           selectedStock = null;
           uploadedFileName = null;
           selectedDate = DateTime.now();
        }
      });
      
      if (pendingTrades.isNotEmpty) {
         _populateNextPendingTrade();
      }
      
      _showSuccessDialog();
    }
  }

  Future<void> saveTax() async {
    if (showTaxWarning) return;
    setState(() { _isSaving = true; _hasAttemptedSave = false; });

    // Check if trades exist today
    DateTime start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    DateTime end = start.add(const Duration(days: 1));

    var qs = await FirebaseFirestore.instance.collection('trades_v2')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('time', isLessThan: Timestamp.fromDate(end))
        .get();

    if (qs.docs.isEmpty) {
      setState(() { _isSaving = false; });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161616),
            title: const Text("No Trades", style: TextStyle(color: Colors.white)),
            content: const Text("No trades saved on this date. You cannot enter a tax.", style: TextStyle(color: Colors.grey)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.amber)))],
          )
        );
      }
      return;
    }

    double taxAmount = double.tryParse(taxController.text) ?? 0;
    String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Update or set daily_taxes
    await FirebaseFirestore.instance.collection('daily_taxes').doc(dateStr).set({
      "taxAmount": taxAmount,
      "time": Timestamp.fromDate(selectedDate),
      "dateString": dateStr
    });

    taxController.clear();
    if (mounted) {
      setState(() { selectedDate = DateTime.now(); _isSaving = false; });
      _showSuccessDialog();
    }
  }

  Widget label(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }

  Widget inputField(TextEditingController controller, {Function? onChanged, String? hintText}) {
    return Container(
      height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: Colors.white38, fontSize: 16), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          onChanged: (val) { if (onChanged != null) onChanged(); },
        ),
      ),
    );
  }

  Widget summaryRow(String labelText, double value, {bool isCharges = false, bool isBold = false}) {
    Color valColor = (isCharges) ? const Color(0xFFFF5252) : (value == 0 ? Colors.white : (value > 0 ? Colors.greenAccent : const Color(0xFFFF5252)));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(labelText, style: TextStyle(color: isBold ? Colors.white : Colors.grey, fontSize: isBold ? 16 : 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        Text("${value >= 0 && !isCharges ? "+" : (isCharges && value == 0 ? "-" : "-")}₹${value.abs().toStringAsFixed(2)}",
          style: TextStyle(color: valColor, fontSize: isBold ? 18 : 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text("Add Entry", style: TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            const SizedBox(height: 24),

            // Toggle Bar
            Container(
              height: 60,
              decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { isTradeEntry = true; _hasAttemptedSave = false; }),
                      child: Container(
                        decoration: BoxDecoration(color: isTradeEntry ? Colors.amber.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: isTradeEntry ? Border.all(color: Colors.amber.withOpacity(0.5)) : null),
                        child: Center(child: Text("Trade Entry", style: TextStyle(color: isTradeEntry ? Colors.amber : Colors.grey, fontSize: 16, fontWeight: isTradeEntry ? FontWeight.bold : FontWeight.w500))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { isTradeEntry = false; _hasAttemptedSave = false; }),
                      child: Container(
                        decoration: BoxDecoration(color: !isTradeEntry ? Colors.amber.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: !isTradeEntry ? Border.all(color: Colors.amber.withOpacity(0.5)) : null),
                        child: Center(child: Text("Tax Entry", style: TextStyle(color: !isTradeEntry ? Colors.amber : Colors.grey, fontSize: 16, fontWeight: !isTradeEntry ? FontWeight.bold : FontWeight.w500))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Content
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

            // CSV Upload Box
            if (isTradeEntry) ...[
              GestureDetector(
                onTap: _pickAndParseCSV,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_rounded, color: Colors.amber.withOpacity(0.8), size: 48),
                      const SizedBox(height: 16),
                      const Text("Browse Files to upload", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text("Supported formats: CSV, Excel", style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              if (uploadedFileName != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Colors.blueAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Text(uploadedFileName! + (pendingTrades.isNotEmpty ? ' (${pendingTrades.length} pending)' : ''), style: const TextStyle(color: Colors.white, fontSize: 15))),
                      GestureDetector(
                        onTap: () {
                          setState(() { uploadedFileName = null; pendingTrades.clear(); });
                        },
                        child: const Icon(Icons.delete_outline, color: Colors.grey, size: 24),
                      )
                    ],
                  ),
                ),
              const SizedBox(height: 28),
            ],

                  label("DATE"),
                  GestureDetector(
                    onTap: pickDate,
                    child: Container(
                      height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(formatDate(selectedDate), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isTradeEntry) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      label("NAME OF THE STOCK"),
                      GestureDetector(
                        onTap: _addStock,
                        child: Row(children: const [Icon(Icons.add, color: Colors.amber, size: 18), SizedBox(width: 4), Text("Add a Stock", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold))]),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('stocks').orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        List<String> stocks = [];
                        if (snapshot.hasData) stocks = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                        return Container(
                          height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
                          child: Autocomplete<String>(
                            key: autocompleteKey,
                            initialValue: TextEditingValue(text: selectedStock ?? ""),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return stocks;
                              return stocks.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (String selection) { setState(() { selectedStock = selection; }); },
                            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                              return Container(
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: controller, focusNode: focusNode, textAlignVertical: TextAlignVertical.center,
                                  decoration: const InputDecoration(hintText: "Type or Select a Stock", hintStyle: TextStyle(color: Colors.grey, fontSize: 16, height: 1.2), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, suffixIcon: Icon(Icons.search, color: Colors.grey, size: 22), suffixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 28)),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  onChanged: (val) { selectedStock = val.trim().toUpperCase(); }
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12), elevation: 4.0,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 72),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final String option = options.elementAt(index);
                                        return InkWell(onTap: () => onSelected(option), child: Padding(padding: const EdgeInsets.all(20.0), child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))));
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 24),
                    label("BUY VALUE"),
                    inputField(buyController, onChanged: calculateTrade),
                    const SizedBox(height: 24),
                    label("SELL VALUE"),
                    inputField(sellController, onChanged: calculateTrade),
                    const SizedBox(height: 24),
                    label("QUANTITY"),
                    inputField(qtyController),


                  ] else ...[
                    // Tax Entry Form
                    label("NET TAX VALUE FOR DAY (₹)"),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('daily_taxes').doc(DateFormat('yyyy-MM-dd').format(selectedDate)).snapshots(),
                      builder: (context, taxSnap) {
                        double savedTax = 0;
                        if (taxSnap.hasData && taxSnap.data!.exists) {
                            savedTax = (taxSnap.data!.data() as Map<String, dynamic>)['taxAmount']?.toDouble() ?? 0.0;
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            inputField(taxController, onChanged: () => setState(() {}), hintText: savedTax > 0 ? "Saved: ₹${savedTax.toStringAsFixed(2)}" : ""),
                            const SizedBox(height: 24),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('trades_v2')
                                  .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(selectedDate.year, selectedDate.month, selectedDate.day)))
                                  .where('time', isLessThan: Timestamp.fromDate(DateTime(selectedDate.year, selectedDate.month, selectedDate.day).add(const Duration(days: 1))))
                                  .snapshots(),
                              builder: (context, snapshot) {
                                double dailyGross = 0;
                                if (snapshot.hasData) {
                                  for (var d in snapshot.data!.docs) dailyGross += ((d.data() as Map<String, dynamic>)['gross'] ?? 0).toDouble();
                                }
                                double curTax = taxController.text.isNotEmpty ? (double.tryParse(taxController.text) ?? 0) : savedTax;
                                double dailyNet = dailyGross - curTax;

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Day's Overview - ${formatDate(selectedDate)}", style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      summaryRow("Day's Gross P/L", dailyGross),
                                      const SizedBox(height: 12),
                                      summaryRow("Day's Tax", curTax, isCharges: true),
                                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10, height: 1)),
                                      summaryRow("Day's Net P/L", dailyNet, isBold: true),
                                    ],
                                  ),
                                );
                              }
                            )
                          ]
                        );
                      }
                    )
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (isTradeEntry) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label("SUMMARY"), const SizedBox(height: 16), summaryRow("Gross Profit / Loss", gross, isBold: true)],
                ),
              ),
              const SizedBox(height: 28),
            ],

            if (isTradeEntry && showTradeWarning && _hasAttemptedSave && !_isSaving)
              const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 16), child: Text("Please fill in Buy Value, Sell Value, and Quantity.", style: TextStyle(color: Color(0xFFFF5252), fontSize: 14)))),
            if (!isTradeEntry && showTaxWarning && _hasAttemptedSave && !_isSaving)
              const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 16), child: Text("Please enter the Tax Value.", style: TextStyle(color: Color(0xFFFF5252), fontSize: 14)))),

            GestureDetector(
              onTap: () {
                setState(() { _hasAttemptedSave = true; });
                if (isTradeEntry && !showTradeWarning && !_isSaving) { saveTrade(); }
                else if (!isTradeEntry && !showTaxWarning && !_isSaving) { saveTax(); }
              },
              child: Container(
                width: double.infinity, height: 65,
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2.0)),
                child: Center(
                  child: Text(_isSaving ? "Saving..." : (isTradeEntry ? "Save Trade" : "Save Tax"), style: TextStyle(color: _isSaving ? Colors.amber.withOpacity(0.5) : Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
//////////////// HISTORY //////////////////

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('trades_v2').snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Trade History",
                      style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    Text("$count trades", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('trades_v2').orderBy('time', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var trades = snapshot.data!.docs;
                  if (trades.isEmpty) {
                    return const Center(child: Text("No trades yet.", style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.builder(
                    itemCount: trades.length,
                    itemBuilder: (context, index) {
                      return TradeHistoryCard(
                        key: ValueKey(trades[index].id),
                        doc: trades[index],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum TradeCardState { normal, deleting, editing }

class TradeHistoryCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const TradeHistoryCard({super.key, required this.doc});

  @override
  State<TradeHistoryCard> createState() => _TradeHistoryCardState();
}

class _TradeHistoryCardState extends State<TradeHistoryCard> {
  TradeCardState currentState = TradeCardState.normal;
  bool isUpdating = false;

  late TextEditingController buyController;
  late TextEditingController sellController;
  late TextEditingController qtyController;
  late DateTime selectedDate;
  String? tempStock;
  Key editAutocompleteKey = UniqueKey();

  double tempGross = 0;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    var t = widget.doc.data() as Map<String, dynamic>;
    buyController = TextEditingController(text: (t['buy'] ?? 0).toString().replaceAll(RegExp(r'\.0$'), ''));
    sellController = TextEditingController(text: (t['sell'] ?? 0).toString().replaceAll(RegExp(r'\.0$'), ''));
    qtyController = TextEditingController(text: (t['qty'] ?? 0).toString().replaceAll(RegExp(r'\.0$'), ''));
    selectedDate = (t['time'] as Timestamp).toDate();
    tempStock = t['stock'];
    _calculateTemp();
  }

  void _calculateTemp() {
    double b = double.tryParse(buyController.text) ?? 0;
    double s = double.tryParse(sellController.text) ?? 0;
    setState(() {
      tempGross = s - b; // Formula specified
    });
  }

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _showPopup(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
                  const SizedBox(height: 20),
                  Text(msg, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<void> updateTrade() async {
    setState(() { isUpdating = true; });
    double b = double.tryParse(buyController.text) ?? 0;
    double s = double.tryParse(sellController.text) ?? 0;
    double q = double.tryParse(qtyController.text) ?? 0;
    double gross = s - b;

    if (tempStock != null && tempStock!.isNotEmpty) {
       var qs = await FirebaseFirestore.instance.collection('stocks').where('name', isEqualTo: tempStock).get();
       if (qs.docs.isEmpty) {
           await FirebaseFirestore.instance.collection('stocks').add({'name': tempStock});
       }
    }

    await FirebaseFirestore.instance.collection('trades_v2').doc(widget.doc.id).update({
      "buy": b, "sell": s, "qty": q, "gross": gross, "time": Timestamp.fromDate(selectedDate), "stock": tempStock,
    });

    if (mounted) {
      setState(() {
        isUpdating = false;
        currentState = TradeCardState.normal;
      });
      _showPopup("Updated!");
    }
  }

  Future<void> deleteTrade() async {
    _showPopup("Deleted!");
    await FirebaseFirestore.instance.collection('trades_v2').doc(widget.doc.id).delete();
  }

  Widget smallInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              onChanged: (_) => _calculateTemp(),
            ),
          )
        )
      ]
    );
  }

  Widget buildEditingCard(BuildContext context) {
     return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.0),
        ),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Row(
                      children: const [
                        Icon(Icons.edit, size: 14, color: Colors.amber),
                        SizedBox(width: 8),
                        Text("Editing Trade", style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                      ]
                    ),
                    GestureDetector(
                      onTap: () => setState(() => currentState = TradeCardState.normal),
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                 ]
              ),
              const SizedBox(height: 24),
              const Text("DATE", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                   final DateTime? picked = await showDatePicker(
                      context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100),
                      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.amber, onPrimary: Colors.black, surface: Color(0xFF1A1A1A), onSurface: Colors.white)), child: child!),
                   );
                   if (picked != null) setState(() { selectedDate = DateTime(picked.year, picked.month, picked.day); });
                },
                child: Container(
                   height: 46,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(10)),
                   child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(formatDate(selectedDate), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                         const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                      ]
                   )
                )
              ),
              const SizedBox(height: 20),
              const Text("STOCK", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('stocks').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  List<String> stocks = [];
                  if (snapshot.hasData) stocks = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                  return Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(10)),
                    child: Autocomplete<String>(
                      key: editAutocompleteKey,
                      initialValue: TextEditingValue(text: tempStock ?? ""),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) { return stocks; }
                        return stocks.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) { setState(() { tempStock = selection; }); },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                         return Container(
                           alignment: Alignment.centerLeft,
                           child: TextField(
                             controller: controller, focusNode: focusNode, textAlignVertical: TextAlignVertical.center,
                             decoration: const InputDecoration(hintText: "Type or Select Stock", hintStyle: TextStyle(color: Colors.grey, fontSize: 13, height: 1.2), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, suffixIcon: Icon(Icons.search, color: Colors.grey, size: 16), suffixIconConstraints: BoxConstraints(minWidth: 20, minHeight: 20)),
                             style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                             onChanged: (val) { tempStock = val.trim().toUpperCase(); }
                           ),
                         );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12), elevation: 4.0,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 100),
                              child: ListView.builder(
                                padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(index);
                                  return InkWell(onTap: () => onSelected(option), child: Padding(padding: const EdgeInsets.all(16.0), child: Text(option, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: smallInput("BUY PRICE (₹)", buyController)),
                  const SizedBox(width: 14),
                  Expanded(child: smallInput("SELL PRICE (₹)", sellController)),
                ]
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: smallInput("QUANTITY", qtyController)),
                  const SizedBox(width: 14),
                  const Spacer(),
                ]
              ),
              const SizedBox(height: 24),
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    const Text("Gross", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text("${tempGross >= 0 ? "+" : ""}₹${tempGross.abs().toStringAsFixed(2)}", style: TextStyle(color: tempGross >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontSize: 15, fontWeight: FontWeight.bold)),
                 ]
              ),
              const SizedBox(height: 20),
              GestureDetector(
                 onTap: () { if (!isUpdating) updateTrade(); },
                 child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.5))),
                    child: Center(
                       child: Text(isUpdating ? "Updating..." : "Update Trade", style: TextStyle(color: isUpdating ? Colors.amber.withOpacity(0.5) : Colors.amber, fontSize: 15, fontWeight: FontWeight.bold)),
                    )
                 )
              )
           ]
        )
     );
  }

  @override
  Widget build(BuildContext context) {
    if (currentState == TradeCardState.editing) return buildEditingCard(context);

    var t = widget.doc.data() as Map<String, dynamic>;
    double gross = (t['gross'] ?? 0).toDouble();
    double b = (t['buy'] ?? 0).toDouble();
    double s = (t['sell'] ?? 0).toDouble();
    double q = (t['qty'] ?? 0).toDouble();
    DateTime date = (t['time'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Row(
                  children: [
                    Text(formatDate(date), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    if (t['stock'] != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                        child: Text(t['stock'], style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]
                ),
                Text(
                  "${gross >= 0 ? "+" : ""}₹${gross.abs().toStringAsFixed(2)}",
                  style: TextStyle(color: gross >= 0 ? Colors.greenAccent : const Color(0xFFFF5252), fontSize: 16, fontWeight: FontWeight.bold),
                ),
             ]
          ),
          const SizedBox(height: 6),
          Text("₹${b.toStringAsFixed(0)} → ₹${s.toStringAsFixed(0)} × ${q.toStringAsFixed(0)} quantity", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                     _initControllers();
                     setState(() => currentState = TradeCardState.editing);
                  },
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Edit", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                      ]
                    )
                  )
                )
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                     showDialog(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161616),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: const Icon(Icons.close, color: Colors.grey, size: 20),
                                    )
                                  ),
                                  Container(
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF5252), width: 2)),
                                    child: const Center(child: Icon(Icons.close, color: Color(0xFFFF5252), size: 32)),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text("Are you sure?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  const Text("Do you really want to delete this record? This process cannot be undone.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                                  const SizedBox(height: 30),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                                            child: const Center(child: Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                            deleteTrade();
                                          },
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(12)),
                                            child: const Center(child: Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        }
                     );
                  },
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.delete_outline, size: 14, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Delete", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                      ]
                    )
                  )
                )
              ),
            ]
          ),
        ]
      )
    );
  }
}
//////////////// PROFILE //////////////////

class ProfileScreen extends StatefulWidget {
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
                        const Center(child: Text("SPYDEX v2.0 — Your Premium Trading Journal", style: TextStyle(color: Colors.white38, fontSize: 12))),
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
  final String? docId;
  LedgerItem({required this.date, required this.title, required this.subtitle, required this.amount, required this.isCredit, this.balance = 0.0, this.docId});
}

//////////////// FUND MARGIN SCREEN //////////////////

class FundMarginScreen extends StatefulWidget {
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
      builder: (dialogContext) {
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
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: btnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    double? val = double.tryParse(amountController.text);
                    if (val != null && val > 0) {
                      FirebaseFirestore.instance.collection('transactions').add({ 'amount': isCredit ? val : -val, 'time': Timestamp.fromDate(popupDate), 'type': type }).then((_) {
                        if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Transaction added successfully"), backgroundColor: Colors.green));
                      });
                      Navigator.pop(dialogContext);
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

  void _showEditTransactionDialog(String docId, double currentAmount, DateTime currentDate, String titleStr, bool isCredit) {
    TextEditingController amountController = TextEditingController(text: currentAmount.toString());
    DateTime popupDate = currentDate;
    Color btnColor = Colors.amber;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161616), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Edit $titleStr", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: btnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    double? val = double.tryParse(amountController.text);
                    if (val != null && val > 0) {
                      Navigator.pop(dialogContext);
                      FirebaseFirestore.instance.collection('transactions').doc(docId).update({ 'amount': isCredit ? val : -val, 'time': Timestamp.fromDate(popupDate) }).then((_) {
                        if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Transaction updated successfully"), backgroundColor: Colors.green));
                      });
                    }
                  },
                  child: const Text("Update", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showDeleteConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Transaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to delete this transaction?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(dialogContext);
              FirebaseFirestore.instance.collection('transactions').doc(docId).delete().then((_) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Transaction deleted successfully"), backgroundColor: Colors.green));
              });
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
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
                       items.add(LedgerItem(date: time, title: "Added Fund", subtitle: "Credited", amount: amt, isCredit: true, docId: doc.id));
                    } else if (tType == 'penalty') {
                       items.add(LedgerItem(date: time, title: "Penalty Applied", subtitle: "Debited", amount: amt.abs(), isCredit: false, docId: doc.id));
                    } else {
                       items.add(LedgerItem(date: time, title: "Payout Fund", subtitle: "Debited", amount: amt.abs(), isCredit: false, docId: doc.id));
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text("Available margin (Cash + Collateral)", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                SizedBox(width: 6),
                                Icon(Icons.info_outline, color: Colors.grey, size: 14),
                              ],
                            ),
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
                                  return _SwipeableTransactionTile(
                                    item: items[index],
                                    onEdit: () => _showEditTransactionDialog(items[index].docId!, items[index].amount, items[index].date, items[index].title, items[index].isCredit),
                                    onDelete: () => _showDeleteConfirmation(items[index].docId!),
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

class _SwipeableTransactionTile extends StatefulWidget {
  final LedgerItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SwipeableTransactionTile({Key? key, required this.item, required this.onEdit, required this.onDelete}) : super(key: key);

  @override
  State<_SwipeableTransactionTile> createState() => _SwipeableTransactionTileState();
}

class _SwipeableTransactionTileState extends State<_SwipeableTransactionTile> {
  bool _isSwiped = false;

  @override
  Widget build(BuildContext context) {
    bool isZero = widget.item.amount == 0;
    bool isPenalty = widget.item.title.contains("Penalty");
    IconData iconData = isPenalty ? Icons.warning_amber_rounded : (widget.item.title.contains("Fund") ? Icons.account_balance_wallet : Icons.show_chart);
    Color iconColor = isZero ? Colors.grey : (isPenalty ? Colors.deepOrange : (widget.item.isCredit ? Colors.greenAccent : const Color(0xFFFF5252)));
    Color bgColor = isZero ? Colors.grey.withOpacity(0.1) : (isPenalty ? Colors.deepOrange.withOpacity(0.1) : (widget.item.isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)));

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (widget.item.docId == null) return;
        if (details.primaryDelta! < -2) {
          if (!_isSwiped) setState(() => _isSwiped = true);
        } else if (details.primaryDelta! > 2) {
          if (_isSwiped) setState(() => _isSwiped = false);
        }
      },
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))),
        child: Stack(
          children: [
            // Background Action Menu
            if (widget.item.docId != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                    color: const Color(0xFF222222),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      setState(() => _isSwiped = false);
                      if (value == 'edit') widget.onEdit();
                      else if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit", style: TextStyle(color: Colors.white))),
                      const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ),
              ),
            // Foreground Tile
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_isSwiped ? -60.0 : 0.0, 0, 0),
              color: Colors.black, // Important: hides the background action menu
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Icon(iconData, color: iconColor, size: 20)),
                title: Text(widget.item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text("${DateFormat('dd MMM hh:mm a').format(widget.item.date)} · ${widget.item.subtitle}", style: const TextStyle(color: Colors.white54, fontSize: 12))),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${widget.item.isCredit ? '+' : '-'}₹${widget.item.amount.toStringAsFixed(2)}", style: TextStyle(color: iconColor, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("₹${widget.item.balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
