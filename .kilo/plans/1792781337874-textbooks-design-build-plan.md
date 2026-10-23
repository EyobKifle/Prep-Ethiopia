# Plan: Working with Ethiopian National Textbooks

## Goal
Explore and plan how to use the existing Ethiopian national textbooks (PDFs) in this repo for frontend/backend design/build options.

## Current State
- Textbooks exist in `Ethiopian national textbooks/` with organized structure by grade (Grade 2-5, grade 1 at root level, plus some loose files)
- 26+ PDFs total across grades 1-5 covering subjects like Amharic, English, Mathematics, Environmental Science, Physical Education/Art ("የክወናና የዕይታ ጥበባት")
- App already has textbook support: `TextbookLocal` model in Isar, `textbook_viewer_screen.dart`, download/sync logic in dashboard and sync service
- Backend infrastructure exists (Supabase, sync service, Edge functions in `supabase/functions/`)
- Stitch frontend templates exist for reference

## Questions to Resolve
1. **Purpose**: Are we redesigning the textbook UI/UX (moving to AI design tool like Figma) or building backend processing for textbooks (OCR/extraction/indexing)?
2. **Scope**: Which grades/subjects to focus on first? All or specific?
3. **Format**: Keep as PDFs for viewing or extract to structured content (lessons/units/steps)?
4. **Hosting**: Store PDFs locally in app assets vs upload to Supabase storage vs keep as-is?
5. **AI features**: Want AI tutor to use textbook content (RAG) - need to understand current `AiChatLocal`/RAG setup?

## Plan Options

### Option A: Frontend Design (Figma/AI Design Tool)
**Goal:** Convert existing textbook UI to editable design
- **Extract design tokens** from `lib/core/theme/app_theme.dart`
- **Screenshot** textbook viewer (`textbook_viewer_screen.dart`), library, dashboard
- **Use AI design tool** (Figma Make/Visily/Uizard) as discussed earlier
- **Create component library** for PDF viewer, textbook cards, etc.

### Option B: Backend Processing & Content Structure
**Goal:** Process PDFs into structured curriculum data
- **Parse textbooks** - extract chapters/units/lessons from PDFs
- **Create seed data** matching `TextbookLocal`/`UnitLocal`/`LessonLocal` schema
- **Upload to Supabase** or bundle as assets
- **Enable offline sync** via existing sync service
- **Support AI tutor RAG** using extracted content

### Option C: Hybrid - Design + Backend Pipeline
Do both in parallel: redesign UI while building content pipeline.

## Recommended Approach
Start with **Option A + B combined**:
1. **Inventory** - Document all textbooks (done above)
2. **Understand current flow** - Trace how textbooks are loaded/downloaded in app
3. **Decide processing strategy** - Manual structuring vs automated extraction
4. **Design first** - Screenshot current UI, move to design tool
5. **Backend** - Process content to match schema

## Next Steps
1. Read `textbook_viewer_screen.dart` and `student_dashboard_screen.dart` (guest textbook flow) fully
2. Read `sync_service.dart` textbook sync logic
3. Read `seed_data.dart` to understand content structure
4. Check `supabase_schema.sql` for textbook-related tables
5. Decide: redesign UI first, or process content first?

## Immediate Action Needed
**Question:** What is the primary goal?
- A) Redesign the textbook UI in Figma/AI design tool (visual redesign)
- B) Build backend to process textbooks into structured lessons/quizzes
- C) Both - need plan for both frontend and backend

Recommend starting with B) understanding current implementation first, then decide direction.
