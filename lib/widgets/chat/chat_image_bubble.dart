import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/whatsapp_models.dart';
import '../../services/odoo_service.dart';

class ChatImageBubble extends StatefulWidget {
  final WhatsAppMessage message;
  final bool isMe;

  const ChatImageBubble({super.key, required this.message, required this.isMe});

  @override
  State<ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<ChatImageBubble>
    with AutomaticKeepAliveClientMixin {
  String? _localPath;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final url = widget.message.attachmentUrl;
    if (url == null) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    // If it's already a local path (starts with /data/user or C:\ etc, NOT http or /web)
    // We assume it's a local file update from optimistic UI
    if (!url.startsWith('http') && !url.startsWith('/web/content')) {
      if (mounted) setState(() => _localPath = url);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      debugPrint(
        "📸 ChatImageBubble: Loading URL -> $url (Type: ${widget.message.type})",
      );
      final path = await OdooService.instance.downloadMedia(url);
      if (mounted) {
        if (path == null) {
          debugPrint("❌ ChatImageBubble: downloadMedia returned NULL for $url");
        }
        setState(() {
          _localPath = path;
          _isLoading = false;
          _hasError = path == null;
        });
      }
    } catch (e) {
      debugPrint("❌ ChatImageBubble: Error loading image: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Fixed Dimensions to prevent Layout Shift
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 250,
        height: 250,
        color: Colors.grey.withValues(alpha: 0.1),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: Colors.grey, size: 40),
            SizedBox(height: 4),
            Text("Error", style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
        ),
      );
    }

    if (_localPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.message.type == MessageType.image ||
              widget.message.type == MessageType.sticker)
            Image.file(
              File(_localPath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 400,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.error_outline, color: Colors.grey),
                );
              },
            )
          else if (widget.message.type == MessageType.video)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Color(0xFF1A73E8), size: 48),
                    SizedBox(height: 8),
                    Text(
                      "Video",
                      style: TextStyle(
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.message.type == MessageType.video)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
