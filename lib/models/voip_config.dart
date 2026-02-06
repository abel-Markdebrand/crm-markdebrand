class VoipConfig {
  final String sipLogin; // SIP Extension / Username
  final String sipPassword; // SIP Secret
  final String domain; // SIP Domain (e.g. pabx.axivox.com)
  final String wsUrl; // WebSocket URL (e.g. wss://pabx.axivox.com:3443)

  VoipConfig({
    required this.sipLogin,
    required this.sipPassword,
    required this.domain,
    required this.wsUrl,
  });

  /// Check if configuration is strictly valid (no empty fields)
  bool get isValid {
    return sipLogin.isNotEmpty &&
        sipPassword.isNotEmpty &&
        domain.isNotEmpty &&
        wsUrl.isNotEmpty;
  }

  @override
  String toString() {
    return 'VoipConfig(user: $sipLogin, domain: $domain, ws: $wsUrl)';
  }

  /// Factory from the normalized Odoo response
  factory VoipConfig.fromJson(Map<String, dynamic> json) {
    return VoipConfig(
      sipLogin: json['sip_login']?.toString() ?? '',
      sipPassword: json['sip_password']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      wsUrl: json['ws_url']?.toString() ?? '',
    );
  }

  /// Helper to clone with modifications (e.g. switching WS -> WSS)
  VoipConfig copyWith({
    String? sipLogin,
    String? sipPassword,
    String? domain,
    String? wsUrl,
  }) {
    return VoipConfig(
      sipLogin: sipLogin ?? this.sipLogin,
      sipPassword: sipPassword ?? this.sipPassword,
      domain: domain ?? this.domain,
      wsUrl: wsUrl ?? this.wsUrl,
    );
  }
}
