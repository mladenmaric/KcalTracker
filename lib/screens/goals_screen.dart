import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goals.dart';
import '../providers/goals_provider.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _kcalCtrl = TextEditingController();
  double _proteinPct = 40;
  double _carbsPct   = 30;
  double _fatPct     = 30;
  bool _loaded = false;

  @override
  void dispose() {
    _kcalCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(Goals g) {
    if (_loaded) return;
    _kcalCtrl.text = g.dailyKcal.toStringAsFixed(0);
    _proteinPct = g.proteinPct;
    _carbsPct   = g.carbsPct;
    _fatPct     = g.fatPct;
    _loaded = true;
  }

  // Keep the three sliders summing to 100.
  void _adjustOthers(String changed, double value) {
    final remaining = 100 - value;
    setState(() {
      switch (changed) {
        case 'protein':
          _proteinPct = value;
          final ratio = _carbsPct / (_carbsPct + _fatPct);
          _carbsPct = remaining * ratio;
          _fatPct   = remaining * (1 - ratio);
        case 'carbs':
          _carbsPct = value;
          final ratio = _proteinPct / (_proteinPct + _fatPct);
          _proteinPct = remaining * ratio;
          _fatPct     = remaining * (1 - ratio);
        case 'fat':
          _fatPct = value;
          final ratio = _proteinPct / (_proteinPct + _carbsPct);
          _proteinPct = remaining * ratio;
          _carbsPct   = remaining * (1 - ratio);
      }
    });
  }

  double get _totalPct => _proteinPct + _carbsPct + _fatPct;

  Future<void> _save() async {
    final kcal = double.tryParse(_kcalCtrl.text);
    if (kcal == null || kcal <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid calorie goal')));
      return;
    }
    final goals = Goals(
      dailyKcal:  kcal,
      proteinPct: double.parse(_proteinPct.toStringAsFixed(1)),
      carbsPct:   double.parse(_carbsPct.toStringAsFixed(1)),
      fatPct:     double.parse(_fatPct.toStringAsFixed(1)),
    );
    await ref.read(goalsProvider.notifier).save(goals);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals saved!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);

    return goalsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (goals) {
        _loadFrom(goals);
        // Derived gram targets from current slider values and kcal field.
        final kcal = double.tryParse(_kcalCtrl.text) ?? goals.dailyKcal;
        final proteinG = (kcal * _proteinPct / 100) / 4;
        final carbsG   = (kcal * _carbsPct   / 100) / 4;
        final fatG     = (kcal * _fatPct     / 100) / 9;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Daily Goals'),
            actions: [
              TextButton(
                onPressed: _save,
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Calorie goal ──────────────────────────────────────────
              Text('Calorie Goal', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _kcalCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  suffixText: 'kcal / day',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Macro split ───────────────────────────────────────────
              Text('Macro Split', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Sliders auto-balance to 100% (currently ${_totalPct.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              _MacroSlider(
                label: 'Protein',
                value: _proteinPct,
                grams: proteinG,
                color: Colors.blue,
                onChanged: (v) => _adjustOthers('protein', v),
              ),
              const SizedBox(height: 12),
              _MacroSlider(
                label: 'Carbs',
                value: _carbsPct,
                grams: carbsG,
                color: Colors.amber.shade700,
                onChanged: (v) => _adjustOthers('carbs', v),
              ),
              const SizedBox(height: 12),
              _MacroSlider(
                label: 'Fat',
                value: _fatPct,
                grams: fatG,
                color: Colors.red,
                onChanged: (v) => _adjustOthers('fat', v),
              ),
              const SizedBox(height: 24),

              // ── Visual split bar ──────────────────────────────────────
              Text('Distribution', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    _Bar(flex: _proteinPct.round(), color: Colors.blue,          label: 'P'),
                    _Bar(flex: _carbsPct.round(),   color: Colors.amber.shade700, label: 'C'),
                    _Bar(flex: _fatPct.round(),     color: Colors.red,            label: 'F'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MacroSlider extends StatelessWidget {
  final String label;
  final double value;
  final double grams;
  final Color color;
  final ValueChanged<double> onChanged;

  const _MacroSlider({
    required this.label,
    required this.value,
    required this.grams,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              Text(
                '${value.toStringAsFixed(0)}%  ≈ ${grams.toStringAsFixed(0)}g',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Slider(
            value: value.clamp(5, 90),
            min: 5,
            max: 90,
            divisions: 85,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      );
}

class _Bar extends StatelessWidget {
  final int flex;
  final Color color;
  final String label;
  const _Bar({required this.flex, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex.clamp(1, 100),
        child: Container(
          height: 32,
          color: color,
          alignment: Alignment.center,
          child: Text(
            '$label $flex%',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
}
