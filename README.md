# Prep-Ethiopia Backend & Database Schema

This repository contains the database DDL schema and local storage model configurations for building a high-powered, offline-first educational platform tailored for students in Ethiopia.

---

## 1. Directory Structure

```
.
├── lib/
│   └── core/
│       ├── database/
│       │   └── isar_models.dart      # Isar local database models (Dart)
│       └── utils/
│           └── fast_hash.dart        # Deterministic UUID-to-int64 hash
├── README.md                          # Setup & verification guide
├── seed_data.sql                      # Mock data for Ethiopian Grade 9 curriculum
└── supabase_schema.sql                # Supabase PostgreSQL database schema DDL
```

---

## 2. Supabase Backend Setup (PostgreSQL)

### Steps to Deploy
1. **Initialize Supabase**: Sign in to the [Supabase Dashboard](https://supabase.com) and create a new project.
2. **Execute Database DDL**:
   - Navigate to the **SQL Editor** in the Supabase Dashboard.
   - Click "New Query".
   - Copy the contents of [`supabase_schema.sql`](file:///c:/Users/eyobk/OneDrive/Documents/Prep-Ethiopia/supabase_schema.sql) and paste them into the editor.
   - Click **Run** to execute. This sets up the tables, triggers, indexes, and Row-Level Security (RLS) policies.
3. **Execute Mock Seed Data**:
   - Open another "New Query" in the SQL Editor.
   - Copy the contents of [`seed_data.sql`](file:///c:/Users/eyobk/OneDrive/Documents/Prep-Ethiopia/seed_data.sql) and paste them.
   - Click **Run** to populate Grade 9 Mathematics data with dynamic translations (Amharic & English) and default feature flags.

---

## 3. Client Local Storage Setup (Isar Database)

The app utilizes **Isar** as the high-performance local relational storage engine.

### Prerequisites
Make sure your Flutter project's `pubspec.yaml` has the following dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0

dev_dependencies:
  isar_generator: ^3.1.0
  build_runner: ^2.4.0
```

### Code Generation
Because Isar uses compile-time generators, you need to run the `build_runner` command to generate the model adapters (`isar_models.g.dart`):

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 4. Key Offline-First Concepts

### 1. Deterministic Primary Keys
Isar requires a 64-bit integer (`Id`) as its primary key. To bridge this with Supabase's `UUID` format, we use a FNV-1a deterministic hashing algorithm ([`fast_hash.dart`](file:///c:/Users/eyobk/OneDrive/Documents/Prep-Ethiopia/lib/core/utils/fast_hash.dart)):
```dart
int id = fastHash(uuidString);
```
This enables references to be generated offline on the client without contacting the server first, resolving offline relation-mapping instantly.

### 2. Multi-lingual Support
To allow the addition of regional Ethiopian languages later without DB migrations, all curriculum content fields use PostgreSQL `JSONB` maps. In Dart, these map to `Map<String, String>` structures.

To resolve translations locally in the UI, use the helper extension:
```dart
String title = unit.title.getLocalized(activeLanguageCode); // Falls back to English if locale is missing
```

### 3. Timestamp Delta-Sync & Dirty Flags
Each local progress collection contains:
- `isDirty`: Set to `true` when updated offline. When a connection is detected, the sync worker uploads dirty records to Supabase.
- `isDeleted`: Soft delete indicator to sync deletions.
- `updatedAt`: Combined with Last-Write-Wins (LWW) resolution.
