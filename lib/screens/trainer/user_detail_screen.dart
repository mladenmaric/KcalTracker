import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/meal.dart';
import '../../models/meal_comment.dart';
import '../../providers/trainer_provider.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  DateTime _date = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();

  RealtimeChannel? _mealsChannel;
  RealtimeChannel? _foodItemsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final db = Supabase.instance.client;

    _mealsChannel = db
        .channel('trainer-meals-${widget.userId}')
        .onPostgresChanges(
          event:    PostgresChangeEvent.all,
          schema:   'public',
          table:    'meals',
          filter:   PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'user_id',
            value:  widget.userId,
          ),
          callback: (_) => ref.invalidate(
              trainerUserMealsProvider((userId: widget.userId, date: _date))),
        )
        .subscribe();

    _foodItemsChannel = db
        .channel('trainer-food-items-${widget.userId}')
        .onPostgresChanges(
          event:    PostgresChangeEvent.all,
          schema:   'public',
          table:    'food_items',
          callback: (_) => ref.invalidate(
              trainerUserMealsProvider((userId: widget.userId, date: _date))),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mealsChannel?.unsubscribe();
    _foodItemsChannel?.unsubscribe();
    super.dispose();
  }

  void _shiftDate(int days) {
    final next     = _date.add(Duration(days: days));
    final todayMid = DateTime.now();
    final today    = DateTime(todayMid.year, todayMid.month, todayMid.day);
    if (next.isAfter(today)) return;
    setState(() => _date = next);
  }

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final todayMid = DateTime(now.year, now.month, now.day);
    final isToday  = _date == todayMid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu),         text: 'Meals'),
            Tab(icon: Icon(Icons.bedtime_outlined),        text: 'Sleep'),
            Tab(icon: Icon(Icons.monitor_weight_outlined), text: 'Weight'),
            Tab(icon: Icon(Icons.fitness_center),          text: 'Training'),
          ],
        ),
      ),
      body: Column(
        children: [
          _DateNavigator(date: _date, isToday: isToday, onShift: _shiftDate),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MealsTab(userId: widget.userId, date: _date),
                _SleepTab(userId: widget.userId, date: _date),
                _WeightTab(userId: widget.userId, date: _date),
                _TrainingTab(userId: widget.userId, date: _date),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date navigator bar ────────────────────────────────────────────────────────

class _DateNavigator extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final void Function(int days) onShift;

  const _DateNavigator({
    required this.date,
    required this.isToday,
    required this.onShift,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onShift(-1),
        ),
        Text(
          isToday ? 'Today' : DateFormat('EEE, MMM d').format(date),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday ? null : () => onShift(1),
        ),
      ],
    );
  }
}

// ── Meals tab ─────────────────────────────────────────────────────────────────

class _MealsTab extends ConsumerWidget {
  final String   userId;
  final DateTime date;
  const _MealsTab({required this.userId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(
      trainerUserMealsProvider((userId: userId, date: date)),
    );

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(trainerUserMealsProvider((userId: userId, date: date))),
      child: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => ListView(children: [Center(child: Text('Error: $e'))]),
        data:    (meals) {
          if (meals.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text('No meals logged for this date.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: meals.length,
            itemBuilder: (context, i) =>
                _MealCard(meal: meals[i], userId: userId),
          );
        },
      ),
    );
  }
}

// ── Weight tab ────────────────────────────────────────────────────────────────

class _WeightTab extends ConsumerWidget {
  final String   userId;
  final DateTime date;
  const _WeightTab({required this.userId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trainerUserWeightProvider((userId: userId, date: date)));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(trainerUserWeightProvider((userId: userId, date: date))),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => ListView(children: [Center(child: Text('Error: $e'))]),
        data:    (entries) {
          if (entries.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text('No weight entries yet.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            );
          }

          final weights = entries.map((e) => e.weightKg).toList();
          final labels  = entries
              .map((e) => DateFormat('MMM d').format(e.date.toLocal()))
              .toList();
          final minKg  = weights.reduce(math.min);
          final maxKg  = weights.reduce(math.max);
          final first  = entries.first.weightKg;
          final last   = entries.last.weightKg;
          final change = last - first;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: _WeightChart(
                          weights: weights,
                          labels:  labels,
                          minKg:   minKg,
                          maxKg:   maxKg,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip('Oldest', '${first.toStringAsFixed(1)} kg'),
                          _StatChip('Latest', '${last.toStringAsFixed(1)} kg'),
                          _StatChip(
                            'Change',
                            change == 0
                                ? '0.0 kg'
                                : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                            color: change <= 0 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Weight chart (line chart with date labels) ────────────────────────────────

class _WeightChart extends StatelessWidget {
  final List<double> weights;
  final List<String> labels;
  final double       minKg;
  final double       maxKg;

  const _WeightChart({
    required this.weights,
    required this.labels,
    required this.minKg,
    required this.maxKg,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _WeightChartPainter(
        weights:    weights,
        labels:     labels,
        minKg:      minKg,
        maxKg:      maxKg,
        color:      color,
        labelStyle: Theme.of(context).textTheme.labelSmall!,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<double> weights;
  final List<String> labels;
  final double       minKg;
  final double       maxKg;
  final Color        color;
  final TextStyle    labelStyle;

  static const _bottomPad = 24.0;
  static const _topPad    = 20.0;
  static const _leftPad   =  4.0;

  _WeightChartPainter({
    required this.weights,
    required this.labels,
    required this.minKg,
    required this.maxKg,
    required this.color,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = weights.length;
    if (n == 0) return;

    final chartH = size.height - _topPad - _bottomPad;
    final range  = (maxKg - minKg).abs() < 0.1 ? 1.0 : maxKg - minKg;
    final step   = (size.width - _leftPad) / n;

    final gridPaint = Paint()
      ..color      = Colors.grey.shade200
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color      = color
      ..strokeWidth = 2
      ..strokeCap  = StrokeCap.round;
    final dotPaint = Paint()..color = color;

    // Grid lines
    for (var i = 0; i <= 4; i++) {
      final y = _topPad + chartH * (1 - i / 4);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width, y), gridPaint);
    }

    // Pixel positions for each entry
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = _leftPad + i * step + step / 2;
      final y = _topPad + chartH * (1 - (weights[i] - minKg) / range);
      pts.add(Offset(x, y));
    }

    // Connecting lines
    for (var k = 0; k < pts.length - 1; k++) {
      canvas.drawLine(pts[k], pts[k + 1], linePaint);
    }

    // Dots, weight labels above, date labels below
    for (var i = 0; i < n; i++) {
      final pt = pts[i];
      canvas.drawCircle(pt, 4, dotPaint);

      final valueTp = TextPainter(
        text: TextSpan(
          text:  weights[i].toStringAsFixed(1),
          style: labelStyle.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      valueTp.paint(
          canvas, Offset(pt.dx - valueTp.width / 2, pt.dy - valueTp.height - 4));

      final dateTp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      dateTp.paint(
          canvas, Offset(pt.dx - dateTp.width / 2, size.height - dateTp.height));
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.weights != weights || old.minKg != minKg || old.maxKg != maxKg;
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatChip(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey.shade500)),
        ],
      );
}

// ── Sleep tab ─────────────────────────────────────────────────────────────────

class _SleepTab extends ConsumerWidget {
  final String   userId;
  final DateTime date;
  const _SleepTab({required this.userId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      trainerUserSleepProvider((userId: userId, date: date)),
    );

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(trainerUserSleepProvider((userId: userId, date: date))),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => ListView(children: [Center(child: Text('Error: $e'))]),
        data:    (entry) {
          if (entry == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text('No sleep logged for this date.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        icon:  Icons.bedtime_outlined,
                        label: 'Bedtime',
                        value: entry.sleepTime ?? '—',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon:  Icons.wb_sunny_outlined,
                        label: 'Wake time',
                        value: entry.wakeTime ?? '—',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon:  Icons.timer_outlined,
                        label: 'Duration',
                        value: entry.durationLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Training tab ──────────────────────────────────────────────────────────────

class _TrainingTab extends ConsumerWidget {
  final String   userId;
  final DateTime date;
  const _TrainingTab({required this.userId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      trainerUserTrainingProvider((userId: userId, date: date)),
    );

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(trainerUserTrainingProvider((userId: userId, date: date))),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => ListView(children: [Center(child: Text('Error: $e'))]),
        data:    (entries) {
          if (entries.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text('No training logged for this date.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(e.type,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: (e.notes != null && e.notes!.isNotEmpty)
                      ? Text(e.notes!)
                      : null,
                  trailing: Text(e.durationLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Sleep info row helper ─────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Per-meal card with integrated comment ─────────────────────────────────────

class _MealCard extends ConsumerStatefulWidget {
  final Meal   meal;
  final String userId;

  const _MealCard({required this.meal, required this.userId});

  @override
  ConsumerState<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends ConsumerState<_MealCard> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(MealComment? existing) async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(commentServiceProvider).save(
        mealId: widget.meal.id!,
        body:   body,
      );
      ref.invalidate(trainerCommentProvider(widget.meal.id!));
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(int commentId) async {
    await ref.read(commentServiceProvider).delete(commentId);
    ref.invalidate(trainerCommentProvider(widget.meal.id!));
  }

  @override
  Widget build(BuildContext context) {
    final time         = DateFormat('HH:mm').format(widget.meal.date);
    final commentAsync = ref.watch(trainerCommentProvider(widget.meal.id!));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(widget.meal.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$time  ·  ${widget.meal.totalCalories.toStringAsFixed(0)} kcal'),
        children: [
          // ── Food items ──────────────────────────────────────
          ...widget.meal.foodItems.map((item) => ListTile(
                dense: true,
                title: Text(item.name),
                subtitle: Text(
                  '${item.grams.toStringAsFixed(0)}g  '
                  '| P ${item.protein.toStringAsFixed(1)}g  '
                  '| C ${item.carbs.toStringAsFixed(1)}g  '
                  '| F ${item.fat.toStringAsFixed(1)}g',
                ),
                trailing: Text(
                  '${item.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),

          const Divider(height: 1),

          // ── Trainer comment ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: commentAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (e, _) => Text('Error: $e'),
              data:    (comment) => _CommentSection(
                comment:    comment,
                controller: _ctrl,
                saving:     _saving,
                onSave:     () => _save(comment),
                onDelete:   comment != null ? () => _delete(comment.id!) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment section widget ────────────────────────────────────────────────────

class _CommentSection extends StatefulWidget {
  final MealComment?          comment;
  final TextEditingController controller;
  final bool                  saving;
  final VoidCallback          onSave;
  final VoidCallback?         onDelete;

  const _CommentSection({
    required this.comment,
    required this.controller,
    required this.saving,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<_CommentSection> {
  bool _editing = false;

  @override
  void didUpdateWidget(_CommentSection old) {
    super.didUpdateWidget(old);
    if (old.comment?.body != widget.comment?.body) {
      _editing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.comment;

    if (existing != null && !_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMM d, HH:mm').format(existing.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () {
                  widget.controller.text = existing.body;
                  setState(() => _editing = true);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18,
                    color: Colors.red),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          Text(existing.body),
        ],
      );
    }

    return Column(
      children: [
        TextField(
          controller: widget.controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: existing == null
                ? 'Add a comment for this meal…'
                : 'Edit your comment…',
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_editing)
              TextButton(
                onPressed: () => setState(() {
                  _editing = false;
                  widget.controller.clear();
                }),
                child: const Text('Cancel'),
              ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.saving ? null : widget.onSave,
              child: widget.saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(existing == null ? 'Post' : 'Update'),
            ),
          ],
        ),
      ],
    );
  }
}
