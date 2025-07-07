import 'package:flutter/material.dart';
import '../pages/Chat_screen.dart';
import '../pages/home.dart';
import '../pages/userdetails.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final VoidCallback? onChatPressed;
  final VoidCallback? onLogoutPressed;
  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onChatPressed,
    this.onLogoutPressed,
  });


  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.currentIndex;
  }

  IconData _getOutlinedIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.chat_outlined;
      case 2:
        return Icons.person_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  void _onTabTapped(BuildContext context, int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;

      case 1: // Chat
        if (widget.onChatPressed != null) {
          widget.onChatPressed!(); // open chat popup
        }
        break;

      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
             // 👈 Pass it forward
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final List<IconData> icons = [Icons.home, Icons.chat, Icons.person];
    final List<String> labels = ['HOME', 'CHAT', 'PROFILE'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              spreadRadius: 2,
              offset: Offset(0, -1), // Only top shadow
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (index) {
                bool isSelected = selectedIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabTapped(context, index),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? icons[index] : _getOutlinedIcon(index),
                          color: isSelected
                              ? const Color.fromRGBO(37, 138, 212, 1)
                              : Colors.grey.shade500,
                          size: screenWidth * 0.065,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          style: TextStyle(
                            fontFamily: 'FunnelDisplay',
                            fontWeight: FontWeight.w600,
                            fontSize: screenWidth * 0.03,
                            color: isSelected
                                ? const Color.fromRGBO(37, 138, 212, 1)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );



  }

}
