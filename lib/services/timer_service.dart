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
  DateTime? _lastUpdateTime;
  int _lastNotificationUpdateSecond = -1;
  static const platform = MethodChannel('com.example.mureed_timer/battery_optimization');

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

  Future<void> _requestBatteryOptimizationPermission() async {
    try {
      final bool result = await platform.invokeMethod('requestBatteryOptimizationPermission');
      print('Battery optimization permission result: $result');
    } catch (e) {
      print('Error requesting battery optimization permission: $e');
    }
  }

  Future<void> init() async {
    await _initNotifications();
    await _prepareSoundFile();
    await _loadSavedTimer();
    await _loadSettings();
    await _requestBatteryOptimizationPermission();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    // Clear any existing notifications when starting the app
    await _notifications.cancelAll();
    
    // Configure notification handling
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Received response: ${response.notificationResponseType}, id: ${response.actionId}, payload: ${response.payload}');
        
        // Handle action buttons
        if (response.actionId != null) {
          _handleNotificationAction(response.actionId!);
        }
      },
    );
    
    // Set up additional action handlers for Android
    final androidPlugin = _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
    if (androidPlugin != null) {
      // Create high-priority notification channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'timer_channel',
          'Timer',
          description: 'Timer notifications',
          importance: Importance.max,
          enableVibration: false,
          playSound: false,
          showBadge: true,
        ),
      );
    
      // Request permissions
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _handleNotificationAction(String action) {
    print('Handling notification action: $action');
    
    // Perform actions based on the notification action
    switch (action) {
      case 'pause_action':
        print('Processing pause action');
        if (_isRunning) {
          pause();
        }
        break;
      case 'resume_action':
        print('Processing resume action');
        if (!_isRunning && _currentSeconds > 0) {
          start();
        }
        break;
      case 'reset_action':
        print('Processing reset action');
        reset();
        // Cancel the notification if reset was pressed
        _notifications.cancel(0);
        break;
      default:
        print('Unknown action: $action');
    }
    
    // Update notification after action
    _updateNotification();
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
    _vibrationEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
  }

  Future<void> _loadSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSeconds = prefs.getInt('currentSeconds') ?? 0;
    _totalSeconds = prefs.getInt('totalSeconds') ?? 0;
    _isRunning = prefs.getBool('isRunning') ?? false;
    _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(
      prefs.getInt('lastUpdateTime') ?? DateTime.now().millisecondsSinceEpoch
    );

    if (_isRunning && _currentSeconds > 0) {
      final now = DateTime.now();
      final difference = now.difference(_lastUpdateTime!).inSeconds;
      
      // Adjust current time based on elapsed time since last update
      if (difference > 0) {
        _currentSeconds = (_currentSeconds - difference).clamp(0, _totalSeconds);
      }
      
      if (_currentSeconds > 0) {
        // Start the timer in background mode
        _startTimerInBackground();
      } else {
        _completeTimer();
      }
    }
  }

  void _startTimerInBackground() {
    _isRunning = true;
    _timerCompleted = false;
    _timer?.cancel();
    
    // Start foreground service for Android
    _startForegroundService();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds <= 0) {
        _completeTimer();
      } else {
        _currentSeconds--;
        _saveTimerState();
        
        // Always update notification on every second
        _updateNotification();
        
        onTick?.call();
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    final androidPlugin = _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
    if (androidPlugin != null) {
      await androidPlugin.startForegroundService(
        0, // notification id
        const AndroidNotificationDetails(
          'timer_channel',
          'Timer',
          channelDescription: 'Timer notifications',
          importance: Importance.max,
          priority: Priority.max,
          ongoing: true,
          autoCancel: false,
          enableVibration: false,
          playSound: false,
          onlyAlertOnce: true,
          category: AndroidNotificationCategory.service,
        ) as String?,
        'Таймер работает', // title
      );
    }
  }

  void start() {
    if (_currentSeconds <= 0) return;

    // If already running, don't restart
    if (_isRunning) return;

    _isRunning = true;
    _timerCompleted = false;
    _timer?.cancel();
    
    // Start foreground service for Android
    _startForegroundService();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds <= 0) {
        _completeTimer();
      } else {
        _currentSeconds--;
        _saveTimerState();
        
        // Always update notification on every second
        _updateNotification();
        
        onTick?.call();
        notifyListeners();
      }
    });
    
    // Save state immediately
    _saveTimerState();
    
    // Always update notification on state change
    _updateNotification();
    
    notifyListeners();
  }

  void pause() {
    // If not running, nothing to pause
    if (!_isRunning) return;
    
    _isRunning = false;
    _timer?.cancel();
    
    // Stop foreground service for Android
    _stopForegroundService();
    
    // Save state immediately
    _saveTimerState();
    
    // Always update notification on state change
    _updateNotification();
    
    notifyListeners();
  }

  Future<void> _stopForegroundService() async {
    final androidPlugin = _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
    if (androidPlugin != null) {
      await androidPlugin.stopForegroundService();
    }
  }

  void reset() {
    _currentSeconds = _totalSeconds;
    _isRunning = false;
    _timerCompleted = false;
    _timer?.cancel();
    
    // Stop foreground service for Android
    _stopForegroundService();
    
    // Cancel the notification first before updating
    _notifications.cancel(0).then((_) {
      // Save state immediately
      _saveTimerState();
      
      // Reset notification update tracker
      _lastNotificationUpdateSecond = -1;
      
      // If there's still time remaining, show a reset notification
      if (_totalSeconds > 0) {
        _updateNotification();
      }
      
      // Notify UI
      onTick?.call();
      notifyListeners();
    });
  }

  Future<void> _updateNotification() async {
    try {
      // Cancel notification if timer is done and not running
      if (_currentSeconds <= 0 && !_isRunning) {
        await _notifications.cancel(0);
        print('Cancelled timer notification (timer at 0)');
        return;
      }

      final List<AndroidNotificationAction> actions = [];
      
      // Add appropriate action button based on timer state
      if (_isRunning) {
        print('Adding PAUSE button to notification');
        actions.add(const AndroidNotificationAction(
          'pause_action',
          'Пауза',
          showsUserInterface: false,
        ));
      } else if (_currentSeconds > 0) {
        print('Adding RESUME button to notification');
        actions.add(const AndroidNotificationAction(
          'resume_action',
          'Возобновить',
          showsUserInterface: false,
        ));
      }
      
      // Always show reset button if there's time set
      if (_totalSeconds > 0) {
        print('Adding RESET button to notification');
        actions.add(const AndroidNotificationAction(
          'reset_action',
          'Сброс',
          showsUserInterface: false,
        ));
      }

      final androidDetails = AndroidNotificationDetails(
        'timer_channel',
        'Timer',
        channelDescription: 'Timer notifications',
        importance: Importance.max,
        priority: Priority.max,
        ongoing: true,
        autoCancel: false,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
        actions: actions,
        ticker: 'Timer ticking',
        fullScreenIntent: false,
        color: const Color.fromARGB(255, 0, 150, 136),
        category: AndroidNotificationCategory.service,
      );

      final details = NotificationDetails(android: androidDetails);

      await _notifications.show(
        0,
        _isRunning ? 'Таймер работает' : 'Таймер на паузе',
        'Осталось: $timeLeft',
        details,
      );
      print('Notification updated: $_currentSeconds seconds left, isRunning: $_isRunning');
    } catch (e) {
      print('Notification error: $e');
      // Try to recover by cancelling and recreating the notification
      try {
        await _notifications.cancel(0);
        await Future.delayed(const Duration(milliseconds: 100));
        await _updateNotification();
      } catch (e) {
        print('Failed to recover from notification error: $e');
      }
    }
  }

  Future<void> _completeTimer() async {
    _isRunning = false;
    _timerCompleted = true;
    _timer?.cancel();
    
    await _saveTimerState();
    
    // Always cancel the timer notification first
    await _notifications.cancel(0);
    
    // Small delay to ensure the timer notification is dismissed
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_vibrationEnabled) {
      await _vibrate();
    }
    
    if (_soundEnabled) {
      await _playCompletionSound();
    }
    
    await _showCompletionNotification();
    
    onComplete?.call();
    notifyListeners();
  }

  Future<void> _showCompletionNotification() async {
    // Create a separate channel for completion notifications
    const AndroidNotificationChannel completionChannel = AndroidNotificationChannel(
      'timer_completion_channel',
      'Timer Completion',
      description: 'Timer completion notifications',
      importance: Importance.high,
      enableVibration: false,
      playSound: false,
    );

    // Register the completion channel
    await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(completionChannel);

    // Show completion notification
    final androidDetails = AndroidNotificationDetails(
      'timer_completion_channel',
      'Timer Completion',
      channelDescription: 'Timer completion notifications',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      enableVibration: false,
      playSound: false,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      1,  // Different ID from the timer notification
      'Таймер завершен',
      'Время истекло!',
      details,
    );
  }

  Future<void> _vibrate() async {
    if (!_vibrationEnabled) return;
    
    try {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 400));
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 400)); 
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Vibration error: $e');
    }
  }

  Future<void> _prepareSoundFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _soundFilePath = '${directory.path}/timer_complete.mp3';
      
      final file = File(_soundFilePath!);
      if (!file.existsSync()) {
        ByteData? data;
        try {
          data = await rootBundle.load('assets/sounds/timer_complete.mp3');
        } catch (e) {
          try {
            data = await rootBundle.load('lib/assets/sounds/timer_complete.mp3');
          } catch (e) {
            print('Sound file not found: $e');
          }
        }
        
        if (data != null) {
          List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await file.writeAsBytes(bytes);
        } else {
          _soundFilePath = null;
        }
      }
    } catch (e) {
      print('Sound file preparation error: $e');
      _soundFilePath = null;
    }
  }

  Future<void> _playCompletionSound() async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      
      // Simplify sound playing logic - just try the asset source
      await _audioPlayer.play(AssetSource('sounds/timer_complete.mp3'));
    } catch (e) {
      print('Sound playback error: $e');
    }
  }

  Future<void> _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentSeconds', _currentSeconds);
    await prefs.setInt('totalSeconds', _totalSeconds);
    await prefs.setBool('isRunning', _isRunning);
    await prefs.setInt('lastUpdateTime', DateTime.now().millisecondsSinceEpoch);
  }

  void setTime(int minutes) {
    _totalSeconds = minutes * 60;
    _currentSeconds = _totalSeconds;
    _isRunning = false;
    _timerCompleted = false;
    _timer?.cancel();
    _saveTimerState();
    _lastNotificationUpdateSecond = -1; // Reset notification update tracker
    _updateNotification();
    notifyListeners();
  }

  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
} 