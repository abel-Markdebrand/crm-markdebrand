import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'odoo_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final OdooService _odooService = OdooService.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  final Set<int> _notifiedMessageIds = {};
  bool _isInitialized = false;

  // Observables for UI
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> recentChannels =
      ValueNotifier([]);
  final ValueNotifier<bool> isPolling = ValueNotifier(false);

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        debugPrint("Notification tapped: ${details.payload}");
      },
    );

    _isInitialized = true;
    debugPrint("NotificationService: Initialized.");
  }

  void startPolling() {
    if (_pollingTimer != null) return;

    debugPrint("NotificationService: Starting background polling...");
    // Frequency increased to 15 seconds for a better real-time feel
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchUpdates();
    });

    // Initial fetch
    _fetchUpdates();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint("NotificationService: Stopped polling.");
  }

  Future<void> _fetchUpdates() async {
    if (isPolling.value || !_odooService.isInitialized) return;

    try {
      isPolling.value = true;
      final channels = await _odooService.fetchDiscussChannels();

      int totalUnread = 0;
      for (var channel in channels) {
        final unread = channel['message_needaction_counter'] ?? 0;
        int currentUnread = (unread as int? ?? 0);
        totalUnread += currentUnread;

        if (currentUnread > 0) {
          await _checkAndNotify(channel);
        }
      }

      unreadCount.value = totalUnread;
      recentChannels.value = channels;

      debugPrint(
        "NotificationService: Polled ${channels.length} channels. Unread: $totalUnread",
      );
    } catch (e) {
      debugPrint("NotificationService: Error fetching updates: $e");
    } finally {
      isPolling.value = false;
    }
  }

  Future<void> _checkAndNotify(Map<String, dynamic> channel) async {
    try {
      final channelId = channel['id'] as int;
      final messages = await _odooService.fetchWhatsAppMessages(
        null,
        channelId: channelId,
        limit: 1,
      );

      if (messages.isNotEmpty) {
        final lastMsg = messages.last;
        // Only notify if it's incoming and we haven't notified it yet
        if (!lastMsg.isOutgoing && !_notifiedMessageIds.contains(lastMsg.id)) {
          _notifiedMessageIds.add(lastMsg.id);
          await _showLocalNotification(
            id: channelId,
            title: channel['display_name'] ?? channel['name'] ?? "New Message",
            body: lastMsg.body,
            payload: channelId.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint("NotificationService: Error checking message for notify: $e");
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'whatsapp_messages',
          'WhatsApp Messages',
          channelDescription: 'Notifications for incoming WhatsApp messages',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  void reset() {
    stopPolling();
    unreadCount.value = 0;
    recentChannels.value = [];
    _notifiedMessageIds.clear();
  }
}
