import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  DateTime _date = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();

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

    final mealsAsync = ref.watch(
      trainerUserMealsProvider((userId: widget.userId, date: _date)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftDate(-1),
              ),
              Text(
                isToday ? 'Today' : DateFormat('EEE, MMM d').format(_date),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday ? null : () => _shiftDate(1),
              ),
            ],
          ),
        ),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (meals) {
          if (meals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No meals logged for this date.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: meals.length,
            itemBuilder: (context, i) =>
                _MealCard(meal: meals[i], userId: widget.userId),
          );
        },
      ),
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
