// lib/widgets/calendar_card.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarCard extends StatefulWidget {
  final Color? primaryColor;
  final VoidCallback? onDaySelected;

  const CalendarCard({super.key, this.primaryColor, this.onDaySelected});

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  // ✅ PERBAIKAN: Nullable, bukan late!
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final Set<DateTime> _eventDays = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    ));

    _animationController!.forward();
  }

  @override
  void dispose() {
    // ✅ PERBAIKAN: Aman dispose walau null
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? const Color(0xFF1E3C72);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ PERBAIKAN: Return widget simpel kalau animasi belum siap
    if (_fadeAnimation == null || _slideAnimation == null) {
      return _buildSimpleCalendar(color, isDark);
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: _buildCalendarContent(color, isDark),
      ),
    );
  }

  // 🔥 KALENDER FULL
  Widget _buildCalendarContent(Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(26), color.withAlpha(13), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withAlpha(51), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: color.withAlpha(38)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(color),
            _buildCalendarBody(color, isDark),
            const SizedBox(height: 8),
            _buildQuickActions(color),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // 🔥 SIMPLE CALENDAR (FALLBACK)
  Widget _buildSimpleCalendar(Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_month, color: color, size: 20),
            const SizedBox(width: 8),
            const Text('Kalender', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.now().add(const Duration(days: 3650)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => _isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
              widget.onDaySelected?.call();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: color.withAlpha(77), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
        ],
      ),
    );
  }

  // 🔥 HEADER
  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withAlpha(200)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Kalender', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDay),
                    style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(200))),
              ]),
            ]),
            Container(
              decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: Icon(
                  _calendarFormat == CalendarFormat.month ? Icons.view_week : Icons.calendar_view_month,
                  color: Colors.white, size: 20,
                ),
                onPressed: () => setState(() => _calendarFormat = _calendarFormat == CalendarFormat.month ? CalendarFormat.week : CalendarFormat.month),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildNavButton(Icons.chevron_left_rounded, () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1))),
            Text(DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            _buildNavButton(Icons.chevron_right_rounded, () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1))),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildInfoChip('Hari Ini', Icons.today_rounded, Colors.white),
            if (!_isSameDay(_selectedDay, DateTime.now())) _buildInfoChip('Dipilih', Icons.check_circle_rounded, Colors.amber),
          ]),
        ],
      ),
    );
  }

  // 🔥 CALENDAR BODY
  Widget _buildCalendarBody(Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 3650)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => _isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
          widget.onDaySelected?.call();
        },
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withAlpha(180)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(77), blurRadius: 8)],
          ),
          todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withAlpha(200)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(128), blurRadius: 12)],
          ),
          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          weekendTextStyle: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.w500),
          defaultTextStyle: TextStyle(color: isDark ? Colors.white : Colors.grey.shade800, fontSize: 13),
          outsideTextStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          markersMaxCount: 3,
          markerDecoration: BoxDecoration(color: color.withAlpha(128), shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false, titleCentered: true,
          leftChevronVisible: false, rightChevronVisible: false,
          headerPadding: EdgeInsets.zero, headerMargin: EdgeInsets.zero,
          titleTextStyle: TextStyle(fontSize: 0),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 11),
          weekendStyle: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.w600, fontSize: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color.withAlpha(38)))),
        ),
      ),
    );
  }

  // 🔥 QUICK ACTIONS
  Widget _buildQuickActions(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildQuickAction(Icons.today_rounded, 'Hari Ini', color, () {
          final now = DateTime.now();
          setState(() { _selectedDay = now; _focusedDay = now; });
          widget.onDaySelected?.call();
        }),
        _buildQuickAction(Icons.event_busy_rounded, 'Kosongkan', color, () {
          setState(() { _selectedDay = DateTime.now(); _focusedDay = DateTime.now(); });
        }),
        _buildQuickAction(
          _calendarFormat == CalendarFormat.month ? Icons.view_week : Icons.calendar_view_month,
          _calendarFormat == CalendarFormat.month ? 'Minggu' : 'Bulan',
          color,
          () => setState(() => _calendarFormat = _calendarFormat == CalendarFormat.month ? CalendarFormat.week : CalendarFormat.month),
        ),
      ]),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(38),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 20))),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(50))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: iconColor), const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(220), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withAlpha(13), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(38))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color), const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ]),
        )),
    );
  }

  // ==================== HELPERS ====================
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void addEventDays(List<DateTime> dates) => setState(() => _eventDays.addAll(dates));
  void clearEvents() => setState(() => _eventDays.clear());
  void selectDay(DateTime day) => setState(() { _selectedDay = day; _focusedDay = day; });
}