import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../models/voip_config.dart';

enum AppCallState {
  idle,
  registering,
  registered,
  calling,
  incoming,
  connected,
  held,
  ended,
  error,
}

class CallManager extends ChangeNotifier implements SipUaHelperListener {
  static final CallManager _instance = CallManager._internal();
  static CallManager get instance => _instance;

  final SIPUAHelper _helper = SIPUAHelper();

  AppCallState _callState = AppCallState.idle;
  AppCallState get state => _callState;

  Call? _currentCall;
  UaSettings? _settings;
  VoipConfig? _config;

  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;

  // Retry
  Timer? _retryTimer;
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 5;

  // Duration
  Timer? _durationTimer;
  Stopwatch? _callStopwatch;
  String _durationText = "00:00";
  String get durationText => _durationText;

  String? get remoteIdentity {
    if (_currentCall == null) return null;
    return _currentCall!.remote_display_name ?? _currentCall!.remote_identity;
  }

  CallManager._internal();

  void _startDurationTimer() {
    _callStopwatch = Stopwatch()..start();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = _callStopwatch!.elapsed;
      final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
      final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
      _durationText = "$minutes:$seconds";
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _callStopwatch?.stop();
    _durationTimer = null;
    _callStopwatch = null;
    _durationText = "00:00";
  }

  // ==============================
  // INIT
  // ==============================
  Future<void> init({required VoipConfig config}) async {
    if (!config.isValid) {
      debugPrint("❌ VOIP: Invalid config");
      return;
    }

    _config = config;
    _callState = AppCallState.registering;
    notifyListeners();

    _helper.removeSipUaHelperListener(this);
    _helper.addSipUaHelperListener(this);

    _register();
  }

  RegistrationState? _lastRegistrationState;
  RegistrationState? get registrationState => _lastRegistrationState;

  Future<void> _register() async {
    if (_config == null) return;

    final cleanDomain = _config!.domain
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('/', '');

    final domain = cleanDomain;
    final user = _config!.sipLogin;

    final settings = UaSettings()
      ..uri = 'sip:$user@$domain'
      ..authorizationUser = user
      ..password = _config!.sipPassword
      ..displayName = user
      // 🌐 TRANSPORTE DINÁMICO
      ..webSocketUrl = _config!.wsUrl
      ..transportType = TransportType.WS
      ..register = true
      // 📞 MEDIA
      ..dtmfMode = DtmfMode.RFC2833
      ..userAgent = 'Flutter SIP Client'
      // ❄️ ICE
      ..iceServers = [
        {'url': 'stun:stun.l.google.com:19302'},
      ];

    // 🔐 WebSocket settings
    settings.webSocketSettings.allowBadCertificate = true;

    // Auto-detect Origin Protocol
    final originScheme = _config!.wsUrl.startsWith('wss') ? 'https' : 'http';
    settings.webSocketSettings.extraHeaders = {
      'Origin': '$originScheme://$cleanDomain',
    };

    _settings = settings;

    debugPrint(" Intentando conectar a WebSocket en puerto 8088...");
    debugPrint("📡 VOIP: Registering to ${_config!.wsUrl}");
    await _helper.start(settings);
  }

  // ==============================
  // RETRY (AUTO + MANUAL)
  // ==============================
  void _scheduleReconnect() {
    // If we fail too many times, we can try to switch transport protocol (WS <-> WSS)
    // trying 8088 (ws) vs 8089 (wss) might solve firewall issues
    if (_retryAttempt > 2 && _config != null) {
      if (_config!.wsUrl.contains(':8088')) {
        debugPrint("🔀 VOIP: FAILOVER -> Switching to WSS (8089)");
        _config = _config!.copyWith(
          wsUrl: _config!.wsUrl
              .replaceFirst('ws://', 'wss://')
              .replaceFirst(':8088', ':8089'),
        );
      } else if (_config!.wsUrl.contains(':8089')) {
        debugPrint("🔀 VOIP: FAILOVER -> Switching to WS (8088)");
        _config = _config!.copyWith(
          wsUrl: _config!.wsUrl
              .replaceFirst('wss://', 'ws://')
              .replaceFirst(':8089', ':8088'),
        );
      }
    }

    if (_retryAttempt >= _maxRetryAttempts) {
      debugPrint("❌ VOIP: Max retry attempts reached");
      _callState = AppCallState.error;
      notifyListeners();
      return;
    }

    _retryAttempt++;
    final delay = Duration(seconds: 1 << _retryAttempt);

    debugPrint("🔁 VOIP: Retrying in ${delay.inSeconds}s");

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      await _register();
    });
  }

  /// 🔥 ESTE ES EL MÉTODO QUE TE FALTABA
  Future<void> retryConnection() async {
    debugPrint("🔄 VOIP: Manual retry");

    _retryTimer?.cancel();
    _retryAttempt = 0;
    _callState = AppCallState.registering;
    notifyListeners();

    await _register();
  }

  // ==============================
  // CALL CONTROL
  // ==============================
  Future<void> call(String destination) async {
    // 1. Check if we are really registered
    if (_callState != AppCallState.registered) {
      debugPrint(
        "⚠️ VOIP: Call attempted but not registered. State: $_callState",
      );
      // Instead of throwing, we just admonish the developer in logs or maybe return
      // Depending on preference, we can just return silently or throw a safer error.
      // For now, let's print and return to avoid crashing the UI if the button logic fails.
      return;
    }

    if (!_helper.registered) {
      debugPrint(
        "⚠️ VOIP: Internal SIP Helper says not registered, trying to reconnect...",
      );
      _scheduleReconnect();
      return;
    }

    final domain = _settings!.uri!.split('@').last;
    final uri = destination.contains('@')
        ? destination
        : 'sip:$destination@$domain';

    debugPrint("📞 VOIP: Calling $uri...");
    await _helper.call(uri, voiceOnly: true);
  }

  void answer() {
    _currentCall?.answer(_helper.buildCallOptions());
  }

  void hangup() {
    _currentCall?.hangup();
    _currentCall = null;
    _callState = AppCallState.idle;
    _stopDurationTimer();
    notifyListeners();
  }

  void setMinimize(bool value) {
    _isMinimized = value;
    notifyListeners();
  }

  // ==============================
  // SIP LISTENERS
  // ==============================
  @override
  void registrationStateChanged(RegistrationState state) {
    debugPrint("📶 SIP REG STATE CHANGE: ${state.state}");
    _lastRegistrationState = state;

    if (state.state == RegistrationStateEnum.REGISTERED) {
      debugPrint("✅ VOIP: Registered successfully!");
      _callState = AppCallState.registered;
      _retryAttempt = 0;
      _retryTimer?.cancel();
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      debugPrint("❌ VOIP: Registration Failed");
      _callState = AppCallState.registering; // Keep trying or set to error
      _scheduleReconnect();
    } else if (state.state == RegistrationStateEnum.NONE) {
      debugPrint("⚪ VOIP: Registration NONE");
    }

    notifyListeners();
  }

  // Duration
  @override
  void callStateChanged(Call call, CallState state) {
    _currentCall ??= call;

    switch (state.state) {
      case CallStateEnum.PROGRESS:
        _callState = AppCallState.calling;
        break;
      case CallStateEnum.CONFIRMED:
        _callState = AppCallState.connected;
        _startDurationTimer();
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _callState = AppCallState.idle;
        _currentCall = null;
        _stopDurationTimer();
        break;
      default:
        if (call.direction == 'INCOMING') {
          _callState = AppCallState.incoming;
        }
    }

    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
    if (state.state == TransportStateEnum.DISCONNECTED) {
      debugPrint("⚠️ VOIP: Transport disconnected");
      _scheduleReconnect();
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // 🔥 DEBUG: Log incoming SIP messages to trace Registration flow
    // requestUri might be null, usually we look at request.method
    final method = msg.request.method;
    final uri = msg.request.uri;
    debugPrint("📨 SIP MSG: $method $uri");
  }

  @override
  void onNewNotify(Notify ntf) {
    debugPrint("🔔 SIP NOTIFY: ${ntf.request?.method}");
  }

  @override
  void onNewReinvite(ReInvite event) {}
}
