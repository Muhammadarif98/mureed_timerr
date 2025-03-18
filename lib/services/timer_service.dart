import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _currentSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  final _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Function()? onTick;
  Function()? onComplete;
  bool _timerCompleted = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String? _soundFilePath;

  bool get isRunning => _isRunning;
  bool get isCompleted => _timerCompleted;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  int get currentSeconds => _currentSeconds;
  
  String get timeLeft {
    int hours = _currentSeconds ~/ 3600;
    int minutes = (_currentSeconds % 3600) ~/ 60;
    int seconds = _currentSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> init() async {
    await _initNotifications();
    await _prepareSoundFile();
    await _loadSavedTimer();
    await _loadSettings();
  }

  // Метод для подготовки звукового файла
  Future<void> _prepareSoundFile() async {
    try {
      // Создаем звуковой файл в папке приложения, если он еще не существует
      final directory = await getApplicationDocumentsDirectory();
      _soundFilePath = '${directory.path}/timer_complete.mp3';
      
      final file = File(_soundFilePath!);
      if (!file.existsSync()) {
        // Попытка загрузить звуковой файл из разных путей
        ByteData? data;
        try {
          print('Попытка загрузить звук из assets/sounds/timer_complete.mp3');
          data = await rootBundle.load('assets/sounds/timer_complete.mp3');
          print('Звук успешно загружен из assets/sounds');
        } catch (e) {
          print('Не удалось загрузить звук из assets/sounds: $e');
          try {
            print('Попытка загрузить звук из lib/assets/sounds/timer_complete.mp3');
            data = await rootBundle.load('lib/assets/sounds/timer_complete.mp3');
            print('Звук успешно загружен из lib/assets/sounds');
          } catch (e) {
            print('Не удалось загрузить звук из lib/assets/sounds: $e');
          }
        }
        
        if (data != null) {
          List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await file.writeAsBytes(bytes);
          print('Звуковой файл создан: $_soundFilePath');
        } else {
          print('Звуковой файл не найден в ресурсах');
          _soundFilePath = null;
        }
      } else {
        print('Звуковой файл уже существует: $_soundFilePath');
      }
    } catch (e) {
      print('Ошибка при подготовке звукового файла: $e');
      _soundFilePath = null;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    // Обновляем настройку вибрации
    _vibrationEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Получено действие уведомления: ${response.actionId ?? 'нет actionId'}, payload: ${response.payload}');
        _handleNotificationAction(response.actionId ?? response.payload ?? '');
      },
    );
    
    // Создаем только один канал для всех уведомлений без вибрации
    const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
      'timer_channel',
      'Timer',
      description: 'Timer notifications',
      importance: Importance.high,
      enableVibration: false,
      enableLights: false,
      playSound: false,
    );
    
    // Регистрируем канал уведомлений
    await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(timerChannel);
    
    // Запрашиваем разрешения для Android 13+
    await _requestPermissions();
  }
  
  Future<void> _requestPermissions() async {
    // Запрос разрешений для Android 13 и выше
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _handleNotificationAction(String action) {
    print('Обработка действия: $action');
    if (action == 'pause_action') {
      pause();
    } else if (action == 'resume_action') {
      start();
    } else if (action == 'reset_action') {
      reset();
      _notifications.cancel(0); // Удаляем уведомление при сбросе
    }
  }

  Future<void> _loadSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSeconds = prefs.getInt('currentSeconds') ?? 0;
    _totalSeconds = prefs.getInt('totalSeconds') ?? 0;
    _isRunning = prefs.getBool('isRunning') ?? false;
    _timerCompleted = prefs.getBool('timerCompleted') ?? false;
    
    if (_isRunning) {
      final lastSaved = prefs.getInt('lastSavedTime') ?? DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (now - lastSaved) ~/ 1000;
      _currentSeconds = (_currentSeconds - elapsedSeconds).clamp(0, _totalSeconds);
      
      if (_currentSeconds > 0) {
        start();
      } else {
        _isRunning = false;
        _timerCompleted = true;
        await _saveTimerState();
        onComplete?.call();
      }
    }
  }

  Future<void> _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentSeconds', _currentSeconds);
    await prefs.setInt('totalSeconds', _totalSeconds);
    await prefs.setBool('isRunning', _isRunning);
    await prefs.setBool('timerCompleted', _timerCompleted);
    await prefs.setInt('lastSavedTime', DateTime.now().millisecondsSinceEpoch);
  }

  void setTime(int minutes) {
    _totalSeconds = minutes * 60;
    _currentSeconds = _totalSeconds;
    _isRunning = false;
    _timerCompleted = false;
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }
    _saveTimerState();
    onTick?.call();
    _updateNotification();
    notifyListeners();
  }

  void start() {
    if (_currentSeconds <= 0) return;
    
    _isRunning = true;
    _timerCompleted = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds <= 0) {
        _completeTimer();
      } else {
        _currentSeconds--;
        onTick?.call();
        _saveTimerState();
        
        // Обновляем уведомление каждую секунду
        _updateNotification();
        notifyListeners();
      }
    });
    _saveTimerState();
    _updateNotification();
    notifyListeners();
  }

  void pause() {
    _isRunning = false;
    _timer?.cancel();
    _saveTimerState();
    _updateNotification();
    notifyListeners();
  }

  void reset() {
    _currentSeconds = _totalSeconds;
    _isRunning = false;
    _timerCompleted = false;
    _timer?.cancel();
    onTick?.call();
    _saveTimerState();
    _updateNotification();
    _notifications.cancel(0); // Удаляем уведомление при сбросе
    notifyListeners();
  }

  Future<void> _completeTimer() async {
    _isRunning = false;
    _timerCompleted = true;
    _timer?.cancel();
    
    // Сохраняем состояние таймера
    await _saveTimerState();
    
    // Отменяем активное уведомление таймера
    await _notifications.cancel(0);
    
    // Добавляем вибрацию при завершении таймера
    await _vibrate();
    
    // Воспроизводим звук только если он включен
    if (_soundEnabled) {
      await _playCompletionSound();
    }
    
    // Показываем простое уведомление о завершении
    await _showSimpleCompletionNotification();
    
    onComplete?.call();
    notifyListeners();
  }

  Future<void> _vibrate() async {
    // Проверяем, включена ли вибрация в настройках
    if (!_vibrationEnabled) return;
    
    try {
      // Используем системную вибрацию через HapticFeedback
      // для создания трех вибраций при завершении
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 400));
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 400)); 
      await HapticFeedback.vibrate();
      
      print('Вибрация при завершении таймера');
    } catch (e) {
      print('Ошибка вибрации: $e');
    }
  }

  Future<void> _updateNotification() async {
    if (_timerCompleted) {
      return; // Не обновляем обычное уведомление если таймер уже завершен
    }
    
    if (!_isRunning && _currentSeconds <= 0) {
      // Если таймер не запущен и время 0, удаляем уведомление
      await _notifications.cancel(0);
      return;
    }
    
    try {
      // Добавляем кнопки действий в уведомление
      List<AndroidNotificationAction> actions = [];
      
      if (_isRunning) {
        actions.add(const AndroidNotificationAction(
          'pause_action',
          'Пауза',
          icon: DrawableResourceAndroidBitmap('ic_pause'),
          showsUserInterface: false,
          cancelNotification: false,
        ));
      } else {
        actions.add(const AndroidNotificationAction(
          'resume_action',
          'Старт',
          icon: DrawableResourceAndroidBitmap('ic_play'),
          showsUserInterface: false,
          cancelNotification: false,
        ));
      }
      
      actions.add(const AndroidNotificationAction(
        'reset_action',
        'Сброс',
        icon: DrawableResourceAndroidBitmap('ic_reset'),
        showsUserInterface: false,
        cancelNotification: true,
      ));
      
      // Настройки без вибрации
      final androidDetails = AndroidNotificationDetails(
        'timer_channel',
        'Timer',
        channelDescription: 'Timer notifications',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        actions: actions,
        enableVibration: false,
        playSound: false,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );
      
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      
      if (_isRunning || (_currentSeconds > 0 && _totalSeconds > 0)) {
        await _notifications.show(
          0,
          'Таймер активен',
          'Осталось: $timeLeft',
          details,
          payload: 'timer',
        );
      }
    } catch (e) {
      print('Ошибка при обновлении уведомления: $e');
    }
  }

  Future<void> _showSimpleCompletionNotification() async {
    try {
      // Настройки Android-уведомления (простое, без действий, без вибрации)
      final androidDetails = AndroidNotificationDetails(
        'timer_channel',
        'Timer',
        channelDescription: 'Timer notifications',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        enableVibration: false,
        playSound: false, // Звук мы воспроизводим отдельно через AudioPlayer
      );
      
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false, // Звук мы воспроизводим отдельно
      );
      
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      
      // Показываем простое уведомление о завершении
      await _notifications.show(
        0, // Используем тот же ID
        'Таймер завершен!',
        'Время вышло!',
        details,
      );
    } catch (e) {
      print('Ошибка при отправке уведомления о завершении: $e');
    }
  }

  Future<void> _playCompletionSound() async {
    // Проверяем, включен ли звук
    if (!_soundEnabled) {
      print('Звук отключен в настройках');
      return;
    }

    try {
      print('Начинаем воспроизведение звука таймера...');
      
      // Устанавливаем громкость на максимум
      await _audioPlayer.setVolume(1.0);
      
      // Останавливаем любое текущее воспроизведение
      await _audioPlayer.stop();
      
      // Отключаем режим цикличного воспроизведения
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      
      // Воспроизводим звук из Android ресурса
      print('Пробуем воспроизвести из Android ресурсов: timer_complete.mp3');
      await _audioPlayer.play(
        AssetSource('sounds/timer_complete.mp3'), 
        mode: PlayerMode.lowLatency
      );
      print('Запущено воспроизведение звука из ресурса');
      
      // Ждем небольшую паузу для начала воспроизведения
      await Future.delayed(Duration(milliseconds: 500));
      
      // Регистрируем слушатель завершения для дебага
      _audioPlayer.onPlayerComplete.listen((event) {
        print('Воспроизведение звука завершено успешно');
      });
    } catch (e) {
      print('Ошибка воспроизведения звука из ресурса: $e');
      
      // План Б - воспроизведение из файла
      try {
        // Создаем локальную копию звукового файла в кэше приложения
        final temporaryDir = await getTemporaryDirectory();
        final tempSoundFile = File('${temporaryDir.path}/timer_complete_temp.mp3');
        
        // Проверяем, существует ли файл уже
        if (!tempSoundFile.existsSync()) {
          try {
            // Загружаем файл из ресурсов
            final data = await rootBundle.load('assets/sounds/timer_complete.mp3');
            await tempSoundFile.writeAsBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), 
              flush: true
            );
            print('Звуковой файл скопирован во временную директорию: ${tempSoundFile.path}');
          } catch (e) {
            print('Ошибка копирования звукового файла: $e');
            throw Exception('Не удалось скопировать звуковой файл');
          }
        }
        
        // Проверяем, что файл существует перед воспроизведением
        if (!tempSoundFile.existsSync()) {
          throw Exception('Звуковой файл не существует на диске');
        }
        
        // Воспроизводим звук из временного файла
        final source = DeviceFileSource(tempSoundFile.path);
        print('Запускаем воспроизведение из временного файла: ${tempSoundFile.path}');
        await _audioPlayer.play(source);
        print('Звук запущен из временного файла');
      } catch (e2) {
        print('Ошибка воспроизведения из временного файла: $e2');
        
        // План В - попытка воспроизведения через URI к raw ресурсам
        try {
          print('Попытка воспроизведения через нативные ресурсы');
          final uri = Uri(
            scheme: 'android.resource', 
            host: 'mureed_timer', 
            path: '/raw/timer_complete'
          );
          await _audioPlayer.play(DeviceFileSource(uri.toString()));
          print('Запущено воспроизведение через нативные ресурсы Android');
        } catch (e3) {
          print('Критическая ошибка воспроизведения звука: $e3');
        }
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
  }
} 