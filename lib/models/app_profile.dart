class AppProfile {
  final String id;
  final String displayName;
  final String role; // 'user' | 'trainer' | 'admin'

  const AppProfile({
    required this.id,
    required this.displayName,
    required this.role,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) => AppProfile(
        id:          map['id'] as String,
        displayName: map['display_name'] as String,
        role:        map['role'] as String,
      );

  bool get isTrainer => role == 'trainer';
  bool get isAdmin   => role == 'admin';
  bool get isUser    => role == 'user';
}
