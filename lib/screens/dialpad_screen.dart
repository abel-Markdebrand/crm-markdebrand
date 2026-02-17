import 'package:flutter/material.dart';
import '../services/voip_service.dart';
import '../services/call_manager.dart';

class DialpadScreen extends StatefulWidget {
  const DialpadScreen({super.key});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  final TextEditingController _controller = TextEditingController();
  String _detectedFlag = "";

  final Map<String, String> _countryFlags = {
    '+1': '🇺🇸', // USA/Canada
    '+58': '🇻🇪', // Venezuela
    '+57': '🇨🇴', // Colombia
    '+52': '🇲🇽', // Mexico
    '+34': '🇪🇸', // Spain
    '+54': '🇦🇷', // Argentina
    '+56': '🇨🇱', // Chile
    '+51': '🇵🇪', // Peru
    '+55': '🇧🇷', // Brazil
    '+49': '🇩🇪', // Germany
    '+44': '🇬🇧', // UK
    '+33': '🇫🇷', // France
    '+39': '🇮🇹', // Italy
    '+81': '🇯🇵', // Japan
    '+86': '🇨🇳', // China
  };

  void _detectCountry() {
    String text = _controller.text;
    String matched = "";
    // Check 2, 3, 4 digit codes
    // Sort keys by length desc to match longest first if needed, but simple iteration works
    for (var code in _countryFlags.keys) {
      if (text.startsWith(code)) {
        matched = _countryFlags[code]!;
        break; // Match first found
      }
    }
    setState(() {
      _detectedFlag = matched;
    });
  }

  void _onKeyPress(String val) {
    setState(() {
      _controller.text += val;
      _detectCountry();
    });
  }

  void _onBackspace() {
    final text = _controller.text;
    if (text.isNotEmpty) {
      setState(() {
        _controller.text = text.substring(0, text.length - 1);
        _detectCountry();
      });
    }
  }

  void _call() {
    if (_controller.text.isNotEmpty) {
      // Trigger Call via VoipService
      VoipService.instance.makeCall(_controller.text.trim());
      // Optionally pop, but maybe we want to stay here or go to call screen?
      // Usually, call manager handles navigation to CallOverlay or similar.
      // But we should probably pop this "Compose" screen so back button works nicely.
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Premium Number Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_detectedFlag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          _detectedFlag,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double size = 36;
                          int len = _controller.text.length;
                          if (len > 10) size = 36 * (10 / len);
                          if (size < 24) size = 24;

                          return TextField(
                            controller: _controller,
                            readOnly: true,
                            textAlign: TextAlign.center,
                            showCursor: true,
                            cursorColor: const Color(0xFF1A73E8),
                            style: TextStyle(
                              fontSize: size,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 2,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "000 000 000",
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 20),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 20),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 20),
                  _buildRow(['*', '0', '#']),
                ],
              ),
            ),

            const Spacer(flex: 4),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 48, right: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Add Contact
                  _buildCircleAction(
                    icon: Icons.person_add_outlined,
                    onTap: () {},
                    color: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF64748B),
                  ),

                  // Call Button
                  _buildCallButton(),

                  // Backspace
                  _buildCircleAction(
                    icon: Icons.backspace_outlined,
                    onTap: _onBackspace,
                    onLongPress: () => setState(() => _controller.clear()),
                    color: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String label) {
    String subtitle = "";
    if (label == "2")
      subtitle = "ABC";
    else if (label == "3")
      subtitle = "DEF";
    else if (label == "4")
      subtitle = "GHI";
    else if (label == "5")
      subtitle = "JKL";
    else if (label == "6")
      subtitle = "MNO";
    else if (label == "7")
      subtitle = "PQRS";
    else if (label == "8")
      subtitle = "TUV";
    else if (label == "9")
      subtitle = "WXYZ";
    else if (label == "0")
      subtitle = "+";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Color color,
    required Color iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }

  Widget _buildCallButton() {
    return ListenableBuilder(
      listenable: VoipService.instance.callManager,
      builder: (context, _) {
        final state = VoipService.instance.callManager.state;
        final isRegistered = state == AppCallState.registered;

        // Use a better visual indicator for non-registered state
        // Instead of "phone_disabled", show a slightly transparent phone
        return InkWell(
          onTap: isRegistered
              ? _call
              : () {
                  // Suggesting registration if tapped while not registered
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Conectando con el servidor de voz..."),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isRegistered
                  ? const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color: (isRegistered ? Colors.green : Colors.grey).withAlpha(
                    80,
                  ),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.phone, color: Colors.white, size: 38),
          ),
        );
      },
    );
  }
}
