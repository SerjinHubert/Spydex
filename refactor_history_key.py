import os

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

target = """                  return ListView.builder(
                    itemCount: trades.length,
                    itemBuilder: (context, index) {
                      return TradeHistoryCard(doc: trades[index]);
                    },
                  );"""

replacement = """                  return ListView.builder(
                    itemCount: trades.length,
                    itemBuilder: (context, index) {
                      return TradeHistoryCard(
                        key: ValueKey(trades[index].id),
                        doc: trades[index],
                      );
                    },
                  );"""

if target in text:
    text = text.replace(target, replacement)
    with open("lib/main.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Replacement successful")
else:
    print("Target block not found, check formatting.")
