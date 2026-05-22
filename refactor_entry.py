import os
import re

def replace_between(content, start_marker, end_marker, replacement):
    start_idx = content.find(start_marker)
    if start_idx == -1:
        print(f"Error: Could not find start_marker: {start_marker}")
        return content
    
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1:
        print(f"Error: Could not find end_marker: {end_marker}")
        return content
    
    return content[:start_idx] + replacement + content[end_idx:]

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update EntryScreen
entry_new_code = '''class EntryScreen extends StatefulWidget {
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

  bool get showTradeWarning => buyController.text.isEmpty || sellController.text.isEmpty || qtyController.text.isEmpty;
  bool get showTaxWarning => taxController.text.isEmpty;

  void calculateTrade() {
    double buy = double.tryParse(buyController.text) ?? 0;
    double sell = double.tryParse(sellController.text) ?? 0;
    setState(() {
      gross = sell - buy; // Formula specified
    });
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

    buyController.clear(); sellController.clear(); qtyController.clear();
    if (mounted) {
      setState(() {
        gross = 0; selectedDate = DateTime.now(); selectedStock = null;
        autocompleteKey = UniqueKey(); _isSaving = false;
      });
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
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }

  Widget inputField(TextEditingController controller, {Function? onChanged}) {
    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
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
        Text(labelText, style: TextStyle(color: isBold ? Colors.white : Colors.grey, fontSize: isBold ? 15 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        Text("${value >= 0 && !isCharges ? "+" : (isCharges && value == 0 ? "-" : "-")}₹${value.abs().toStringAsFixed(2)}",
          style: TextStyle(color: valColor, fontSize: isBold ? 16 : 14, fontWeight: FontWeight.bold),
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
            const Align(alignment: Alignment.centerLeft, child: Text("Add Entry", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            const SizedBox(height: 24),

            // Toggle Bar
            Container(
              height: 50,
              decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { isTradeEntry = true; _hasAttemptedSave = false; }),
                      child: Container(
                        decoration: BoxDecoration(color: isTradeEntry ? Colors.amber.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: isTradeEntry ? Border.all(color: Colors.amber.withOpacity(0.5)) : null),
                        child: Center(child: Text("Trade Entry", style: TextStyle(color: isTradeEntry ? Colors.amber : Colors.grey, fontWeight: isTradeEntry ? FontWeight.bold : FontWeight.w500))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { isTradeEntry = false; _hasAttemptedSave = false; }),
                      child: Container(
                        decoration: BoxDecoration(color: !isTradeEntry ? Colors.amber.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16), border: !isTradeEntry ? Border.all(color: Colors.amber.withOpacity(0.5)) : null),
                        child: Center(child: Text("Tax Entry", style: TextStyle(color: !isTradeEntry ? Colors.amber : Colors.grey, fontWeight: !isTradeEntry ? FontWeight.bold : FontWeight.w500))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label("DATE"),
                  GestureDetector(
                    onTap: pickDate,
                    child: Container(
                      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(formatDate(selectedDate), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (isTradeEntry) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      label("NAME OF THE STOCK"),
                      GestureDetector(
                        onTap: _addStock,
                        child: Row(children: const [Icon(Icons.add, color: Colors.amber, size: 16), SizedBox(width: 4), Text("Add a Stock", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold))]),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('stocks').orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        List<String> stocks = [];
                        if (snapshot.hasData) stocks = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                        return Container(
                          height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                  decoration: const InputDecoration(hintText: "Type or Select a Stock", hintStyle: TextStyle(color: Colors.grey, fontSize: 15, height: 1.2), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, suffixIcon: Icon(Icons.search, color: Colors.grey, size: 18), suffixIconConstraints: BoxConstraints(minWidth: 24, minHeight: 24)),
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
                                    constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 72),
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
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label("BUY PRICE (₹)"), inputField(buyController, onChanged: calculateTrade)])),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label("SELL PRICE (₹)"), inputField(sellController, onChanged: calculateTrade)])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    label("QUANTITY"),
                    inputField(qtyController),
                  ] else ...[
                    // Tax Entry Form
                    label("NET TAX VALUE FOR DAY (₹)"),
                    inputField(taxController),
                    const SizedBox(height: 20),
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
                        double curTax = double.tryParse(taxController.text) ?? 0;
                        double dailyNet = dailyGross - curTax;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Daily Overview - ${formatDate(selectedDate)}", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              summaryRow("Day's Gross P&L", dailyGross),
                              const SizedBox(height: 8),
                              summaryRow("Day's Tax", curTax, isCharges: true),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10, height: 1)),
                              summaryRow("Day's Net P&L", dailyNet, isBold: true),
                            ],
                          ),
                        );
                      }
                    )
                  ]
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            if (isTradeEntry) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label("SUMMARY"), const SizedBox(height: 12), summaryRow("Trade Gross Profit", gross, isBold: true)],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (isTradeEntry && showTradeWarning && _hasAttemptedSave && !_isSaving)
              const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 12), child: Text("Please fill in Buy Price, Sell Price, and Quantity.", style: TextStyle(color: Color(0xFFFF5252), fontSize: 13)))),
            if (!isTradeEntry && showTaxWarning && _hasAttemptedSave && !_isSaving)
              const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 12), child: Text("Please enter the Tax Value.", style: TextStyle(color: Color(0xFFFF5252), fontSize: 13)))),

            GestureDetector(
              onTap: () {
                setState(() { _hasAttemptedSave = true; });
                if (isTradeEntry && !showTradeWarning && !_isSaving) { saveTrade(); }
                else if (!isTradeEntry && !showTaxWarning && !_isSaving) { saveTax(); }
              },
              child: Container(
                width: double.infinity, height: 55,
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5)),
                child: Center(
                  child: Text(_isSaving ? "Saving..." : (isTradeEntry ? "Save Trade" : "Save Tax"), style: TextStyle(color: _isSaving ? Colors.amber.withOpacity(0.5) : Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}'''

text = replace_between(text, "class EntryScreen extends StatefulWidget {", "//////////////// HISTORY //////////////////", entry_new_code + "\n")

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(text)
print("Updated EntryScreen successfully!")
