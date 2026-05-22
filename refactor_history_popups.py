import os

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

target_method1 = """  Future<void> updateTrade() async {
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
  }"""

replacement_method1 = """  void _showPopup(String msg) {
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
  }"""

target_method2 = """  Future<void> deleteTrade() async {
    await FirebaseFirestore.instance.collection('trades_v2').doc(widget.doc.id).delete();
  }"""

replacement_method2 = """  Future<void> deleteTrade() async {
    _showPopup("Deleted!");
    await FirebaseFirestore.instance.collection('trades_v2').doc(widget.doc.id).delete();
  }"""

if target_method1 in text and target_method2 in text:
    text = text.replace(target_method1, replacement_method1)
    text = text.replace(target_method2, replacement_method2)
    with open("lib/main.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Replacement successful")
else:
    print("Methods not found, check target string exactly.")
