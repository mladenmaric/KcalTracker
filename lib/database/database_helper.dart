import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_definition.dart';
import '../models/food_item.dart';
import '../models/meal.dart';
import '../models/meal_plan.dart';
import '../models/plan_item.dart';
import '../models/sleep_entry.dart';
import '../models/training_entry.dart';
import '../models/weight_entry.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kcal_tracker.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createFoodTables(db);
    await _createTrackingTables(db);
    await _createPlannerTables(db);
    await _seedSerbianFoods(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS food_items');
      await _createFoodTables(db);
    }
    if (oldVersion < 3) {
      await _createTrackingTables(db);
    }
    if (oldVersion < 4) {
      await _createPlannerTables(db);
    }
    if (oldVersion < 5) {
      await _seedSerbianFoods(db);
    }
  }

  Future<void> _createPlannerTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_plans (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        date             TEXT    NOT NULL,
        name             TEXT    NOT NULL,
        goal_kcal        REAL    NOT NULL,
        protein_goal_g   REAL    NOT NULL,
        carbs_goal_g     REAL    NOT NULL,
        fat_goal_g       REAL    NOT NULL,
        is_solved        INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_items (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id              INTEGER NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
        meal_name            TEXT    NOT NULL,
        food_definition_id   INTEGER NOT NULL,
        food_name            TEXT    NOT NULL,
        min_grams            REAL    NOT NULL,
        max_grams            REAL    NOT NULL,
        optimal_grams        REAL,
        calories_per_100g    REAL    NOT NULL,
        protein_per_100g     REAL    NOT NULL,
        carbs_per_100g       REAL    NOT NULL,
        fat_per_100g         REAL    NOT NULL
      )
    ''');
  }

  Future<void> _createFoodTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_definitions (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT    NOT NULL,
        calories_per_100g REAL    NOT NULL,
        protein_per_100g  REAL    NOT NULL,
        carbs_per_100g    REAL    NOT NULL,
        fat_per_100g      REAL    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meals (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        date  TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_items (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id              INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
        food_definition_id   INTEGER NOT NULL REFERENCES food_definitions(id),
        name                 TEXT    NOT NULL,
        grams                REAL    NOT NULL,
        calories             REAL    NOT NULL,
        protein              REAL    NOT NULL,
        carbs                REAL    NOT NULL,
        fat                  REAL    NOT NULL
      )
    ''');
  }

  Future<void> _createTrackingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sleep_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL UNIQUE,
        sleep_time  TEXT,
        wake_time   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_entries (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        date       TEXT    NOT NULL,
        weight_kg  REAL    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_entries (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        date              TEXT    NOT NULL,
        type              TEXT    NOT NULL,
        duration_minutes  INTEGER NOT NULL,
        notes             TEXT
      )
    ''');
  }

  // ── Seed data ─────────────────────────────────────────────────────────────────────────────────

  Future<void> _seedSerbianFoods(Database db) async {
    final foods = [
      ('100% Ovseni hrskavi hleb sa golicom, Deus Crispbreads', 420, 14, 71, 9),
      ('100% Whey Gold Standard Protein, Optimum Nutrition', 372, 78.62, 5.92, 3.62),
      ('100% Whey Protein fuel, Twinlab', 393, 75.75, 12.12, 4.55),
      ('100% Whey Protein, okus Čokolada, Scitec Nutrition', 376, 70, 8.1, 6.5),
      ('100% Whey Protein, Professional, okus bijela čokolada (White Chocolate), Scitec Nutrition', 380, 72, 8.4, 6.2),
      ('100% Whey Protein, Professional, okus Chocolate Coconut, Scitec Nutrition', 380, 73, 8.1, 5.9),
      ('100% Whey Protein, Professional, okus Chocolate Cookies & Cream Flavored, Scitec Nutrition', 382, 74, 8, 5.8),
      ('100% Whey Protein, Professional, okus Čokolada, Scitec Nutrition', 382, 73, 8.4, 5.9),
      ('100% Whey Protein, Professional, okus Strawberry White Chocolate, Scitec Nutrition', 380, 72, 9.2, 5.6),
      ('100% Whey Protein, Professional, okus Vanila, Scitec Nutrition', 380, 73, 9.4, 5.6),
      ('100% Whey Protein, Professional, Scitec Nutrition', 371, 73, 4.7, 6.7),
      ('ABC supa (juha), dehidrirana (u kesici), Maggi', 317, 10.2, 61.1, 2.8),
      ('ABC svježi krem sir, namaz, Belje', 241, 6.5, 3, 22.5),
      ('ABC svježi krem sir, namaz, vlasac, Belje', 222, 5.7, 2.5, 21),
      ('Acerola', 32, 0.4, 7.69, 0.3),
      ('Agar Agar u prahu, Domestic', 26, 0.5, 7, 0),
      ('Agavin sirup (sirup od agave), zaslađivač', 310, 0.09, 76.37, 0.45),
      ('Ajvar, blagi, Vitaminka', 168, 2, 11.7, 12.5),
      ('Ajvar, hajvar, blagi/ljuti', 78, 1.5, 11, 4),
      ('Ajvar, hajvar, uprženi, blagi/ljuti', 99, 1.5, 13, 5.3),
      ('Amarant', 371, 13.56, 62.25, 7.02),
      ('Amino Whey Hydro Protein, The Nutrition', 395, 85.6, 3.9, 4.2),
      ('Ananas', 50, 0.54, 13.12, 0.12),
      ('Anis (aniš) sjeme (seme)', 337, 17.6, 50.02, 15.9),
      ('Aronija', 47, 1.4, 9.6, 0.5),
      ('Artičoka', 47, 3.27, 10.51, 0.15),
      ('asap Protein Cookie, Banana, Gym Beam', 368, 29.1, 34.3, 16.3),
      ('Avokado', 160, 2, 8.53, 14.66),
      ('Badem', 579, 21.15, 21.55, 49.93),
      ('Badem (suvi, prženi, bez soli)', 597, 22.26, 19.44, 53),
      ('Badem (suvi, prženi, posoljeni)', 597, 22.26, 19.44, 53),
      ('Badem, blanširani', 581, 21.9, 19.9, 50.6),
      ('Badem, prženi, slani, Berny', 597, 22.1, 19.3, 52.8),
      ('Bademovo mlijeko (mleko)', 15, 0.59, 0.58, 1.1),
      ('Bademovo mlijeko (mleko), Alpro', 24, 0.5, 3, 1.1),
      ('Bademovo mlijeko (mleko), okus čokolada', 50, 0.63, 9.38, 1.25),
      ('Bademovo mlijeko (mleko), okus vanilija, sa šećerom', 38, 0.42, 6.59, 1.04),
      ('Bademovo mlijeko, 0% šećer, Joya', 14, 0.4, 0.1, 1.2),
      ('Bakalar', 86, 19.3, 0, 0.9),
      ('Bakalar (suvi, sušeni)', 290, 63, 0, 2.37),
      ('Bakalar fileti', 118, 18, 0, 5.13),
      ('Baklava', 304.9, 3.7, 41, 13.8),
      ('Balans + Protein čoko šejk, Imlek', 70, 6, 9.3, 1),
      ('Banana', 89, 1.09, 22.84, 0.33),
      ('Batat (slatki krompir)', 86, 1.57, 20.12, 0.05),
      ('Battery Whey Protein', 387, 70, 12.3, 6.3),
      ('Biber crni, mljeveni', 251, 10.39, 63.95, 3.26),
      ('Biskvit (biscuits) Nutella, Ferrero', 511, 7.9, 63.3, 24.6),
      ('Biskvit čokoladni (choc & choc biscuit), Milka', 454, 5.6, 58, 22),
      ('Bjelance (belance), kokošje', 52, 10.9, 0.73, 0.17),
      ('Black Forest, Mix (kupina, višnja, borovnica, crna ribizla), Volim, Tropic', 42, 0.9, 8.2, 0.1),
      ('Blitva', 19, 1.8, 3.74, 0.2),
      ('Blitva, kuvana (barena)', 20, 1.88, 4.13, 0.08),
      ('Bob mahune', 88, 7.92, 17.63, 0.73),
      ('Bob sjemenke', 341, 26.12, 58.29, 1.53),
      ('Bok Čoj (kinesko zelje, bok choy)', 13, 1.5, 2.2, 0.2),
      ('Bomboni karamele', 382, 4.6, 77, 8.1),
      ('Bomboni pjenasti (Marshmallow), Bebeto', 327, 4.5, 77, 0),
      ('Bomboni tvrdi (obični)', 394, 0, 98, 0.2),
      ('Bomboni, gumeni, Malaco', 349, 0, 85, 0.3),
      ('Bombonjera, Paradis, Marabou', 530, 4.1, 58, 31),
      ('Bombonjera, Toffifee, STORCK', 522, 6, 59, 28.8),
      ('Borovnice', 57, 0.74, 14.49, 0.33),
      ('Bosiljak list, suvi (sušen)', 233, 22.98, 47.75, 4.07),
      ('Bosiljak list, svjež', 23, 3.15, 2.65, 0.64),
      ('Brašno od kokosa (kokosovo brašno), dmBio', 361, 20, 20, 15),
      ('Brašno, krumpirovo', 357, 6.9, 83.1, 0.34),
      ('Brašno, kukuruzno, cjelovito, žuto ili bijelo', 361, 6.93, 76.85, 3.86),
      ('Brašno, ovseno (zobeno), integralno, Vega', 348, 13.25, 65.7, 3.65),
      ('Brašno, sojino', 434, 37.81, 31.92, 20.65),
      ('Breskva', 39, 0.91, 9.54, 0.25),
      ('Breskva, sušena (suva)', 239, 3.61, 61.33, 0.76),
      ('Brokoli (brokula)', 34, 2.82, 6.64, 0.37),
      ('Brokoli (brokula) kuvana', 35, 2.38, 7.18, 0.41),
      ('Brown Rice Bar, Zero sugar, milk chocolate', 439, 8.6, 53, 20),
      ('Bruschette chips, fine cheese selection, Maretti', 447, 8.8, 70, 14),
      ('Bruschette chips, mediterranean vegetables, Maretti', 453, 9.1, 71, 14),
      ('Brusnica, suva (sušena)', 308, 0.17, 82.8, 1.09),
      ('Brusnice', 46, 0.39, 12.2, 0.13),
      ('Bubrezi goveđi', 99, 17.4, 0.29, 3.09),
      ('Bubrezi janjeći', 97, 15.74, 0.82, 2.95),
      ('Bubrezi svinjski', 100, 16.46, 0, 3.25),
      ('Bukovače, gljive (pečurke)', 33, 3.31, 6.09, 0.41),
      ('Bulgur', 342, 12.29, 75.87, 1.33),
      ('Bulgur, kuvani', 83, 3.08, 18.58, 0.24),
      ('Bundeva (tikva, dulek, buča, ludaja)', 26, 1, 6.5, 0.1),
      ('Bundeva (tikva, dulek, buča, ludaja) pulpa, kuvana, ocijeđena, soljena', 18, 0.72, 4.31, 0.07),
      ('Bundeva (tikva, dulek, buča, ludaja), pečena', 46, 1.08, 7.94, 1.75),
      ('Bundeva (tikva, dulek, buča, ludaja), pulpa, kuvana, ocjeđena, bez soli', 20, 0.72, 4.9, 0.07),
      ('Burek', 375, 8, 27.5, 25),
      ('Caffe Freddo, Espresso, Movenpick Of Switzerland', 69, 3.7, 10.1, 1.5),
      ('Caffe Latte, Cappuccino, Imlek', 64, 3, 11, 1.2),
      ('Caffe Latte, Macchiato, Imlek', 81, 3, 10.5, 3),
      ('Čaj kuvan (kuhan)', 1, 0.06, 0.17, 0),
      ('Čaj, crni', 0, 0, 0, 0),
      ('Čaj, zeleni', 1, 0.22, 0, 0),
      ('Čajna kobasica, Zlatiborac', 454.5, 23.2, 0.2, 40.1),
      ('Čajni kolutići, Tea Rings, Kraš', 468, 6, 75, 16),
      ('Cappuccino (kapućino) original, Nescafe', 389, 9.7, 69.6, 7),
      ('Cappuccino (kapućino), čokolada, Nescafe', 396, 8.6, 69.7, 8.2),
      ('Cappuccino Irish Cream, Franck', 443, 7, 76, 12),
      ('Cappuccino Vanilla Cream, Franck', 441, 6.8, 75, 13),
      ('Carska mješavina, smrznuto mješano povrće, Frikom', 11, 1.3, 0.4, 0.2),
      ('Carska mješavina, smrznuto mješano povrće, Ledo', 32, 2, 4, 0.5),
      ('Čedar (Cheddar) sir', 404, 22.87, 3.09, 33.31),
      ('Cedevita, narandža', 365, 0, 84, 0),
      ('Celer', 16, 0.69, 2.97, 0.17),
      ('Ćevapi (bez lepinje - goveđe/juneće meso), svježi (sirovi)', 230, 19.28, 3.72, 15.45),
      ('Ćevapi (bez lepinje - svinjsko/goveđe meso), svježi (sirovi)', 263, 17.88, 3.72, 19.75),
      ('Ćevapi u lepinji (roštilj), porcija od 390 grama', 924, 49.3, 85.6, 42),
      ('Chocolate Crisp Balls, creamy milk filling, Favorina, LIDL', 539, 6.8, 57.5, 31.1),
      ('Čia (chia) sjemenke', 486, 16.54, 42.12, 30.74),
      ('Čičoka', 73, 2, 17.44, 0.01),
      ('Čili Bili (Chili Billy), Berny', 514, 12.3, 40.6, 32.6),
      ('Cimet', 247, 3.99, 80.59, 1.24),
      ('Cipal', 117, 19.35, 0, 3.79),
      ('Čips od krompira (krumpira), obični, slani', 532, 6.39, 53.83, 33.98),
      ('Čips od riže (pirinča), Ekozona, bio&bio', 381, 4.67, 83.6, 3),
      ('Coca cola', 44, 0, 12, 0),
      ('Coca cola zero', 0, 0, 0, 0),
      ('Čokolada', 512, 5, 51, 32),
      ('Čokolada bijela, Milka', 534, 4.2, 65, 28),
      ('Čokolada Merci', 563, 7.8, 49.9, 36.1),
      ('Čokolada Mikado, 72% kakao, sa punjenjem od borovnice, Zvečevo', 502, 6.5, 39.4, 35.4),
      ('Čokolada Mikado, 72% kakao, Zvečevo', 596, 9.8, 46.9, 41),
      ('Čokolada mliječna s lješnjacima, (Alpine Milk with Hazelnuts) Schogetten', 567, 6.5, 53, 36),
      ('Čokolada mliječna sa keksom, Najljepše želje, Štark', 535, 9, 55, 31),
      ('Čokolada mliječna sa lješnjacima, Pionir', 550, 7.5, 53.1, 33.5),
      ('Čokolada mliječna, (Alpine Milk) Schogetten', 551, 5.5, 57, 33),
      ('Čokolada mliječna, Heidi', 541, 5.7, 57, 32),
      ('Čokolada mliječna, Kinder', 566, 8.7, 53.5, 35),
      ('Čokolada mliječna, Najljepše želje, Štark', 540, 9, 54, 32),
      ('Čokolada MMMAX, Choco & Biscuit, Milka', 562, 4.9, 56, 35),
      ('Čokolada s lešnjacima', 610, 12, 28, 50),
      ('Čokolada sa lješnjacima, Milka', 563, 8.2, 47, 37),
      ('Čokolada tamna, (Dark chocolate) Schogetten', 529, 6.8, 52, 31),
      ('Čokolada tamna, 72% kakao, Sarotti', 551, 9, 30, 41),
      ('Čokolada tamna, 74% kakao, Bellarom', 570, 9.8, 32, 42),
      ('Čokolada tamna, 74% kakao, fin Carre', 571, 9.9, 32, 42),
      ('Čokolada tamna, 75% kakao, Najljepše Želje, Štark', 552, 10, 33, 40),
      ('Čokolada tamna, 75% kakao, okus višnja, Najljepše Želje, Štark', 547, 11, 33, 39),
      ('Čokolada tamna, 85% kakao, Lindt excellence', 575, 12.5, 37.5, 45),
      ('Čokolada tamna, 85% kakao, Sarotti', 597, 9.7, 16, 51),
      ('Čokolada tamna, 85% kakao, The Belgian', 588, 9.7, 16.9, 49.9),
      ('Čokolada tamna, 99% kakao, Lindt Excellence', 590, 15, 8, 51),
      ('Čokolada tamna, Extreme, 85% kakao, Heidi', 603, 9.3, 16, 52),
      ('Čokolada tamna, Mild, cocoa 50% kakao, Heidi', 530, 4.9, 50, 32),
      ('Čokolada za jelo i kuvanje, 47% kakaa, La Bomba', 521, 5.5, 56, 29),
      ('Čokolada, Blanc, Nestle', 559, 8.2, 54.5, 34.2),
      ('Čokolada, Noir, 52% kakao, Nestle', 553, 5.9, 50, 35),
      ('Čokolada, Noir Corse, 65% kakao, Nestle', 544, 7.2, 41, 38),
      ('Čokolada, bijela za kuvanje', 560, 4.5, 59, 34),
      ('Čokolada, Jagoda & jogurt, Najljepše želje, Štark', 544, 8.8, 53, 33),
      ('Čokolada, karamela, DELICADORE, Baron', 483, 5.1, 59, 25),
      ('Čokolada, Mersi', 563, 7.8, 49.9, 36.1),
      ('Čokolada, mliječna s alpskim mlijekom, Milka (Milka Alpine Milk)', 530, 6.3, 59, 29),
      ('Čokolada, mliječna s oreom, Milka (Milka Oreo Brownie)', 548, 6.4, 51, 34),
      ('Čokolada, mliječna sa karamelom i lješnjacima, Milka (Milka Toffee wholenut)', 553, 5.9, 52, 35),
      ('Čokolada, mliječna sa krem sirom i jagodama, Milka (Milka Strawberry Cheesecake)', 528, 5.4, 59, 29),
      ('Čokolada, mliječna, Almond Caramel, Milka', 549, 5.8, 52, 34),
      ('Čokolada, mliječna, punjena kremom obranog mlijeka i jogurta sa okusom jagoda, Milka (Milka Strawberry)', 552, 4.6, 57, 34),
      ('Čokolada, s jagodama (strawberry), Milka', 560, 4, 57, 35),
      ('Čokolada, tamna (crna), 80% kakao, Galeb Premium, Pionir', 558, 11.2, 31.6, 40.6),
      ('Čokolada, traube-nuss, Finn Carre', 499, 6.4, 56.7, 26.7),
      ('Čokoladica proteinska, ESN Designer, Protein bar, Kikiriki/karamel okus', 409, 31, 33, 19),
      ('Čokoladica, bananica čokoladna, Štark', 371, 1.5, 74.2, 7.6),
      ('Čokoladica, Cipiripi', 536, 5.7, 59, 30.3),
      ('Čokoladica, Eurocrem Blok, SL Takovo', 540, 6.5, 62, 29),
      ('Čokoladica, Kinder Bueno', 572, 8.6, 49.5, 37.3),
      ('Čokoladica, okus čoko-banana, Corny Big', 424, 4.9, 67.8, 13.8),
      ('Čokoladica, proteinska (okus čokolada), Oatein Flapjack', 413, 24.9, 50.3, 11.5),
      ('Čokoladica, proteinska, Choco Banana, fitspo', 358, 33, 38, 14),
      ('Čokoladica, proteinska, Choco Brownie, fitspo', 395, 40, 17.5, 18.8),
      ('Čokoladica, proteinska, Cocoa & Chocolate, Go On', 418, 20, 42, 18),
      ('Čokoladica, proteinska, Crunchy Chocolate Brownie, fitspo', 412, 33.4, 35, 16.5),
      ('Čokoladica, proteinska, Kakao (High Cocoa), Go On', 409, 32, 33, 15),
      ('Čokoladica, proteinska, Kokos (coconut), fitspo', 377, 33, 38.4, 16),
      ('Čokoladica, proteinska, Peanut & Chocolate, Go On', 430, 20, 41, 20),
      ('Čokoladica, proteinska, Triple Chocolate Protein, fitspo', 363, 36, 28.5, 13.4),
      ('Čokoladica, proteinska, Vanilija i Čokolada (Vanilla & Chocolate), Go On', 420, 20, 43, 18),
      ('Čokoladni bomboni', 490, 5, 68, 22),
      ('Čokoladni bomboni s likerom', 400, 3, 42, 19),
      ('Čokoladni lješnjak, Gameha', 584, 15.7, 27.62, 45.62),
      ('Čokoladni namaz (stevia), s pistacijom, Stevia Lane', 506, 5.2, 48.7, 37.6),
      ('Čokoladni tartufi (cocoa dusted truffles), Belgid\'Or', 599, 4.2, 41, 45),
      ('Čokoladno mlijeko (mleko) 1% mm, Moja Kravica, Imlek', 62, 3.3, 10, 1),
      ('Čokoladno mlijeko (mleko), Dukat', 63, 2.3, 10.7, 1.1),
      ('Čokoladno mlijeko (mleko), punomasno', 92, 3, 10, 4),
      ('Čokolino, Whey Protein Power, Podravka', 382, 25, 59, 3.5),
      ('Compact Whey, Gold, Puregold', 399, 78, 12, 4.2),
      ('Complete Whey Protein, Optimum Nutrition', 358, 59.5, 19, 4),
      ('Čvarci', 726, 32, 1.5, 66),
      ('Cvekla (cikla)', 43, 1.61, 9.56, 0.17),
      ('Cvekla (cikla), kuvana, konzervisana', 32, 1.1, 7, 0.1),
      ('Dagnje', 86, 11.9, 3.69, 2.24),
      ('Dagnje kuvane', 172, 23.8, 7.39, 4.48),
      ('Datulja (datula, urma)', 142, 2.6, 36.6, 0.6),
      ('Datulja (datula, urma) sušena (suva, suha)', 282, 2.45, 75.03, 0.39),
      ('Datulja (datula, urma), Medjoul, Avgerinos', 290, 2.7, 69.8, 0.5),
      ('Dekstroza, D-glukoza, grožđani šećer', 375, 0, 100, 0),
      ('Dimljena pureća šunka, Ovako', 96, 19, 0.5, 2),
      ('Dimljeni kare (meso suvo, sušeno)', 121, 15, 1, 6),
      ('Dimljeni svinjski vrat, Pavić', 164, 15, 2.2, 10.5),
      ('Dinja', 34, 0.84, 8.16, 0.19),
      ('Divka, Franck', 367, 9.8, 74.3, 1.8),
      ('Divljač, zečetina, (zec, kunić)', 114, 21.79, 0, 2.32),
      ('Dobra ovsena (zobena) kaša, oskus čokolada, Mogador s.r.o.', 428, 6.8, 66, 14),
      ('Dobra ovsena (zobena) kaša, oskus jabuka i cimet, Mogador s.r.o.', 425, 6.3, 68, 13),
      ('Dobra Zobena (ovsena) kaša, šumsko voće, mogador', 413, 8, 65, 12),
      ('Domaće kore za pite, Fantasy', 263.96, 8.6, 55.1, 0.3),
      ('Domaći ajvar, ljuti, Mama\'s', 170, 3.5, 13.41, 15.16),
      ('Domaći ajvar, ljuti, Vitaminka', 123, 1.4, 14, 6.8),
      ('Dresing (preliv za salatu) sa jogurtom, Kuhne', 200, 2.1, 11, 16),
      ('Dresing (preliv za salatu) sa začinskim biljem, Kuhne', 25, 0.1, 5.2, 0.1),
      ('Dud (murva)', 43, 1.44, 9.8, 0.39),
      ('Dunja', 57, 0.4, 15.3, 0.1),
      ('Duo Mix, indijski orašćić/brusnica, Euro Company', 418, 5.8, 63.7, 16.6),
      ('Dvopek, Bake Rolls, oskus paradajz, maslina i origano, 7 Days', 449, 14, 63, 15),
      ('Dvopek, bijelo brašno, Mulino Bianco', 392, 11.5, 72, 5),
      ('Dvopek, Granetti Classici, Mulino Bianco', 420, 10, 69.9, 10),
      ('Dvopek, integralni, Mulino Bianco', 391, 12, 67.7, 6),
      ('Džem domaći, (bez šećera) šumsko voće', 71, 1.3, 16.4, 0.5),
      ('Džem od jagoda, 30% manje šećera, Podravka', 181, 0.3, 45, 0),
      ('Džin (Gin)', 263, 0, 0, 0),
      ('Đumbir korjen (koren)', 80, 1.82, 17.77, 0.75),
      ('Edamer sir', 357, 24.99, 1.43, 27.8),
      ('Elite Whey Protein, Dymatize Nutrition', 368, 77.42, 6.5, 4.84),
      ('Ementaler sir', 397, 29, 0, 31.4),
      ('Energetska pločica, granola bar, okus oras/lješnjak, Vitalia', 411, 8.2, 57.6, 16.5),
      ('Energetska pločica, okus malina/kakao, bez dodatog šećera, Wellness, Bambi', 372, 5.7, 69.5, 13.4),
      ('Energetske čokoladice sa whey proteinima', 362, 17.8, 34.6, 17.1),
      ('Energetsko piće, Juiced Monster, Mango Loco Energy + Juice', 48, 0, 12, 0),
      ('Fazan cijeli (celi)', 181, 22.7, 0, 9.29),
      ('Filet, Pangasius', 75, 13.67, 0, 1.9),
      ('Fit proteinski napitak, okus čokolada, Dukat', 51, 6, 5.2, 0.5),
      ('Fit proteinski napitak, okus kafa (kava), Dukat', 48, 6, 5.2, 0.3),
      ('Fit proteinski napitak, okus vanilija, Dukat', 50, 6, 5.8, 0.3),
      ('Fitness mješavina (fitness mix), smrznuto, Ledo', 41, 3.5, 4.4, 0.4),
      ('Gauda (gouda) sir', 356, 24.94, 2.22, 27.44),
      ('Gavun', 97, 17.63, 0, 2.42),
      ('Goji bobice, sušene (suve)', 349, 14.26, 77.06, 0.39),
      ('Golub mladi (samo meso)', 134, 21.76, 0, 4.52),
      ('Golub odrasli, cijeli (celi)', 294, 18.47, 0, 23.8),
      ('Gorgonzola, plavi sir', 353, 21.4, 2.34, 28.74),
      ('Govedina (junetina)', 276, 14.97, 0, 23.52),
      ('Govedina (junetina) jako masna', 410, 14, 0, 39),
      ('Govedina (junetina) masna', 307, 19, 1, 25),
      ('Govedina (junetina) prsa', 252, 16.8, 0, 20.5),
      ('Govedina (junetina) rostbraten', 290, 16, 0, 25.1),
      ('Govedina (junetina) srednje masna', 214, 18.8, 0, 15.4),
      ('Govedina (junetina) u konzervi', 223, 26, 0, 14),
      ('Govedina (junetina), but, krtina', 142, 21.59, 0, 5.53),
      ('Govedina (junetina), plećka (lopatica), pečena', 277, 25, 0, 19.6),
      ('Govedina (junetina), slabine', 201, 20.3, 0, 12.71),
      ('Govedina (junetina), vrat', 197, 18.9, 0, 13.5),
      ('Govedina, junetina, suva (sušena)', 154, 31.1, 2.74, 2),
      ('Goveđa (govedja) kocka (Maggi, Knorr, Podravka, Takovo, Premia) pripremljena 100 ml', 6, 0.36, 0.16, 0.48),
      ('Goveđa juha, fini-mini, Podravka', 65, 1.8, 11, 1.3),
      ('Goveđi filet', 138, 16, 0, 8),
      ('Grah (pasulj) crveni, konzervirani, Podravka', 114, 4.8, 8, 0.3),
      ('Graham hljeb (kruh, hleb)', 217, 7.8, 42.7, 1.4),
      ('Granola čokoladna, Sante', 457, 8.8, 66, 16),
      ('Granola domaća sa suvim (sušenim) voćem', 401, 10.2, 53.5, 17.6),
      ('Granola, čokolada/narandža, Wellness', 448, 8.9, 66, 15),
      ('Granola, čokoladna sa suvim voćem', 399, 11, 55, 15),
      ('Granola, Voćna, Sante', 423, 7.6, 68, 12),
      ('Grašak i mrkva, smrznuto mješano povrće, Ledo', 45, 3.4, 7.8, 0.2),
      ('Grašak zeleni (u zrnu)', 81, 5.42, 14.45, 0.4),
      ('Grašak zeleni (u zrnu), smrznuti', 77, 5.22, 13.62, 0.4),
      ('Grčki jogurt 0% mm, Dodoni', 54, 9, 4.5, 0),
      ('Grčki jogurt 10% mm, Dodoni', 125, 6, 2.9, 10),
      ('Grčki jogurt, 0%mm, Olympus', 54, 9.5, 4, 0),
      ('Grčki jogurt, okus jagoda, Kolios', 76, 6.7, 12.3, 0),
      ('Grčki jogurt, okus nar/malina, Kolios', 84, 6.7, 14.2, 0),
      ('Grčki tip jogurta 2%mm, Olympus', 70, 9, 4, 2),
      ('Grdobina', 76, 14.48, 0, 1.52),
      ('Grdobina kuvana', 97, 18.56, 0, 1.95),
      ('Grejpfrut', 32, 0.63, 8.08, 0.1),
      ('Grgeč (bandar)', 91, 19.39, 0, 0.92),
      ('Grisini, chilly, Vegan, Nutribella', 545, 7.8, 59.8, 30.3),
      ('Grožđe crno (crveno) i bijelo (belo)', 69, 0.72, 18.1, 0.16),
      ('Grožđice (grožđe suvo)', 299, 3.07, 79.18, 0.46),
      ('Guava', 68, 2.55, 14.32, 0.95),
      ('Guma za žvakanje (žvakaća guma, žvaka)', 360, 0, 96.7, 0.3),
      ('Guma za žvakanje (žvakaća guma, žvaka), bez šećera', 268, 0, 94.8, 0.4),
      ('Gumeni bomboni', 396, 0, 98.9, 0),
      ('Gumeni bomboni, Jelly Berries, Fini', 334, 3.5, 80, 0),
      ('Guska (samo meso)', 161, 22.75, 0, 7.13),
      ('Guska, cijela (cela)', 371, 15.86, 0, 33.62),
      ('Hahne corn flakes (žitarice)', 377, 7.2, 83.4, 1),
      ('Hahne corn flakes (žitarice) 0% šećera', 376, 7.4, 82.7, 1),
      ('Hamburger (od goveđeg mesa)', 360, 14, 4, 32),
      ('Haringa (sleđ), atlantska', 158, 17.96, 0, 9.04),
      ('Haringa (sleđ), atlantska, pečena', 203, 23.03, 0, 11.59),
      ('Haringa (sleđ), pacifička', 195, 16.39, 0, 13.88),
      ('Haringa (sleđ), pacifička, pečena', 250, 21.01, 0, 17.79),
      ('Haringa, fileti u paradajz sosu, konzervirana, Wefina', 185, 11.5, 4.3, 13.3),
      ('Haringa, fileti u senf sosu, konzervirana, Wefina', 186, 11.6, 2.6, 14.2),
      ('Haskap (sibirska borovnica, modra kozokrvina, kamčatkica)', 53, 1, 14, 0.3),
      ('Heljda (heljdino zrno)', 343, 13.25, 71.5, 3.4),
      ('Heljda (heljdino zrno), suvo-pržena', 346, 11.73, 74.95, 2.71),
      ('Heljdina kaša', 346, 8, 74, 2),
      ('Heljdino (heljda) brašno, integralno', 335, 12.62, 70.59, 3.1),
      ('HI Protein, Shake, Brownie, Dolcela', 380, 34, 35, 11),
      ('HI Protein, Shake, Cheesecake/Malina, Dolcela', 388, 33, 41, 9.8),
      ('Hidra, Iso limun', 22, 0.1, 4.6, 0.1),
      ('Hidra, Up, narandža', 19, 0.1, 4.6, 0.1),
      ('Hight protein, Quark raspberry, Pilos', 70, 12.5, 3.6, 0.5),
      ('Hladetina', 239, 43, 1, 7),
      ('Hlap (rarog, lap) rak', 77, 16.52, 0, 0.75),
      ('Hljeb (hleb, kruh) kukuruzni žuti domaći (kukuruza, proja)', 418, 7, 69.5, 12.2),
      ('Hljeb (hleb, kruh) miješani (pšenica+raž)', 230, 14, 39, 2),
      ('Hljeb (hleb, kruh) miješani (pšenica+raž), Jaus', 218, 7.4, 42, 0.9),
      ('Hljeb (hleb, kruh) pšenični bijeli mliječni', 239, 9, 44, 3),
      ('Hljeb (hleb, kruh) pšenični crni', 222, 8, 43, 2),
      ('Hljeb (hleb, kruh) ražev (raženi)', 170, 5.2, 34.3, 1.3),
      ('Hljeb (hleb, kruh), domaći bijeli', 234, 8, 51.7, 0.9),
      ('Hljeb (hleb, kruh), Glukofit, Maxi', 259, 8.1, 37.5, 6.6),
      ('Hljeb (hleb, kruh), Manja Mix, Pekara Manja', 255, 9.1, 44, 6.2),
      ('Hljeb (hleb, kruh), miješani iz cijelog zrna, Žitopeka', 289, 11.45, 40.65, 8.88),
      ('Hljeb (hleb, kruh), proteinski, Mestemacher', 264, 22, 7.5, 13.1),
      ('Hljeb (hleb, kruh), pšenični, bijeli', 265, 9, 49, 3.2),
      ('Hljeb (hleb, kruh), ražev (raženi), cjelovite žitarice, Mestemacher', 170, 5.2, 34.3, 1.3),
      ('Hljeb baget, kukuruzni, Manja', 220, 9, 31, 5),
      ('Hljeb, baget, francuski', 289, 12, 56, 1.8),
      ('Hljeb, FIT, Mlinar', 284, 11.8, 32.5, 9.3),
      ('Hljeb, integralni, rezani za tost, Mulino Bianco', 274, 9.2, 43.2, 5.5),
      ('Hljeb, polubijeli, Chia, Mlinar', 275, 10.6, 32.5, 10.5),
      ('Hljeb, ražev (kreker), Wasa original', 334, 9, 61.5, 1.5),
      ('Hljeb, Tost, Protein Plus, Klas', 258, 14.10, 37.59, 5.78),
      ('Hljeb, zrnata štanglica, Pekara Dubravica', 312, 8.9, 51.41, 8.76),
      ('Hobotnica', 82, 14.91, 2.2, 1.04),
      ('Hobotnica, pečena', 164, 29.82, 4.4, 2.08),
      ('Hren (ren)', 48, 1.18, 11.29, 0.69),
      ('Hren (ren) umak, Zvijezda', 162, 1.6, 9.7, 10),
      ('Hrenovke (viršle) pileće', 223, 15.51, 2.74, 16.19),
      ('Hrenovke (viršle), govedina + svinjetina', 305, 11.53, 1.72, 27.64),
      ('Hrenovke (viršle), pureće', 223, 12.23, 3.81, 17.29),
      ('Hrenovke (viršle), svinjske', 269, 12.81, 0.28, 23.68),
      ('Hrenovke, pileće, Classic, Cekin, Vindija', 186.7, 14.59, 1.44, 13.62),
      ('Humus (namaz od leblebija), pikant, Ribella', 252, 7, 8, 21),
      ('Humus (namaz od leblebija), sa sjemenkama bundeve, Ribella', 271, 7, 8, 24),
      ('Hyper Whey Protein, Nutrabolics', 375, 62.5, 15.63, 3.125),
      ('Ice Coffee OAT, Landessa', 53, 0.4, 6.5, 2.7),
      ('Ice Coffee, Cappuccino, Landessa', 69, 1.7, 11, 1.9),
      ('Ice Coffee, Espresso, Landessa', 64, 1.8, 11, 1.5),
      ('Ice Coffee, Latte Macchiato, Landessa', 71, 1.8, 11, 1.9),
      ('Ice Coffee, Pink Latte, Limited Edition', 58, 2.6, 10, 0.8),
      ('Impact whey protein, Isolate, My Protein', 369, 86, 5.4, 0.3),
      ('Impact whey protein, Isolate, okus chocolate smooth, My Protein', 363, 82, 6.3, 0.8),
      ('Impact whey protein, koncentrat (concetrate), okus Blueberry Cheesecake, My Protein', 413, 79, 8.1, 7.1),
      ('Impact whey protein, koncentrat (concetrate), okus Chocolate Brownie, My Protein', 379, 72, 7.3, 6.7),
      ('Impact whey protein, My Protein', 390, 71, 7.9, 7.5),
      ('Inćun', 131, 20.35, 0, 4.84),
      ('Inćun, konzerviran u ulju, ocijeđen', 210, 28.89, 0, 9.71),
      ('Indijski orah (oraščići)', 553, 18.22, 30.19, 43.85),
      ('Indijski orah (oraščići), pečen, neslani', 574, 15.31, 32.69, 46.35),
      ('Indijski orah (oraščići), pečen, slani', 574, 15.31, 32.69, 46.35),
      ('Indijski orah (oraščići), pržen u ulju, slani', 581, 16.84, 30.16, 47.77),
      ('Indijski orah, slani prženi, Berny', 550, 21, 15.2, 48),
      ('Iron Whey by Arnold Schwarzenegger Series, Muscle Pharm', 370, 68, 18.5, 3),
      ('Ironmaxx 100% Whey Protein, IronMaxx', 395, 77.3, 6.3, 6.2),
      ('Isotonic electrolytes, Aqua Viva, Reboot', 18, 0, 4.2, 0),
      ('Iverak (pasara, ploča)', 70, 12.41, 0, 1.93),
      ('Jabuka', 52, 0.26, 13.81, 0.17),
      ('Jabuka sušena (suva)', 243, 0.93, 65.89, 0.32),
      ('Jabuka, Crveni Delišes (Red Delicious)', 59, 0.27, 14.06, 0.2),
      ('Jabuka, Fuji Kiku', 63, 0.2, 15.22, 0.18),
      ('Jabuka, Gala', 57, 0.25, 13.68, 0.12),
      ('Jabuka, Granny Smith', 58, 0.44, 13.61, 0.19),
      ('Jabuka, oguljena (bez kore)', 48, 0.27, 12.76, 0.13),
      ('Jabuka, oguljena (bez kore), kuvana', 53, 0.26, 13.64, 0.36),
      ('Jabuka, smrznuta, nezaslađena (nezašećerena)', 48, 0.28, 12.31, 0.32),
      ('Jabuka, Zlatni Delišes (Golden Delicious)', 57, 0.28, 13.6, 0.15),
      ('Jaffa cakes orange classic, Crvenka', 378, 4.1, 69, 9),
      ('Jagode', 33, 0.67, 7.68, 0.3),
      ('Jagode, zaleđene (smrznute), nezaslađene', 35, 0.43, 9.13, 0.11),
      ('Jaje (jaja) guščje, cijelo (celo)', 185, 13.87, 1.35, 13.27),
      ('Jaje (jaja) kokošje u prahu cijelo, (celo)', 592, 48.05, 1.13, 43.9),
      ('Jaje (jaja) kokošje, cijelo (celo)', 147, 12.58, 0.77, 9.94),
      ('Jaje (jaja) kokošje, kajgana', 167, 11.15, 2.13, 12.13),
      ('Jaje (jaja) kokošje, kuvano, tvrdo-kuvano, poširano', 144, 12.6, 0.8, 9.6),
      ('Jaje (jaja) pačje cijelo (celo)', 185, 12.81, 1.45, 13.77),
      ('Jaje (jaja) prepelice, cijelo (celo)', 158, 13.05, 0.41, 11.09),
      ('Jaje (jaja) pureće, cijelo (celo)', 171, 13.68, 1.15, 11.88),
      ('Jaje kokošje, pečeno', 143, 12.6, 0.08, 8.7),
      ('Jakopska (jakobova) kapica', 69, 12.06, 3.18, 0.49),
      ('Jam', 118, 1.53, 27.88, 0.17),
      ('Janjetina (jagnjetina) nemasna', 243, 17.54, 0, 18.66),
      ('Jastog', 112, 20.6, 2.43, 1.51),
      ('Javorov sirup', 260, 0.04, 67.04, 0.06),
      ('Ječmena kaša', 360, 7.9, 83.6, 1.7),
      ('Jegulja', 184, 18.44, 0, 11.66),
      ('Jesetra', 105, 16.14, 0, 4.04),
      ('Jetra goveđa', 135, 20.36, 3.89, 3.63),
      ('Jetra svinjska', 134, 21.39, 2.47, 3.65),
      ('Jetra teleća', 140, 19.93, 2.91, 4.85),
      ('Jetrena pašteta (prosječno)', 201, 13.45, 6.55, 13.1),
      ('Jezik goveđi', 224, 14.9, 3.68, 16.09),
      ('Jogurt  0,5% MM', 34, 3.2, 4, 0.5),
      ('Jogurt  0% MM', 32, 3.5, 4.6, 0.05),
      ('Jogurt 1,5% MM', 45, 3.3, 4.1, 1.5),
      ('Jogurt 1% MM', 42, 3.2, 5.2, 1),
      ('Jogurt 1%mm, Natura Milk', 36, 2.9, 3.9, 1),
      ('Jogurt 2,8% mm', 52, 2.9, 4, 2.8),
      ('Jogurt 3,2% mm', 61, 3.5, 4.7, 3.2),
      ('Jogurt grčki', 125, 3.8, 5.7, 9.7),
      ('Jogurt kefir, 0,5% mm', 32, 3, 3.6, 0.5),
      ('Jogurt kefir, 0,9% mm', 41, 3.6, 4.8, 0.9),
      ('Jogurt kefir, 2,8% mm', 54, 3, 3.6, 2.8),
      ('Jogurt kefir, 3,5% mm', 65, 3.6, 4.8, 3.5),
      ('Jogurt Natur, Active Protein, Meggle', 78, 8.9, 6.4, 1.8),
      ('Jogurt proteinski, okus borovnica, Zott', 65, 10, 6, 0.3),
      ('Jogurt proteinski, okus breskva i narandza, Zott', 65, 10, 6, 0.3),
      ('Jogurt proteinski, okus jagoda, Zott', 65, 10, 6, 0.3),
      ('Jogurt SKYR (islandski tip jogurta), proteinski, jagoda, Zbregov, Vindija', 76, 9.1, 9.1, 0.3),
      ('Jogurt SKYR (islandski tip jogurta), proteinski, okus jabuka, zob, grožđice, Zbregov, Vindija', 77, 9.1, 9.2, 0.3),
      ('Jogurt SKYR (islandski tip jogurta), proteinski, šumsko voće, Zbregov, Vindija', 76, 9.1, 0.1, 0.3),
      ('Jogurt tekući Skyr, natur protein, breskva-marakuja, Zbregov', 69, 6.9, 9.4, 0.4),
      ('Jogurt tekući Skyr, natur protein, Zbregov', 53, 8, 4.4, 0.4),
      ('Jogurt voćni, breskva, Zott', 91, 3.5, 12.2, 2.7),
      ('Jogurt voćni, nemasni', 95, 4.4, 19, 0.2),
      ('Jogurt voćni, Smoothie, b Aktiv, okus borovnica i banana, Dukat', 71, 2.7, 12.1, 1.1),
      ('Jogurt voćni, šumsko voće, Freska', 88, 2.8, 14.3, 2.2),
      ('Jogurt, 0,9% mm', 45, 4.3, 5.1, 0.9),
      ('Jogurt, b Aktiv, LGG, Dukat', 47, 3.4, 4.9, 1.5),
      ('Jogurt, balans + protein 0% mm, Imlek', 36, 4, 4, 0.05),
      ('Jogurt, Balans+ Imuno, 1% mm, Imlek', 39, 3.3, 4, 1),
      ('Jogurt, Balans+, 1% mm, Imlek', 41, 3.2, 4, 1),
      ('Jogurt, grčki tip, Dukatos, Dukat', 125, 3.8, 5.7, 9.7),
      ('Jogurt, islandski tip, SKYR NATUR, Zbregov, Vindija', 62, 11, 4, 0.2),
      ('Jogurt, LCA, Protein, Zelene Doline', 61, 8, 4, 1.4),
      ('Jogurt, Sensia, 0,9% mm, Dukat', 42, 3.2, 4.7, 0.9),
      ('Kačamak, palenta, pura', 441, 5.6, 60, 20),
      ('Kačkavalj, (kaškaval)', 389, 25, 0, 32.14),
      ('Kafa (kava), espreso', 9, 0.12, 1.67, 0.18),
      ('Kafa (kava), turska', 38, 0.11, 9.56, 0.02),
      ('Kafa, Black n Easy, milk, Barcaffe', 346, 25, 43, 4.1),
      ('Kafa, mljevena', 241, 12.2, 10.1, 0.5),
      ('Kajmak, mladi, kravlji', 481, 4.6, 3.2, 50),
      ('Kajsija (marelica)', 48, 1.4, 11.12, 0.39),
      ('Kajsija (marelica), suva (sušena)', 241, 3.39, 62.64, 0.51),
      ('Kakao mix, u prahu', 398, 6.67, 83.73, 4),
      ('Kakao prah, Centro', 340, 24, 17, 11),
      ('Kakao prah, nezaslađen', 228, 19.6, 57.9, 13.7),
      ('Kakao prah, nezaslađen, dm Bio', 387, 22, 12, 21),
      ('Kakao prah, nezaslađen, Kraš', 392, 21, 18, 20),
      ('Kakao prah, Topingo', 300, 23, 9.9, 11),
      ('Kamamber (camembert) sir', 300, 19.8, 0.46, 24.26),
      ('Kamenica (ostriga)', 125, 21.55, 0, 3.67),
      ('Kamenice (ostrige), kuvane', 159, 28.81, 0, 3.97),
      ('Kandirano voće (sve vrste)', 322, 0.34, 82.74, 0.07),
      ('Kapar (kapara, kapari), konzervisan', 23, 2.36, 4.89, 0.86),
      ('Karambola', 31, 1.04, 6.73, 0.33),
      ('Kardamon (kardamom) sjeme (seme)', 311, 10.76, 68.47, 6.7),
      ('Karfiol (cvjetača), kuvan (baren), ocijeđen, bez soli', 23, 1.84, 4.11, 0.45),
      ('Karfiol (cvjetača), zeleni', 31, 2.95, 6.09, 0.3),
      ('Karfiol, (cvjetača)', 25, 1.98, 5.3, 0.1),
      ('Kavijar, crni i crveni, granulirani', 264, 24.6, 4, 17.9),
      ('Kazein (Casein) protein, okus čokolada, My Protein', 355, 78, 6.7, 1.2),
      ('Kazein, Micellar Casein Perfection, Body & Fit', 372, 82, 6.5, 2),
      ('Kečap, blagi, Polimark', 77, 1.1, 18, 0.1),
      ('Kečap, Heinz', 88, 0, 23.53, 0),
      ('Kefir', 60, 3, 3, 4),
      ('Keks (Cookies), classic, Chocolate Mountain, Griesson', 502, 7, 58, 26),
      ('Keks (Cookies), dupla čokolada (double chocolate), Merba', 498, 6.6, 59, 25),
      ('Keks petit beurre', 415, 6, 67.4, 8.2),
      ('Keks sa čokoladnim preljevom', 524, 5.7, 67.4, 27.6),
      ('Keks, Belini biscuit, Belina', 440.6, 11.19, 65.47, 12.08),
      ('Keks, biskvit sa bijelom čokoladom, SL Takovo', 373, 7.5, 61, 26),
      ('Keks, čoko biskvit, SL Takovo', 490, 7, 66, 22),
      ('Keks, mljeveni, Vitanova, Pionir', 420, 11, 73, 9.3),
      ('Keks, O\'cake, okus brusnica i jogurt, Jaffa, Crvenka', 481, 6.7, 65, 22),
      ('Keks, O\'cake, okus brusnica, Jaffa, Crvenka', 484, 7, 63, 23),
      ('Keks, O\'cake, okus narandža, Jaffa, Crvenka', 474, 7.6, 58, 24),
      ('Keks, Oreo', 476, 5.3, 68, 20),
      ('Keks, Plazma Diet, Bambi', 394, 11.3, 66.2, 11.9),
      ('Keks, Plazma, Bambi', 437, 11.9, 70.4, 12),
      ('Keks, Tart nougat, Banini,', 492, 6.9, 65, 23),
      ('Keks, Wellness integralni keks sa crnom čokoladom, Bambi', 453, 9.9, 58.2, 18.1),
      ('Keks, Wellness integralni keks sa ovsenim pahuljicama, Bambi', 464, 8.9, 57.4, 20.1),
      ('Keks, Wellness integralni keks sa ovsenim pahuljicama, okus narandža, Bambi', 492, 8.4, 57, 24),
      ('Keks, Wellness, keks sa integralnim žitaricama, okus kakao i malina, Bambi', 488, 6.8, 58, 24),
      ('Keleraba (koraba, korabica, repa žuta)', 27, 1.7, 6.2, 0.1),
      ('Keleraba (koraba, korabica, repa žuta), kuvana (barena), ocijeđena, bez soli', 29, 1.8, 6.69, 0.11),
      ('Keleraba, (koraba, korabica, repa žuta), kuvana, ocijeđena, soljena', 29, 1.8, 6.69, 0.11),
      ('Kelj', 27, 2, 6.1, 0.1),
      ('Kelj papučar (prokulica)', 43, 3.38, 8.95, 0.3),
      ('Kesten', 213, 2.42, 45.54, 2.26),
      ('Kesten suvi (sušeni), neoguljen', 374, 6.39, 77.31, 4.45),
      ('Kesten, cijeli, pečen', 245, 3.17, 52.96, 2.2),
      ('Kesten, suvi (sušeni), oguljen', 369, 5.01, 78.43, 3.91),
      ('Kiki karamele (bombone), voćne, Kraš', 405, 1.3, 81, 8.3),
      ('Kikiriki Gud Diet, pečeni, nesoljeni, Marbo', 618, 29.5, 10.2, 49.4),
      ('Kikiriki puter (maslac od kikirikija), kremasti, Barney\'s Best', 629, 26, 15, 51),
      ('Kikiriki puter (maslac od kikirikija), kremasti, bez soli', 598, 22.21, 22.31, 51.36),
      ('Kikiriki puter (maslac od kikirikija), kremasti, Delhaize', 644, 22.5, 10.1, 55.4),
      ('Kikiriki puter (maslac od kikirikija), kremasti, sa soli', 598, 22.21, 22.31, 51.36),
      ('Kikiriki puter (maslac od kikirikija), kremasti, Voćar', 563, 26, 14, 51),
      ('Kikiriki puter (maslac od kikirikija), sa komadićima kikirikija, bez soli', 589, 24.06, 21.57, 49.94),
      ('Kikiriki puter (maslac od kikirikija), sa komadićima kikirikija, sa soli', 589, 24.06, 21.57, 49.94),
      ('Kikiriki puter (maslac od kikirikija), Smooth Peanut Butter, McEnnedy', 651, 27, 9.3, 55),
      ('Kikiriki puter (maslac od kikrikija, pasta), Body&Fit', 639, 27, 10, 53),
      ('Kikiriki Puter u prahu, Gym Beam', 459, 50, 33, 12),
      ('Kikiriki u ljusci', 565, 25.8, 16.25, 49.11),
      ('Kikiriki, Nic Nac, Lorenz', 543, 17, 37, 35),
      ('Kikiriki, suvo-pečeni, bez soli (sve vrste)', 587, 24.35, 21.26, 49.66),
      ('Kikiriki, suvo-pečeni, slani (sve vrste)', 587, 24.35, 21.26, 49.66),
      ('Kim sjeme (seme)', 333, 19.77, 49.9, 14.59),
      ('Kinder Cards, Kinder', 510, 11.5, 55.9, 26.3),
      ('Kinder Country, Kinder', 561, 8.6, 54.9, 33.8),
      ('Kinder, Maxi King', 521, 6.7, 38.2, 37.5),
      ('Kinoa', 368, 14.12, 64.16, 6.07),
      ('Kinoa, kuvana', 120, 4.4, 21.3, 1.92),
      ('Kisela pavlaka, kiselo vrhnje, 12% mm, Dukat', 138, 2.9, 4.5, 12),
      ('Kisela pavlaka, kiselo vrhnje, 18% mm', 192, 3, 3, 18),
      ('Kisela pavlaka, kiselo vrhnje, 20% mm, Dukat', 206, 2.7, 3.9, 20),
      ('Kisela pavlaka, kiselo vrhnje, 25% mm, Dukat', 248, 2.5, 3.2, 25),
      ('Kisela pavlaka, kiselo vrhnje, mileram, 22% mm, Dukat', 224, 2.6, 3.9, 22),
      ('Kisela pavlaka, kiselo vrhnje, mileram, 30% mm, Dukat', 290, 2.3, 2.8, 30),
      ('Kivano (kiwano)', 44, 1.78, 7.56, 1.26),
      ('Kivi (kiwi)', 61, 1.14, 14.66, 0.52),
      ('Klementine', 47, 0.85, 12.02, 0.15),
      ('Klen', 79, 13.4, 0, 2.8),
      ('Klinčić (karanfilić)', 274, 5.97, 65.53, 13),
      ('Kobasica (prosječno)', 401, 14, 3, 37),
      ('Kobasica kranjska', 280, 15, 1, 24),
      ('Kobasica, čajna', 469, 24, 0.9, 41),
      ('Kobasica, Domaća, Pavić', 335, 13.72, 0.96, 30.55),
      ('Kobasica, tirolska', 291, 14, 2.6, 25),
      ('Kobasice (govedina i svinjetina)', 394, 14.2, 0, 37.4),
      ('Kobasice svinjske (dimljene)', 387, 21.9, 2, 31.3),
      ('Kobasice svinjske (suve, sušene)', 513, 21.3, 0, 47.5),
      ('Kokice gotove, slane, Volim, Tropic', 467, 8.3, 53, 22),
      ('Kokice, kokane na vazduhu', 387, 12.94, 77.78, 4.54),
      ('Kokice, kokane, pečene u ulju', 582, 7.3, 45.45, 43.64),
      ('Kokice, mikrovalna. La Grana, EuroCompany', 464, 9.7, 58, 19),
      ('Kokice, mikrovalna. La Grana, Mogyi', 438, 8, 42, 24),
      ('Kokos', 354, 3.33, 15.23, 33.49),
      ('Kokos u listićima (kokos čips)', 456, 3.13, 51.85, 27.99),
      ('Kokošija kocka (Maggi, Knorr, Podravka, Takovo, Premia) pripremljena 100 ml', 7, 0.36, 0.24, 0.48),
      ('Kokošja pašteta, Argeta Junior', 235, 12, 4, 19),
      ('Kokosov šećer, Fornatura', 384, 0.97, 95.01, 0),
      ('Kokosova voda', 18, 0.22, 4.24, 0),
      ('Kokosovo brašno, bez šećera', 660, 6.88, 23.65, 64.53),
      ('Kokosovo brašno, sa šećerom', 501, 2.88, 47.67, 35.49),
      ('Kokosovo brašno, Topingo', 659, 6.7, 24.3, 64.6),
      ('Kokosovo mlijeko (mleko)', 230, 2.29, 5.54, 23.84),
      ('Kokosovo mlijeko (mleko), u limenci (konzervirano)', 197, 2.02, 2.81, 21.33),
      ('Komorač korijen (koren)', 31, 1.24, 7.3, 0.2),
      ('Komorač sjeme (seme)', 345, 15.8, 52.29, 14.87),
      ('Kompot od ananasa', 77, 0.3, 20.2, 0),
      ('Kompot od bresaka', 87, 0.4, 22.9, 0),
      ('Kompot od krušaka', 77, 0.4, 20, 0),
      ('Kompot od šljiva', 70, 0.4, 17, 0),
      ('Kompot od trešanja ili višanja', 78, 0.4, 19, 0),
      ('Kondenzovano mlijeko (mleko), zaslađeno, punomasno, Markomilk', 328, 7.2, 56.5, 8.1),
      ('Konjetina (srednje masno)', 110, 20.9, 0, 2.8),
      ('Kopriva, obarena', 42, 2.71, 7.49, 0.11),
      ('Kore (biskvit) za tortu, gotove, Vincinni', 358, 10, 78, 3.5),
      ('Kore za pitu, jufke, tijesto (testo) za savijače, heljdino brašno, svježe', 291, 8.7, 55, 1.1),
      ('Kore za pitu, jufke, tijesto (testo) za savijače, integralne, svježe', 291, 11.56, 59.17, 0.9),
      ('Kore za pitu, jufke, tijesto (testo) za savijače, svježe', 220, 5.6, 64.6, 1.9),
      ('Kore za pitu, Klas', 296, 9.7, 61.7, 1.1),
      ('Korijander list, suvi (sušeni)', 279, 21.93, 52.1, 4.78),
      ('Korijander list, svjež', 23, 2.13, 3.67, 0.52),
      ('Korijander sjeme (seme)', 298, 12.37, 54.99, 17.77),
      ('Kornjača (zelena)', 89, 19.8, 0, 0.5),
      ('Koštana srž', 849, 3.2, 0, 89.9),
      ('Kovač', 78, 16.2, 1.2, 0.9),
      ('Kozice, gamberi (gambori), kuvani', 99, 23.98, 0.2, 0.28),
      ('Kozice, gamberi (gambori), svježi', 85, 20.1, 0, 0.51),
      ('Kozje meso', 109, 20.6, 0, 2.31),
      ('Kraš Express, Kraš', 349, 5.6, 73, 2.5),
      ('Krastavac', 15, 0.65, 3.63, 0.11),
      ('Krastavac kiseli', 11, 0.33, 2.26, 0.2),
      ('Krastavac, oguljen', 12, 0.59, 2.16, 0.16),
      ('Krekeri sa sirom', 489, 10.93, 59.42, 22.74),
      ('Krekeri sa sjemenkama, domaći', 535, 17.6, 34, 39.62),
      ('Krekeri slani, Colussi', 435, 11, 69, 12),
      ('Krem juha od gljiva fini-mini, Podravka', 90, 1.8, 9.2, 4.8),
      ('Krem juha od rajčice s mozzarellom, fini-mini, Podravka', 90, 1.9, 12, 3.5),
      ('Krem juha od špinata i sira, fini-mini, Podravka', 104, 2.2, 9.9, 5.8),
      ('Krem namaz sa lješnjacima (lešnikom), Bonno Premium, Pionir', 440, 7.6, 57, 31),
      ('Krem namaz sa lješnjacima (lešnikom), Maza', 537, 6.4, 52.7, 32.4),
      ('Krem namaz, Lino Lada, Gold, Podravka', 530, 6.2, 57, 30),
      ('Krem pileća juha, fini-mini, Podravka', 67, 2.3, 8.8, 2.2),
      ('Krem sir (mliječni namaz), Arla', 252, 4.5, 3, 25),
      ('Krem sirni namaz, Labne', 189, 4.5, 4.5, 17),
      ('Krem supa od pečuraka, dehidrirana (u kesici), aleva', 323, 9.9, 52, 8.3),
      ('Kroasan (Croissant), kakao punjenje, 7 days', 453, 5.6, 43, 28),
      ('Kroasani (Croissant)', 410, 5, 35, 25),
      ('Krompir (krumpir)', 77, 2.05, 17.49, 0.09),
      ('Krompir (krumpir), bijeli (beli)', 69, 1.68, 15.71, 0.1),
      ('Krompir (krumpir), cijeli (celi), pečen (pržen), bez soli', 93, 2.5, 21.15, 0.13),
      ('Krompir (krumpir), cijeli (celi), pečen (pržen), slan', 93, 2.5, 21.15, 0.13),
      ('Krompir (krumpir), crveni', 70, 1.89, 15.9, 0.14),
      ('Krompir (krumpir), oguljen, pečen (pržen), bez soli', 93, 1.96, 21.55, 0.1),
      ('Krompir (krumpir), oguljen, pečen (pržen), slan', 93, 1.96, 21.55, 0.1),
      ('Krompir pire (kućna priprema sa mlijekom i margarinom)', 113, 1.96, 16.94, 4.2),
      ('Krompir pire (kućna priprema sa mlijekom i maslacem)', 113, 1.86, 16.81, 4.22),
      ('Krompir pire (kućna priprema sa mlijekom)', 83, 1.91, 17.57, 0.57),
      ('Kruška', 57, 0.36, 15.23, 0.14),
      ('Kruška, sušena (suva)', 262, 1.87, 69.7, 0.63),
      ('Krvavice', 380, 14.8, 1.2, 34.4),
      ('Kukuruz, bijeli (beli), u zrnu', 365, 9.42, 74.26, 4.74),
      ('Kukuruz, žuti (šećerac), slatki, konzervirani (ocijeđena masa), Bonduelle', 112, 3, 20.5, 1.3),
      ('Kukuruz, žuti, slatki', 86, 3.27, 18.7, 1.35),
      ('Kukuruz, žuti, slatki, konzervisan', 67, 2.29, 14.34, 1.22),
      ('Kukuruz, žuti, slatki, kuvan (baren), ocijeđen, bez soli', 96, 3.41, 20.98, 1.5),
      ('Kukuruz, žuti, u zrnu', 365, 9.42, 74.26, 4.74),
      ('Kukuruzna krupica, palenta', 349, 7, 79, 2),
      ('Kukuruzne pahuljice (cornflakes)', 357, 7.5, 84.1, 0.4),
      ('Kukuruzni krekeri', 387, 8.1, 83.4, 2.4),
      ('Kulen (Kobasica)', 450, 24, 5, 37),
      ('Kumin sjeme (seme)', 375, 17.81, 44.24, 22.27),
      ('Kumkvat', 71, 1.88, 15.9, 0.86),
      ('Kupina', 43, 1.39, 9.61, 0.49),
      ('Kupine, smrznute', 64, 1.18, 15.67, 0.43),
      ('Kupus i repa kiseli', 20, 2, 3, 0.3),
      ('Kupus kiseli', 18, 3.57, 3.57, 0),
      ('Kupus, glavica, crveni', 31, 1.43, 7.37, 0.16),
      ('Kupus, glavica, zeleni', 25, 1.28, 5.8, 0.1),
      ('Kupus, kineski', 13, 1.5, 2.18, 0.2),
      ('Kupus, zeleni, kuvan, soljen, ocijeđen', 23, 1.27, 5.51, 0.06),
      ('Kurkuma (indijski šafran)', 312, 9.68, 67.14, 3.25),
      ('Kuskus', 376, 12.76, 77.43, 0.64),
      ('Kuskus, kuvan', 112, 3.79, 23.22, 0.16),
      ('Kvas, Smetoniška Gira, Bravoro Rauginimo', 28, 0.15, 6.9, 0),
      ('Kvasac, suvi (suhi)', 325, 40.44, 41.22, 7.61),
      ('Kvasac, svjež', 105, 8.4, 18.1, 1.9),
      ('Lan (laneno) sjeme', 534, 18.29, 28.88, 42.16),
      ('Laneni protein, Granum', 378, 34, 16.74, 15.67),
      ('Leblebija (slanutak), kuvana, ne posoljena', 164, 8.86, 27.42, 2.59),
      ('Leblebija (slanutak), suva', 364, 19.3, 60.65, 6.04),
      ('Leća (sočivo)', 352, 24.63, 63.35, 1.06),
      ('Leća (sočivo), crvena (roza)', 358, 23.91, 63.1, 2.17),
      ('Leća (sočivo), kuvana sa soli', 114, 9.02, 19.54, 0.38),
      ('Ledeni desert, Bourbon Vanilija, Dr. Oetker', 442, 4.6, 79, 12),
      ('Ledeni desert, Čokolada, Dr. Oetker', 426, 8.2, 67, 12),
      ('Liči (lychee), trešnja', 66, 0.83, 16.53, 0.44),
      ('Lignja', 92, 15.58, 3.08, 1.38),
      ('Limeta', 30, 0.7, 10.54, 0.2),
      ('Limeta sok 100%, cijeđen, svjež', 25, 0.42, 8.42, 0.07),
      ('Limun', 29, 1.1, 9.32, 0.3),
      ('Limun sok 100%, cijeđen', 22, 0.35, 6.9, 0.24),
      ('Limun, oguljen', 29, 1.1, 9.32, 0.3),
      ('Limunada, napravljena sa vodom', 40, 0.08, 10.41, 0.04),
      ('Limunova kora', 47, 1.5, 16, 0.3),
      ('Linjak', 71, 15, 0, 1.2),
      ('Lino, Lješnjak Čokolino, Podravka', 417, 6.5, 79, 7.6),
      ('Lisnato tijesto, smrznuto, pečeno', 558, 7.4, 45.7, 38.5),
      ('Lisnato tijesto, smznuto', 551, 7.3, 45.1, 38.1),
      ('List', 83, 15.9, 0.9, 1.7),
      ('Lizalo (lizalica), Chupa Chups', 389, 0.9, 94, 0.06),
      ('Lješnjak (lešnik)', 628, 14.95, 16.7, 60.75),
      ('Lješnjak, pečeni, Berny', 677, 16, 17, 60.5),
      ('Ljute papričice (feferoni) crvene, čili (hot chili)', 40, 1.87, 8.81, 0.44),
      ('Ljute papričice (feferoni) zelene, čili (hot chili)', 40, 2, 9.46, 0.2),
      ('Loj goveđi', 902, 0, 0, 100),
      ('Loj ovčiji', 902, 0, 0, 100),
      ('Losos', 208, 20.42, 0, 13.42),
      ('Losos, konzerviran, Losos Ustka', 173, 12, 10, 9),
      ('Lubenica', 30, 0.61, 7.55, 0.15),
      ('Lubin (brancin)', 97, 19.3, 0, 2),
      ('Luk bijeli (beli)', 149, 6.36, 33.06, 0.5),
      ('Luk crveni (crni)', 40, 1.1, 9.34, 0.1),
      ('Luk mladi', 27, 0.97, 5.74, 0.47),
      ('m&m\'s, okus slani karamel (salted caramel)', 474, 4.4, 71, 18),
      ('Mahune (boranija, buranija), zelene (mlade)', 31, 1.83, 6.97, 0.22),
      ('Mahune (boranija, buranija), zelene, smrznute, Ledo', 39, 1.8, 7.5, 0.21),
      ('Mahune (boranija, buranija), žute (zrele)', 31, 1.82, 7.13, 0.12),
      ('Majonez lajt (light)', 238, 0.37, 9.23, 22.22),
      ('Majonez lajt (light), Polimark', 250, 0, 8.5, 24),
      ('Majonez, Light, Zvijezda', 394, 0.5, 6.1, 41),
      ('Majonez, obični', 680, 0.96, 0.57, 74.85),
      ('Majonez, Polimark', 705, 1.1, 2.6, 77),
      ('Makadamia orah (makadamski orasi)', 718, 7.91, 13.82, 75.77),
      ('Makarone sa sirom', 233.9, 9.7, 26.6, 9.8),
      ('Makarone, tjestenina, Pasta Ricco', 356, 11, 74, 1.1),
      ('Malidžano domaći, ljuti, Mama\'s', 168, 3.86, 6.63, 10.34),
      ('Malina', 52, 1.2, 11.94, 0.65),
      ('Malina, smrznuta, Ledo', 25, 0.9, 5.6, 0),
      ('Maltodextrin, My protein', 380, 0, 94, 0),
      ('Mandarina', 53, 0.81, 13.34, 0.31),
      ('Mango', 60, 0.82, 14.98, 0.38),
      ('Margarin (biljna ulja)', 719, 0.9, 0.9, 80.5),
      ('Marinara sos', 108, 1.4, 9.8, 5.1),
      ('Maskarpone (mascarpone)', 450, 7, 2, 45),
      ('Maskarpone (mascarpone), Zelene Doline', 322, 2.8, 5.7, 32),
      ('Maslac, neslani', 717, 0.85, 0.06, 81.11),
      ('Maslac, slani', 717, 0.85, 0.06, 81.11),
      ('Maslačak (divlji radič), list, svjež', 45, 2.7, 9.2, 0.7),
      ('Masline zelene, kisele', 145, 1.03, 3.84, 15.32),
      ('Mast biljna', 884, 0, 0, 99.97),
      ('Mast guščija', 900, 0, 0, 99.8),
      ('Mast kokošja', 900, 0, 0, 99.8),
      ('Mast pačja', 882, 0, 0, 99.8),
      ('Mast pureća', 900, 0, 0, 99.8),
      ('Mast svinjska', 902, 0, 0, 100),
      ('Matična mleč (mliječ)', 310, 0, 76.19, 0),
      ('Matovilac (repušac)', 21, 2, 3.6, 0.4),
      ('Med', 304, 0.3, 82.4, 0),
      ('Medenjak čokoladni, Medeno Srce, Pionir', 340, 5.7, 66.1, 8.5),
      ('Medeno Srce, Pionir', 340, 5.7, 66.1, 8.5),
      ('Mediteranska salata sa tunjevinom (tunom), Calvo', 164, 7.1, 3.5, 13),
      ('Mekinje, pšenične', 206, 14.1, 26.8, 5.5),
      ('Mekinje, zobene (ovsene)', 246, 17.3, 66.22, 7.03),
      ('Meksička mješavina (mexički mix), smrznuto mješano povrće, Ledo', 52, 2.3, 7.9, 0.5),
      ('Mesni narezak (svinjsko + goveđe)', 338, 13, 4, 30),
      ('Mesni narezak (svinjsko meso)', 424, 5, 4, 40),
      ('Meso jelena i srnetina', 120, 22.96, 0, 2.42),
      ('Milbona High Protein Quark Bar, Vanilija', 287, 22, 19, 15),
      ('Milka keks, Choco Creme', 504, 5.7, 65, 24),
      ('Mirođija (kopar) list, suvi (sušeni)', 253, 19.96, 55.82, 4.36),
      ('Mirođija (kopar) list, svjež', 43, 3.46, 7.02, 1.12),
      ('Mirođija (kopar) sjeme (seme)', 305, 15.98, 55.17, 14.54),
      ('Mlaćenica', 40, 3.3, 4.8, 0.9),
      ('Mliječni namaz (cheesy spread), Arla', 320, 9, 1.5, 31),
      ('Mliječni namaz s povrćem, Dukatela, Dukat', 257, 3, 4.5, 25),
      ('Mliječni namaz, Vajkrem Biser, Mlijekoprodukt d.o.o.', 279, 5, 4, 27),
      ('Mliječni napitak, Protein, Čoko šejk, Imlek', 61, 10, 5, 0.1),
      ('Mliječni napitak, Protein, Jagoda šejk, Imlek', 55, 10, 3.6, 0.05),
      ('Mliječni napitak, Protein, Jagoda, Zbregov', 61, 10, 4.8, 0.2),
      ('Mliječni napitak, Protein, Keks, Zbregov', 63, 10, 5.4, 0.2),
      ('Mliječni napitak, Protein, malina/bijela čokolada, Zbregov', 64, 10, 4.9, 0.5),
      ('Mliječni napitak, Protein, Nougat, Zbregov', 63, 10, 5.2, 0.2),
      ('Mliječni napitak, Protein, okus čokolada, Zbregov', 62, 10, 4.7, 0.4),
      ('Mliječni napitak, protein, okus čokolada/banana, Zbregov', 65, 10, 4.9, 0.5),
      ('Mliječni napitak, Protein, okus čokolada/kikiriki maslac, Zbregov', 63, 10, 4.9, 0.4),
      ('Mliječni napitak, Protein, okus šumsko voće, Zbregov', 64, 10, 4.8, 0.5),
      ('Mliječni napitak, Protein, Vanilija, Zbregov', 62, 10, 4.9, 0.2),
      ('Mlijeko (mleko) kravlje 0,9% mm', 40, 3.2, 4.7, 0.9),
      ('Mlijeko (mleko) kravlje 0% mm, Lagano Jutro, Dukat', 32, 3.3, 4.6, 0.1),
      ('Mlijeko (mleko) kravlje 1,5% mm, bez laktoze, Alpsko Mleko, Ljubljanska Mlekara', 46, 3.3, 4.7, 1.5),
      ('Mlijeko (mleko) kravlje 1,8% mm', 49, 3.5, 5, 1.8),
      ('Mlijeko (mleko) kravlje 1% mm, Vindija', 41, 3.2, 4.7, 1),
      ('Mlijeko (mleko) punomasno u prahu', 480, 26.3, 39.8, 25.1),
      ('Mlijeko (mleko) rižino, mlijeko od pirinča', 47, 0.28, 9.17, 0.97),
      ('Mlijeko (mleko) žene', 70, 1.03, 6.89, 4.38),
      ('Mlijeko (mleko), kozje', 69, 3.56, 4.45, 4.14),
      ('Mlijeko (mleko), kravlje 2,8% mm', 56, 3.1, 4.5, 2.8),
      ('Mlijeko (mleko), kravlje 3,8% mm, punomasno', 64, 3.3, 4.7, 3.8),
      ('Mlijeko (mleko), kravlje 3.2% mm', 60, 3.25, 4.5, 3.25),
      ('Mlijeko (mleko), kravlje obrano', 33, 3.4, 4.7, 0.2),
      ('Mlijeko (mleko), kravlje, 0,5% mm', 35, 3.1, 4.6, 0.5),
      ('Mlijeko (mleko), kravlje, 1,5% mm', 44, 3.1, 4.6, 1.5),
      ('Mlijeko (mleko), obrano u prahu', 336, 34.9, 50.9, 0.7),
      ('Mlijeko (mleko), ovčije', 108, 5.98, 5.36, 7),
      ('Mlijeko kravlje kiselo, 2,8% mm, Meggle', 54, 3, 3.6, 2.8),
      ('Mljeveno, miješano meso', 210, 18.8, 0, 15.4),
      ('Monte Snack, Zott', 443, 5, 35.5, 31),
      ('Morski pas (ajkula)', 130, 20.98, 0, 4.51),
      ('Morski pas (ajkula), pečen', 228, 18.6, 6.35, 13.76),
      ('Mortadela', 415, 13.9, 0, 39.9),
      ('Mozak, svinjski, svjež (sirov)', 127, 10.28, 0, 9.21),
      ('Mrena', 84, 14, 0.1, 3.1),
      ('Mrvice hljebne (hlebne), suve (sušene), bijelo pšenično brašno, komercijalno pripravljene', 395, 13.35, 71.98, 5.3),
      ('Muesli (prosjek)', 314, 11.4, 55.8, 6.4),
      ('Munchmallow', 416, 4.3, 60.5, 16.9),
      ('Murina', 99, 17.6, 1.3, 2.7),
      ('Muškantni oraščić (orah), muskat, muškat, mljeveni', 525, 5.84, 49.29, 36.31),
      ('Muškatna (butternut) bundeva (tikva, dulek, buča, ludaja)', 45, 1, 11.69, 0.1),
      ('Musli & Fruits, Crunchy, Bona Vita', 440, 6, 68, 15),
      ('Mušmule (mušmulje)', 43, 0.5, 8.6, 0.2),
      ('Namaz od lješnjaka i kakaa, Proteinella, HealthyCo', 503, 13.3, 43.9, 36.1),
      ('Namaz od lješnjaka, nutela (nutella), Ferrero', 539, 6.3, 57.5, 30.9),
      ('Namaz od smokve, narandže i kakaa, Dida Boža, Jaffa', 285, 0.7, 69, 0),
      ('Namaz sa paprikom, Rajska bašta', 320, 5.4, 3.7, 30.4),
      ('Namaz, med sa dodatkom oraha i paste suncokreta, Rajska bašta', 456, 1.5, 54, 22.4),
      ('Napitak, kafa, instant, cikorija', 3, 0.09, 0.75, 0),
      ('Napolitanke prosječno', 550, 4, 62, 32),
      ('Nar (šipak, mogranj)', 83, 1.67, 18.7, 1.17),
      ('Narandža', 47, 0.94, 11.75, 0.12),
      ('Narandžina kora', 97, 1.5, 25, 0.2),
      ('Natural Bites, Hazelnut Brownie', 263, 5.82, 14.09, 20.61),
      ('Nektarina', 44, 1.06, 10.55, 0.32),
      ('Nescafe 3/1 (classic, original), Instant kafa (kava)', 433, 1.3, 75, 13.6),
      ('Nescafe classic, original,  granulirana', 63, 7, 9, 0.2),
      ('Njoki, krompirovo tijesto, Crivellin', 154, 4, 33, 0.3),
      ('Ogrozd', 44, 0.88, 10.18, 0.58),
      ('Orada (komarča, podlanica, dinigla, lovrata, ovrata, zlatulja, sekulica)', 96, 18, 0, 3),
      ('Orah (orasi)', 654, 15.23, 13.71, 65.21),
      ('Orah (orasi), brazilski', 659, 14.32, 11.74, 67.1),
      ('Origano (mravinac), suvi (sušeni)', 265, 9, 68.92, 4.28),
      ('Oslić', 71, 17, 0.1, 0.3),
      ('Oslić fileti', 118, 18, 0, 5.13),
      ('Ovčetina (prosječno)', 293, 17, 0, 25),
      ('Pahuljice (krupne), zobene, ovsene', 402, 14, 66, 7),
      ('Pahuljice (sitne), zobene, ovsene', 360, 12.5, 57, 7),
      ('Pahuljice, ječmene', 357, 10.18, 73.61, 2.24),
      ('Pahuljice, ražene (raževe), instant, Fun & Fit', 327, 9.7, 62, 1.5),
      ('Pahuljice, sojine', 464, 37, 24, 23),
      ('Palačinke', 174.3, 4.9, 28.1, 4.4),
      ('Palenta, Tomico', 349.36, 7, 79, 2),
      ('Panirane lignje (štapići)', 180, 13.4, 12.9, 8),
      ('Panirani fišburger (fishburger) pljeskavica', 142, 7.9, 23.3, 1.4),
      ('Panirani oslić (fileti)', 140, 11.8, 20.2, 1.3),
      ('Panirani riblji štapići', 193, 11, 18.2, 8.3),
      ('Panirani surimi (štapići)', 208, 7, 27, 8),
      ('Panirani surimi račići', 205, 7, 27, 8),
      ('Papaja', 43, 0.47, 10.82, 0.26),
      ('Papalina', 293, 25.5, 0, 21.5),
      ('Papričice sa sirom u tegli, mješane, ljuto, Volim', 278, 6.3, 27.2, 15.2),
      ('Paprika (suva, sušena), mljevena', 282, 14.14, 53.99, 12.89),
      ('Paprika crvena, slatka (mesnata)', 31, 0.99, 6.03, 0.3),
      ('Paprika kisela', 15, 0.8, 1.7, 0.6),
      ('Paprika pečena sa bijelim lukom, Volim, Tropic', 33, 0.96, 6.91, 0.04),
      ('Paprika zelena, slatka (mesnata)', 20, 0.86, 4.64, 0.17),
      ('Paprika žuta, slatka (mesnata)', 27, 1, 6.32, 0.21),
      ('Paradajz (rajčica) sos, koncentrat, 28-30% suve tvari, Podravka', 84, 4.6, 16, 0.16),
      ('Paradajz čeri (cherry)', 21, 1.47, 4.41, 0.3),
      ('Paradajz sos (koncentrat 10)', 39, 1.7, 7, 0),
      ('Paradajz, rajčica', 18, 0.88, 3.92, 0.2),
      ('Parmezan', 411, 40, 2, 27),
      ('Parmezan, Grana Padano', 398, 33, 0, 29),
      ('Pasirani paradajz Tomatello, Nectar', 27, 0.9, 4.85, 0.21),
      ('Pasirani paradajz, sos, Russo', 24, 1.5, 3.8, 0.1),
      ('Pasirani paradajz, sos, Victoria', 34, 1.3, 6.3, 0.2),
      ('Pasta, tjestenina (testenina), integralna', 352, 13.87, 73.37, 2.93),
      ('Pašteta Argeta sa tunjevinom', 320, 13, 1.8, 29),
      ('Pastrmka (pastrva) filet, dimljena (suva, sušena)', 113, 21.1, 3.4, 1.4),
      ('Pastrmka (pastrva) filet, dimljena (suva, sušena), Tropic ribarstvo', 137, 21.27, 0.5, 5.8),
      ('Pastrmka (pastrva) kalifornijska', 195, 21.5, 0, 11.4),
      ('Pastrmka (pastrva) pečena', 169, 24.3, 0, 7.2),
      ('Pastrmka (pastrva) potočna', 86, 14.7, 0, 3),
      ('Pasulj (grah) mladi, šareni (trešnjevac), smrznuti', 170, 9.8, 32.5, 0.5),
      ('Pasulj (grah), bijeli (beli), tetovac', 333, 23.36, 60.27, 0.85),
      ('Pasulj (grah), crni', 341, 21.6, 62.36, 1.42),
      ('Pasulj (grah), crveni', 337, 22.53, 61.29, 1.06),
      ('Pasulj (grah), šareni (trešnjevac)', 347, 21.42, 62.55, 1.23),
      ('Pasulj (grah), šareni (trešnjevac), kuvan, soljen', 143, 9.01, 26.22, 0.65),
      ('Patka (samo meso)', 122, 19.7, 0, 4.8),
      ('Patka (srednje masna)', 341, 20, 0, 29),
      ('Patka, divlja', 211, 17.42, 0, 15.2),
      ('Patlidžan', 25, 0.98, 5.88, 0.18),
      ('Pečenica, dimljena, svinjska, Tulumović', 228, 33, 2.8, 9.4),
      ('Pecivo (bijelo brašno)', 256, 8, 47, 4),
      ('Pecivo za hamburgere, sa susamom (sezamom), Viva il panino, Emmeci Pane s.r.l.', 295, 7.8, 52.6, 5.4),
      ('Pegra, pčelinji hljeb', 220, 27.5, 6.88, 1.23),
      ('Pekmez', 261, 0.6, 69, 0),
      ('Pelat, Podravka', 19, 1.1, 3, 0.1),
      ('Pepermint bomboni', 392, 0, 98, 0),
      ('Pepsi', 42, 0, 11.55, 0),
      ('Pereci', 303, 8.5, 57, 5.1),
      ('Persimon (kaki, japanska jabuka, mekana jabuka)', 70, 0.58, 18.59, 0.19),
      ('Peršin (peršun) list', 36, 2.97, 6.33, 0.79),
      ('Pica (pizza) sa kobasicom', 255, 14.225, 28.028, 9.86),
      ('Pica (pizza) sa sirom', 267, 12.06, 32.38, 9.68),
      ('Pica (pizza) sa sirom, mesom i povrćem', 233, 16.456, 26.96, 6.84),
      ('Pica hljeb (podloga), pizza base, Dijo, Fun & Food', 325, 6.5, 54, 8.9),
      ('Pileća pašteta, Smazalice, Carnex', 253, 10, 2.4, 22),
      ('Pileća prsa Cekin, u ovitku, Vindija', 89, 16, 3, 1.5),
      ('Pileća prsa u ovitku, Neoplanta', 75, 13, 3.6, 1),
      ('Pileća prsa, dimljena u ovitku, Cekin Dimček, Vindija', 89, 17, 1.8, 1.5),
      ('Pileća prsa, dimljena, Grande, Madi', 78, 14.95, 2, 1.02),
      ('Pileća prsa, Slim&fit, Perutnina Ptuj', 79, 14, 1.3, 1),
      ('Pileći parizer, Jeli, Gavrilović', 187, 12, 1, 15),
      ('Piletina, cijelo pile', 215, 18.6, 0, 15.06),
      ('Piletina, kokoš, cijela', 200, 17.15, 0, 14.02),
      ('Piletina, pileća jetra', 119, 16.92, 0.73, 4.83),
      ('Piletina, pileća krila (krilca)', 191, 17.52, 0, 12.85),
      ('Piletina, pileća krila (krilca), pečena', 254, 23.79, 0, 16.87),
      ('Piletina, pileća krila (krilca), pohovana', 321, 26.11, 2.39, 22.16),
      ('Piletina, pileća prsa', 120, 22.5, 0, 2.62),
      ('Piletina, pileća prsa, dimljena, Madi', 104, 23.2, 3.66, 1.63),
      ('Piletina, pileća prsa, dimljena, Perutnina Ptuj', 99, 18, 2, 2),
      ('Piletina, pileća prsa, kuvana', 151, 28.98, 0, 3.03),
      ('Piletina, pileća prsa, pečena', 165, 31.02, 0, 3.57),
      ('Piletina, pileće srce', 153, 15.55, 0.71, 9.33),
      ('Piletina, pileći karabatak', 214, 16.37, 0.17, 15.95),
      ('Piletina, pileći karabatak, bez kože', 120, 19.16, 0, 4.22),
      ('Piletina, pileći karabatak, bez kože, kuvan', 185, 26.26, 0, 8.06),
      ('Piletina, pileći karabatak, bez kože, pečen', 174, 24.22, 0, 7.8),
      ('Piletina, pileći želudac', 94, 17.7, 0, 2.1),
      ('Piletina, prsa, dimljena, vakumirana, Grande', 146, 23.23, 3.02, 4.48),
      ('Pire, voćni mix, jabuka, kruška i dinja, Nutrino', 71, 0.5, 14.7, 0.4),
      ('Pirinač, riža, Basmati, suva (sirova)', 351, 7.5, 77, 1.2),
      ('Pirinač, riža, bijelo zrno, kuvano', 130, 2.38, 28.59, 0.21),
      ('Pirinač, riža, bijelo zrno, sirovo', 360, 6.61, 79.34, 0.58),
      ('Pirinač, riža, divlji, crno zrno, suvo (sirovo),', 355, 7, 73, 3),
      ('Pirinač, riža, integralna, smeđa, kuvana', 112, 2.32, 23.51, 0.83),
      ('Pirinač, riža, integralna, smeđa, sirova', 362, 7.5, 76.17, 2.68),
      ('Pirinač, riža, parboiled, kuvana', 123, 2.91, 26.05, 0.37),
      ('Pirinač, riža, parboiled, suva', 374, 7.51, 80.89, 1.03),
      ('Pirovo brašno (pir), speltino brašno (spelta), krupnik, krupnica', 338, 14.57, 70.19, 2.43),
      ('Piškoti', 391, 12, 70, 7),
      ('Pistaći (pistacija), pečeni, soljeni', 569, 21.05, 27.55, 45.82),
      ('Pita zeljanica (približna vrijednost)', 207, 9.24, 29.12, 6.54),
      ('Pivo sa voćnim sokom 2%, radler - prosjek', 43, 0.1, 7.7, 0.2),
      ('Pivo, bezalkoholno', 29, 0.24, 1.64, 0),
      ('Pivo, đumbirovo', 34, 0, 8.76, 0),
      ('Pivo, svijetlo (svetlo), regularno', 43, 0.46, 3.55, 0),
      ('Pomelo', 38, 0.76, 9.62, 0.04),
      ('Pomfrit (Mcdonalds)', 324, 4.23, 40.85, 15.49),
      ('Pomfrit, kućna priprema, smrznut, pečen u pećnici, ne posoljen', 134, 2.6, 27.8, 5.2),
      ('Pomfrit, kućna priprema, smrznut, pečen u pećnici, posoljen', 200, 3.2, 31.2, 7.6),
      ('Pomfrit, smrznuti, pakovanje', 140, 2.5, 20, 5),
      ('Popečci od soje, Oplant', 214, 9.7, 22, 8.6),
      ('Posni pasulj, Carnex', 100, 4.4, 16, 2.2),
      ('Povrtna juha, fini-mini, Podravka', 54, 1.6, 9, 1),
      ('Praline, Milka', 554, 6.1, 53, 35),
      ('Prašak za puding (kremu), Čokolada, Galetta, Dr. Oetker', 380, 2.4, 86, 1.7),
      ('Prašak za puding (kremu), vanilija, Galetta, Dr. Oetker', 385, 0, 95, 0.1),
      ('Prašak za puding, vanilija, Briž', 363, 0.5, 90, 0.1),
      ('Praziluk (prasa, poriluk)', 61, 1.5, 14.15, 0.3),
      ('Preljev za torte, crveni, Dolcela, Podravka', 376, 0, 90, 0),
      ('Preljev za torte, svijetli, Dolcela, Podravka', 343, 0, 79, 0),
      ('Prepelica', 134, 21.8, 0, 4.5),
      ('Prezle', 367, 8.15, 80.58, 1.3),
      ('Proso', 378, 11.02, 72.85, 4.22),
      ('Proso, brašno', 382, 10.75, 75.12, 4.25),
      ('Proso, kuvan', 119, 3.51, 23.67, 1),
      ('Protein bar, Double Dutch Chocolate, Amix Exclusive', 433, 28, 42.5, 16.8),
      ('Protein Bar, Fresh Lemon, Proteini.si', 419, 22.8, 45.1, 16),
      ('Protein bar, kakao punjenje (cocoa coating), okus sa čokoladom, Tekmar', 376, 25, 37.8, 15.8),
      ('Protein Bar, Milk Chocolate, Proteini.si', 422, 22.8, 43.5, 16.5),
      ('Protein Bar, orange/chocolate, Proteini.si', 422, 22.7, 44, 16.5),
      ('Protein Bar, Tamna Čokolada, Enervit', 383, 50, 22, 13),
      ('Protein graška, Nutrigold', 384, 80, 0.5, 4.1),
      ('Protein Micellar Casein, GymBeam, Vanilija', 358, 77, 9.6, 1.5),
      ('Protein mousse, čokolada, Stay Strong PRO,  Dukat', 84, 11, 5.6, 1.7),
      ('Protein mousse, vanilija, Zott', 78, 10.8, 4.9, 1.5),
      ('Protein mousse, Zott', 84, 10.8, 6, 1.5),
      ('Protein puding, Cocoa, Stay Strong PRO, Dukat', 75, 10, 5.9, 1.1),
      ('Protein puding, lješnjak, Stay Strong PRO, Dukat', 73, 10, 6.1, 0.9),
      ('Protein puding, vanilija, Stay Strong PRO, Dukat', 73, 10, 6.2, 0.9),
      ('Protein Pure Bar, Cookies & Cream, GymBeam', 357, 32.5, 20.3, 14),
      ('Protein Pure Bar, double chocolate chunks, GymBeam', 334, 31.7, 21.2, 11.8),
      ('Protein, čoko puding, Imlek', 81, 10, 6.4, 1.6),
      ('Proteini.si, 100% Natrural Whey Protein, čokolada, Whey Concentrate', 423, 72.5, 8.1, 11.2),
      ('Proteini.si, 100% Natrural Whey Protein, vanilija, Whey Concentrate', 423, 72.5, 8.1, 11.2),
      ('Proteinska ruska salata', 83.8, 9.34, 6.68, 2.4),
      ('Proteinski bar (proteinska pločica) sa bananom, Bakkalland BA!', 381, 27, 31, 12),
      ('Proteinski bar (proteinska pločica) sa jagodom, Bakkalland BA!', 376, 29, 33, 10),
      ('Proteinski bar (proteinska pločica) sa kafom, Bakkalland BA!', 390, 29, 29, 13),
      ('Proteinski bar (proteinska pločica) sa kikirikijem, Bakkalland BA!', 386, 32, 25, 13),
      ('Pršut, goveđi', 187, 30, 0, 7.5),
      ('Pršut, Serrano, bez kosti, Elpozo', 228, 30, 0, 12),
      ('Pršut, svinjski', 252, 30, 0, 14.4),
      ('Pršut, svinjski, Dobro', 276, 28, 0.5, 18),
      ('Prženi badem u šećeru', 459, 7.9, 65, 18.6),
      ('Pšenica u zrnu (mekane sorte)', 326, 10.2, 72, 2),
      ('Pšenica u zrnu (tvrde sorte)', 332, 12.7, 70, 2.5),
      ('Pšenična krupica, griz', 333, 11, 70, 1),
      ('Pšenične klice', 287, 27, 20, 11),
      ('Pšenično brašno (puno zrno)', 318, 13.2, 65.8, 2),
      ('Pšenično brašno bijelo', 350, 9.8, 80.1, 1.2),
      ('Pšenično brašno crno (85 ekst.)', 327, 12.8, 68.8, 2),
      ('Pšenično brašno polubijelo (72 ekst.)', 337, 11.3, 74.8, 1.2),
      ('Psilijum ljuspice', 200, 4.6, 77.3, 0.5),
      ('Puding (prašak), Vanilija, Briž', 363, 0.5, 90, 0.1),
      ('Puding od čokolade', 134, 3.5, 21, 4),
      ('Puding proteinski, čokolada, Zbregov, Vindija', 81, 10, 6.4, 1.6),
      ('Puding proteinski, karamela, Zbregov, Vindija', 80, 10, 6.8, 1.4),
      ('Puding proteinski, kokos-badem, Zbregov, Vindija', 87, 10, 7, 2),
      ('Puding proteinski, okus Čokolada, Zott', 83, 10.3, 6.2, 1.5),
      ('Puding proteinski, vanilija, Zbregov, Vindija', 79, 10, 6.5, 1.5),
      ('Puding u prahu', 380, 0, 95, 0),
      ('Puran (bijelo meso)', 134, 22, 0, 4.9),
      ('Puran (cijeli)', 143, 20, 0, 7),
      ('Puran (crno meso  batak)', 186, 20.9, 0, 11.2),
      ('Pure IsoWhey, GymBeam, Vanilla ice cream (vanila sladoled)', 410, 88, 6.8, 2.8),
      ('Puretina, pureća krila (krilca)', 197, 20.22, 0, 12.32),
      ('Puretina, pureća prsa', 114, 23.66, 0.14, 1.48),
      ('Puretina, pureća prsa, pečena', 147, 30.13, 0, 2.08),
      ('Puretina, pureći batak', 144, 19.54, 0, 6.72),
      ('Puretina, pureći ćevapčići, (ćevapi), Vindon, Vindija', 182, 17, 2.3, 11),
      ('Puter (namaz) od indijskog oraha, Lučar', 612, 32.1, 19.1, 45.3),
      ('Puž vinogradski (očišćeni)', 75, 15, 2, 0.8),
      ('Radić savinjski', 16, 0.7, 3.2, 0.3),
      ('Radić zeleni', 24, 1.8, 3.2, 0.5),
      ('Radić, crveni', 23, 1.43, 4.48, 0.25),
      ('Raffaello, Ferrero', 627, 7.4, 38.6, 48.3),
      ('Rak slatkovodni', 71, 13.6, 2.9, 0.6),
      ('Ramen, okus govedina, Maggi', 462, 9.5, 58.8, 20.4),
      ('Ramen, okus govedina, podravka', 442, 10, 65, 15),
      ('Ramen, okus piletina, podravka', 459, 11, 68, 18),
      ('Raštan (raštika, rašćika, zeleni kupus), kuvan (kuhan), ocjeđen', 33, 2.71, 5.65, 0.72),
      ('Raštan (raštika, rašćika, zeleni kupus), sirov (svjež)', 36, 2.97, 7.1, 0.41),
      ('Raža', 68, 14.2, 0.8, 0.9),
      ('Raženo brašno (100 ekst.)', 335, 8.2, 75.9, 2),
      ('Raženo brašno (60 ekst.)', 333, 8, 73, 1),
      ('Raževi krekreri, Tastino', 379, 11.5, 59, 7.1),
      ('Red bul (Red Bull)', 43, 0.46, 10.23, 0),
      ('Repa bijela', 20, 0.8, 3.8, 0.3),
      ('Rezanci (nudle), od jaja, suvi (sušeni)', 384, 14.16, 71.27, 4.44),
      ('Rezanci (nudle), od riže (rižini, pirinčani), kuvani', 108, 1.79, 24.01, 0.2),
      ('Rezanci (nudle), od riže (rižini, pirinčani), suvi (sušeni)', 364, 5.95, 80.18, 0.56),
      ('Rezanci, tjestenina (s jajima), Ragusa', 361, 12.4, 75, 1.3),
      ('Ribizl crni', 63, 1.4, 15.38, 0.41),
      ('Ribizl crveni i bijeli (beli)', 56, 1.4, 13.8, 0.2),
      ('Riblja ikra', 143, 22.32, 1.5, 6.42),
      ('Riblja ikra, kuvana na pari (barena)', 204, 28.62, 1.92, 8.23),
      ('Rikota, polumasni svježi sir,(punomasno mlijeko)', 174, 11.26, 3.04, 12.98),
      ('Riža (pirinač), expandirana, zaslađena fruktozom, Vitalia', 362, 7.1, 80, 2.7),
      ('Rižine pahuljice', 394, 6.69, 86.22, 1.26),
      ('Rižini (pirinčani) krekeri', 416, 10, 82.64, 5),
      ('Rižini (pirinčani) krekeri, Fiorentini Alimentari', 379, 8.8, 80.3, 1.9),
      ('Rižino brašno', 347, 7.5, 70, 0.5),
      ('Rogač, mljeveni', 222, 4.62, 88.88, 0.65),
      ('Rotkva crna', 28, 2, 5, 0),
      ('Rotkvica crvena', 16, 0.68, 3.4, 0.1),
      ('Rukola (rikula)', 25, 2.58, 3.65, 0.66),
      ('Rum', 231, 0, 0, 0),
      ('Ruzmarin (ružmarin)', 131, 3.31, 20.7, 5.86),
      ('Ruzmarin (ružmarin), suvi (sušeni)', 331, 4.88, 64.06, 15.22),
      ('Sabljarka (iglun)', 121, 19.8, 0, 4),
      ('Sabljarka (iglun) pečena', 155, 25.4, 0, 5.1),
      ('Salama  parizer', 523, 17, 1, 47),
      ('Salama goveđa trajna', 417, 25.4, 0, 34.7),
      ('Salama Poli Classic, Perutnina Ptuj', 216, 12, 0.6, 18.3),
      ('Salama trajna (milanska)', 475, 22.5, 0, 42.8),
      ('Salama trajna (svinjsko + goveđe)', 454, 27.4, 0, 38.3),
      ('Salama trajna (svinjsko)', 465, 34.5, 0, 36.3),
      ('Salama, pileća, pureća', 197, 16.6, 0.7, 13.8),
      ('Salata endivija', 17, 1.25, 3.35, 0.2),
      ('Salata glavatica', 12, 1, 1.2, 0.4),
      ('Salata sa tunom (tunjevinom) i majonezom, Calvo', 138, 7.3, 10, 7.4),
      ('Salata zelena', 13, 1.35, 2.23, 0.22),
      ('Salata, zelena, ajsberg (iceberg)', 14, 0.9, 2.97, 0.14),
      ('Salvia (kadulja, žalfija), suva (sušena), mljevena', 315, 10.63, 60.73, 12.75),
      ('Šampanjac', 84, 0.07, 2.72, 0),
      ('Šampinjoni gljive (pečurke)', 22, 3.09, 3.26, 0.34),
      ('Šaran', 127, 15.8, 0.7, 6.8),
      ('Sardela (srdela, sardina) konzervirana, (samo riba)', 208, 24.62, 0, 11.45),
      ('Sardela (srdela, sardina), svježa (sirova)', 160, 20, 0, 8),
      ('Sardina (srdela, sardela) konzervirana (u ulju)', 334, 19.7, 0, 28.3),
      ('Sardine (srdela, sardela) s povrćem, Eva, Podravka', 120, 15, 3.3, 5.7),
      ('Sardine, konzervirane, u suncokretovom ulju, Mio Mare', 310, 18.3, 0.1, 26.2),
      ('Šargarepa (mrkva)', 41, 0.93, 9.58, 0.24),
      ('Šargarepa (mrkva), kuvana (barena), ocijeđena, bez soli', 35, 0.76, 8.22, 0.18),
      ('Sarma, kuvana', 126, 13, 10.8, 4.2),
      ('Sataraš, smrznuto povrće, Ledo', 29, 1.2, 5.4, 0.3),
      ('Šećer granulirani', 381, 0, 100, 0),
      ('Šećer kristal', 400, 0, 99.9, 0),
      ('Šećer smeđi (djelomično raf.)', 380, 0, 95, 0),
      ('Šećer u prahu', 380, 0, 95, 0),
      ('Šećer, vanilin, dolcela, Podravka', 395, 0, 99, 0),
      ('Sejtan (seitan)', 370, 75.16, 13.79, 1.85),
      ('Senf', 60, 3.74, 5.83, 3.34),
      ('Serious Mass, Mass Gainer, Optimum Nutrition', 380, 15, 74, 2.1),
      ('Sipa', 72, 14, 0.8, 1.4),
      ('Sipa (pečena)', 158, 32.5, 1.6, 1.4),
      ('Sir (posni), svjež, Yezerka, Milex', 80, 3.8, 13.4, 0.05),
      ('Sir Edamer Pizza Gourmet, polutvrdi, Paladin, 30% mm', 255, 27, 0, 16),
      ('Sir Edamer, polutvrdi, Paladin, 40% mm', 301, 25, 0, 22),
      ('Sir Gouda, polutvrdi, Paladin, 48% mm', 357, 25.5, 0, 28),
      ('Sir K Plus, svjež, posni, Konzum d.d.', 78, 13, 3, 1.5),
      ('Sir kravlji svježi (cottage)', 95, 14, 3, 3),
      ('Sir kravlji svježi (obrano)', 72, 12.4, 2.7, 1),
      ('Sir Livada (Pomurske mlekarne)', 327, 25.1, 1.4, 24.5),
      ('Sir mladi u salamuri, Poljorad', 66, 13, 2, 0.5),
      ('Sir posni, Ella, mljekara Subotica', 55, 12, 1, 0),
      ('Sir proteinski', 80, 15, 2.2, 1.5),
      ('Sir skuta,  posni, svjež, Pilos, Lidl', 68, 11.8, 4, 0.3),
      ('Sir svježi, Quark Natur Fit, Dukat', 60, 10, 4.5, 0.1),
      ('Sir topljeni, okus Gauda,', 235, 13, 7.5, 17),
      ('Sir u listićima, Lactima (za burgere)', 299, 15, 8, 23),
      ('Sir, danski', 262, 10, 1.5, 25),
      ('Sir, feta, meki (u salamuri)', 263, 14.21, 4.21, 21.32),
      ('Sir, kačkavalj, Mlekovita', 327, 25, 0.5, 25),
      ('Sir, kozji, meki sa plemenitnom plijesni, Caprilo, Vindija', 324, 20.3, 0.4, 26.8),
      ('Sir, meki, punomasni, Grekos, Mlekara Subotica', 183, 11, 2, 14.5),
      ('Sir, mladi President Dukat, Somboled', 115, 12.5, 4, 5.5),
      ('Sir, mladi, kozji, Puđa', 381, 16.33, 1.9, 30.9),
      ('Sir, Mozzarella (mocarela) djelimično obrano mlijeko', 254, 24.26, 2.77, 15.92),
      ('Sir, Mozzarella (mocarela) Premium, Paladin', 265, 19, 1.7, 20),
      ('Sir, Mozzarella (mocarela), Meggle', 228, 17.5, 0.8, 17),
      ('Sir, Mozzarella (mocarela), neobrano punomasno mlijeko', 299, 22.17, 2.4, 22.14),
      ('Sir, polutvrdi (tipa tilzit), Livada', 312, 23, 0, 24),
      ('Sir, polutvrdi, dimljeni, Dimek, Vindija', 352, 26.1, 0.4, 27.6),
      ('Sir, polutvrdi, Gauda, Vindija', 351, 25.3, 0.4, 27.6),
      ('Sir, polutvrdi, Gauda, Zelene Doline', 344, 26, 2.7, 25.5),
      ('Sir, polutvrdi, kravlji, Maasdam (Maasdamer)', 347, 26, 0.1, 27),
      ('Sir, polutvrdi, punomasni, Dimsi, Sirela', 343, 23, 2, 27),
      ('Sir, polutvrdi, Šmarski Rok 30% mm, Zelene Doline', 259, 31.3, 3.1, 13.5),
      ('Sir, polutvrdi, Tilsiter, 45% mm, Royal Orange', 329, 24, 0, 26),
      ('Sir, polutvrdi, Tilzit, Vindija', 340, 24.4, 1.9, 26),
      ('Sir, posni, svjež, mljekara Pilos, Lidl', 82, 14, 2, 2),
      ('Sir, punomasni, Babybel', 295, 22, 0.1, 23),
      ('Sir, Ricotta (rikota), Zanetti', 143, 8.5, 2.5, 11),
      ('Sir, rokfor (roquefort)', 369, 21.54, 2, 30.64),
      ('Sir, švapski', 98, 11.12, 3.38, 4.3),
      ('Sir, svjež, Zagrebački, Dukat', 101, 11, 3, 5),
      ('Sir, svježi (mladi), 5%mm, Milkos', 113, 15, 4, 5),
      ('Sir, svježi, kravlji, punomasni (neobrano mlijeko), Puđa', 251, 16.1, 2.7, 19.5),
      ('Sir, svježi, lajt (light), Meggle', 82, 10, 7.2, 1.5),
      ('Sir, svježi, Moja Kravica, Imlek', 72, 9.6, 3.4, 2.3),
      ('Sir, svježi, posni, Dukat', 78, 11, 4.4, 1.8),
      ('Sir, svježi, zrnati, Cottage, Bayerland', 92, 13, 1, 4),
      ('Sir, svježi, zrnati, Cottage, Dukat', 80, 12, 3.1, 2.2),
      ('Sir, svježi, zrnati, K Plus, Konzum d.d.', 92, 13, 1, 4),
      ('Sir, Trapist Natur, polutvrdi, punomasni, Hajdu', 329, 23, 0.5, 26),
      ('Sir, trapist, polutvrdi, Zelene Doline', 315, 25.5, 2.7, 26.5),
      ('Sir, tvrdi, 32% mm, ribani, San Sebastiano', 368, 32, 0, 26),
      ('Sir, tvrdi, ribanac, Sirela', 426, 41, 3.5, 27.5),
      ('Sirni namaz (20%)', 174, 20, 1, 10),
      ('Sirni namaz (30%)', 219, 20, 1, 15),
      ('Sirni namaz (40%)', 251, 19, 1, 19),
      ('Sirnica (pita sa sirom)', 318, 10.5, 36.6, 14.3),
      ('Sirutka (surutka) svježa', 26, 0.9, 5.1, 0.3),
      ('Sirutka (surutka) u prahu', 349, 12.9, 73.5, 1.1),
      ('Šitake (shiitake) gljive (pečurke)', 34, 2.24, 6.79, 0.49),
      ('Sjemenke (seme) maka', 525, 17.99, 28.13, 41.56),
      ('Sjemenke (seme) susama (sezam)', 573, 17.73, 23.45, 49.67),
      ('Sjemenke bundeve, pečene, slane', 446, 18.55, 53.75, 19.4),
      ('Sjemenke bundeve, suve (sušene), oljuštene', 559, 30.23, 10.71, 49.05),
      ('Sjemenke suncokreta, suve (sušene), oljuštene', 584, 20.78, 20, 51.46),
      ('Škampi', 91, 16.9, 0.5, 1.9),
      ('Škampi (kuvani)', 99, 20.9, 0, 1.1),
      ('Škampi (prženi)', 242, 21.4, 11.5, 12.3),
      ('Škarpina', 91, 19.4, 0, 1),
      ('Škarpina (pečena)', 118, 24.8, 0, 1.3),
      ('Skrob (škrob) kukuruzni, Briž', 381, 0.3, 91.3, 0.1),
      ('Škrpina', 87, 19.3, 0, 0.5),
      ('Skuša (lokarda)', 184, 19, 0, 12),
      ('Skuša fileti, u biljnom ulju, konzervirana, Trend', 219, 21.7, 0, 14.6),
      ('Skuša, fileti sa kožom u biljnom ulju,  konzervirana, Eva', 389, 14, 0, 37),
      ('Skuša, lokarda (pečena)', 262, 23.9, 0, 17.8),
      ('Skyr, jogurt islandski, proteinski, bourbon vanilija, Zbregov', 73, 9.4, 8.2, 0.3),
      ('SL Eurocrem, Takovo', 549, 4.5, 63, 31),
      ('Sladoled', 222, 4.1, 22.2, 13),
      ('Sladoled King, okus pistacija, Harmony, Ledo', 340, 4.2, 31, 21),
      ('Sladoled King, okus višnja, Desire', 350, 3.3, 34, 22),
      ('Sladoled kornet, čokolada, Ledo', 301, 4.8, 33, 16),
      ('Sladoled kornet, vanilija, Ledo', 290, 4.4, 33, 16),
      ('Sladoled Quattro Forte, okus lješnjak, čokolada, crna i bijela i straćatela, Ledo', 217, 3.5, 24.83, 11.33),
      ('Sladoled, Bananica, Frikom', 290, 3.9, 24, 20),
      ('Sladoled, Duo, čokolada/vanilija', 146.3, 2.8, 18.7, 6.7),
      ('Sladoled, Duo, okus lješnjak', 148.33, 3, 15.67, 8),
      ('Sladoled, Gellato, Sicilian-Style, okus vanilijia, domaći sladoled', 141, 4.2, 0.2, 10.7),
      ('Sladoled, HighLife, okus čokolada, Ledo', 134, 5.5, 18, 6.1),
      ('Sladoled, HighLife, okus malina, čokolada, brownie, Ledo', 128, 4.8, 19, 4.7),
      ('Sladoled, HighLife, okus vanilija, Ledo', 130, 5.3, 17, 6.3),
      ('Sladoled, okus čokolada, Carte Dor', 200, 4, 28, 8),
      ('Sladoled, okus čokolada, vanilija i jagodoa, Carte Dor', 181, 2.9, 25, 7.1),
      ('Sladoled, okus jagodoa, Carte Dor', 166, 2.5, 27, 5.3),
      ('Sladoled, Plazma sa preljevom od karamele, Ledo', 252, 4.6, 32, 12),
      ('Sladoled, Rumenko, Frikom', 92, 0, 23, 0),
      ('Sladoled, Snjeguljica, Ledo', 245, 3.9, 22, 16),
      ('Šlag, na bazi biljne masti, Halta', 302, 0.6, 12, 27.9),
      ('Šlag, slatko vrhnje', 257, 3.2, 12.49, 22.22),
      ('Slanina (suva, sušena) masna', 781, 4, 0, 85),
      ('Slanina (suva, sušena) mesnata', 506, 14, 0, 50),
      ('Slanina svinjska (kuvana, pržena, pečena)', 542, 36.84, 1.58, 41.58),
      ('Slanina svinjska (sirova, bez kože)', 784, 3.2, 0, 85.4),
      ('Slanina svinjska (sirova, soljena)', 782, 3.9, 0, 85),
      ('Slatka pavlaka (vrhnje)', 317, 3, 2, 32),
      ('Slatko od trešanja', 287, 0.51, 71.42, 0.06),
      ('Šljiva', 46, 0.7, 11.42, 0.28),
      ('Šljiva suva (sušena)', 240, 2.18, 63.88, 0.38),
      ('Smeđi šećer, nerafinisani, Tamni Muskavado, Vitalija', 347, 0.58, 94.9, 0.09),
      ('Smjesa za Američke palačinke i Vafle, Dolčela, Podravka', 340, 1.2, 83, 0.1),
      ('Smoki, Chocolate Filling, Štark', 497, 9.2, 57, 25),
      ('Smoki, Štark', 521, 13, 50, 29),
      ('Smokva', 74, 0.75, 19.18, 0.3),
      ('Smokva, suva (sušena)', 249, 3.3, 63.87, 0.93),
      ('Smokva, suva (sušena), kuvana', 107, 1.42, 27.57, 0.4),
      ('Smrznuta mješavina povrća, Lidl', 53, 3, 7, 1),
      ('Smuđ', 93, 19.14, 0, 1.22),
      ('Soja fermentirana', 206, 13, 25, 6),
      ('Soja komadići, ljuskice', 357, 52, 31.7, 1.5),
      ('Soja pašteta, okus paprika, Vitas', 272, 3.6, 5.7, 25.9),
      ('Soja protein, Just Protein, Body & Fit', 391, 78.9, 7.4, 4.93),
      ('Soja sjeme (zrno), zrelo, sirovo', 446, 36.49, 30.16, 19.94),
      ('Soja sos, Alnatura', 87, 11, 9.9, 0.1),
      ('Soja sos, Heinz', 246, 2.8, 58, 0),
      ('Soja sos, Tamari', 60, 10.51, 5.57, 0.1),
      ('Soja sos, tamni, Superior Dark, Pearl River Bridge', 144, 5.6, 29.3, 0),
      ('Sojin sir (tofu)', 72, 7.8, 2.5, 4.2),
      ('Sojino brašno (mast ekstrahir.)', 346, 52, 30, 2),
      ('Sojino mlijeko (mleko)', 54, 3.27, 6.28, 1.75),
      ('Sojino mlijeko (mleko), alpro', 39, 3, 2.5, 1.8),
      ('Sojino mlijeko (mleko), bez šećera', 33, 2.86, 1.74, 1.61),
      ('Sojino mlijeko (mleko), čokolada', 63, 2.26, 9.95, 1.53),
      ('Sojino mlijeko (mleko), svi okusi, obogaćeni vitaminima i mineralima', 45, 2.94, 3.45, 1.99),
      ('Sok od borovnice u limenci', 38, 0, 12, 0),
      ('Sok od brusnice', 46, 0.39, 12.2, 0.13),
      ('Sok od cvekle, Domaće, Kuća prirode', 52, 0.23, 12.97, 0),
      ('Sok od grejpa (grejpfrut)', 39, 0.5, 9.2, 0.1),
      ('Sok od grožđa u limenci', 57, 0, 14.55, 0),
      ('Sok od jabuke', 46, 0.1, 11.3, 0.13),
      ('Sok od mrkve', 40, 0.95, 9.28, 0.15),
      ('Sok od narandže, cijeđen', 45, 0.7, 10.4, 0.2),
      ('Sok od narandže, cijeđen, bez pulpe', 21, 0.21, 5.42, 0),
      ('Sok od pomorandže 100%, Life Premium, Nectar', 44, 0.93, 9.19, 0.09),
      ('Som', 95, 16.4, 0, 2.8),
      ('Som (pečen)', 105, 18.5, 0, 2.9),
      ('Som (pohovan)', 229, 18.1, 8, 13.3),
      ('Sos (umak) od bijelog luka, BURCU', 12, 1, 3, 0),
      ('Sos (umak), Barbecue Delicates Sauce, Polimark', 118, 1.5, 24, 1.8),
      ('Sos (umak), Chili, Polimark', 73, 0.4, 8.8, 4),
      ('Sos (umak), Indijski Curry, dm Bio', 95, 1.6, 8.3, 5.5),
      ('Sos (umak), Meksička Salsa, Hot & Spicy, Remia', 84, 1.4, 17, 0.3),
      ('Sos (umak), Meksička Salsa, THOMY', 86, 1.6, 18, 0.5),
      ('Sos (umak), od paradajza sa pečenom paprikom, dm Bio', 48, 1.3, 5, 2.3),
      ('Sos (umak), Salsa Mexican Style, Kuhne', 104, 1.2, 22, 0.1),
      ('Sos od jabuka (jabučni sos), kućna priprava', 70, 0, 18, 0),
      ('Sos paradajz, origano i bosiljak, Polimark', 27, 0.9, 5.5, 0.1),
      ('Špageti, tjestenina', 371, 13.04, 74.67, 1.51),
      ('Špageti, tjestenina, integralne', 330, 12, 62, 1.5),
      ('Šparoge (špargle)', 20, 2.2, 3.88, 0.12),
      ('Šparoge (špargle), smrznute', 24, 3.23, 4.1, 0.23),
      ('Špinat (španać, zelje)', 23, 2.86, 3.63, 0.39),
      ('Špinat (španać, zelje) kuvan, baren, bez soli', 23, 2.97, 3.75, 0.26),
      ('Spirulina alga u prahu, suva (sušena)', 290, 57.47, 23.9, 7.72),
      ('Sprite', 40, 0.05, 10.14, 0.02),
      ('Sriće, jabukovo (jabučni ocat)', 21, 0, 0.93, 0),
      ('Sriracha, ljuti čili sos', 80, 2, 16, 0.5),
      ('Srpska kobasica, Carnex', 267, 16, 1.51, 22),
      ('Štanglica (bar), žitarice + grožđice, Vitanova, Pionir', 413, 5.8, 73.2, 10.6),
      ('Štanglica (bar), žitarice + jagoda, Vitanova, Pionir', 414, 5.3, 72.6, 11),
      ('štapići, slani', 406, 11, 74.4, 6.5),
      ('Štapići, slani, punjeni kikirikijem', 470, 15.6, 55.7, 19.6),
      ('Student mix, Berny', 495, 15.6, 38, 32),
      ('Štuka', 85, 17.4, 0, 1.7),
      ('Štuka (pečena)', 113, 24.7, 0, 0.9),
      ('Šumsko voće, smrznuto, Ledo', 57, 1.1, 11, 0.9),
      ('Šunka bez masti', 153, 28, 0, 4.6),
      ('Šunka dimljena kuvana', 412, 21.1, 0, 36.4),
      ('Šunka dimljena sušena', 434, 22.8, 0, 38.1),
      ('Šunka narezak u konzervi, Podravka', 128, 14, 1.5, 7.3),
      ('Šunka prešana (bez masti)', 129, 15.6, 0.8, 7.1),
      ('Šunka pureća, Slim&fit, Perutnina Ptuj', 85, 15, 4, 0.95),
      ('Šunka pureća/pileća', 128, 19.03, 0.37, 5.09),
      ('Šunka, delikates, Pekabesko', 81, 13, 2.34, 2.2),
      ('Šunka, pureća dimljena, Pik', 98, 19, 1, 2),
      ('Šunka, pureća, Deluxe, Vindon, Vindija', 90, 18, 2.3, 1),
      ('Superior Whey Core Protein, Superior 14 Supplement', 408, 76, 8.5, 8),
      ('Surimi', 99, 15.18, 6.85, 0.9),
      ('Sutlijaš (sutlija, rižin puding)', 108, 3.23, 18.39, 2.15),
      ('Sveži obrani sir, Top Fit', 66, 13, 3, 0.2),
      ('Svinjetina (svinja) divlja', 104, 21, 0, 2),
      ('Svinjetina bez masti', 161, 20, 0, 9),
      ('Svinjetina masna', 371, 14, 0, 35),
      ('Svinjetina srednje masna', 280, 16, 0, 24),
      ('Svinjska pečenica, sušena (suva), suvo meso', 345, 15, 0, 30),
      ('Svinjske pljeskavice', 342, 13.3, 1.7, 30.9),
      ('Svinjski filet', 120, 21, 0, 3.4),
      ('Svinjski kotlet (bez kostiju)', 117, 22.4, 0, 2.3),
      ('Svinjski kotlet (s kostima)', 240, 28.7, 0, 13.1),
      ('Svinjski vrat, suvi (sušeni), suvo meso', 450, 20.8, 1.4, 40.2),
      ('Tahini (taan), pasta (namaz)', 595, 17, 21.19, 53.76),
      ('Tamna (crna) čokolada, đumbir i limun, Eugen', 577, 7.7, 51, 38),
      ('Tapioca Pearls, Gym Beam', 350, 0.5, 86, 0.5),
      ('Tartar umak', 211, 1, 13.3, 16.7),
      ('Tartuf', 37, 4.4, 0.2, 2),
      ('Teleća plećka', 164, 26.1, 0, 5.8),
      ('Teleća rebarca', 177, 25.8, 0, 7.4),
      ('Teleći but', 150, 28.1, 0, 3.4),
      ('Teleći odrezak', 168, 26.3, 0, 6.2),
      ('Teletina bez masti', 113, 21.3, 0, 3.1),
      ('Teletina masna', 204, 18.1, 0, 14.6),
      ('Teletina srednje masna', 160, 19.1, 0, 9.3),
      ('Temeljac pileći, kućna priprava', 36, 2.52, 3.53, 1.2),
      ('Tikvica, zelena', 17, 1.21, 3.11, 0.32),
      ('Tikvica, zelena, kuvana, neslana (bez soli), ocijeđena', 15, 1.14, 2.69, 0.36),
      ('Tjestenina (makaroni),  Penne Rigate, Barilla', 359, 12.5, 71.2, 2),
      ('Tjestenina bez jaja', 336, 10.8, 77.4, 0.3),
      ('Tjestenina kuhana', 141, 4.7, 28.35, 0.6),
      ('Tjestenina sa jajima', 368, 13, 78.6, 2.4),
      ('Tjestenina, integralna, makaron, Ragusa', 330, 12, 62, 1.5),
      ('Tjestenina, špageti, Barilla', 359, 12.8, 70.9, 2),
      ('Tofu, natural, Bio, Vemondo', 129, 13, 1.8, 7.5),
      ('Tofu, Rosso, dmBio', 227, 15, 1.7, 17),
      ('Tonus hljeb (hleb, kruh)', 187, 8.2, 43, 1.4),
      ('Topla čokolada, bijela, Bonito', 376, 1.5, 92, 0.1),
      ('Topla Čokolada, Ciobar, Dr Oetker', 365, 5.1, 78, 2.1),
      ('Topla čokolada, Franck', 369, 5.8, 75, 3.2),
      ('Torta, orandž/čokolada, Manja', 324, 3.1, 37.8, 18.1),
      ('Tortilja Mexicana, Fit', 356, 10.6, 56.99, 8.21),
      ('Tortilja, Durum, Anadolu', 308, 9.3, 4.8, 7.6),
      ('Tortilje (pšenično brašno i sjemenke)', 313, 8.7, 52.4, 7),
      ('Tortilje (pšenično i kukuruzno brašno)', 309, 8.2, 51.2, 7.3),
      ('Tortilje (pšenično i kukuruzno brašno), Deli Sun', 310, 6.6, 50, 8),
      ('Tortilje kukurzne, K-Classic', 308, 10, 51, 6.7),
      ('Tortilje pšenične, Poco Loco', 332, 9.3, 54, 8),
      ('Tortilje, Dijo, Fun & Food', 289, 9.1, 42, 6.5),
      ('Tortilje, integralne, El Grito', 287, 9, 45, 7.5),
      ('Toscana Mix, smrznuto mješano povrće, Frikom', 41, 1.4, 2.8, 2.4),
      ('Tost CLASSIC, Tvojih 5 Minuta, DON DON', 299, 8.4, 55.3, 4.2),
      ('Tost sa sjemenkama, Klas Sarajevo', 273, 10.17, 42.82, 6.88),
      ('Tost sa sjemenkama, Tvojih 5 Minuta, DON DON', 299, 8.5, 51.5, 5.5),
      ('Tost, cjelovite žitarice, Tvojih 5 Minuta, DON DON', 247, 9.5, 43, 3),
      ('Tost, integralni, Mulino Bianco', 260, 10.8, 37.8, 5.5),
      ('Tost, Pan Baulleto Bianco, Mulino Bianco', 268, 8.5, 49, 3.2),
      ('Tost, PanCarre, Mulino Bianco', 287, 7.5, 50.5, 5.2),
      ('Tost, pšenično brašno', 313, 12.96, 55.77, 4.27),
      ('Trešnja', 63, 1.06, 16.01, 0.2),
      ('Trlja blatarica', 139, 16, 1.1, 7.9),
      ('Trlja kamenjarka (barbun)', 109, 15.7, 1.2, 4.6),
      ('True Whey Protein, GymBeam, Cookies & Cream', 387, 74, 14, 4),
      ('True Whey, GymBeam, Chocolate (čokolada)', 379, 74, 8.5, 4.7),
      ('True Whey, GymBeam, Čokolada', 389, 74, 8.9, 5.6),
      ('True Whey, GymBeam, okus bijela čokolada i malina', 388, 74, 12.1, 5.1),
      ('True Whey, GymBeam, Vanilija', 384, 76, 6.9, 5.9),
      ('Tuna komadi u sopstvenom soku, konzervisana, Marco Polo', 71, 17, 0, 0.3),
      ('Tuna salata, Balance, Eva, Podravka', 150, 11, 9, 6),
      ('Tuna salata, Protein, Eva, Podravka', 206, 13, 9, 12),
      ('Tuna steak u maslinovom ulju, Franz Josef', 162, 27, 0, 5.9),
      ('Tunjevina, tuna, konzervirana u ulju, neocijeđena', 403, 17.5, 0, 37),
      ('Tunjevina, tuna, konzervirana u ulju, ocijeđena', 186, 26.6, 0, 8.09),
      ('Tunjevina, tuna, konzervirana, s povrćem', 197, 9, 6.5, 13),
      ('Tunjevina, tuna, konzervirana, u salamuri', 90, 19.68, 0, 0.909),
      ('Tunjevina, tuna, konzervirana, u sopstvenom sosu', 128, 23.62, 0, 2.97),
      ('Tunjevina, tuna, odrezak, svjež (sirov), Ledo', 110, 27.2, 0.01, 0.2),
      ('Tunjevina, tuna, pečena', 139, 30, 0, 1.2),
      ('Tunjevina, tuna, sirova', 144, 23.33, 0, 4.9),
      ('Ugor', 147, 19.1, 0.1, 7.8),
      ('Ulje bakalara iz jetre', 902, 0, 0, 100),
      ('Ulje bučino (ulje iz sjemenki bundeve)', 857, 0, 0, 100),
      ('Ulje haringe', 902, 0, 0, 100),
      ('Ulje kanole (kanolino ulje)', 884, 0, 0, 100),
      ('Ulje kikiriki (ulje od kikirikija)', 884, 0, 0, 100),
      ('Ulje kukuruzno (ulje od kukuruznih klica)', 900, 0, 0, 100),
      ('Ulje lana (Laneno ulje)', 884, 0.11, 0, 99.98),
      ('Ulje maslinovo', 884, 0, 0, 100),
      ('Ulje od kokosa (kokosovo ulje)', 892, 0, 0, 99.06),
      ('Ulje od koštica (sjemenki) grožđa', 884, 0, 0, 100),
      ('Ulje od pšeničnih klica', 884, 0, 0, 100),
      ('Ulje palmino', 884, 0, 0, 100),
      ('Ulje repino', 900, 0, 0, 99.9),
      ('Ulje sojino', 884, 0, 0, 100),
      ('Ulje suncokretovo', 884, 0, 0, 100),
      ('Ulje susamovo (sezamovo)', 884, 0, 0, 100),
      ('Umak, Pesto alla Genovese, Barilla', 514, 5, 5.5, 62),
      ('Vafel sa lješnjakom, Hanuta, Ferrero', 542, 7.6, 54, 31.9),
      ('Vegan protein 100%, Scitec Nutrition', 390, 68, 10, 8),
      ('Vegan protein, Chocolate Flavour (čokolada), Proteini.si', 394, 64, 9.8, 9.9),
      ('Vegeta, Podravka', 137, 8.5, 32, 0.5),
      ('Vino crno (crveno)', 85, 0.07, 2.61, 0),
      ('Vino, bijelo (belo)', 82, 0.07, 2.6, 0),
      ('Viski', 250, 0, 0.1, 0),
      ('Višnja', 50, 1, 12.18, 0.3),
      ('Visokoproteinski hljeb, Klas Sarajevo', 262, 14, 39.03, 5.77),
      ('Vivis, svježi krem sir, namaz, Zbregov, Vindija', 258, 6.6, 2.8, 24.5),
      ('Voćni jogurt, Jagoda, Imlek', 63, 2.7, 11.8, 0.6),
      ('Voćni sos, mix (jabuka, malina, jagoda, cvekla), Nutrino Lab', 85, 1.1, 16, 0.9),
      ('Vodka', 231, 0, 0, 0),
      ('Vrganj', 82, 7.39, 9.5, 1.7),
      ('Vrhnje za kuvanje, Brzo & Fino, Dukat', 206, 2.5, 4, 20),
      ('Vrhnje za kuvanje, lagano (light), Brzo & Fino, Dukat', 125, 2.9, 5.7, 10),
      ('Vrhnje za šlag, Brzo & Fino, Dukat', 317, 2.2, 2.7, 33),
      ('Whey protein Isolate 90, gonutrition', 363, 88.3, 3.3, 1.5),
      ('Whey Protein Plus, Equilibra', 353, 64, 17, 2.1),
      ('Whey protein, Activlab Muscle Up Protein', 386, 70, 13, 6),
      ('Whey Protein, Battery Rebel, Proteini Si', 373, 79, 12, 0.3),
      ('Whey protein, Isolate, sa okusom, Pure Series, Bulk Powders', 382, 87, 4, 2),
      ('Whey protein, sa okusom Vanile, Pure Series, Bulk Powders', 417, 77.2, 7.8, 7.5),
      ('Žablji kraci', 73, 16.4, 0, 0.3),
      ('Želatin', 61, 1.2, 14, 0),
      ('Zimska kobasica', 535, 21, 0, 50),
      ('Žitarice bez glutena, Sharkies, Hookies, gullon', 459, 1.9, 75, 16),
      ('Žitarice Nesquik, Choco Crunchy, Nestle', 378, 8.7, 74.6, 3),
      ('Žitarice, Froot Loops, Unicorn, Kelloggs', 385, 8.3, 79, 3),
      ('Žitarice, Lino jastučići (Pillows Milk), Lino Lada, Podravka', 446, 7, 72, 14),
      ('Žito, kuvano (sa orasima i šlagom), desert', 425, 11.2, 62, 17),
      ('Zobene (ovsene), pahuljice, krupne, Biofor', 392, 10.94, 68.8, 7.73),
      ('Zobene klice sa mekinjama, biofor', 246, 17.3, 66, 7),
      ('Zobeni (ovseni) keksi s brusnicom, BOOM BOX', 449, 9.7, 56, 18),
      ('Žumance (žumanjak) kokošje', 322, 15.86, 3.59, 26.54),

    ];
    final batch = db.batch();
    for (final (name, kcal, protein, carbs, fat) in foods) {
      batch.insert('food_definitions', {
        'name': name,
        'calories_per_100g': kcal,
        'protein_per_100g': protein,
        'carbs_per_100g': carbs,
        'fat_per_100g': fat,
      });
    }
    await batch.commit(noResult: true);
  }

  // ── Food definitions ──────────────────────────────────────────────────────────────────────────

  Future<List<FoodDefinition>> getAllFoodDefinitions() async {
    final db = await database;
    final rows = await db.query('food_definitions', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(FoodDefinition.fromMap).toList();
  }

  Future<List<FoodDefinition>> searchFoodDefinitions(String query) async {
    final db = await database;
    final rows = await db.query(
      'food_definitions',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(FoodDefinition.fromMap).toList();
  }

  Future<int> insertFoodDefinition(FoodDefinition def) async {
    final db = await database;
    return db.insert('food_definitions', def.toMap());
  }

  Future<void> updateFoodDefinition(FoodDefinition def) async {
    final db = await database;
    await db.update('food_definitions', def.toMap(), where: 'id = ?', whereArgs: [def.id]);
  }

  Future<void> deleteFoodDefinition(int id) async {
    final db = await database;
    await db.delete('food_definitions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Meals ─────────────────────────────────────────────────────────────────────────────────────

  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return db.insert('meals', meal.toMap());
  }

  Future<List<Meal>> getMealsForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('meals', where: 'date LIKE ?', whereArgs: ['$dateStr%'], orderBy: 'date ASC');
    final meals = <Meal>[];
    for (final row in rows) {
      final meal = Meal.fromMap(row);
      final items = await getFoodItemsForMeal(meal.id!);
      meals.add(meal.copyWith(foodItems: items));
    }
    return meals;
  }

  Future<List<Meal>> getMealsForDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'meals',
      where: "substr(date, 1, 10) BETWEEN ? AND ?",
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    final meals = <Meal>[];
    for (final row in rows) {
      final meal = Meal.fromMap(row);
      final items = await getFoodItemsForMeal(meal.id!);
      meals.add(meal.copyWith(foodItems: items));
    }
    return meals;
  }

  Future<void> deleteMeal(int id) async {
    final db = await database;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  // ── Food items ────────────────────────────────────────────────────────────────────────────────

  Future<int> insertFoodItem(FoodItem item) async {
    final db = await database;
    return db.insert('food_items', item.toMap());
  }

  Future<List<FoodItem>> getFoodItemsForMeal(int mealId) async {
    final db = await database;
    final rows = await db.query('food_items', where: 'meal_id = ?', whereArgs: [mealId]);
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<void> deleteFoodItem(int id) async {
    final db = await database;
    await db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalCaloriesForDate(DateTime date) async {
    final meals = await getMealsForDate(date);
    return meals.fold<double>(0.0, (sum, m) => sum + m.totalCalories);
  }

  // ── Sleep ───────────────────────────────────────────────────────────────────────────────────────

  Future<SleepEntry?> getSleepForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('sleep_entries', where: 'date LIKE ?', whereArgs: ['$dateStr%']);
    if (rows.isEmpty) return null;
    return SleepEntry.fromMap(rows.first);
  }

  Future<List<SleepEntry>> getRecentSleep(int days) async {
    final db = await database;
    final rows = await db.query('sleep_entries', orderBy: 'date DESC', limit: days);
    return rows.map(SleepEntry.fromMap).toList();
  }

  Future<List<SleepEntry>> getSleepForDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'sleep_entries',
      where: "substr(date, 1, 10) BETWEEN ? AND ?",
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    return rows.map(SleepEntry.fromMap).toList();
  }

  Future<void> upsertSleep(SleepEntry entry) async {
    final db = await database;
    await db.insert('sleep_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSleep(int id) async {
    final db = await database;
    await db.delete('sleep_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ── Weight ────────────────────────────────────────────────────────────────────────────────────

  Future<List<WeightEntry>> getRecentWeight(int days) async {
    final db = await database;
    final rows = await db.query('weight_entries', orderBy: 'date DESC', limit: days);
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<WeightEntry?> getWeightForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('weight_entries', where: 'date LIKE ?', whereArgs: ['$dateStr%']);
    if (rows.isEmpty) return null;
    return WeightEntry.fromMap(rows.first);
  }

  Future<List<WeightEntry>> getWeightForDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'weight_entries',
      where: "substr(date, 1, 10) BETWEEN ? AND ?",
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<int> insertWeight(WeightEntry entry) async {
    final db = await database;
    return db.insert('weight_entries', entry.toMap());
  }

  Future<void> deleteWeight(int id) async {
    final db = await database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ── Training ──────────────────────────────────────────────────────────────────────────────────

  Future<List<TrainingEntry>> getTrainingForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('training_entries', where: 'date LIKE ?', whereArgs: ['$dateStr%'], orderBy: 'date ASC');
    return rows.map(TrainingEntry.fromMap).toList();
  }

  Future<List<TrainingEntry>> getTrainingForDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'training_entries',
      where: "substr(date, 1, 10) BETWEEN ? AND ?",
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    return rows.map(TrainingEntry.fromMap).toList();
  }

  Future<List<TrainingEntry>> getRecentTraining(int days) async {
    final db = await database;
    final rows = await db.query('training_entries', orderBy: 'date DESC', limit: days);
    return rows.map(TrainingEntry.fromMap).toList();
  }

  Future<int> insertTraining(TrainingEntry entry) async {
    final db = await database;
    return db.insert('training_entries', entry.toMap());
  }

  Future<void> deleteTraining(int id) async {
    final db = await database;
    await db.delete('training_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ── Meal plans ──────────────────────────────────────────────────────────────────────────────────

  Future<int> insertMealPlan(MealPlan plan) async {
    final db = await database;
    return db.insert('meal_plans', plan.toMap());
  }

  Future<void> updateMealPlan(MealPlan plan) async {
    final db = await database;
    await db.update('meal_plans', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
  }

  Future<void> deleteMealPlan(int id) async {
    final db = await database;
    await db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<MealPlan?> getMealPlanForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('meal_plans',
        where: 'date LIKE ?', whereArgs: ['$dateStr%'], limit: 1);
    if (rows.isEmpty) return null;
    final plan = MealPlan.fromMap(rows.first);
    final items = await getPlanItems(plan.id!);
    return plan.copyWith(items: items);
  }

  Future<List<MealPlan>> getAllMealPlans() async {
    final db = await database;
    final rows = await db.query('meal_plans', orderBy: 'date DESC');
    final plans = <MealPlan>[];
    for (final row in rows) {
      final plan = MealPlan.fromMap(row);
      final items = await getPlanItems(plan.id!);
      plans.add(plan.copyWith(items: items));
    }
    return plans;
  }

  // ── Plan items ──────────────────────────────────────────────────────────────────────────────────

  Future<void> insertPlanItems(List<PlanItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('plan_items', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updatePlanItemOptimal(int itemId, double optimalGrams) async {
    final db = await database;
    await db.update('plan_items', {'optimal_grams': optimalGrams},
        where: 'id = ?', whereArgs: [itemId]);
  }

  Future<List<PlanItem>> getPlanItems(int planId) async {
    final db = await database;
    final rows = await db
        .query('plan_items', where: 'plan_id = ?', whereArgs: [planId]);
    return rows.map(PlanItem.fromMap).toList();
  }
}
