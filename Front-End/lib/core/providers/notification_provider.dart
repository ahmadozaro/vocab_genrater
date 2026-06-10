import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ai/core/models/notification.dart';
import 'package:ai/core/services/api.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await _localNotif.initialize(settings);

  final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'main_channel',
      'Main Notifications',
      description: 'General app notifications',
      importance: Importance.high,
    ),
  );
}

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasLoaded = false;
  Set<int> _lastSeenIds = {};
  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  NotificationProvider() {
    _schedulePeriodicSync();
  }

  void _schedulePeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _syncWhenReady();
    });
  }

  Future<void> _syncWhenReady() async {
    if (_isLoading || _isSyncing) return;
    _isSyncing = true;
    try {
      await sync();
    } finally {
      _isSyncing = false;
    }
  }

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.getNotifications(),
        ApiService.getUnreadNotificationCount(),
      ]);
      _notifications = results[0] as List<AppNotification>;
      _unreadCount = (results[1] as Map<String, dynamic>)['unreadCount'] ?? 0;
      _hasLoaded = true;
      _trackSeenIds();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sync() async {
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < Duration(minutes: 5)) {
      return;
    }
    if (_isLoading || _isSyncing) return;
    _lastSyncTime = now;
    _isSyncing = true;
    try {
      final newNotifs = await ApiService.syncNotifications();
      final previousIds = Set<int>.from(_notifications.map((n) => n.id));

      _notifications = newNotifs;
      _hasLoaded = true;

      final countResult = await ApiService.getUnreadNotificationCount();
      _unreadCount = (countResult as Map)['unreadCount'] ?? 0;

      await _showLocalForNew(previousIds, newNotifs);
    } catch (_) {
      
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _trackSeenIds() {
    _lastSeenIds = _notifications.map((n) => n.id).toSet();
  }

  Future<void> _showLocalForNew(
      Set<int> previousIds, List<AppNotification> current) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notificationsEnabled') ?? false;
    if (!enabled) return;

    for (final notif in current) {
      if (!previousIds.contains(notif.id) && !_lastSeenIds.contains(notif.id)) {
        _showLocalNotification(notif.title, notif.message);
      }
    }
    _lastSeenIds = current.map((n) => n.id).toSet();
  }

  static Future<void> showTestNotification() async {
    const android = AndroidNotificationDetails(
      'main_channel',
      'Main Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _localNotif.show(
      DateTime.now().microsecondsSinceEpoch,
      'WordUp 📚',
      'Time to practice your vocabulary!',
      details,
    );
  }

  static Future<void> _showLocalNotification(
      String title, String message) async {
    const android = AndroidNotificationDetails(
      'main_channel',
      'Main Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _localNotif.show(
      DateTime.now().microsecondsSinceEpoch,
      title,
      message,
      details,
    );
  }

  Future<void> markRead(int id) async {
    try {
      await ApiService.markNotificationRead(id);
      await load();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      await load();
    } catch (_) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
