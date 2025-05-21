import 'package:flutter/material.dart';
import '../pages/Chat_screen.dart';
import '../pages/home.dart';
import '../pages/userdetails.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback? onChatPressed; // <-- Add optional chat popup callback

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onChatPressed,
  });

  void _onTabTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;
      case 1:
        if (onChatPressed != null) {
          onChatPressed!(); // <-- Show popup if callback is provided
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final List<IconData> icons = [
      Icons.home,
      Icons.chat,
    ];

    final List<String> labels = ['HOME', 'CHAT'];

    return Container(
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(2, (index) {
          bool isSelected = currentIndex == index;
          return GestureDetector(
            onTap: () => _onTabTapped(context, index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? screenWidth * 0.04 : 0,
                vertical: screenHeight * 0.01,
              ),
              decoration: isSelected
                  ? BoxDecoration(
                color: const Color(0xFF4F83E9),
                borderRadius: BorderRadius.circular(20),
              )
                  : null,
              child: Row(
                children: [
                  Icon(
                    icons[index],
                    color: isSelected ? Colors.white : Colors.black,
                    size: screenWidth * 0.06,
                  ),
                  if (isSelected) SizedBox(width: screenWidth * 0.015),
                  if (isSelected)
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
