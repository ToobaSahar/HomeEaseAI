import 'package:flutter/material.dart';
import 'items.dart';
import 'items_details.dart';

class ItemUiDesignWidget extends StatefulWidget {
  Items? itemsInfo;
  BuildContext? context;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  ItemUiDesignWidget({
    this.itemsInfo,
    this.context,
    this.onTap,
    this.onLongPress,

  });

  @override
  State<ItemUiDesignWidget> createState() => _ItemUiDesignWidgetState();
}

class _ItemUiDesignWidgetState extends State<ItemUiDesignWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap ??
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => ItemsDetailsScreen(
                  clickedItemInfo: widget.itemsInfo,
                ),
              ),
            );
          },
      onLongPress: widget.onLongPress,

      splashColor: const Color(0xFF148DD8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.grey.shade300, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 100,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: Image.network(
                    widget.itemsInfo!.itemImage.toString(),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 15, top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemsInfo!.itemName.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCAA54D),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'FunnelDisplay',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.itemsInfo!.itemDescription.toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCAA54D),
                          fontSize: 13,
                          fontFamily: 'FunnelDisplay',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
