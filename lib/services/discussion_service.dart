import 'package:flutter/foundation.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

class DiscussionService {
  static final DiscussionService _instance = DiscussionService._internal();
  factory DiscussionService() => _instance;
  DiscussionService._internal();

  /// Fetch channels for the current user
  /// Usually 'mail.channel' with 'public'='public' or member in channel_partner_ids
  Future<List<Map<String, dynamic>>> getChannels() async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final partnerId = await _getPartnerId(uid);
      debugPrint("DiscussionService: Partner ID for user $uid is $partnerId");
      if (partnerId == null) return [];

      // Relaxed domain: Just check partner membership.
      final domain = [
        [
          'channel_partner_ids',
          'in',
          [partnerId],
        ],
      ];

      debugPrint("DiscussionService: Fetching channels with domain $domain");

      dynamic response;
      String currentModel = 'mail.channel';

      try {
        response = await OdooService.instance.callKw(
          model: 'discuss.channel', // Odoo 17+
          method: 'search_read',
          args: [domain],
          kwargs: {
            'fields': [
              'id',
              'name',
              'display_name',
              'channel_type',
              'description',
              'channel_partner_ids',
              'channel_member_ids',
            ],
            'limit': 50,
          },
        );
        currentModel = 'discuss.channel';
      } catch (e) {
        debugPrint(
          "DiscussionService: discuss.channel failed, falling back to mail.channel. Error: $e",
        );
        try {
          response = await OdooService.instance.callKw(
            model: 'mail.channel', // Odoo 16 and below
            method: 'search_read',
            args: [domain],
            kwargs: {
              'fields': [
                'id',
                'name',
                'display_name',
                'channel_type',
                'description',
                'channel_partner_ids',
              ],
              'limit': 50,
            },
          );
        } catch (innerE) {
          debugPrint(
            "DiscussionService: mail.channel also failed. Error: $innerE",
          );
          // Try fetching all public channels if channel_partner_ids is fully failing
          debugPrint(
            "DiscussionService: trying without channel_partner_ids filter",
          );
          response = await OdooService.instance.callKw(
            model: 'mail.channel',
            method: 'search_read',
            args: [[]],
            kwargs: {
              'fields': [
                'id',
                'name',
                'display_name',
                'channel_type',
                'description',
                'channel_partner_ids',
              ],
              'limit': 50,
            },
          );
        }
      }

      debugPrint("DiscussionService: Response ($currentModel): $response");

      if (response != null && response is List) {
        List<Map<String, dynamic>> channels = List<Map<String, dynamic>>.from(
          response,
        );

        // Enhance partner list fetching by using channel_member_ids for Odoo 17+
        Set<int> memberIdsToFetch = {};
        for (var channel in channels) {
          if (channel['channel_member_ids'] is List) {
            for (var mId in channel['channel_member_ids']) {
              if (mId is int) memberIdsToFetch.add(mId);
            }
          }
        }

        Map<int, int> memberToPartner = {};
        Map<int, String> memberPartnerNames = {};

        if (memberIdsToFetch.isNotEmpty) {
          try {
            final membersResp = await OdooService.instance.callKw(
              model: 'discuss.channel.member',
              method: 'search_read',
              args: [
                [
                  ['id', 'in', memberIdsToFetch.toList()],
                ],
              ],
              kwargs: {
                'fields': ['id', 'partner_id'],
              },
            );

            if (membersResp is List) {
              for (var m in membersResp) {
                if (m['partner_id'] is List && m['partner_id'].isNotEmpty) {
                  final pId = m['partner_id'][0] as int;
                  final pName = m['partner_id'][1].toString();
                  memberToPartner[m['id'] as int] = pId;
                  memberPartnerNames[pId] = pName;
                }
              }
            }
          } catch (e) {
            debugPrint(
              "DiscussionService: Failed to fetch discuss.channel.member (may not exist in legacy Odoo): $e",
            );
          }
        }

        // Map to hold partnerId -> name to fetch in batch
        Set<int> partnersToFetch = {};

        // Some Odoo versions return channel_partner_ids as [id1, id2]
        // Others might return [[id1, name1], [id2, name2]]
        Map<int, String> alreadyKnownNames = Map.from(memberPartnerNames);

        for (var channel in channels) {
          // Priority 1: Use display_name if available and valid
          String dispName = channel['display_name']?.toString() ?? '';
          if (dispName.isNotEmpty && dispName != 'false') {
            // Odoo display_name is sometimes 'Chat with John' or just 'John'
            channel['name'] = dispName;
          }

          if (channel['channel_partner_ids'] == null ||
              channel['channel_partner_ids'] == false ||
              (channel['channel_partner_ids'] is List &&
                  (channel['channel_partner_ids'] as List).isEmpty)) {
            if (channel['channel_member_ids'] is List &&
                (channel['channel_member_ids'] as List).isNotEmpty) {
              List<int> synthesized = [];
              for (var mId in channel['channel_member_ids']) {
                if (memberToPartner.containsKey(mId)) {
                  synthesized.add(memberToPartner[mId]!);
                }
              }
              channel['channel_partner_ids'] = synthesized;
            }
          }

          if (channel['channel_type'] == 'chat') {
            String cName = channel['name']?.toString() ?? '';
            // If the name is default/empty/ugly, we need to extract from partners
            if (cName.isEmpty || cName == 'false' || cName.contains(',')) {
              if (channel['channel_partner_ids'] is List) {
                final List<dynamic> pIds = channel['channel_partner_ids'];
                for (var pId in pIds) {
                  if (pId is int) {
                    if (pId != partnerId) partnersToFetch.add(pId);
                  } else if (pId is List && pId.isNotEmpty) {
                    // e.g. [id, name]
                    final id = pId[0] as int;
                    if (pId.length > 1) {
                      alreadyKnownNames[id] = pId[1].toString();
                    }
                    if (id != partnerId && !alreadyKnownNames.containsKey(id)) {
                      partnersToFetch.add(id);
                    }
                  }
                }
              }
            }
          }
        }

        Map<int, String> partnerNames = Map.from(alreadyKnownNames);

        if (partnersToFetch.isNotEmpty) {
          try {
            final partnerResponse = await OdooService.instance.callKw(
              model: 'res.partner',
              method: 'name_get',
              args: [partnersToFetch.toList()],
              kwargs: {},
            );

            if (partnerResponse is List) {
              for (var p in partnerResponse) {
                if (p is List && p.length >= 2) {
                  partnerNames[p[0] as int] = p[1].toString();
                }
              }
            }
          } catch (e) {
            debugPrint("DiscussionService: Error resolving partner names: $e");
          }
        }

        // Apply names to channels
        for (var channel in channels) {
          if (channel['channel_type'] == 'chat') {
            String cName = channel['name']?.toString() ?? '';
            if (cName.isEmpty || cName == 'false' || cName.contains(',')) {
              if (channel['channel_partner_ids'] is List) {
                final List<dynamic> pIds = channel['channel_partner_ids'];
                List<String> foundNames = [];
                for (var pId in pIds) {
                  int? id;
                  if (pId is int) {
                    id = pId;
                  } else if (pId is List && pId.isNotEmpty) {
                    id = pId[0] as int;
                  }

                  if (id != null &&
                      id != partnerId &&
                      partnerNames.containsKey(id)) {
                    foundNames.add(partnerNames[id]!);
                  }
                }
                if (foundNames.isNotEmpty) {
                  channel['name'] = foundNames.join(', ');
                }
              }
            }
          }
        }

        return channels;
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching channels: $e");
      return [];
    }
  }

  /// Fetch messages for a specific channel
  Future<List<Map<String, dynamic>>> getMessages(
    int channelId, {
    int limit = 50,
  }) async {
    try {
      final domain = [
        [
          'model',
          'in',
          ['mail.channel', 'discuss.channel'],
        ],
        ['res_id', '=', channelId],
        // ['message_type', '!=', 'notification'], // DISABLED: Show all messages including system notes
      ];

      final response = await OdooService.instance.callKw(
        model: 'mail.message',
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': [
            'id',
            'date',
            'body',
            'author_id',
            'message_type',
            'subtype_id',
          ],
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
          model: 'discuss.channel', // Odoo 17+
          method: 'message_post',
          args: [channelId],
          kwargs: {
            'body': body,
            'message_type': 'comment',
            'subtype_xmlid': 'mail.mt_comment',
          },
        );
      } catch (e) {
        debugPrint(
          "Sending via discuss.channel failed, trying mail.channel. Error: $e",
        );
        await OdooService.instance.callKw(
          model: 'mail.channel', // Odoo 16 and below
          method: 'message_post',
          args: [channelId],
          kwargs: {
            'body': body,
            'message_type': 'comment',
            'subtype_xmlid': 'mail.mt_comment',
          },
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error sending message: $e");
      return false;
    }
  }

  // Helper to get partner ID
  Future<int?> _getPartnerId(int uid) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'res.users',
        method: 'search_read',
        args: [
          [
            ['id', '=', uid],
          ],
        ],
        kwargs: {
          'fields': ['partner_id'],
          'limit': 1,
        },
      );

      if (response != null && response is List && response.isNotEmpty) {
        // partner_id is usually [id, name]
        final partnerField = response[0]['partner_id'];
        if (partnerField is List && partnerField.isNotEmpty) {
          return partnerField[0] as int;
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching partner ID: $e");
      return null;
    }
  }

  /// Get list of users (for creating new DMs)
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      dynamic response;
      try {
        response = await OdooService.instance.callKw(
          model: 'res.users',
          method: 'search_read',
          args: [
            [
              ['share', '=', false],
            ], // Typically internal users
          ],
          kwargs: {
            'fields': ['id', 'name', 'partner_id'],
            'limit': 100,
          },
        );
      } catch (e) {
        // Fallback if 'share' field causes permission or missing field error
        response = await OdooService.instance.callKw(
          model: 'res.users',
          method: 'search_read',
          args: [[]],
          kwargs: {
            'fields': ['id', 'name', 'partner_id'],
            'limit': 100,
          },
        );
      }

      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching users: $e");
      return [];
    }
  }

  /// Get public channels (to join/message)
  Future<List<Map<String, dynamic>>> getPublicChannels() async {
    // In Odoo 17, 'public' field might not exist on discuss.channel.
    // Easiest is to search by channel_type: channel or group.
    final domain = [
      [
        'channel_type',
        'in',
        ['channel', 'group'],
      ],
    ];

    dynamic response;
    dynamic lastError;

    try {
      response = await OdooService.instance.callKw(
        model: 'discuss.channel',
        method: 'search_read',
        args: [domain],
        kwargs: {
          'fields': ['id', 'name', 'channel_type', 'description'],
          'limit': 100,
        },
      );
    } catch (e) {
      debugPrint(
        "getPublicChannels discuss.channel failed, trying mail.channel: $e",
      );
      lastError = e;
      try {
        response = await OdooService.instance.callKw(
          model: 'mail.channel',
          method: 'search_read',
          args: [domain],
          kwargs: {
            'fields': ['id', 'name', 'channel_type', 'description'],
            'limit': 100,
          },
        );
      } catch (innerE) {
        debugPrint(
          "getPublicChannels mail.channel fallback failed, trying without filter: $innerE",
        );
        lastError = innerE;
        try {
          response = await OdooService.instance.callKw(
            model: 'mail.channel',
            method: 'search_read',
            args: [[]],
            kwargs: {
              'fields': ['id', 'name'],
              'limit': 100,
            },
          );
        } catch (finalE) {
          lastError = finalE;
        }
      }
    }

    if (response != null && response is List) {
      return List<Map<String, dynamic>>.from(response);
    }

    if (lastError != null) {
      throw Exception("Odoo API Error: $lastError");
    }
    return [];
  }

  /// Create or get a Direct Message channel with a specific partner
  Future<int?> createOrGetChat(int partnerId) async {
    // In Odoo, channel_get takes a list of partner IDs.
    // E.g., model.channel_get([partnerId])
    final args = [
      [partnerId],
    ];

    dynamic response;
    dynamic lastError;

    try {
      response = await OdooService.instance.callKw(
        model: 'discuss.channel',
        method: 'channel_get',
        args: args,
        kwargs:
            {}, // Some Odoo versions crash if kwargs isn't present for channel_get
      );
    } catch (e) {
      debugPrint("discuss.channel.channel_get failed, trying mail.channel: $e");
      lastError = e;
      try {
        response = await OdooService.instance.callKw(
          model: 'mail.channel',
          method: 'channel_get',
          args: args,
          kwargs: {},
        );
      } catch (innerE) {
        debugPrint("mail.channel.channel_get failed: $innerE");
        lastError = innerE;
        // Fallback: If channel_get completely fails, try to search for an existing chat first
        try {
          final domain = [
            ['channel_type', '=', 'chat'],
            [
              'channel_partner_ids',
              'in',
              [partnerId],
            ],
          ];

          final searchResponse = await OdooService.instance.callKw(
            model: 'discuss.channel',
            method: 'search_read',
            args: [domain],
            kwargs: {
              'fields': ['id', 'channel_partner_ids'],
              'limit': 100, // Fetch recent chats to find if it exists
            },
          );

          if (searchResponse is List && searchResponse.isNotEmpty) {
            // Find a chat that has EXACTLY us and the target partner
            final uid = OdooService.instance.uid;
            int? myPartnerId;
            if (uid != null) {
              myPartnerId = await _getPartnerId(uid);
            }

            for (var channel in searchResponse) {
              if (channel['channel_partner_ids'] is List) {
                List<int> pIds = [];
                for (var p in channel['channel_partner_ids']) {
                  if (p is int) {
                    pIds.add(p);
                  } else if (p is List && p.isNotEmpty) {
                    pIds.add(p[0] as int);
                  }
                }

                // A chat is direct if it has exactly 2 members, and one is the partner
                // Or if myPartnerId is known, it has both.
                if (myPartnerId != null) {
                  if (pIds.contains(partnerId) &&
                      pIds.contains(myPartnerId) &&
                      pIds.length <= 2) {
                    return channel['id'] as int?;
                  }
                } else {
                  if (pIds.contains(partnerId) && pIds.length <= 2) {
                    return channel['id'] as int?;
                  }
                }
              }
            }
          }
        } catch (_) {}

        // If search fails or nothing is found, create it manually as a last resort
        final createArgs = [
          {
            'channel_partner_ids': [
              [
                4,
                partnerId,
              ], // Odoo automatically adds the current user's partner to the chat
            ],
            'channel_type': 'chat',
            'name': '',
          },
        ];

        try {
          final fallbackResponse = await OdooService.instance.callKw(
            model: 'discuss.channel',
            method: 'create',
            args: createArgs,
            kwargs: {},
          );
          return fallbackResponse as int?;
        } catch (finalE) {
          lastError = finalE;
        }
      }
    }

    if (response != null) {
      if (response is Map) {
        return response['id'] as int?;
      } else if (response is int) {
        return response;
      } else if (response is List &&
          response.isNotEmpty &&
          response[0] is Map) {
        return response[0]['id'] as int?;
      }
    }

    if (lastError != null) {
      throw Exception("Odoo API Error: $lastError");
    }
    return null;
  }
}
