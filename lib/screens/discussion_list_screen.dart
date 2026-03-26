import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mvp_odoo/services/discussion_service.dart';
import 'package:mvp_odoo/screens/discussion_chat_screen.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

class DiscussionListScreen extends StatefulWidget {
  final bool showAppBar;

  const DiscussionListScreen({super.key, this.showAppBar = true});

  @override
  State<DiscussionListScreen> createState() => _DiscussionListScreenState();
}

class _DiscussionListScreenState extends State<DiscussionListScreen> {
  final DiscussionService _discussionService = DiscussionService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allChannels = [];
  List<Map<String, dynamic>> _filteredChannels = [];
  String? _errorMessage;
  String? _currentUserPartnerName;
  Map<int, String> _partnerNamesMap = {};

  String _selectedFilter = 'Chats'; // 'Chats' or 'Canales'
  Future<List<Map<String, dynamic>>>? _usersFuture;
  Future<List<Map<String, dynamic>>>? _publicChannelsFuture;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _usersFuture = _discussionService.getUsers().then((users) {
      if (mounted) {
        setState(() {
          for (var user in users) {
             final partnerData = user['partner_id'];
             if (partnerData is List && partnerData.isNotEmpty) {
               final id = partnerData[0] as int;
               final name = partnerData[1] as String;
               _partnerNamesMap[id] = name;
             }
          }
          debugPrint("DiscussionListScreen: Built partner map with ${_partnerNamesMap.length} entries");
        });
      }
      return users;
    });
    _publicChannelsFuture = _discussionService.getPublicChannels();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentUserPartnerName == null) {
        try {
          final profile = await OdooService.instance.getUserProfile();
          _currentUserPartnerName = profile['name']?.toString();
          debugPrint("DiscussionListScreen: Logged in as $_currentUserPartnerName");
        } catch (_) {}
      }

      final channels = await _discussionService.getChannels();
      
      // PROACTIVE: Fetch missing partner names in bulk
      final Set<int> missingPartnerIds = {};
      final myPartnerId = OdooService.instance.currentPartnerId;
      
      for (var channel in channels) {
        final pIds = channel['channel_partner_ids'];
        if (pIds is List) {
          for (var id in pIds) {
            if (id is int && id != myPartnerId && !_partnerNamesMap.containsKey(id)) {
              missingPartnerIds.add(id);
            }
          }
        }
      }
      
      if (missingPartnerIds.isNotEmpty) {
        debugPrint("DiscussionListScreen: Fetching ${missingPartnerIds.length} missing partner names...");
        try {
          final partners = await OdooService.instance.callKw(
            model: 'res.partner',
            method: 'search_read',
            args: [[['id', 'in', missingPartnerIds.toList()]]],
            kwargs: {'fields': ['id', 'name']},
          );
          if (partners is List) {
            setState(() {
              for (var p in partners) {
                _partnerNamesMap[p['id']] = p['name']?.toString() ?? 'Desconocido';
              }
            });
          }
        } catch (e) {
          debugPrint("DiscussionListScreen: Error fetching missing partners: $e");
        }
      }

      if (mounted) {
        setState(() {
          _allChannels = channels;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'Chats') {
        _filteredChannels = _allChannels.where((c) {
          final type = c['channel_type']?.toString().toLowerCase() ?? 'chat';
          // In Odoo 17, direct chats often have type 'chat' or can have no type if malformed.
          // Fallback to chat if it's not explicitly a channel/group.
          return type == 'chat' || (type != 'channel' && type != 'group');
        }).toList();
      } else {
        _filteredChannels = _allChannels.where((c) {
          final type = c['channel_type']?.toString().toLowerCase() ?? '';
          return type == 'channel' || type == 'group';
        }).toList();
      }
      
      debugPrint("DiscussionListScreen: Applied filter '$_selectedFilter'. Showing ${_filteredChannels.length} of ${_allChannels.length} total channels.");
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _showNewMessageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Nuevo Mensaje",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.person, color: Color(0xFF2563EB)),
                ),
                title: Text(
                  "Nueva Persona",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Iniciar chat directo"),
                onTap: () {
                  Navigator.pop(context);
                  _showUsersList();
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF7ED),
                  child: Icon(Icons.tag, color: Color(0xFFEA580C)),
                ),
                title: Text(
                  "Nuevo Canal",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Buscar un canal público"),
                onTap: () {
                  Navigator.pop(context);
                  _showChannelsList();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUsersList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text("No se encontraron usuarios o error"),
                  );
                }

                final users = snapshot.data!;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Seleccionar Persona",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final name = user['name'] ?? 'Desconocido';
                          // Make sure partner_id is an array [id, name]
                          final partnerIdObj = user['partner_id'];
                          int? partnerId;
                          if (partnerIdObj is List && partnerIdObj.isNotEmpty) {
                            partnerId = partnerIdObj[0] as int;
                          }

                          final avatarBase64 = OdooService.getBestImage(user);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFF1F5F9),
                              backgroundImage: avatarBase64 != null
                                  ? MemoryImage(base64Decode(avatarBase64))
                                  : null,
                              child: avatarBase64 == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF64748B),
                                    )
                                  : null,
                            ),
                            title: Text(name),
                            onTap: () async {
                              Navigator.pop(context);
                              if (partnerId != null) {
                                // Create or get chat
                                // Show loading
                                showDialog(
                                  context: this.context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                int? newChannelId;
                                String? errorMessage;

                                try {
                                  newChannelId = await _discussionService
                                      .createOrGetChat(partnerId);
                                } catch (e) {
                                  errorMessage = e.toString();
                                }

                                if (!mounted) return;

                                Navigator.pop(this.context); // pop loading

                                if (newChannelId != null) {
                                  Navigator.push(
                                    this.context,
                                    MaterialPageRoute(
                                      builder: (_) => DiscussionChatScreen(
                                        channelId: newChannelId!,
                                        channelName: name,
                                      ),
                                    ),
                                  ).then((_) => _loadChannels());
                                } else {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Error al crear el chat: ${errorMessage ?? 'Desconocido'}",
                                      ),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showChannelsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _publicChannelsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text("No se encontraron canales públicos."),
                  );
                }

                final channels = snapshot.data!;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Canales Públicos",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          final name = channel['name'] ?? 'Canal';
                          final id = channel['id'];

                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF1F5F9),
                              child: Icon(Icons.tag, color: Colors.grey),
                            ),
                            title: Text(name),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (_) => DiscussionChatScreen(
                                    channelId: id,
                                    channelName: name,
                                  ),
                                ),
                              ).then((_) => _loadChannels());
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) _onFilterChanged(label);
      },
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFFEFF6FF),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold completely refactored to ensure no glitches and smooth background.
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                "Discusión",
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadChannels,
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageDialog,
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                _buildFilterChip('Chats'),
                const SizedBox(width: 8),
                _buildFilterChip('Canales'),
              ],
            ),
          ),
          // Separator
          Container(height: 1, color: const Color(0xFFF1F5F9)),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text("Error: $_errorMessage"))
                : _filteredChannels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No hay conversaciones",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredChannels.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final channel = _filteredChannels[index];

                      String name = channel['display_name']?.toString() ??
                          channel['name']?.toString() ??
                          'Sin nombre';
                      if (name == 'false' || name.isEmpty || name == 'Chat sin nombre') {
                        // FALLBACK: Try to find the other partner's name from channel_partner_ids
                        final partnerIds = channel['channel_partner_ids'];
                        if (partnerIds is List && partnerIds.isNotEmpty) {
                          final myPartnerId = OdooService.instance.currentPartnerId;
                          final otherPartnerIds = partnerIds.where((id) => id != myPartnerId).toList();
                          
                          if (otherPartnerIds.isNotEmpty) {
                            final otherId = otherPartnerIds.first as int;
                            if (_partnerNamesMap.containsKey(otherId)) {
                              name = _partnerNamesMap[otherId]!;
                              debugPrint("DiscussionListScreen: Resolved name '$name' from partner map for ID $otherId");
                            }
                          }
                        }
                        
                        if (name == 'false' || name.isEmpty || name == 'Chat sin nombre') {
                          name = 'Chat sin nombre';
                        }
                      }
                      
                      if (name != 'Chat sin nombre') {
                        // Clean up Odoo auto-generated DM names like ", abel cardenas"
                        name = name
                            .replaceAll(RegExp(r'^,\s*'), '')
                            .replaceAll(RegExp(r',\s*$'), '');
                            
                        // If it's a DM, try to remove the current user's name to show only the other person
                        if (_currentUserPartnerName != null && name.contains(_currentUserPartnerName!)) {
                           // Cases: "Me, Other", "Other, Me", "Me"
                           final parts = name.split(',').map((e) => e.trim()).toList();
                           if (parts.length > 1) {
                             parts.removeWhere((p) => p == _currentUserPartnerName);
                             name = parts.join(', ');
                           }
                        }
                      }
                      if (name.isEmpty) name = 'Chat sin nombre';

                      final type = channel['channel_type'] ?? 'channel';

                      IconData iconData;
                      Color iconColor;
                      Color bgColor;
                      if (type == 'chat') {
                        iconData = Icons.person;
                        iconColor = const Color(0xFF2563EB); // Blue
                        bgColor = const Color(0xFFEFF6FF);
                      } else {
                        iconData = Icons.tag;
                        iconColor = const Color(0xFF059669); // Emerald
                        bgColor = const Color(0xFFECFDF5);
                      }

                      String description =
                          channel['description']?.toString() ?? '';
                      if (description == 'false') description = '';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF64748B,
                              ).withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: bgColor,
                            backgroundImage:
                                OdooService.getBestImage(channel) != null
                                ? MemoryImage(
                                    base64Decode(
                                      OdooService.getBestImage(channel)!,
                                    ),
                                  )
                                : null,
                            child: OdooService.getBestImage(channel) == null
                                ? Icon(iconData, color: iconColor, size: 20)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                              fontSize: 15,
                            ),
                          ),
                          subtitle: description.isNotEmpty
                              ? Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFFCBD5E1),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DiscussionChatScreen(
                                  channelId: channel['id'],
                                  channelName: name,
                                ),
                              ),
                            ).then(
                              (_) => _loadChannels(),
                            ); // reload after returning
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
