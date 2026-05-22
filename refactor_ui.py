import os

with open("lib/main.dart", "r", encoding="utf-8") as f:
    text = f.read()

target_block = """                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label("BUY PRICE (₹)"), inputField(buyController, onChanged: calculateTrade)])),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label("SELL PRICE (₹)"), inputField(sellController, onChanged: calculateTrade)])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    label("QUANTITY"),
                    inputField(qtyController),"""

replacement_block = """                    label("BUY VALUE (₹)"),
                    inputField(buyController, onChanged: calculateTrade),
                    const SizedBox(height: 20),
                    label("SELL VALUE (₹)"),
                    inputField(sellController, onChanged: calculateTrade),
                    const SizedBox(height: 20),
                    label("QUANTITY"),
                    inputField(qtyController),"""

if target_block in text:
    text = text.replace(target_block, replacement_block)
    # Also update the summary text
    text = text.replace('("Please fill in Buy Price, Sell Price, and Quantity."', '("Please fill in Buy Value, Sell Value, and Quantity."')
    with open("lib/main.dart", "w", encoding="utf-8") as f:
        f.write(text)
    print("Replacement successful")
else:
    print("Target block not found, check formatting.")

