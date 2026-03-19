# KcalTracker — Project Context for Claude

## What This App Is
A Flutter calorie tracking app targeting Android (primary). Users log meals, track weight/sleep/training, set macro goals, and generate meal plans. The food database is seeded from the Serbian nutrition database at tablicakalorija.com.

## Tech Stack
- **Flutter** with **Riverpod** (riverpod_generator + build_runner for code generation)
- **sqflite** for local SQLite storage
- **go_router** for navigation
- **http** for API calls (OpenFoodFacts or similar)
- **shared_preferences** for user settings

## Project Structure
```
lib/
  main.dart                        # Entry point, ProviderScope + MaterialApp.router
  router/app_router.dart           # GoRouter config
  database/database_helper.dart    # Singleton SQLite helper, all DB logic
  models/                          # Plain Dart models (food_definition, meal, etc.)
  providers/                       # Riverpod providers (generated + manual)
  screens/                         # One file per screen
  services/                        # meal_plan_solver.dart, food_api_service.dart
  widgets/                         # Shared widgets (calorie_summary, etc.)
```

## Database
- File: `lib/database/database_helper.dart`
- Singleton pattern: `DatabaseHelper.instance`
- Current schema version: **5**
- Migration logic in `_onUpgrade` — each `if (oldVersion < N)` block runs the corresponding migration
- `_seedSerbianFoods(db)` is called on fresh install (`_onCreate`) and on upgrade from v<5

### food_definitions table
Columns: `id, name, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g`

### Seeded food data
- **1362 foods** sourced from tablicakalorija.com (all 69 pages)
- Stored as Dart record tuples: `('Name', kcal, protein, carbs, fat)`
- Apostrophes in names are escaped as `\'`
- Serbian UTF-8 characters (č, ć, š, đ, ž) are stored as-is

## Incrementing the DB Version
When food data or schema changes, bump `version:` in `_initDb()` and add a migration block in `_onUpgrade`. For food-only re-seeds targeting existing users, add:
```dart
if (oldVersion < 6) {
  await _seedSerbianFoods(db);
}
```

## Re-Scraping Food Data
If the food list needs updating, scrape tablicakalorija.com with Python+curl:
- Pagination URL: `https://www.tablicakalorija.com/?paged=N` (69 pages, N=1..69)
- HTML table column order: `DK | Name | kCal | UH(carbs) | Proteini(protein) | Masti(fat)`
- Dart tuple order: `(name, kcal, protein, carbs, fat)` — note protein and carbs are swapped vs HTML
- Collapse whitespace in names: `' '.join(name.split())`
- Sleep 0.3s between requests to avoid rate limiting
- Site rate limit resets at 6am Europe/Belgrade

Example scraper snippet:
```python
import subprocess, re, time

food_rows = []
for page in range(1, 70):
    r = subprocess.check_output(['curl', '-s', f'https://www.tablicakalorija.com/?paged={page}'], text=True, encoding='utf-8')
    for row in re.findall(r'<tr[^>]*>(.*?)</tr>', r, re.DOTALL):
        cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
        if len(cells) < 6:
            continue
        cleaned = [re.sub(r'<[^>]+>', '', c).strip() for c in cells]
        name = ' '.join(cleaned[1].split())
        kcal, carbs, protein, fat = cleaned[2], cleaned[3], cleaned[4], cleaned[5]
        nd = name.replace('\\', '\\\\').replace("'", "\\'")
        food_rows.append(f"      ('{nd}', {kcal}, {protein}, {carbs}, {fat}),")
    time.sleep(0.3)
```

To replace the food list in `database_helper.dart`, find the block between:
- Start: `    final foods = [\n`
- End: `\n    ];\n    final batch = db.batch();`

## Common Commands
```bash
flutter analyze          # Lint check — must pass before considering work done
flutter pub get          # Install dependencies
dart run build_runner build --delete-conflicting-outputs  # Regenerate Riverpod providers
flutter run              # Run on connected device/emulator
```

## State Management Pattern
Riverpod with code generation. Providers live in `lib/providers/`. After adding or modifying a `@riverpod` annotated file, run `build_runner` to regenerate the `.g.dart` file.
