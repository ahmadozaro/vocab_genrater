import 'package:flutter/material.dart';
import 'package:ai/core/models/notification.dart';
import 'package:ai/core/services/api.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasLoaded = false;

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
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sync() async {
    if (_isLoading) return;
    try {
      final results = await Future.wait([
        ApiService.syncNotifications(),
        ApiService.getUnreadNotificationCount(),
      ]);
      _notifications = (results[0] as List)
          .map((e) => AppNotification.fromJson(e))
          .toList();
      _unreadCount = (results[1] as Map)['unreadCount'] ?? 0;
      _hasLoaded = true;
    } catch (_) {}
    notifyListeners();
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
}