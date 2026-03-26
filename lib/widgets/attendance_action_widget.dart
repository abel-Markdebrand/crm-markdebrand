import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mvp_odoo/services/attendance_service.dart';

class AttendanceActionWidget extends StatefulWidget {
  const AttendanceActionWidget({super.key});

  @override
  State<AttendanceActionWidget> createState() => _AttendanceActionWidgetState();
}

class _AttendanceActionWidgetState extends State<AttendanceActionWidget> {
  bool _isLoading = true;
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  Timer? _timer;
  String _durationString = "00:00:00";

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    try {
      final last = await AttendanceService().getLastAttendance();
      if (mounted) {
        setState(() {
          if (last != null &&
              (last['check_out'] == false || last['check_out'] == null)) {
            _isCheckedIn = true;
            DateTime utcTime = DateTime.parse(
              last['check_in'] + (last['check_in'].endsWith('Z') ? '' : 'Z'),
            );
            _checkInTime = utcTime.toLocal();
            _startTimer();
          } else {
            _isCheckedIn = false;
            _checkInTime = null;
            _timer?.cancel();
            _durationString = "00:00:00";
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_checkInTime != null) {
        final now = DateTime.now();
        final diff = now.difference(_checkInTime!);
        if (mounted) {
          setState(() {
            _durationString = _formatDuration(diff);
          });
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _toggleAttendance() async {
    setState(() => _isLoading = true);
    try {
      if (_isCheckedIn) {
        await AttendanceService().checkOut();
      } else {
        await AttendanceService().checkIn();
      }
      await _loadState();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActiveSessionView(),
          const SizedBox(height: 40),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActiveSessionView() {
    return Column(
      children: [
        if (_isCheckedIn) ...[
          Text(
            _durationString,
            style: GoogleFonts.outfit(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "SESSION IN PROGRESS",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          if (_checkInTime != null)
            Text(
              "Started at ${DateFormat('HH:mm').format(_checkInTime!)}",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
        ] else ...[
          Text(
            "00:00:00",
            style: GoogleFonts.outfit(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "SYSTEM READY",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: _toggleAttendance,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: _isCheckedIn
                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                : [const Color(0xFF10B981), const Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (_isCheckedIn
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981))
                      .withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
              color: Colors.white,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              _isCheckedIn ? "CHECK OUT" : "CHECK IN",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
