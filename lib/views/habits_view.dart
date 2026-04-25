import 'package:flutter/material.dart';
import 'package:FocusFlow/views/widgets/skeleton_loader.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/database/database_service.dart';
import 'package:FocusFlow/services/database/database_habit.dart';

class HabitsView extends StatefulWidget {
  const HabitsView({super.key});
  @override
  State<HabitsView> createState() => _HabitsViewState();
}

class _HabitsViewState extends State<HabitsView> {
  String? get _uid => AuthService.firebase().currentUser?.id;
  final _db = DatabaseService.firebase();

  List<DatabaseHabit> _habits = [];
  bool _loading = true;

  static String get _todayKey =>
      DateTime.now().toIso8601String().substring(0, 10); // "2025-03-23"

  @override
  void initState() {
    super.initState();
    _listenHabits();
  }

  void _listenHabits() {
    if (_uid == null) return;
    _db.habitsStream(ownerUserId: _uid!).listen((habits) {
      if (mounted) setState(() { _habits = habits; _loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  bool _isDoneToday(DatabaseHabit h) => h.completedDates.contains(_todayKey);

  int get _doneCount => _habits.where(_isDoneToday).length;

  // Toggle today's completion
  Future<void> _toggle(DatabaseHabit habit) async {
    if (_uid == null) return;
    final dates = List<String>.from(habit.completedDates);
    if (dates.contains(_todayKey)) {
      dates.remove(_todayKey);
    } else {
      dates.add(_todayKey);
    }
    await _db.markHabitComplete(
      ownerUserId: _uid!, habitId: habit.id, completedDates: dates,
    );
  }

  Future<void> _delete(DatabaseHabit habit) async {
    if (_uid == null) return;
    await _db.deleteHabit(ownerUserId: _uid!, habitId: habit.id);
  }

  // Current streak = consecutive days ending today
  int _streak(DatabaseHabit h) {
    int count = 0;
    var day = DateTime.now();
    while (true) {
      final key = day.toIso8601String().substring(0, 10);
      if (h.completedDates.contains(key)) {
        count++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }

  // Last 7 days completion map
  List<bool> _last7(DatabaseHabit h) {
    return List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      final key = day.toIso8601String().substring(0, 10);
      return h.completedDates.contains(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FF.bg,
      appBar: AppBar(
        backgroundColor: FF.bg, elevation: 0,
        title: Text('Habits',
            style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('$_doneCount/${_habits.length} today',
                    style: TextStyle(color: FF.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const HabitsViewSkeleton()
          : Column(children: [
              _buildProgressBar(),
              Expanded(child: _habits.isEmpty ? _buildEmpty() : _buildList()),
            ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits_fab',
        onPressed: () => _showAddSheet(context),
        backgroundColor: FF.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _habits.isEmpty ? 0.0 : _doneCount / _habits.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Today's progress",
              style: TextStyle(color: FF.textSec, fontSize: 13)),
          Text('${(pct * 100).round()}%',
              style: TextStyle(color: FF.accent, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct, minHeight: 6,
            backgroundColor: FF.card,
            valueColor: AlwaysStoppedAnimation<Color>(FF.accent),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.track_changes_rounded, color: FF.textSec, size: 52),
      const SizedBox(height: 14),
      Text('No habits yet', style: TextStyle(color: FF.textPri, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Tap + to add your first habit', style: TextStyle(color: FF.textSec, fontSize: 13)),
    ]));
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _habits.length,
      itemBuilder: (_, i) {
        final h = _habits[i];
        final done = _isDoneToday(h);
        final streak = _streak(h);
        final last7  = _last7(h);
        return Dismissible(
          key: ValueKey(h.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
                color: FF.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.delete_outline, color: FF.danger),
          ),
          onDismissed: (_) => _delete(h),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: done ? FF.accent.withOpacity(0.08) : FF.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: done ? FF.accent.withOpacity(0.4) : FF.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(
                  onTap: () => _toggle(h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: done ? FF.accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: done ? FF.accent : FF.textSec, width: 2),
                    ),
                    child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(h.title,
                    style: TextStyle(
                      color: done ? FF.textPri : FF.textPri,
                      fontSize: 15, fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.none : null,
                    ))),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: FF.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_fire_department, color: FF.warning, size: 13),
                      Text(' $streak', style: TextStyle(
                          color: FF.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 12),
              // 7-day grid
              Row(children: [
                Text('Last 7 days  ',
                    style: TextStyle(color: FF.textSec, fontSize: 11)),
                ...last7.map((done) => Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: done ? FF.accent : FF.divider,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }

  void _showAddSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: FF.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          bool saving = false;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20, right: 20, top: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: FF.textSec.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('New Habit',
                  style: TextStyle(color: FF.textPri, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl, autofocus: true,
                style: TextStyle(color: FF.textPri),
                decoration: InputDecoration(
                  hintText: 'e.g. Read 20 pages, Morning workout...',
                  hintStyle: TextStyle(color: FF.textSec),
                  filled: true, fillColor: FF.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: FF.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: FF.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: FF.accent)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (ctrl.text.trim().isEmpty || _uid == null) return;
                    setS(() => saving = true);
                    await _db.createHabit(ownerUserId: _uid!, title: ctrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FF.accent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Habit',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }
}