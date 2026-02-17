import 'package:flutter/material.dart';
import '../../models/whatsapp_models.dart';
import '../../services/odoo_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'chat_image_bubble.dart';

class ChatBubble extends StatefulWidget {
  final WhatsAppMessage message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with AutomaticKeepAliveClientMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.audio) {
      _initAudio();
      if (widget.message.duration != null) {
        _duration = widget.message.duration!;
      }
    }
  }

  void _initAudio() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.message.attachmentUrl != null) {
        try {
          Source source;
          final url = widget.message.attachmentUrl!;

          if (url.startsWith('http')) {
            setState(() => _isLoading = true);
            // Download via authenticated service
            final localPath = await OdooService.instance.downloadMedia(url);
            setState(() => _isLoading = false);

            if (localPath != null) {
              source = DeviceFileSource(localPath);
            } else {
              // Fallback
              source = UrlSource(url);
            }
          } else {
            source = DeviceFileSource(url);
          }
          await _audioPlayer.play(source);
        } catch (e) {
          debugPrint("Error playing audio: $e");
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMe = widget.isMe;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A73E8), Color(0xFF155DB5)],
                    )
                  : null,
              color: isMe ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isMe
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? const Color(0xFF1A73E8).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isMe ? 12 : 8,
                  offset: isMe ? const Offset(0, 4) : const Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.message.type == MessageType.audio)
                  _buildAudioContent()
                else if (widget.message.type == MessageType.image ||
                    widget.message.type == MessageType.sticker)
                  _buildImageContent()
                else
                  Text(
                    widget.message.body,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: isMe ? Colors.white : const Color(0xFF1D2939),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.8)
                            : const Color(0xFF667085),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _getStatusIcon(widget.message.state),
                        size: 14,
                        color: widget.message.state == MessageState.read
                            ? const Color(0xFF90CAF9) // Blue ticks for read
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.message.state == MessageState.failed &&
              widget.message.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
              child: Text(
                widget.message.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFD92D20),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioContent() {
    final isMe = widget.isMe;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _isLoading
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : GestureDetector(
                onTap: _toggleAudio,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFF1D2939).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 20,
                    color: isMe ? Colors.white : const Color(0xFF1D2939),
                  ),
                ),
              ),
        const SizedBox(width: 12),
        // Static Wave Visualization
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.3)
                  : const Color(0xFF1D2939).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final progress = _duration.inSeconds > 0
                        ? _position.inSeconds / _duration.inSeconds
                        : 0.4; // Default visual state like in template
                    return Container(
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white : const Color(0xFF1A73E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatDuration(_duration),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isMe ? Colors.white : const Color(0xFF1D2939),
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent() {
    return ChatImageBubble(message: widget.message, isMe: widget.isMe);
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  IconData _getStatusIcon(MessageState state) {
    switch (state) {
      case MessageState.pending:
        return Icons.access_time;
      case MessageState.sent:
        return Icons.check;
      case MessageState.delivered:
        return Icons.done_all;
      case MessageState.read:
        return Icons.done_all;
      case MessageState.failed:
        return Icons.error_outline;
      case MessageState.received:
        return Icons.done_all; // Assuming received means delivered
    }
  }
}
