import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mvp_odoo/services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;

  // Filter state
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    try {
      final history = await AttendanceService().getAttendances(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'SELECCIONAR MES',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null &&
        (picked.month != _selectedMonth.month ||
            picked.year != _selectedMonth.year)) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_buildMonthFilter(), const SizedBox(height: 20)],
              ),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/image/logo_mdb.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Asistencias",
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _loadState,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildMonthFilter() {
    return InkWell(
      onTap: _selectMonth,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 48,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 16),
              Text(
                "No hay registros este mes",
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildHistoryItem(_history[index]),
          childCount: _history.length,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> rec) {
    final checkInStr = rec['check_in'] as String;
    final checkOutStr = rec['check_out'] is String
        ? rec['check_out'] as String
        : null;

    final checkIn = DateTime.parse(
      checkInStr + (checkInStr.endsWith('Z') ? '' : 'Z'),
    ).toLocal();
    final checkOut = checkOutStr != null
        ? DateTime.parse(
            checkOutStr + (checkOutStr.endsWith('Z') ? '' : 'Z'),
          ).toLocal()
        : null;

    final workedHours = (rec['worked_hours'] as num? ?? 0.0).toDouble();
    final workedExtraHours = (rec['worked_extra_hours'] as num? ?? 0.0)
        .toDouble();
    final extraHours = (rec['extra_hours'] as num? ?? 0.0).toDouble();
    final overtime = (rec['overtime'] as num? ?? 0.0).toDouble();

    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF8FAFC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Calendar Icon & Date/Time
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                dateTimeFormat.format(checkIn),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Middle Row: Entrada -> Salida | Horas
          Row(
            children: [
              // Entrada Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ENTRADA",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeFormat.format(checkIn),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Arrow
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 16),

              // Salida Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SALIDA",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    checkOut != null ? timeFormat.format(checkOut) : "--:--",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Vertical Divider
              Container(height: 40, width: 1, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 16),

              // Horas Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "HORAS",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${workedHours.toStringAsFixed(2)}h",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB), // Blue text for hours
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (workedExtraHours > 0 || extraHours > 0 || overtime > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (workedExtraHours > 0)
                    _buildExtraMetric(
                      "EX. TRAB.",
                      workedExtraHours,
                      const Color(0xFF10B981),
                    ),

                  if (extraHours > 0 || overtime > 0)
                    _buildExtraMetric(
                      "EXTRA",
                      extraHours > 0 ? extraHours : overtime,
                      Colors.blue,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtraMetric(String label, double value, Color color) {
    return Row(
      children: [
        Icon(Icons.add_circle_outline_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          "$label:",
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "+${value.toStringAsFixed(2)}h",
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
