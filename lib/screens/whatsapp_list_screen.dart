import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'whatsapp_chat_screen.dart';

class WhatsAppListScreen extends StatefulWidget {
  const WhatsAppListScreen({super.key});

  @override
  State<WhatsAppListScreen> createState() => _WhatsAppListScreenState();
}

class _WhatsAppListScreenState extends State<WhatsAppListScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    // Explicitly poll if needed, or just use current notifier value
    // For the list screen, we can just rely on the notification service updates
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "WhatsApp & Discuss",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => _notificationService.startPolling(),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: _notificationService.recentChannels,
        builder: (context, channels, child) {
          if (_isLoading && channels.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (channels.isEmpty) {
            return const Center(child: Text("No conversations found."));
          }

          return ListView.separated(
            itemCount: channels.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final channel = channels[index];
              final unread = channel['message_unread_counter'] ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getChannelColor(channel['channel_type']),
                  child: Icon(
                    _getChannelIcon(channel['channel_type']),
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  channel['display_name'] ??
                      channel['name'] ??
                      "Untitled Channel",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  channel['description'] is String
                      ? channel['description']
                      : "Odoo Discuss Conversation",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread > 0
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$unread",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                onTap: () => _navigateToChat(channel),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getChannelIcon(String? type) {
    switch (type) {
      case 'whatsapp':
        return Icons.chat;
      case 'group':
        return Icons.group;
      default:
        return Icons.person;
    }
  }

  Color _getChannelColor(String? type) {
    switch (type) {
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'group':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _navigateToChat(Map<String, dynamic> channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WhatsAppChatScreen(
          partnerId: null, // For now, let channelId handle everything
          partnerName: channel['name'] ?? "Channel",
          channelId: channel['id'],
        ),
      ),
    );
  }
}
