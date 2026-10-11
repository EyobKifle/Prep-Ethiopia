# Prep-Ethiopia (Lumo) — Codebase Audit Report

**Date:** 2026-08-30  
**Project:** Prep-Ethiopia (Lumo) — Offline-first educational platform for Ethiopia  
**Stack:** Flutter (Dart), Riverpod, go_router, Isar, Supabase, Llama.cpp Dart, SQLite-vec  

---

## 1. Executive Summary

The codebase is a mature, feature-rich Flutter application with a clear offline-first architecture. However, it contains **critical architectural contradictions**, **runtime-crash risks**, **security issues**, and **schema mismatches** between the Flutter client, the Supabase backend schema, and the seed data. Several issues will prevent the app from compiling or running correctly without remediation.

---

## 2. Critical Issues (Must Fix)

### 2.1 Supabase SDK Conflict
- **`lib/main.dart`** (lines 20-26) calls `Supabase.initialize(...)` and uses the Supabase Flutter SDK.
- **`lib/core/network/supabase_client.dart`** (lines 3-7) claims *"Supabase SDK removed from the Flutter client"* and returns `null`.
- **`lib/features/auth/auth_provider.dart`** (lines 53-56, 62, 75, 135, 180, 209) still imports `supabase_flutter` and uses `Supabase.instance.client`, `_supabase.auth.onAuthStateChange`, `_supabase.auth.currentSession`, and `_supabase.auth.setSession(...)`.
- **`lib/core/network/remote_api_service.dart`** (lines 195-201) calls `Supabase.instance.client.storage.from(...).uploadBinary(...)` for file uploads.

**Impact:** The app will crash at runtime if `supabase_client.dart` returns `null` but other files expect a real `SupabaseClient`. The comment in `supabase_client.dart` is factually incorrect and misleading.

### 2.2 Missing Isar Schemas
- **`lib/core/database/isar_models.dart`** defines `AiChatLocal` and `AiMessageLocal` (lines 678-718).
- **`lib/main.dart`** (lines 30-57) opens 21 schemas but omits `AiChatLocalSchema` and `AiMessageLocalSchema`.

**Impact:** Any attempt to write AI chat/message data to Isar will throw an `IsarError` at runtime.

### 2.3 Hash Algorithm Inconsistency
- **`lib/core/utils/fast_hash.dart`** implements a **64-bit** FNV-1a hash (offset basis `0xcbf29ce484222325`, prime `0x100000001b3`).
- **`lib/core/database/isar_models.dart`** (lines 8-16) implements an inline **32-bit** FNV-1a hash (offset basis `0x811C9DC5`, prime `0x01000193`).

**Impact:** All Isar IDs are computed with the 32-bit version, not the utility. The utility file is dead code. 32-bit hashes have a much higher collision probability (~4 billion vs ~18 quintillion keyspace).

### 2.4 LocalizedMap Extension Type Bug
- **`lib/core/database/isar_models.dart`** (line 22):
  ```dart
  return this[languageCode] ?? this['en'] ?? values.firstOrNull ?? '';
  ```
  `values.firstOrNull` returns a `MapEntry<String, String>?`, not a `String`.

**Impact:** This line will throw a type error at runtime when neither the language code nor `'en'` is present in the map.

### 2.5 RAG Service Logic Bug
- **`lib/core/ai/rag_service.dart`** (line 90):
  ```dart
  if (!_db == null) return;
  ```
  `!_db` negates the nullable `Database?` (which throws if null), then compares a `bool` to `null` (always `false`). The intended check `if (_db == null) return;` is never reached.

**Impact:** If `initialize()` fails and `_db` remains `null`, `insertChunk` will throw a `NoSuchMethodError` on `_db!.execute(...)`.

### 2.6 Real Credentials Committed
- **`.env`** contains production Supabase credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`).

**Impact:** These are real secrets exposed in version control. They must be rotated immediately and excluded via `.gitignore`.

---

## 3. High-Priority Bugs

### 3.1 Async `void` Methods (Fire-and-Forget)
- **`lib/features/sync/sync_service.dart`** (line 55): `_calculatePendingItems()` is `void` but `async`. It is called in the constructor (line 52) without `await`, so exceptions are unhandled and state updates may race.
- **`lib/core/network/connectivity_service.dart`** (line 16): `_initConnectivity()` is `void` but `async`. Same fire-and-forget risk.

### 3.2 Teacher Role Missing from Database Schema
- **`supabase_schema.sql`** defines `user_role` enum as `('student', 'admin', 'parent')`.
- **`lib/core/router/app_router.dart`** (lines 63, 74, 78, 80) explicitly handles `role == 'teacher'`.
- **`seed_data.sql`** has no teacher accounts.

**Impact:** Teachers cannot sign up or be assigned roles in the database. The role check in routing is dead code for the teacher path.

### 3.3 Auth Session Restoration is Incorrect
- **`lib/features/auth/auth_provider.dart`** (lines 135, 180):
  ```dart
  await _supabase.auth.setSession(response.refreshToken!);
  ```
  Supabase GoTrue's `setSession` expects an **access token**, not a refresh token. Passing a refresh token will cause auth to fail silently or throw.

### 3.4 Partial Sync Failure Leaves Dirty Flags uncleared
- **`lib/features/sync/sync_service.dart`** `_pushUserProgress` and `_pushCurriculum` clear `isDirty = false` only after a successful API call. If the API call throws, dirty items remain dirty and will be retried indefinitely.

### 3.5 No Auth Headers on API Requests
- **`lib/core/network/remote_api_service.dart`** `_invoke` (line 12) sets only `apikey`, `Content-Type`, and `Accept`. It never sends the user's access token.

**Impact:** Backend endpoints that require authentication will reject requests with `401 Unauthorized`.

### 3.6 `POST` Used for Read Operations
- **`lib/core/network/remote_api_service.dart`** uses `_dio.post(...)` for **all** endpoints (lines 27-31), including `fetchFeatureFlags` and `fetchCurriculumIncremental`, which should be `GET`.

### 3.7 AppDiagnosticsLogLocal ID Inconsistency
- **`lib/core/database/isar_models.dart`** (line 490):
  ```dart
  class AppDiagnosticsLogLocal {
    Id id = Isar.autoIncrement;
    ...
  }
  ```
  Every other collection uses `Id get id => fastHash(uuid);`. This model has no `uuid` field and uses auto-increment, which breaks the deterministic-ID convention.

---

## 4. Security Issues

| Issue | File | Line(s) | Severity |
|-------|------|---------|----------|
| Production Supabase credentials in `.env` | `.env` | — | **Critical** |
| `verify_jwt = false` in Edge Function config | `supabase/config.toml` | — | **High** |
| Service role key in client-side `.env` | `.env` | — | **High** |
| No token refresh / expiry handling | `remote_api_service.dart` | — | Medium |
| Auth tokens not attached to requests | `remote_api_service.dart` | 12-16 | **High** |
| `supabase_service_role_key` exposed to client | `.env` | — | **Critical** |

---

## 5. Data Model Issues

### 5.1 Late Field Initialization Risks
The following `late` fields will throw at runtime if not initialized before `put()`:
- `UserProgressLocal.isCompleted`
- `QuizAttemptLocal.submittedAt`
- `ExamAttemptLocal.submittedAt`
- `ExamAttemptLocal.maxScore`
- `WorksheetAttemptLocal.submittedAt`
- `ParentStudentLinkLocal.linkedAt`
- `AiChatLocal.createdAt`, `updatedAt`
- `AiMessageLocal.createdAt`
- `StepLocal.contentMarkdownJson` (getter decodes as `Map<String, String>`)

### 5.2 Models Missing Sync Metadata
- `AiChatLocal` and `AiMessageLocal` lack `isDirty`, `isDeleted`, and `updatedAt`.
- `FeatureFlagLocal` lacks `isDirty`.
- `TextbookNoteLocal` and `TextbookHighlightLocal` are pushed in sync but never pulled.

### 5.3 Schema vs. Model Mismatches
| Backend Schema | Flutter Model | Mismatch |
|----------------|---------------|----------|
| `profiles.grade_level` | `ProfileLocal.selectedGradeLevel` | Field name differs |
| `steps.content_markdown` (JSONB) | `StepLocal.contentMarkdownJson` (String) | OK, but no type safety |
| `units.textbook_pdf_url` (JSONB) | `UnitLocal.textbookPdfUrlJson` | OK, but not synced in pull |
| `worksheets.pdf_url` | `WorksheetLocal.pdfUrlJson` | Backend uses string, client uses JSON map |
| `user_role` enum | Hardcoded strings | No enum safety |

### 5.4 32-bit Hash Collision Risk
With 23 collections using 32-bit FNV-1a, the probability of UUID collision grows with dataset size. A 32-bit hash space (~4B values) is insufficient for a production app with thousands of records.

---

## 6. UI / UX Issues

### 6.1 Onboarding Auto-Advance
- **`lib/features/auth/presentation/onboarding_screen.dart`** (line 493): Grade selection automatically calls `_nextStep()`, which may surprise users who expect to review their choice.
- **`onboarding_screen.dart`** (line 379, 391): Language selection also auto-advances.

### 6.2 Race Conditions
- **`subject_detail_screen.dart`** `_loadSubjectData()` is not debounced. Rapid navigation or widget rebuilds can trigger overlapping loads.
- **`onboarding_screen.dart`** `_startSimulatedDownload` calls `_loadSubjectData` indirectly via sync, but doesn't await it before `context.go('/student')`.

### 6.3 Hardcoded Strings
Multiple screens use hardcoded strings instead of `context.tr(...)`:
- `onboarding_screen.dart` lines 240, 246, 252, 260, 269, 278, 286, 519
- `subject_detail_screen.dart` lines 197, 570
- `student_shell.dart` lines 191, 285

### 6.4 Null Locale Access
- `subject_detail_screen.dart` lines 136, 201, 270, 348, 367: `context.currentLocale` is accessed without null checks. If `localeProvider` is in an invalid state, this will crash.

### 6.5 Commented-Out Code
- `onboarding_screen.dart` line 25: `// bool _isDownloading = false;`

---

## 7. Testing Gaps

- **`test/widget_test.dart`**: Only verifies `MaterialApp` builds. No navigation, no state, no data layer tests.
- **`test/auth_provider_test.dart`**: Good coverage for `AuthNotifier`, but mocks `Isar` at the collection level without testing `isar_models.dart` serialization.
- **No tests for:** `SyncNotifier`, `RemoteApiService`, `ConnectivityNotifier`, `AiService`, `RagService`, any UI screen, or routing guards.

---

## 8. Dependency & Build Issues

| Issue | Detail |
|-------|--------|
| **`isar_models.g.dart`** | Code-generated file exists but may be stale if models were edited after last build. Must run `flutter pub run build_runner build`. |
| **`pubspec.yaml`** line 25-26 | `isar_community` and `isar_community_flutter_libs` versions match, but generator version (`isar_community_generator` ^3.3.2) must match the Isar version exactly. |
| **`pubspec.yaml`** line 44 | `llama_cpp_dart: ^0.1.2` is an early version with limited platform support (may fail on iOS/Web). |
| **`pubspec.yaml`** line 45-47 | `sqlite_vector`, `sqlite3`, `sqflite_common_ffi` combination is platform-sensitive. `sqflite_common_ffi` is desktop-only; mobile uses `sqlite3` via FFI directly. |
| **Dead code** | `lib/core/utils/fast_hash.dart` is unused (models use inline 32-bit hash instead). |
| **Legacy backend** | `prep-ethiopia-backend/` is a default Next.js scaffold with no custom API routes. The actual backend is Supabase Edge Functions. |

---

## 9. Recommended Fixes (Priority Order)

### P0 — Fix Before Any Other Work
1. **Remove real credentials from `.env`** and rotate all keys.
2. **Resolve Supabase SDK conflict**: Either fully migrate to `RemoteApiService` (remove `supabase_flutter` from `main.dart` and `auth_provider.dart`) or restore the SDK usage and remove the misleading comment.
3. **Add missing Isar schemas** in `main.dart`: `AiChatLocalSchema`, `AiMessageLocalSchema`.
4. **Fix `LocalizedMap` extension** in `isar_models.dart` line 22:
   ```dart
   return this[languageCode] ?? this['en'] ?? values.values.firstOrNull ?? '';
   ```
5. **Fix RAG service** `rag_service.dart` line 90:
   ```dart
   if (_db == null) return;
   ```
6. **Unify hash function**: Delete the inline 32-bit hash in `isar_models.dart` and import/use `fastHash` from `core/utils/fast_hash.dart`. Accept the collision risk or migrate to 128-bit (e.g., use full UUID as string key with a separate auto-increment `Id`).

### P1 — Fix Before Production
7. **Add `teacher` to `user_role` enum** in `supabase_schema.sql` and `seed_data.sql`.
8. **Fix auth session restoration**: Use access token, not refresh token, in `setSession`.
9. **Attach access token to API requests** in `remote_api_service.dart`.
10. **Change `_invoke` to use `GET`** for read-only endpoints (`fetchFeatureFlags`, `fetchCurriculumIncremental`, `pullRemoteProgress`, `fetchAdminUserList`, `fetchChildProgress`).
11. **Add `isDirty` to `FeatureFlagLocal`, `AiChatLocal`, `AiMessageLocal`** and include them in sync.
12. **Mark `_calculatePendingItems` and `_initConnectivity` as `void` without `async`**, or properly `await` them and handle errors.
13. **Remove `supabase_service_role_key` from `.env`** and move it to a secure backend-only location.
14. **Set `verify_jwt = true`** in `supabase/config.toml` for the `dynamic-api` function.

### P2 — Fix Before Beta
15. **Add null safety** for `context.currentLocale` across all screens.
16. **Replace hardcoded strings** with `context.tr(...)`.
17. **Debounce `_loadSubjectData`** in `subject_detail_screen.dart` and `_startSimulatedDownload` in `onboarding_screen.dart`.
18. **Add error boundaries** and global crash reporting.
19. **Write integration tests** for routing guards, sync flow, and onboarding.
20. **Remove dead code**: commented-out `_isDownloading`, unused `fast_hash.dart`, `setAuthToken` no-op in `RemoteApiService`.

---

## 10. Schema / API Contract Mismatches

| Flutter Sends | Backend Expects | Backend Returns | Flutter Reads |
|---------------|-----------------|-----------------|---------------|
| `step_uuid` | `step_uuid` | `id` or `uuid` | `id` or `uuid` |
| `updated_at` | `updated_at` | `updated_at` | `updatedAt` |
| `is_deleted` | `is_deleted` | — | `isDeleted` |
| `name` (JSON map) | `name` (JSONB) | `name` (JSONB) | `nameJson` |
| `options` (List<String>) | `options` (JSONB) | `options` (JSONB) | `optionsJson` |

The sync layer handles snake_case ↔ camelCase and JSON ↔ String marshalling correctly in most places, but `_pullCurriculum` sets `updatedAt = DateTime.now()` for every pulled record, which will mark everything as dirty on the next sync cycle.

---

## 11. Architecture Observations

- **Offline-first design is sound**: Isar local DB + dirty flags + delta sync is the correct pattern.
- **Hybrid Supabase approach is fragile**: Using the Supabase SDK for auth/storage while also building a custom `RemoteApiService` creates dual dependencies. Pick one approach.
- **No retry/backoff**: `SyncNotifier` retries immediately on failure. A production app needs exponential backoff and a retry queue.
- **No conflict resolution**: LWW (Last-Write-Wins) is assumed but not enforced. Concurrent edits from two devices will overwrite each other silently.
- **No background sync**: Sync only triggers on connectivity change and manual pull. A periodic background sync (e.g., every 15 min when online) is missing.

---

## 12. File Inventory

| Path | Status |
|------|--------|
| `lib/main.dart` | Initializes Supabase + Isar; missing 2 schemas |
| `lib/core/database/isar_models.dart` | 23 models; has bugs in `LocalizedMap`, hash, late fields |
| `lib/core/database/isar_models.g.dart` | Generated; may be stale |
| `lib/core/database/isar_provider.dart` | Simple override provider |
| `lib/core/database/seed_data.dart` | Seeds Grades 7-12 Math |
| `lib/core/ai/ai_service.dart` | Llama.cpp wrapper |
| `lib/core/ai/rag_service.dart` | SQLite-vec wrapper; has `_db == null` bug |
| `lib/core/router/app_router.dart` | go_router config; handles teacher role |
| `lib/core/theme/app_theme.dart` | Notion-style light/dark theme |
| `lib/core/localization/app_localizations.dart` | EN + AM translations |
| `lib/core/network/remote_api_service.dart` | Dio client; no auth headers, POST-only |
| `lib/core/network/connectivity_service.dart` | Async void init |
| `lib/core/network/supabase_client.dart` | Stub returning null |
| `lib/core/network/api_models.dart` | AuthResponse + exceptions |
| `lib/core/utils/fast_hash.dart` | 64-bit FNV-1a; unused by models |
| `lib/features/auth/auth_provider.dart` | Uses Supabase SDK; auth flow bugs |
| `lib/features/sync/sync_service.dart` | Sync engine; async void, partial failure risks |
| `lib/features/student/...` | 11 screens; some hardcoded strings, race conditions |
| `lib/features/admin/...` | 6 screens |
| `lib/features/parent/...` | 3 screens |
| `test/auth_provider_test.dart` | 7 unit tests for AuthNotifier |
| `test/widget_test.dart` | Trivial smoke test |
| `.env` | **Contains real credentials — must rotate** |
| `supabase_schema.sql` | 464-line schema; missing teacher role |
| `seed_data.sql` | 191-line seed; no teacher accounts |
| `prep-ethiopia-backend/` | Empty Next.js scaffold |

---

*End of audit.*
