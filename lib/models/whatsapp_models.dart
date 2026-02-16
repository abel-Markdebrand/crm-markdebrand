enum MessageType { text, audio, image, video, file, sticker }

enum MessageState { pending, sent, delivered, read, failed, received }

class WhatsAppMessage {
  final int id;
  final String body;
  final MessageType type;
  final MessageState state;
  final bool isOutgoing;
  final DateTime timestamp;
  final String? attachmentUrl;
  final String? fileName; // Added for file display
  final Duration? duration; // For audio messages

  WhatsAppMessage({
    required this.id,
    required this.body,
    required this.type,
    required this.state,
    required this.isOutgoing,
    required this.timestamp,
    this.attachmentUrl,
    this.fileName,
    this.duration,
  });

  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessage(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      type: _parseType(json['type']),
      state: _parseState(json['state']),
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      timestamp:
          DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      attachmentUrl: json['attachment_url'] is bool
          ? null
          : json['attachment_url'] as String?,
      fileName: json['file_name'] as String?,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'type': type.name,
      'state': state.name,
      'is_outgoing': isOutgoing,
      'date': timestamp.toIso8601String(),
      'attachment_url': attachmentUrl,
      'file_name': fileName,
      'duration': duration?.inSeconds,
    };
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'audio':
        return MessageType.audio;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'sticker':
        return MessageType.sticker;
      default:
        return MessageType.text;
    }
  }

  static MessageState _parseState(String? state) {
    switch (state) {
      case 'sent':
        return MessageState.sent;
      case 'delivered':
        return MessageState.delivered;
      case 'read':
        return MessageState.read;
      case 'failed':
        return MessageState.failed;
      case 'received':
        return MessageState.received;
      default:
        return MessageState.pending;
    }
  }
}
