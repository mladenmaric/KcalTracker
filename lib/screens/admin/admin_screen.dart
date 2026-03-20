import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_profile.dart';
import '../../providers/admin_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (users) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(allUsersProvider),
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    u.user.displayName.isNotEmpty
                        ? u.user.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(u.user.displayName),
                subtitle: u.trainer != null
                    ? Text('Trainer: ${u.trainer!.displayName}')
                    : null,
                trailing: _RoleChip(role: u.user.role),
                onTap: () => _showManageDialog(context, ref, u, users),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showManageDialog(
    BuildContext context,
    WidgetRef ref,
    UserWithTrainer target,
    List<UserWithTrainer> allUsers,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ManageUserDialog(
        target:   target,
        allUsers: allUsers,
        onSaved:  () => ref.invalidate(allUsersProvider),
      ),
    );
  }
}

// ── Role chip ────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'admin'   => Colors.red,
      'trainer' => Colors.orange,
      _         => Colors.blue,
    };
    return Chip(
      label: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

// ── Manage user dialog ───────────────────────────────────────────────────────

class _ManageUserDialog extends ConsumerStatefulWidget {
  final UserWithTrainer       target;
  final List<UserWithTrainer> allUsers;
  final VoidCallback          onSaved;

  const _ManageUserDialog({
    required this.target,
    required this.allUsers,
    required this.onSaved,
  });

  @override
  ConsumerState<_ManageUserDialog> createState() => _ManageUserDialogState();
}

class _ManageUserDialogState extends ConsumerState<_ManageUserDialog> {
  late String _role;
  AppProfile? _selectedTrainer;
  bool        _saving = false;
  String?     _error;

  @override
  void initState() {
    super.initState();
    _role            = widget.target.user.role;
    _selectedTrainer = widget.target.trainer;
  }

  List<AppProfile> get _trainers => widget.allUsers
      .where((u) => u.user.isTrainer)
      .map((u) => u.user)
      .toList();

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final svc = ref.read(adminServiceProvider);
    try {
      // Update role if changed.
      if (_role != widget.target.user.role) {
        await svc.setRole(widget.target.user.id, _role);
      }

      // Update trainer assignment if changed.
      final oldTrainerId = widget.target.trainer?.id;
      final newTrainerId = _selectedTrainer?.id;

      if (oldTrainerId != newTrainerId) {
        if (oldTrainerId != null) {
          await svc.removeTrainer(oldTrainerId, widget.target.user.id);
        }
        if (newTrainerId != null) {
          await svc.assignTrainer(newTrainerId, widget.target.user.id);
        }
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.target.user.displayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Role picker ──────────────────────────────────────────
          const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'user',    label: Text('User')),
              ButtonSegment(value: 'trainer', label: Text('Trainer')),
              ButtonSegment(value: 'admin',   label: Text('Admin')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 16),

          // ── Trainer assignment (optional for any role) ────────────
          ...[
            const Text('Trainer', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButton<AppProfile?>(
              isExpanded: true,
              value: _selectedTrainer,
              hint: const Text('None'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ..._trainers
                    .where((t) => t.id != widget.target.user.id)
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))),
              ],
              onChanged: (t) => setState(() => _selectedTrainer = t),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
