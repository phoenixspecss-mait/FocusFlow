import 'package:flutter/material.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';
import 'package:FocusFlow/services/database/database_service.dart';
import 'package:FocusFlow/services/database/database_task.dart';
import 'package:FocusFlow/services/settings_service.dart';
import 'package:FocusFlow/services/localization_service.dart';

class TasksView extends StatefulWidget {
  const TasksView({super.key});
  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  String? get _uid => AuthService.firebase().currentUser?.id;
  final _db = DatabaseService.firebase();

  List<DatabaseTask> _tasks = [];
  bool _loading = true;
  String _filter = 'All';
  final List<String> _filters = ['All', 'Active', 'Done'];

  String _getFilterLabel(String f) {
    if (f == 'All') return LocalizationService.t('all');
    if (f == 'Active') return LocalizationService.t('active_filter');
    if (f == 'Done') return LocalizationService.t('done_filter');
    return f;
  }

  @override
  void initState() {
    super.initState();
    _listenToTasks();
  }

  void _listenToTasks() {
    if (_uid == null) return;
    // Real-time stream from Firebase
    _db.tasksStream(ownerUserId: _uid!).listen((tasks) {
      if (mounted) setState(() { _tasks = tasks; _loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<DatabaseTask> get _filtered {
    switch (_filter) {
      case 'Active': return _tasks.where((t) => !t.completed).toList();
      case 'Done':   return _tasks.where((t) =>  t.completed).toList();
      default:       return _tasks;
    }
  }

  Future<void> _addTask(String title, String tag, _P priority) async {
    if (_uid == null) return;
    // tag and priority stored in title for now (your schema has title + completed)
    await _db.createTask(ownerUserId: _uid!, title: '[$tag][$priority] $title');
  }

  Future<void> _toggleDone(DatabaseTask task) async {
    if (_uid == null) return;
    await _db.updateTask(ownerUserId: _uid!, taskId: task.id, completed: !task.completed);
    // Update tasksDone count on user
    final doneCount = _tasks.where((t) => t.completed).length + (task.completed ? -1 : 1);
    await _db.updateUserStats(ownerUserId: _uid!, tasksDone: doneCount);
  }

  Future<void> _deleteTask(DatabaseTask task) async {
    if (_uid == null) return;
    await _db.deleteTask(ownerUserId: _uid!, taskId: task.id);
  }

  @override
  Widget build(BuildContext context) {
    final active = _tasks.where((t) => !t.completed).length;
    final done   = _tasks.where((t) =>  t.completed).length;

    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: FF.bg,
          appBar: AppBar(
            backgroundColor: FF.bg, elevation: 0,
            title: Text(LocalizationService.t('tasks'),
                style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 22)),
            actions: [
              if (_loading) Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: FF.accent, strokeWidth: 2))),
              ),
            ],
          ),
          body: Column(children: [
            _buildProgressHeader(active, done),
            const SizedBox(height: 16),
            _buildFilterRow(),
            const SizedBox(height: 8),
            Expanded(child: _loading ? Center(child: CircularProgressIndicator(color: FF.accent)) : _buildList()),
          ]),
          floatingActionButton: FloatingActionButton(
            heroTag: 'tasks_fab',
            onPressed: () => _showAddSheet(context),
            backgroundColor: FF.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  Widget _buildProgressHeader(int active, int done) {
    final total   = _tasks.length;
    final percent = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: FF.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: FF.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$active ${LocalizationService.t('tasks_remaining')}',
                style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${(percent * 100).round()}%',
                style: TextStyle(color: FF.accent, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent, minHeight: 8,
              backgroundColor: FF.accentSoft.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(FF.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text('$done ${LocalizationService.t('of')} $total ${LocalizationService.t('completed_of')}', style: TextStyle(color: FF.textSec, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _filters.map((f) {
          final sel = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? FF.accent : FF.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? FF.accent : FF.divider),
              ),
              child: Text(_getFilterLabel(f), style: TextStyle(
                color: sel ? Colors.white : FF.textSec, fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.task_alt_rounded, color: FF.textSec, size: 48),
          const SizedBox(height: 12),
          Text(_filter == 'All' 
              ? LocalizationService.t('no_tasks') 
              : LocalizationService.t('no_filter_tasks').replaceAll('{filter}', _getFilterLabel(_filter)),
              style: TextStyle(color: FF.textSec, fontSize: 15)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final task = list[i];
        return Dismissible(
          key: ValueKey(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: FF.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.delete_outline, color: FF.danger),
          ),
          onDismissed: (_) => _deleteTask(task),
          child: _TaskCard(task: task, onToggle: () => _toggleDone(task)),
        );
      },
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FF.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddTaskSheet(onAdd: _addTask),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DatabaseTask task;
  final VoidCallback onToggle;
  const _TaskCard({required this.task, required this.onToggle});

  // Parse tag from title format: [Tag][Priority] Actual title
  String get _displayTitle {
    final t = task.title;
    final reg = RegExp(r'^\[.*?\]\[.*?\]\s*');
    return t.replaceAll(reg, '');
  }
  String get _tag {
    final m = RegExp(r'^\[(.*?)\]').firstMatch(task.title);
    return m?.group(1) ?? 'Dev';
  }
  Color _tagColor(String tag) {
    switch (tag) {
      case 'Design':  return FF.purple;
      case 'Meeting': return FF.warning;
      case 'Other':   return FF.success;
      default:        return FF.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FF.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: FF.divider)),
      child: Row(children: [
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: task.completed ? FF.accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: task.completed ? FF.accent : FF.textSec, width: 2),
            ),
            child: task.completed ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_displayTitle, style: TextStyle(
            color: task.completed ? FF.textSec : FF.textPri,
            fontSize: 14, fontWeight: FontWeight.w500,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            decorationColor: FF.textSec,
          )),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _tagColor(_tag).withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
            child: Text(_tag, style: TextStyle(color: _tagColor(_tag), fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ])),
      ]),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final Future<void> Function(String, String, _P) onAdd;
  const _AddTaskSheet({required this.onAdd});
  @override State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _ctrl = TextEditingController();
  String _tag  = 'Dev';
  _P _priority = _P.medium;
  bool _saving = false;
  final _tags  = ['Dev', 'Design', 'Meeting', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(LocalizationService.t('new_task'), style: TextStyle(color: FF.textPri, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl, autofocus: true,
          style: TextStyle(color: FF.textPri),
          decoration: InputDecoration(
            hintText: LocalizationService.t('task_hint'),
            hintStyle: TextStyle(color: FF.textSec),
            filled: true, fillColor: FF.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FF.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FF.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FF.accent)),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: _tags.map((t) {
          final sel = t == _tag;
          return GestureDetector(
            onTap: () => setState(() => _tag = t),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? FF.accent.withOpacity(0.2) : FF.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? FF.accent : FF.divider),
              ),
              child: Text(t, style: TextStyle(color: sel ? FF.accent : FF.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),
        Row(children: _P.values.map((p) {
          final sel = p == _priority;
          final colors = {_P.high: FF.danger, _P.medium: FF.warning, _P.low: FF.success};
          final labels = {
            _P.high: LocalizationService.t('high'), 
            _P.medium: LocalizationService.t('medium'), 
            _P.low: LocalizationService.t('low')
          };
          return GestureDetector(
            onTap: () => setState(() => _priority = p),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? colors[p]!.withOpacity(0.15) : FF.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? colors[p]! : FF.divider),
              ),
              child: Text(labels[p]!, style: TextStyle(color: sel ? colors[p] : FF.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () async {
              if (_ctrl.text.trim().isEmpty) return;
              setState(() => _saving = true);
              await widget.onAdd(_ctrl.text.trim(), _tag, _priority);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FF.accent, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(LocalizationService.t('add_task'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

enum _P { high, medium, low }