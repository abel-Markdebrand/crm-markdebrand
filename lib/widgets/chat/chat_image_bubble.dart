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
      final path = await OdooService.instance.downloadMedia(url);
      if (mounted) {
        setState(() {
          _localPath = path;
          _isLoading = false;
          _hasError = path == null;
        });
      }
    } catch (e) {
      debugPrint("Error loading image: $e");
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
        color: Colors.grey.withOpacity(0.1),
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
      return Image.file(
        File(_localPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 400, // Memory optimization
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.error_outline, color: Colors.grey),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
