import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/trainer_provider.dart';

class TrainerScreen extends ConsumerWidget {
  const TrainerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(assignedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Athletes')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (users) {
          if (users.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No athletes assigned yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ask your admin to assign users to you.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(user.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'user-detail',
                  pathParameters: {'userId': user.id},
                  extra: user.displayName,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
