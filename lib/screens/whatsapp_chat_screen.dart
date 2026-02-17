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
        debugPrint(
          "[POLL] New messages received: ${newMessages.length}. Last ID: $_lastMessageId",
        );
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
                    (m.state == MessageState.pending ||
                        m.state == MessageState.failed) &&
                    m.body == msg.body &&
                    m.type == msg.type,
              );
            }

            if (alreadyExists)
              debugPrint("[POLL] Ignored (Already exists): ${msg.id}");
            if (isOurSentMessage)
              debugPrint("[POLL] Ignored (In _sentMessageIds): ${msg.id}");
            if (matchesPending)
              debugPrint(
                "[POLL] Ignored (Matches pending or failed bubble): Body: ${msg.body.substring(0, _min(10, msg.body.length))}",
              );

            return !alreadyExists && !isOurSentMessage && !matchesPending;
          }).toList();

          if (filteredNew.isNotEmpty) {
            debugPrint(
              "[POLL] Adding ${filteredNew.length} new messages to UI",
            );
            _messages.addAll(filteredNew);
            _lastMessageId = newMessages.last.id;
            _scrollToBottom();
          } else {
            debugPrint("[POLL] No new unique messages to add");
          }
        });
      }
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

  int _min(int a, int b) => a < b ? a : b;

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
        "[SEND] Text Start: partner ${widget.partnerId} (Channel: ${widget.channelId}) text: ${text.substring(0, _min(15, text.length))}",
      );
      final sentMessage = await _odooService.sendWhatsAppMessage(
        widget.partnerId,
        text,
        channelId: widget.channelId,
      );

      if (mounted) {
        if (sentMessage != null) {
          debugPrint(
            "[SEND] Text success. Real ID: ${sentMessage.id} (Temp ID: $tempId)",
          );
          _replaceTempWithReal(tempId, sentMessage);
        } else {
          debugPrint("[SEND] Text returned NULL (API Error)");
          _markAsFailed(
            tempId,
            text,
            error: "Error del servidor al enviar texto",
          );
        }
      }
    } catch (e) {
      debugPrint("[SEND] Text failure: $e");
      if (mounted) {
        String errorMsg = "Error de conexión o servidor";
        if (e is OdooServiceException) {
          errorMsg = e.message;
        } else if (e.toString().contains("OdooServiceException")) {
          errorMsg = e.toString().replaceFirst("OdooServiceException: ", "");
        }
        _markAsFailed(tempId, text, error: errorMsg);
      }
    }
  }

  void _markAsFailed(
    int tempId,
    String text, {
    MessageType type = MessageType.text,
    String? error,
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
          errorMessage: error,
        );
      }
    });

    final displayError = error ?? "Failed to send message";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayError),
        backgroundColor: const Color(0xFFF04438),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        "[SEND] Audio Start: partner ${widget.partnerId} (Channel: ${widget.channelId}) path: $path",
      );
      final sentMessage = await _odooService.sendWhatsAppAudio(
        widget.partnerId,
        path,
        channelId: widget.channelId,
      );

      if (mounted) {
        if (sentMessage != null) {
          debugPrint(
            "[SEND] Audio success. Real ID: ${sentMessage.id} (Temp ID: $tempId)",
          );
          _replaceTempWithReal(tempId, sentMessage);
        } else {
          debugPrint("[SEND] Audio returned NULL (API Error)");
          _markAsFailed(
            tempId,
            "Audio failed",
            type: MessageType.audio,
            error: "Error al subir audio",
          );
        }
      }
    } catch (e) {
      debugPrint("[SEND] Audio failure: $e");
      if (mounted) {
        String errorMsg = "Error de conexión al enviar audio";
        if (e is OdooServiceException) {
          errorMsg = e.message;
        } else if (e.toString().contains("OdooServiceException")) {
          errorMsg = e.toString().replaceFirst("OdooServiceException: ", "");
        }
        _markAsFailed(
          tempId,
          "Audio failed",
          type: MessageType.audio,
          error: errorMsg,
        );
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
        "[SEND] File Start: partner ${widget.partnerId} (Channel: ${widget.channelId}) path: $path",
      );
      final sentMessage = await _odooService.sendWhatsAppFile(
        widget.partnerId,
        path,
        channelId: widget.channelId,
      );

      if (mounted) {
        if (sentMessage != null) {
          debugPrint(
            "[SEND] File success. Real ID: ${sentMessage.id} (Temp ID: $tempId)",
          );
          _replaceTempWithReal(tempId, sentMessage);
        } else {
          debugPrint("[SEND] File returned NULL (API Error)");
          _markAsFailed(
            tempId,
            "File failed",
            type: type,
            error: "Error al subir archivo",
          );
        }
      }
    } catch (e) {
      debugPrint("[SEND] File failure: $e");
      if (mounted) {
        String errorMsg = "Error de conexión al enviar archivo";
        if (e is OdooServiceException) {
          errorMsg = e.message;
        } else if (e.toString().contains("OdooServiceException")) {
          errorMsg = e.toString().replaceFirst("OdooServiceException: ", "");
        }
        _markAsFailed(tempId, "File failed", type: type, error: errorMsg);
      }
    }
  }

  /// Replaces an optimistic message (tempId) with the real one from server.
  /// Handles deduplication if the message was already polled.
  void _replaceTempWithReal(int tempId, WhatsAppMessage sentMessage) {
    setState(() {
      final alreadyPolledIndex = _messages.indexWhere(
        (m) => m.id == sentMessage.id,
      );
      final tempIndex = _messages.indexWhere((m) => m.id == tempId);

      debugPrint(
        "[SEND] UI Update - alreadyPolledIndex: $alreadyPolledIndex, tempIndex: $tempIndex",
      );

      if (alreadyPolledIndex != -1) {
        debugPrint(
          "[SEND] Message already in UI from poll. Removing temp bubble.",
        );
        if (tempIndex != -1) {
          _messages.removeAt(tempIndex);
        }
      } else if (tempIndex != -1) {
        debugPrint("[SEND] Replacing temp bubble with real message.");
        _messages[tempIndex] = sentMessage; // Replace temp with real
      } else {
        debugPrint(
          "[SEND] WARNING: Temp message not found in list (tempId: $tempId)",
        );
      }

      _lastMessageId = sentMessage.id;
      _sentMessageIds.add(sentMessage.id);
    });
  }
}
