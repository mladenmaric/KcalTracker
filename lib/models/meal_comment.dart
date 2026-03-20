class MealComment {
  final int?     id;
  final int      mealId;
  final String   trainerId;
  final String?  trainerName; // joined from profiles, nullable
  final String   body;
  final DateTime createdAt;

  const MealComment({
    this.id,
    required this.mealId,
    required this.trainerId,
    this.trainerName,
    required this.body,
    required this.createdAt,
  });

  factory MealComment.fromMap(Map<String, dynamic> m) => MealComment(
        id:          (m['id'] as num?)?.toInt(),
        mealId:      (m['meal_id'] as num).toInt(),
        trainerId:   m['trainer_id']   as String,
        trainerName: m['trainer_name'] as String?,
        body:        m['body']         as String,
        createdAt:   DateTime.parse(m['created_at'] as String),
      );
}
