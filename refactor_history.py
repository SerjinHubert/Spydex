import os

def replace_between(content, start_marker, end_marker, replacement):
    start_idx = content.find(start_marker)
    if start_idx == -1: return content
    end_idx = content.find(end_marker, start_idx)
    if end_idx == -1: return content
    return content[:start_idx] + replacement + content[end_idx:]

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

history_new_code = '''class HistoryScreen extends StatelessWidget {
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
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var trades = snapshot.data!.docs;
                  if (trades.isEmpty) {
                    return const Center(child: Text("No trades yet.", style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.builder(
                    itemCount: trades.length,
                    itemBuilder: (context, index) {
                      return TradeHistoryCard(doc: trades[index]);
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
    buyController = TextEditingController(text: (t['buy'] ?? 0).toString().replaceAll(RegExp(r'\\.0$'), ''));
    sellController = TextEditingController(text: (t['sell'] ?? 0).toString().replaceAll(RegExp(r'\\.0$'), ''));
    qtyController = TextEditingController(text: (t['qty'] ?? 0).toString().replaceAll(RegExp(r'\\.0$'), ''));
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
    }
  }

  Future<void> deleteTrade() async {
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
        color: currentState == TradeCardState.deleting ? const Color(0xFF161616) : const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: currentState == TradeCardState.deleting ? const Color(0xFFFF5252).withOpacity(0.5) : Colors.white10, width: 0.5),
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
          currentState == TradeCardState.deleting 
          ? Row(
              children: [
                const Expanded(child: Text("Delete this trade?", style: TextStyle(color: Color(0xFFFF5252), fontSize: 13, fontWeight: FontWeight.bold))),
                GestureDetector(
                  onTap: () => setState(() => currentState = TradeCardState.normal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(20)),
                    child: const Text("× Cancel", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: deleteTrade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0x1AFF5252), border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.5)), borderRadius: BorderRadius.circular(20)),
                    child: const Text("✓ Delete", style: TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ),
              ]
            )
          : Row(
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
                    onTap: () => setState(() => currentState = TradeCardState.deleting),
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
'''

text = replace_between(text, "class HistoryScreen extends StatelessWidget {", "//////////////// PROFILE //////////////////", history_new_code)

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(text)
print("Updated HistoryScreen successfully!")
