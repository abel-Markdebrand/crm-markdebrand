import 'package:flutter/material.dart';
import '../../services/call_manager.dart' as cm;

class CallOverlay extends StatefulWidget {
  final Widget child;
  const CallOverlay({super.key, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  final cm.CallManager _manager = cm.CallManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_update);
  }

  @override
  void dispose() {
    _manager.removeListener(_update);
    super.dispose();
  }

  void _update() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Main App (Always visible at bottom)
        widget.child,

        // 2. The VoIP Layer
        if (_manager.state == cm.AppCallState.calling ||
            _manager.state == cm.AppCallState.incoming ||
            _manager.state == cm.AppCallState.connected)
          _buildCallUI(),
      ],
    );
  }

  Widget _buildCallUI() {
    // If Minimized -> specific alignment (usually top center or free)
    if (_manager.isMinimized) {
      return Positioned(
        top: 50, // Safe area ish
        left: 20,
        right: 20,
        child: Material(color: Colors.transparent, child: _FloatingRedPill()),
      );
    }

    // If Maximized -> Full Screen covering everything
    return Positioned.fill(
      child: Material(
        color: Colors.black, // Dark background for call
        child: _FullScreenCall(),
      ),
    );
  }
}

class _FloatingRedPill extends StatelessWidget {
  final cm.CallManager _manager = cm.CallManager.instance;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _manager.setMinimize(false), // Maximize on tap
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                return Text(
                  _manager.durationText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _manager.hangup,
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenCall extends StatelessWidget {
  final cm.CallManager _manager = cm.CallManager.instance;

  @override
  Widget build(BuildContext context) {
    // Intercept Back Button
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _manager.setMinimize(true); // Minimize instead of pop
      },
      child: SafeArea(
        child: Column(
          children: [
            // Header with Minimize Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => _manager.setMinimize(true),
                  ),
                  const Text(
                    "Ongoing Call",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),

            const Spacer(),

            // Avatar / Info
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              _manager.remoteIdentity ?? "Unknown",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                return Text(
                  _manager.state == cm.AppCallState.incoming
                      ? "Incoming..."
                      : _manager.durationText,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                );
              },
            ),

            const Spacer(),

            // Controls
            if (_manager.state == cm.AppCallState.incoming)
              _buildIncomingControls()
            else
              _buildConnectedControls(),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.red,
          heroTag: "decline",
          onPressed: _manager.hangup,
          child: const Icon(Icons.call_end),
        ),
        FloatingActionButton(
          backgroundColor: Colors.green,
          heroTag: "accept",
          onPressed: _manager.answer,
          child: const Icon(Icons.call),
        ),
      ],
    );
  }

  Widget _buildConnectedControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.mic_off, color: Colors.white),
          onPressed: () {}, // Mute placeholder
        ),
        FloatingActionButton(
          backgroundColor: Colors.red,
          heroTag: "hangup",
          onPressed: _manager.hangup,
          child: const Icon(Icons.call_end),
        ),
        IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.white),
          onPressed: () {}, // Speaker placeholder
        ),
      ],
    );
  }
}
