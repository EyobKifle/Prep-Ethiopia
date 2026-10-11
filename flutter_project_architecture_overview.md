# Project Structure: Ethiopian Offline Educational Platform

# Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** Riverpod
- **Routing:** go_router
- **Database:** Isar
- **Backend:** Supabase

# Directory Layout
- `lib/core/database/`: Isar initialization and FNV-1a hashing.
- `lib/core/network/`: Supabase client and connectivity monitoring.
- `lib/core/theme/`: High-contrast "Notion-style" light/dark themes.
- `lib/core/localization/`: Amharic & English translations.
- `lib/core/router/`: Responsive go_router configuration.
- `lib/features/auth/`: Authentication flow.
- `lib/features/sync/`: Sync Engine logic and UI indicators.
- `lib/features/student/`: Dashboard, Subject, and Lesson (Markdown, Quiz, Flashcards).
- `lib/features/admin/`: Diagnostics, Resource Management, and Feature Flags.
