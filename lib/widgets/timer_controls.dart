import 'package:flutter/material.dart';

class TimerControls extends StatelessWidget {
  final bool isRunning;
  final bool isTimerSet;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  const TimerControls({
    Key? key,
    required this.isRunning,
    required this.isTimerSet,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play button
        Container(
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (!isRunning && isTimerSet) ? onStart : null,
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                Icons.play_arrow,
                size: 24,
                color: (!isRunning && isTimerSet) 
                    ? const Color(0xFF009688) 
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Pause button
        Container(
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isRunning ? onPause : null,
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                Icons.pause,
                size: 24,
                color: isRunning 
                    ? const Color(0xFF009688) 
                    : Colors.grey,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Reset button
        Container(
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isTimerSet ? onReset : null,
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                Icons.refresh,
                size: 24,
                color: isTimerSet 
                    ? const Color(0xFF009688) 
                    : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 