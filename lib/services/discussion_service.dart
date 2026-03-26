import 'package:flutter/foundation.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

class DiscussionService {
  static final DiscussionService _instance = DiscussionService._internal();
  factory DiscussionService() => _instance;
  DiscussionService._internal();

  /// Fetch channels for the current user
  Future<List<Map<String, dynamic>>> getChannels() async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final partnerId = await _getPartnerId(uid);
      debugPrint("DiscussionService: Partner ID for user $uid is $partnerId");

      dynamic response;
      String currentModel = 'discuss.channel';

      // --- ODOO 17 STRATEGY ---
      try {
        // Attempt 1: Fetch via channel_fetch_preview (Odoo 17 standard)
        try {
          final preview = await OdooService.instance.callKw(
            model: 'discuss.channel',
            method: 'channel_fetch_preview',
            args: [],
            kwargs: {},
          );
          if (preview is List && preview.isNotEmpty) {
            response = preview;
          }
        } catch (_) {}

        // Attempt 2: Search by membership (Odoo 17 field)
        if (response == null || (response is List && response.isEmpty)) {
          try {
            response = await OdooService.instance.callKw(
              model: 'discuss.channel',
              method: 'search_read',
              args: [[['is_member', '=', true]]],
              kwargs: {
                'fields': ['id', 'name', 'display_name', 'channel_type', 'image_128', 'channel_partner_ids'],
                'order': 'id desc',
                'limit': 50,
              },
            );
          } catch (_) {}
        }
        
        // Attempt 3: Search anything accessible (Hyper-permissive fallback)
        if (response == null || (response is List && response.isEmpty)) {
          try {
            response = await OdooService.instance.callKw(
              model: 'discuss.channel',
              method: 'search_read',
              args: [[]],
              kwargs: {
                'fields': ['id', 'name', 'display_name', 'channel_type', 'image_128', 'channel_partner_ids'],
                'limit': 50,
                'order': 'write_date desc',
              },
            );
          } catch (_) {}
        }
      } catch (e) {
        debugPrint("DiscussionService: discuss.channel failed: $e");
      }

      // --- LEGACY FALLBACK (Odoo 16 and below) ---
      if (response == null || (response is List && response.isEmpty)) {
        currentModel = 'mail.channel';
        try {
          final domain = partnerId != null ? [['channel_partner_ids', 'in', [partnerId]]] : [];
          response = await OdooService.instance.callKw(
            model: 'mail.channel',
            method: 'search_read',
            args: [domain],
            kwargs: {
              'fields': ['id', 'name', 'display_name', 'channel_type', 'image_128', 'channel_partner_ids'],
              'limit': 50,
            },
          );
        } catch (_) {
          // Absolute last resort: fetch any accessible mail.channel
          try {
            response = await OdooService.instance.callKw(
              model: 'mail.channel',
              method: 'search_read',
              args: [[]],
              kwargs: {
                'fields': ['id', 'name', 'channel_type'],
                'limit': 50,
              },
            );
          } catch (_) {}
        }
      }

      debugPrint("DiscussionService: Found ${response?.length ?? 0} channels using $currentModel");

      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching channels: $e");
      return [];
    }
  }

  /// Fetch messages for a specific channel
  Future<List<Map<String, dynamic>>> getMessages(int channelId, {int limit = 50}) async {
    try {
      final domain = [
        ['model', 'in', ['mail.channel', 'discuss.channel']],
        ['res_id', '=', channelId],
      ];
      final response = await OdooService.instance.callKw(
        model: 'mail.message',
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': ['id', 'date', 'body', 'author_id', 'message_type'],
          'limit': limit,
          'order': 'date desc',
        },
      );
      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching messages: $e");
      return [];
    }
  }

  /// Send a message to a channel
  Future<bool> sendMessage(int channelId, String body) async {
    try {
      try {
        await OdooService.instance.callKw(
          model: 'discuss.channel',
          method: 'message_post',
          args: [channelId],
          kwargs: {'body': body, 'message_type': 'comment'},
        );
      } catch (_) {
        await OdooService.instance.callKw(
          model: 'mail.channel',
          method: 'message_post',
          args: [channelId],
          kwargs: {'body': body, 'message_type': 'comment'},
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error sending message: $e");
      return false;
    }
  }

  /// Helper to get partner ID
  Future<int?> _getPartnerId(int uid) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'res.users',
        method: 'search_read',
        args: [[['id', '=', uid]]],
        kwargs: {'fields': ['partner_id'], 'limit': 1},
      );

      if (response != null && response is List && response.isNotEmpty) {
        final partnerField = response[0]['partner_id'];
        if (partnerField is List && partnerField.isNotEmpty) {
          return partnerField[0] as int;
        } else if (partnerField is int) {
          return partnerField;
        }
      }
      
      // Fallback: search res.partner by user_id
      final pSearch = await OdooService.instance.callKw(
        model: 'res.partner',
        method: 'search_read',
        args: [[['user_id', '=', uid]]],
        kwargs: {'fields': ['id'], 'limit': 1},
      );
      if (pSearch is List && pSearch.isNotEmpty) {
        return pSearch[0]['id'] as int;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching partner ID: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'res.users',
        method: 'search_read',
        args: [[['share', '=', false]]],
        kwargs: {'fields': ['id', 'name', 'partner_id', 'image_128'], 'limit': 100},
      );
      if (response is List) return List<Map<String, dynamic>>.from(response);
      return [];
    } catch (_) {
      final response = await OdooService.instance.callKw(
        model: 'res.users',
        method: 'search_read',
        args: [[]],
        kwargs: {'fields': ['id', 'name', 'partner_id', 'image_128'], 'limit': 100},
      );
      if (response is List) return List<Map<String, dynamic>>.from(response);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPublicChannels() async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'discuss.channel',
        method: 'search_read',
        args: [[['channel_type', 'in', ['channel', 'group']]]],
        kwargs: {'fields': ['id', 'name', 'channel_type'], 'limit': 100},
      );
      if (response is List) return List<Map<String, dynamic>>.from(response);
      return [];
    } catch (_) {
      try {
        final response = await OdooService.instance.callKw(
          model: 'mail.channel',
          method: 'search_read',
          args: [[['channel_type', 'in', ['channel', 'group']]]],
          kwargs: {'fields': ['id', 'name', 'channel_type'], 'limit': 100},
        );
        if (response is List) return List<Map<String, dynamic>>.from(response);
      } catch (_) {}
      return [];
    }
  }

  Future<int?> createOrGetChat(int partnerId) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'discuss.channel',
        method: 'channel_get',
        args: [[partnerId]],
        kwargs: {},
      );
      if (response is Map) return response['id'] as int?;
      if (response is int) return response;
      return null;
    } catch (_) {
      try {
        final response = await OdooService.instance.callKw(
          model: 'mail.channel',
          method: 'channel_get',
          args: [[partnerId]],
          kwargs: {},
        );
        if (response is Map) return response['id'] as int?;
        if (response is int) return response;
      } catch (_) {}
      return null;
    }
  }
}
