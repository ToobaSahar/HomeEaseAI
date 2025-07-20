import 'package:flutter/material.dart';
import '../pages/items.dart';


class ItemDetailsContentWidget extends StatelessWidget {
  final Items item;
  final VoidCallback onBack;
  final VoidCallback onTryAR;

  const ItemDetailsContentWidget({
    super.key,
    required this.item,
    required this.onBack,
    required this.onTryAR,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 65,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.itemName.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'FunnelDisplay',
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(item.itemImage.toString()),

                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                      child: Text(
                        item.itemName.toString(),
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        item.itemDescription.toString(),
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Divider(
                        height: 1,
                        thickness: 2,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF148DD8),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: onTryAR,
                        icon: const Icon(Icons.mobile_screen_share_rounded),
                        label: const Text("TRY VIRTUALLY (AR VIEW)"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
