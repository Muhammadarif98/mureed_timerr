import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundTestScreen extends StatefulWidget {
  const SoundTestScreen({super.key});

  @override
  State<SoundTestScreen> createState() => _SoundTestScreenState();
}

class _SoundTestScreenState extends State<SoundTestScreen> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
    }

    try {
      setState(() {
        _isPlaying = true;
      });

      // Устанавливаем громкость на максимум
      await _audioPlayer.setVolume(1.0);
      
      // Останавливаем любое текущее воспроизведение
      await _audioPlayer.stop();
      
      // Отключаем режим цикличного воспроизведения
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      
      print('Начинаем воспроизведение звука...');
      
      // Пробуем воспроизвести из Android ресурсов
      await _audioPlayer.play(
        AssetSource('sounds/timer_complete.mp3'),
        mode: PlayerMode.lowLatency
      );
      
      print('Звук запущен');
      
      // Слушаем завершение воспроизведения
      _audioPlayer.onPlayerComplete.listen((event) {
        print('Воспроизведение завершено');
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      print('Ошибка воспроизведения звука: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест звука'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isPlaying ? null : _playSound,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: _isPlaying ? Colors.grey : Colors.blue,
              ),
              child: Text(
                _isPlaying ? 'Воспроизводится...' : 'Воспроизвести звук',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 