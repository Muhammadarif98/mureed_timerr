import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<TimerService>(
        builder: (context, timerService, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              SwitchListTile(
                title: const Text('Звук при завершении'),
                subtitle: const Text('Воспроизводить звук по окончании таймера'),
                value: timerService.soundEnabled,
                onChanged: (bool value) {
                  timerService.setSoundEnabled(value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Вибрация при завершении'),
                subtitle: const Text('Вибрация по окончании таймера'),
                value: timerService.vibrationEnabled,
                onChanged: (bool value) {
                  timerService.setVibrationEnabled(value);
                },
              ),
            ],
          );
        },
      ),
    );
  }
} 