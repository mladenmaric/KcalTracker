import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_profile.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('profiles')
          .update({'display_name': name})
          .eq('id', uid);
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final trainerAsync = ref.watch(myTrainerProvider);
    final cs           = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          // Pre-fill once.
          if (!_initialized) {
            _nameCtrl.text = profile.displayName;
            _initialized   = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [

              // ── Avatar ───────────────────────────────────────
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: _RoleChip(role: profile.role)),
              const SizedBox(height: 36),

              // ── Display name ─────────────────────────────────
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),

              const SizedBox(height: 36),
              const Divider(),
              const SizedBox(height: 24),

              // ── Trainer section ──────────────────────────────
              Text('Your Trainer',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              trainerAsync.when(
                loading: () => const LinearProgressIndicator(),
                error:   (e, _) => Text('Error: $e'),
                data: (trainer) => trainer == null
                    ? Text(
                        'No trainer assigned.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    : _TrainerCard(trainer: trainer),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────

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
      label: Text(
        role[0].toUpperCase() + role.substring(1),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

// ── Trainer card ──────────────────────────────────────────────────────────────

class _TrainerCard extends StatelessWidget {
  final AppProfile trainer;
  const _TrainerCard({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.secondary,
            child: Text(
              trainer.displayName.isNotEmpty
                  ? trainer.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trainer.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Your trainer',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
