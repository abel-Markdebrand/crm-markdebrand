import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:file_picker/file_picker.dart';
import 'dart:async';

class ChatInput extends StatefulWidget {
  final Future<void> Function(String) onSendText;
  final Future<void> Function(String) onSendAudio;
  final Future<void> Function(String) onSendFile;

  const ChatInput({
    super.key,
    required this.onSendText,
    required this.onSendAudio,
    required this.onSendFile,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // State
  bool _hasText = false;
  RecordingState _recordingState = RecordingState.idle;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  double _dragOffset = 0.0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // --- RECORDING LOGIC ---

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(), path: path);

    _startTimer();
    setState(() {
      _recordingState = RecordingState.recording;
      _dragOffset = 0.0;
    });
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();

    setState(() {
      _recordingState = RecordingState.idle;
      _recordDuration = Duration.zero;
    });

    if (cancel || path == null) return;

    setState(() => _isSending = true);
    try {
      await widget.onSendAudio(path);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    _timer?.cancel();
    setState(() {
      _recordingState = RecordingState.paused;
    });
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    _startTimer();
    setState(() {
      _recordingState = RecordingState.recording; // Resume to recording state
    });
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    _timer?.cancel();
    setState(() {
      _recordingState = RecordingState.idle;
      _recordDuration = Duration.zero;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_hasText && !_isSending) {
      final text = _controller.text.trim();
      _controller.clear();

      setState(() => _isSending = true);
      try {
        await widget.onSendText(text);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickFile() async {
    if (_isSending) return;
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isSending = true);
      try {
        await widget.onSendFile(result.files.single.path!);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // THE FLOATING BAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: const Cubic(0.16, 1, 0.3, 1),
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color:
                      _recordingState != RecordingState.idle &&
                          _recordingState != RecordingState.recording
                      ? const Color(0xFFF04438).withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
              border: _recordingState != RecordingState.idle
                  ? Border.all(
                      color: const Color(0xFFF04438).withValues(alpha: 0.1),
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // TEXT MODE (Hidden when recording)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _recordingState == RecordingState.idle ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: _recordingState != RecordingState.idle,
                    child: _buildTextMode(),
                  ),
                ),

                // AUDIO INTERFACE (Recording / Review)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _recordingState == RecordingState.idle ? 0.0 : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: const Cubic(0.16, 1, 0.3, 1),
                    transform: Matrix4.identity()
                      ..translate(
                        0.0,
                        _recordingState == RecordingState.idle ? 10.0 : 0.0,
                      ),
                    child: IgnorePointer(
                      ignoring: _recordingState == RecordingState.idle,
                      child: _buildAudioInterface(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // MAIN MIC BUTTON (Visible only in idle mode)
          Positioned(
            right: 4,
            top: 4,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: _recordingState == RecordingState.idle ? 1.0 : 0.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _recordingState == RecordingState.idle ? 1.0 : 0.0,
                child: _buildMainMicBtn(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFF667085)),
            onPressed: _pickFile,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Escribe un mensaje...",
                hintStyle: TextStyle(color: Color(0xFF98A2B3)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              style: const TextStyle(color: Color(0xFF1D2939), fontSize: 15),
            ),
          ),
          const SizedBox(width: 48), // Padding for the floating mic button
        ],
      ),
    );
  }

  Widget _buildMainMicBtn() {
    return GestureDetector(
      onTap: () {
        if (_hasText) {
          _sendMessage();
        } else {
          _startRecording();
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A73E8), Color(0xFF155DB5)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _hasText ? Icons.send : Icons.mic,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAudioInterface() {
    final bool isReview = _recordingState == RecordingState.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // DELETE BUTTON
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFF04438),
              size: 24,
            ),
            onPressed: _cancelRecording,
          ),

          // CENTER STATE (RECORDING OR REVIEW)
          Expanded(
            child: isReview ? _buildReviewState() : _buildRecordingState(),
          ),

          // CONTROLS RIGHT
          Row(
            children: [
              if (!isReview)
                IconButton(
                  icon: const Icon(
                    Icons.pause_circle_outline,
                    color: Color(0xFFF04438),
                    size: 32,
                  ),
                  onPressed: _pauseRecording,
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.mic_none_outlined,
                    color: Color(0xFF1A73E8),
                    size: 32,
                  ),
                  onPressed: _resumeRecording,
                ),
              const SizedBox(width: 8),
              _buildSendAudioBtn(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const RecordingPulse(),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_recordDuration),
          style: const TextStyle(
            color: Color(0xFFF04438),
            fontWeight: FontWeight.w600,
            fontSize: 16,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 16),
        const WaveVisualizer(),
      ],
    );
  }

  Widget _buildReviewState() {
    return Row(
      children: [
        const Icon(Icons.play_arrow, color: Color(0xFF667085)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E7EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: 0.5, // Mock progress for UI
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned(
                  left: 0.5 * 100, // Matching the fraction
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF1A73E8),
                        width: 3,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_recordDuration),
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSendAudioBtn() {
    return GestureDetector(
      onTap: () => _stopRecording(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A73E8), Color(0xFF155DB5)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.send, color: Colors.white, size: 20),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}

class RecordingPulse extends StatefulWidget {
  const RecordingPulse({super.key});

  @override
  State<RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<RecordingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.1).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFF04438),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class WaveVisualizer extends StatelessWidget {
  const WaveVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => _buildBar(index)),
    );
  }

  Widget _buildBar(int index) {
    return AnimatedWaveBar(delay: index * 0.2);
  }
}

class AnimatedWaveBar extends StatefulWidget {
  final double delay;
  const AnimatedWaveBar({super.key, required this.delay});

  @override
  State<AnimatedWaveBar> createState() => _AnimatedWaveBarState();
}

class _AnimatedWaveBarState extends State<AnimatedWaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _heightAnimation = Tween<double>(
      begin: 8,
      end: 24,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return Container(
          width: 3,
          height: _heightAnimation.value,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

enum RecordingState { idle, recording, locked, paused }
