import 'package:flutter/material.dart';
import 'package:FocusFlow/views/app_shell.dart';
import 'package:FocusFlow/services/timer_settings_service.dart';

class TimerSettingsView extends StatefulWidget {
  const TimerSettingsView({super.key});
  @override
  State<TimerSettingsView> createState() => _TimerSettingsViewState();
}

class _TimerSettingsViewState extends State<TimerSettingsView> {
  final _svc = TimerSettingsService.instance;

  int _focus = 25;
  int _short = 5;
  int _long =15;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _svc.load();
    if (mounted) {
      setState(() {
      _focus = _svc.settings.focusMinutes;
      _short = _svc.settings.shortBreakMinutes;
      _long  = _svc.settings.longBreakMinutes;
    });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _svc.save(TimerSettings(
      focusMinutes: _focus,
      shortBreakMinutes: _short,
      longBreakMinutes: _long,
    ));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved!'),
          backgroundColor: FF.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FF.bg,
      appBar: AppBar(
        backgroundColor: FF.bg, elevation: 0,
        title: Text('Timer Settings',
            style: TextStyle(color: FF.textPri, fontWeight: FontWeight.w700, fontSize: 22)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: FF.accent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_svc.loaded
          ? Center(child: CircularProgressIndicator(color: FF.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildInfoCard(),
                const SizedBox(height: 28),
                _buildSliderCard(
                  label: 'Focus Duration',
                  value: _focus,
                  min: 5, max: 90,
                  color: FF.accent,
                  icon: Icons.timer_rounded,
                  onChanged: (v) => setState(() => _focus = v),
                ),
                const SizedBox(height: 16),
                _buildSliderCard(
                  label: 'Short Break',
                  value: _short,
                  min: 1, max: 15,
                  color: FF.success,
                  icon: Icons.coffee_rounded,
                  onChanged: (v) => setState(() => _short = v),
                ),
                const SizedBox(height: 16),
                _buildSliderCard(
                  label: 'Long Break',
                  value: _long,
                  min: 5, max: 30,
                  color: FF.purple,
                  icon: Icons.self_improvement_rounded,
                  onChanged: (v) => setState(() => _long = v),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FF.accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Settings',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FF.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FF.accent.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: FF.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(
          'These settings apply to your next focus session. Changes are saved to your account.',
          style: TextStyle(color: FF.textSec, fontSize: 13, height: 1.5),
        )),
      ]),
    );
  }

  Widget _buildSliderCard({
    required String label,
    required int value,
    required int min,
    required int max,
    required Color color,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FF.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FF.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: TextStyle(color: FF.textPri, fontSize: 15, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('$value min',
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: FF.divider,
            thumbColor: color,
            overlayColor: color.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(), max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$min min', style: TextStyle(color: FF.textSec, fontSize: 11)),
          Text('$max min', style: TextStyle(color: FF.textSec, fontSize: 11)),
        ]),
      ]),
    );
  }
}