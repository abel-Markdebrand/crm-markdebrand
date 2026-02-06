import 'package:flutter/material.dart';
import '../services/voip_service.dart';

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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Number Display with Flag
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_detectedFlag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _detectedFlag,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  // Auto-Sizing Number Display (Custom implementation)
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate efficient font size
                          double size = 48;
                          int len = _controller.text.length;
                          if (len > 7) size = 48 * (7 / len); // Scale down
                          // Clamp min size
                          if (size < 20) size = 20;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: TextField(
                              controller: _controller,
                              readOnly: true,
                              textAlign: TextAlign.center,
                              showCursor: true,
                              style: TextStyle(
                                fontSize: size,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "",
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  _buildRow(['*', '0', '#']),
                ],
              ),
            ),

            const Spacer(flex: 1), // Reduced flex
            // Actions Row
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Add Contact Button (Left)
                  IconButton(
                    onPressed: () {
                      // Logic to create contact with this number
                    },
                    icon: Icon(
                      Icons.person_add_alt_1,
                      color: Colors.grey[400],
                      size: 28,
                    ),
                  ),

                  // Call Button (Center)
                  InkWell(
                    onTap: _call,
                    borderRadius: BorderRadius.circular(36),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2196F3), // Solid Blue
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),

                  // Backspace Button (Right)
                  GestureDetector(
                    onTap: _onBackspace,
                    onLongPress: () => setState(() => _controller.clear()),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          Icons.backspace_outlined,
                          color: Colors.grey[400],
                          size: 28,
                        ),
                      ),
                    ),
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
    if (label == "2") subtitle = "ABC";
    if (label == "3") subtitle = "DEF";
    if (label == "4") subtitle = "GHI";
    if (label == "5") subtitle = "JKL";
    if (label == "6") subtitle = "MNO";
    if (label == "7") subtitle = "PQRS";
    if (label == "8") subtitle = "TUV";
    if (label == "9") subtitle = "WXYZ";
    if (label == "0") subtitle = "+";

    return InkWell(
      onTap: () => _onKeyPress(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
