# KcalTracker

A personal health & nutrition tracking app built with Flutter. Tracks calories, macronutrients, sleep, weight, training, and includes an LP-optimised meal planner.

## Features

### Nutrition Tracking
- Log meals with a time stamp
- Search a local food database (21 pre-seeded common foods)
- Search the **USDA FoodData Central** API for any food not in the local DB — results are saved automatically
- Input grams; the app calculates calories, protein, carbs, and fat from per-100g values
- Daily calorie summary with macro progress bars vs. your goals

### Food Database
- Browse, add, edit, and delete custom food definitions
- Per-100g nutritional values: calories, protein, carbs, fat

### Goals
- Set a daily calorie target
- Set macro split as percentages (protein / carbs / fat) — sliders auto-balance to 100%
- Live gram targets derived from kcal and percentages

### Meal Planner (LP Optimiser)
- Create a meal plan for any day with multiple named meals (Breakfast, Lunch, Dinner, Snack, etc.)
- Add foods with a min–max gram range per item
- **Optimise with LP Solver**: runs a Projected Gradient Descent QP solver (pure Dart, no packages) to find the exact gram amounts that best satisfy your calorie and macro goals
- View solved results per meal — optimal grams highlighted, macro breakdown shown
- Full plan history with a "jump to day" shortcut

### Sleep Tracker
- Log bedtime and wake-up time with a time picker
- Calculates sleep duration (handles midnight crossover)
- Recent 30-entry history

### Weight Tracker
- Log body weight in kg for any date (date picker)
- History list with delta chips (↑/↓ vs. previous entry)

### Training Tracker
- Log workouts by type: Gym, Tennis, Running, Cycling, Swimming, Walking, Yoga, Other
- Record duration, time of day, and optional notes
- Emoji-coded entries; long-press to delete

## Tech Stack

| Concern | Library |
|---|---|
| Framework | Flutter 3 / Dart 3 |
| State management | flutter_riverpod 2 (AsyncNotifier) |
| Navigation | go_router (ShellRoute for tab nav) |
| Local database | sqflite (versioned migrations, v4) |
| Preferences | shared_preferences |
| Food API | USDA FoodData Central REST API |
| HTTP | http package |
| LP solver | Custom Projected Gradient Descent (pure Dart) |

## Project Structure

```
lib/
  models/          # Data classes (FoodDefinition, Meal, SleepEntry, WeightEntry, TrainingEntry, MealPlan, PlanItem, Goals)
  database/        # DatabaseHelper singleton, migrations, CRUD
  providers/       # Riverpod providers for all features
  services/        # USDA API client, LP solver, secrets
  screens/         # One file per screen
  widgets/         # CalorieSummary widget
  router/          # GoRouter configuration
```

## Setup

### Prerequisites
- Flutter SDK (3.x)
- Android Studio / Xcode for emulator or device

### USDA API Key
The app uses the USDA FoodData Central API for online food search. Create a free key at [fdc.nal.usda.gov](https://fdc.nal.usda.gov/api-guide.html), then:

```bash
cp lib/services/secrets.dart.example lib/services/secrets.dart
# Edit secrets.dart and paste your API key
```

`secrets.dart` is gitignored and must be created locally on each machine.

### Run

```bash
flutter pub get
flutter run
```

For iOS, also run `cd ios && pod install` before the first build, and configure code signing in Xcode (`ios/Runner.xcworkspace`).
