import 'dart:async';
import 'package:flutter/material.dart';
import '../models/whatsapp_models.dart';
import '../services/odoo_service.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_input.dart';

class WhatsAppChatScreen extends StatefulWidget {
  final int? partnerId;
  final String partnerName;
  final String? partnerPhone;
  final String? partnerImage; // Base64 or URL
  final int? channelId; // Optional: direct access to channel

  const WhatsAppChatScreen({
    super.key,
    this.partnerId,
    required this.partnerName,
    this.partnerPhone,
    this.partnerImage,
    this.channelId,
  });

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen> {
  final OdooService _odooService = OdooService.instance;
  final ScrollController _scrollController = ScrollController();

  List<WhatsAppMessage> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  int _lastMessageId = 0;

  // Tracking pending IDs to avoid duplicates during polling
  final Set<int> _sentMessageIds = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    // Ensure WhatsApp client is ready
    if (_odooService.currentPartnerId == null) {
      // If we don't have a partner ID, we might need to wait or re-auth
      // But usually, we have it from login.
    }

    // Explicitly trigger init if not ready
    await _odooService.initWhatsAppClient();

    if (mounted) {
      _loadMessages();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _pollNewMessages();
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _odooService.fetchWhatsAppMessages(
        widget.partnerId,
        channelId: widget.channelId,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
        if (messages.isNotEmpty) {
          _lastMessageId = messages.last.id;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Silent error or snackbar
      }
    }
  }

  Future<void> _pollNewMessages() async {
    if (_lastMessageId == 0) return;

    try {
      final newMessages = await _odooService.pollWhatsAppMessages(
        widget.partnerId,
        _lastMessageId,
        channelId: widget.channelId,
      );

      if (newMessages.isNotEmpty && mounted) {
        setState(() {
          // Filter out messages we already have (by ID) or that we just sent ourselves
          final filteredNew = newMessages.where((msg) {
            final alreadyExists = _messages.any((m) => m.id == msg.id);
            final isOurSentMessage = _sentMessageIds.contains(msg.id);

            // SPECIAL CASE: Check if this polled message matches a currently pending message
            // If it does, we ignore it here because the send completion will handle the transition
            // or we could transition it here. Let's ignore it to let the send call be the source of truth for its own messages.
            bool matchesPending = false;
            if (msg.isOutgoing) {
              matchesPending = _messages.any(
                (m) =>
                    m.state == MessageState.pending &&
                    m.body == msg.body &&
                    m.type == msg.type,
              );
            }

            return !alreadyExists && !isOurSentMessage && !matchesPending;
          }).toList();

          if (filteredNew.isNotEmpty) {
            _messages.addAll(filteredNew);
            _lastMessageId = newMessages.last.id;
            _scrollToBottom();
          }
        });
      }
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendText(String text) async {
    // Optimistic UI Update
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = WhatsAppMessage(
      id: tempId,
      body: text,
      type: MessageType.text,
      state: MessageState.pending,
      isOutgoing: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      debugPrint(
        "WhatsApp: Sending text to partner ${widget.partnerId ?? 'Unknown'} (Channel: ${widget.channelId}): $text",
      );
      final sentMessage = await _odooService.sendWhatsAppMessage(
        widget.partnerId,
        text,
        channelId: widget.channelId,
      );

      if (mounted) {
        if (sentMessage != null) {
          debugPrint(
            "WhatsApp: Message sent successfully with ID ${sentMessage.id}",
          );
          setState(() {
            final alreadyPolledIndex = _messages.indexWhere(
              (m) => m.id == sentMessage.id,
            );
            final tempIndex = _messages.indexWhere((m) => m.id == tempId);

            if (alreadyPolledIndex != -1) {
              if (tempIndex != -1) {
                _messages.removeAt(tempIndex);
              }
            } else if (tempIndex != -1) {
              _messages[tempIndex] = sentMessage; // Replace temp with real
            }

            _lastMessageId = sentMessage.id;
            _sentMessageIds.add(sentMessage.id);
          });
        } else {
          debugPrint("WhatsApp: Send returned null (possible API error)");
          _markAsFailed(tempId, text);
        }
      }
    } catch (e) {
      debugPrint("WhatsApp: Send failed with error: $e");
      if (mounted) {
        _markAsFailed(tempId, text);
      }
    }
  }

  void _markAsFailed(
    int tempId,
    String text, {
    MessageType type = MessageType.text,
  }) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        final existingUrl = _messages[index].attachmentUrl;
        _messages[index] = WhatsAppMessage(
          id: tempId,
          body: text,
          type: type,
          state: MessageState.failed,
          isOutgoing: true,
          timestamp: DateTime.now(),
          attachmentUrl: existingUrl,
        );
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Failed to send message")));
  }

  Future<void> _handleSendAudio(String path) async {
    // Optimistic UI Update
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = WhatsAppMessage(
      id: tempId,
      body: "",
      type: MessageType.audio,
      state: MessageState.pending,
      isOutgoing: true,
      timestamp: DateTime.now(),
      attachmentUrl: path, // Local path for immediate playback
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      debugPrint(
        "WhatsApp: Sending audio from path: $path (Channel: ${widget.channelId})",
      );
      final sentMessage = await _odooService.sendWhatsAppAudio(
        widget.partnerId,
        path,
        channelId: widget.channelId,
      );
      if (mounted) {
        if (sentMessage != null) {
          debugPrint(
            "WhatsApp: Audio sent successfully with ID ${sentMessage.id}",
          );
          setState(() {
            final alreadyPolledIndex = _messages.indexWhere(
              (m) => m.id == sentMessage.id,
            );
            final tempIndex = _messages.indexWhere((m) => m.id == tempId);

            if (alreadyPolledIndex != -1) {
              if (tempIndex != -1) {
                _messages.removeAt(tempIndex);
              }
            } else if (tempIndex != -1) {
              _messages[tempIndex] = sentMessage; // Replace temp with real
            }

            _lastMessageId = sentMessage.id;
            _sentMessageIds.add(sentMessage.id);
          });
        } else {
          debugPrint("WhatsApp: Audio send returned null");
          _markAsFailed(tempId, "Audio failed", type: MessageType.audio);
        }
      }
    } catch (e) {
      debugPrint("WhatsApp: Audio send failed with error: $e");
      if (mounted) {
        _markAsFailed(tempId, "Audio failed", type: MessageType.audio);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Let gradient show through
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leadingWidth: 70,
          leading: InkWell(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chevron_left,
                  color: Color(0xFF1D2939),
                  size: 30,
                ),
                const SizedBox(width: 4),
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE3E8EF), Color(0xFFCDE0F5)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.business_outlined,
                        size: 20,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF12B76A),
                          border: Border.all(color: Colors.white, width: 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.partnerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D2939),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "QUALIFIED",
                      style: TextStyle(
                        color: Color(0xFF12B76A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "Online | ${widget.partnerPhone ?? widget.partnerName.toLowerCase()}@quantum.io",
                style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.phone, color: Color(0xFF1A73E8)),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF1A73E8)),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: _messages.length,
                      cacheExtent: 2000.0, // Pre-render items 2000px off-screen
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ChatBubble(
                          key: ValueKey(message.id), // Ensure efficient updates
                          message: message,
                          isMe: message.isOutgoing,
                        );
                      },
                    ),
            ),
            ChatInput(
              onSendText: _handleSendText,
              onSendAudio: _handleSendAudio,
              onSendFile: _handleSendFile,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendFile(String path) async {
    // 1. Determine local Type (optimistic)
    final fileName = path.split('/').last.toLowerCase();
    MessageType type = MessageType.file;
    if (fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.webp')) {
      type = MessageType.image;
    } else if (fileName.endsWith('.mp4')) {
      type = MessageType.video;
    }

    // 2. Optimistic UI Update
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = WhatsAppMessage(
      id: tempId,
      body: "",
      type: type,
      state: MessageState.pending,
      isOutgoing: true,
      timestamp: DateTime.now(),
      attachmentUrl: path, // Local path for immediate display
      fileName: fileName,
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    // Small delay to let UI render the pending bubble
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Perform Upload
    try {
      debugPrint(
        "WhatsApp: Sending file from path: $path (Channel: ${widget.channelId})",
      );
      final sentMessage = await _odooService.sendWhatsAppFile(
        widget.partnerId,
        path,
        channelId: widget.channelId,
      );

      if (mounted) {
        if (sentMessage != null) {
          debugPrint(
            "WhatsApp: File sent successfully with ID ${sentMessage.id}",
          );
          setState(() {
            final alreadyPolledIndex = _messages.indexWhere(
              (m) => m.id == sentMessage.id,
            );
            final tempIndex = _messages.indexWhere((m) => m.id == tempId);

            if (alreadyPolledIndex != -1) {
              if (tempIndex != -1) {
                _messages.removeAt(tempIndex);
              }
            } else if (tempIndex != -1) {
              _messages[tempIndex] = sentMessage; // Replace temp with real
            }

            _lastMessageId = sentMessage.id;
            _sentMessageIds.add(sentMessage.id);
          });
        } else {
          debugPrint("WhatsApp: File send returned null");
          _markAsFailed(tempId, "File failed", type: type);
        }
      }
    } catch (e) {
      debugPrint("WhatsApp: File send failed with error: $e");
      if (mounted) {
        _markAsFailed(tempId, "File failed", type: type);
      }
    }
  }
}
