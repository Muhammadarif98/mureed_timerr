import 'package:flutter/material.dart';

class TimerButton extends StatelessWidget {
  final String minutes;
  final VoidCallback onPressed;
  final bool isEnabled;

  const TimerButton({
    super.key,
    required this.minutes,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  minutes,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: isEnabled ? const Color(0xFF009688) : Colors.grey,
                  ),
                ),
                Text(
                  'мин',
                  style: TextStyle(
                    fontSize: 16,
                    color: isEnabled ? const Color(0xFF009688) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 