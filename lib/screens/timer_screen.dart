import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/timer_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  final TimerService _timerService = TimerService();
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;
  int? _selectedMinutes;
  
  final List<int> _presetMinutes = [3, 5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTimer();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Когда приложение возвращается на передний план
      setState(() {});
    }
  }

  Future<void> _initializeTimer() async {
    _timerService.onTick = () {
      if (mounted) setState(() {});
    };
    
    _timerService.onComplete = () {
      setState(() {
        _selectedMinutes = null;
      });
    };
    
    await _timerService.init();
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      
      final totalSeconds = prefs.getInt('totalSeconds') ?? 0;
      if (totalSeconds > 0) {
        _selectedMinutes = totalSeconds ~/ 60;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TimerService>(
        builder: (context, timerService, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Таймер
                  Center(
                    child: Text(
                      timerService.timeLeft,
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Кнопки пресетов - первый ряд
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _presetMinutes.sublist(0, 4).map((minutes) =>
                      _presetButton(context, minutes, timerService),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Кнопки пресетов - второй ряд
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _presetMinutes.sublist(4).map((minutes) =>
                      _presetButton(context, minutes, timerService),
                    ).toList(),
                  ),
                  const Spacer(),
                  // Кнопки управления
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _controlButton(
                        icon: Icons.play_arrow,
                        onTap: timerService.currentSeconds > 0 ? () => timerService.start() : null,
                        isEnabled: timerService.currentSeconds > 0 && !timerService.isRunning,
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: Icons.pause,
                        onTap: timerService.isRunning ? () => timerService.pause() : null,
                        isEnabled: timerService.isRunning,
                      ),
                      const SizedBox(width: 16),
                      _controlButton(
                        icon: Icons.refresh,
                        onTap: (timerService.isRunning || timerService.currentSeconds > 0) ? () => timerService.reset() : null,
                        isEnabled: timerService.isRunning || timerService.currentSeconds > 0,
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Переключатели
                  _toggleSwitch(
                    context,
                    'Включить вибрацию',
                    timerService.vibrationEnabled,
                    (value) => timerService.setVibrationEnabled(value),
                  ),
                  const SizedBox(height: 16),
                  _toggleSwitch(
                    context,
                    'Включить звук',
                    timerService.soundEnabled,
                    (value) => timerService.setSoundEnabled(value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _presetButton(BuildContext context, int minutes, TimerService timerService) {
    final bool isEnabled = !timerService.isRunning;
    
    return Container(
      width: 80,
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFFCDCDCD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 0.2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? () {
            timerService.setTime(minutes);
            timerService.start();
          } : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.black12,
          highlightColor: Colors.black12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$minutes',
                style: TextStyle(
                  fontSize: 24,
                  color: isEnabled ? const Color(0xFF008080) : const Color(0xFF008080).withOpacity(0.5),
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                'МИН',
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? const Color(0xFF008080) : const Color(0xFF008080).withOpacity(0.5),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isEnabled,
  }) {
    return Container(
      width: 80,
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFFC3C3C3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 0.2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.black12,
          highlightColor: Colors.black12,
          child: Icon(
            icon,
            color: isEnabled ? const Color(0xFF008080) : const Color(0xFF008080).withOpacity(0.5),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _toggleSwitch(BuildContext context, String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF008080),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.withOpacity(0.3),
        ),
      ],
    );
  }
} 