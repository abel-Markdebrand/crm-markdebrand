import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAttendances = [];
  List<Map<String, dynamic>> _filteredAttendances = [];
  String? _errorMessage;

  // Filter State
  String _selectedFilter = 'Todos'; // 'Todos', 'Entradas', 'Horas', 'Extra'

  @override
  void initState() {
    super.initState();
    _loadAttendances();
  }

  Future<void> _loadAttendances() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _attendanceService.getAttendances(limit: 50);
      if (mounted) {
        setState(() {
          _allAttendances = records;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'Todos') {
        _filteredAttendances = _allAttendances;
      } else if (_selectedFilter == 'Entradas') {
        // Just an example filter: show only checked-in (active) or today's?
        // User asked for "Check-in/Check-out". Maybe just show those columns highlighted?
        // Or filter by "Active" check-ins?
        // Let's filter by "Active" for "Entradas" context if needed, or just show all but focus on times.
        // For now, let's keep it simple: 'Todos' shows everything.
        // Maybe 'Entradas' means "Check-ins from this month"?
        // The user requirement was "place the tables... for filtering".
        // Let's filter by:
        // Todos = All
        // Entradas = Active Check-ins (no checkout)
        // Horas = Finished records (with worked_hours)
        // Extra = Records with Overtime > 0

        _filteredAttendances = _allAttendances; // Default fallback
      } else if (_selectedFilter == 'Extra') {
        _filteredAttendances = _allAttendances.where((record) {
          final overtime = record['overtime'] ?? 0.0;
          return overtime > 0;
        }).toList();
      }

      // Since the request was a bit ambiguous on *hiding* rows vs showing columns,
      // I'll stick to 'Todos' showing everything, and maybe specific filters just reducing the list.
      // Let's refine based on "Tables".
      // Let's implemented:
      // 'Todos' (All)
      // 'Este Mes' (This Month)
      // 'Extra' (Overtime only)

      if (_selectedFilter == 'Este Mes') {
        final now = DateTime.now();
        _filteredAttendances = _allAttendances.where((record) {
          if (record['check_in'] == null || record['check_in'] == false) {
            return false;
          }
          final date = DateTime.parse(record['check_in'].toString()).toLocal();
          return date.year == now.year && date.month == now.month;
        }).toList();
      }
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  String _formatTime(dynamic dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr == false) return '--:--';
    try {
      final date = DateTime.parse(dateTimeStr.toString()).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '--:--';
    }
  }

  String _formatDate(dynamic dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr == false) return '--';
    try {
      final date = DateTime.parse(dateTimeStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy', 'es').format(date);
    } catch (_) {
      return dateTimeStr.toString();
    }
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '--:--';
    if (duration is double) {
      final int totalSeconds = (duration * 3600).round();
      final int hours = totalSeconds ~/ 3600;
      final int minutes = ((totalSeconds % 3600) / 60).floor();
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}h';
    }
    return '${(duration as double).toStringAsFixed(2)}h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Historial de Asistencias",
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendances,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Este Mes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Extra'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 1), // Separator

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text("Error: $_errorMessage"))
                : _filteredAttendances.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No hay registros",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredAttendances.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildAttendanceCard(_filteredAttendances[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) _onFilterChanged(label);
      },
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFFEFF6FF),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final checkIn = record['check_in'];
    final checkOut = record['check_out'];
    final workedHours = record['worked_hours'];
    final isActive =
        checkIn != false && (checkOut == false || checkOut == null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: isActive
            ? Border.all(color: const Color(0xFF10B981), width: 1)
            : Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          // Top Row: Date & Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(checkIn),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      "EN CURSO",
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Middle Row: Metrics
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Check In / Out
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _buildMetricColumn(
                        "ENTRADA",
                        _formatTime(checkIn),
                        Colors.black87,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_right_alt_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 16,
                        ),
                      ),
                      _buildMetricColumn(
                        "SALIDA",
                        isActive ? '--:--' : _formatTime(checkOut),
                        Colors.black87,
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 16),
                // Hours
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricColumn(
                        "HORAS TRAB.",
                        _formatDuration(workedHours),
                        const Color(0xFF2563EB),
                      ),
                      // if (overtime > 0)
                      //   _buildMetricColumn(
                      //     "EXTRA",
                      //     _formatDuration(overtime),
                      //     const Color(0xFFF59E0B),
                      //   ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
