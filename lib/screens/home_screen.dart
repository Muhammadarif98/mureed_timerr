import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mureed Timer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<TimerService>(
        builder: (context, timerService, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timerService.timeLeft,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!timerService.isRunning)
                      ElevatedButton(
                        onPressed: () => timerService.start(),
                        child: const Text('Старт'),
                      ),
                    if (timerService.isRunning)
                      ElevatedButton(
                        onPressed: () => timerService.pause(),
                        child: const Text('Пауза'),
                      ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => timerService.reset(),
                      child: const Text('Сброс'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _showTimePicker(context, timerService),
                  child: const Text('Установить время'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTimePicker(BuildContext context, TimerService timerService) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedMinutes = 0;
        return AlertDialog(
          title: const Text('Выберите время'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 0,
                    max: 120,
                    divisions: 120,
                    label: '$selectedMinutes минут',
                    onChanged: (value) {
                      setState(() {
                        selectedMinutes = value.round();
                      });
                    },
                  ),
                  Text('$selectedMinutes минут'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                timerService.setTime(selectedMinutes);
                Navigator.pop(context);
              },
              child: const Text('Установить'),
            ),
          ],
        );
      },
    );
  }
} 