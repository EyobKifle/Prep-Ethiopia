-- =========================================================================
-- PREP-ETHIOPIA DATABASE SCHEMA
-- Target Backend: Supabase (PostgreSQL 15+)
-- Author: Principal Architect
-- Design Philosophy: High-Contrast, Minimalist, Offline-First Sync Enabled
-- =========================================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- =========================================================================
-- USER PROFILES & SECURITY
-- =========================================================================

create type user_role as enum ('student', 'admin', 'parent', 'teacher');

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    role user_role default 'student'::user_role not null,
    full_name varchar(255),
    phone_number varchar(20),
    preferred_language varchar(5) default 'am' not null, -- Language code: 'en', 'am', etc.
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, role, full_name, phone_number, preferred_language)
  values (
    new.id,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'student'::user_role),
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.phone,
    coalesce(new.raw_user_meta_data->>'preferred_language', 'am')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- =========================================================================
-- CONTENT SCHEMA (Read-Only for Student Clients, Managed by Admin)
-- Multi-lingual fields are stored in JSONB formats: {"en": "Text", "am": "ጽሑፍ"}
-- =========================================================================

-- 1. Grades Table
create table public.grades (
    id uuid primary key default uuid_generate_v4(),
    level integer not null unique, -- e.g., 9, 10, 11, 12
    name jsonb not null,           -- {"en": "Grade 9", "am": "ክፍል 9"}
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Subjects Table
create table public.subjects (
    id uuid primary key default uuid_generate_v4(),
    grade_id uuid references public.grades(id) on delete cascade not null,
    name jsonb not null,           -- {"en": "Mathematics", "am": "ሒሳብ"}
    slug varchar(100) not null,    -- e.g., "math", "physics"
    icon_url text,                 -- Stored in Supabase public storage bucket
    color_code varchar(7),         -- Hex color code for UI (e.g., "#0F172A")
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(grade_id, slug)
);

-- 3. Units Table
create table public.units (
    id uuid primary key default uuid_generate_v4(),
    subject_id uuid references public.subjects(id) on delete cascade not null,
    sequence_number integer not null, -- Unit 1, Unit 2
    title jsonb not null,            -- {"en": "Unit 1: Quadratic Equations", "am": "ምዕራፍ 1: ..."}
    description jsonb,               -- Brief localized summary
    textbook_pdf_url jsonb,          -- Localized URLs hosted on Cloudflare R2/CDN: {"en": "url_en", "am": "url_am"}
    textbook_pdf_size jsonb,         -- Sizes in bytes: {"en": 12450000, "am": 13500000}
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(subject_id, sequence_number)
);

-- 4. Worksheets Table
create table public.worksheets (
    id uuid primary key default uuid_generate_v4(),
    unit_id uuid references public.units(id) on delete cascade not null,
    title jsonb not null,            -- {"en": "Worksheet 1.1", "am": "መልመጃ 1.1"}
    pdf_url jsonb not null,          -- {"en": "url_en", "am": "url_am"}
    pdf_size jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Exams Table
create table public.exams (
    id uuid primary key default uuid_generate_v4(),
    subject_id uuid references public.subjects(id) on delete cascade not null,
    title jsonb not null,            -- {"en": "National Matric Exam Prep", "am": "ብሔራዊ ፈተና ዝግጅት"}
    description jsonb,
    duration_minutes integer not null default 60,
    is_published boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 6. Exam Questions Table
create table public.exam_questions (
    id uuid primary key default uuid_generate_v4(),
    exam_id uuid references public.exams(id) on delete cascade not null,
    question_text jsonb not null,      -- {"en": "Solve x^2 = 4", "am": "x^2 = 4 ፈታ"}
    options jsonb not null,            -- Matrix format: {"en": ["2", "-2", "Both", "None"], "am": ["2", "-2", "ሁለቱም", "ምንም"]}
    correct_option_index integer not null,
    explanation jsonb,                 -- Localized detailed explanation
    points integer default 10 not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Lessons Table
create table public.lessons (
    id uuid primary key default uuid_generate_v4(),
    unit_id uuid references public.units(id) on delete cascade not null,
    sequence_number integer not null,
    title jsonb not null,            -- {"en": "Lesson 1.1: Intro to Functions", "am": "ትምህርት 1.1: መግቢያ"}
    estimated_minutes integer default 10,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(unit_id, sequence_number)
);

-- 8. Steps Table
create type step_type as enum ('read', 'quiz', 'flashcard_review');

create table public.steps (
    id uuid primary key default uuid_generate_v4(),
    lesson_id uuid references public.lessons(id) on delete cascade not null,
    sequence_number integer not null,
    title jsonb not null,
    type step_type not null,
    content_markdown jsonb,          -- Localized study content: {"en": "# Intro...", "am": "# መግቢያ..."}
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(lesson_id, sequence_number)
);

-- 9. Quiz Questions Table
create table public.quiz_questions (
    id uuid primary key default uuid_generate_v4(),
    step_id uuid references public.steps(id) on delete cascade not null, -- step of type 'quiz'
    question_text jsonb not null,
    options jsonb not null,            -- {"en": ["Option A", "Option B"], "am": ["አማራጭ ሀ", "አማራጭ ለ"]}
    correct_option_index integer not null,
    explanation jsonb,
    points integer default 10 not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 10. Flashcard Templates Table
create table public.flashcard_templates (
    id uuid primary key default uuid_generate_v4(),
    unit_id uuid references public.units(id) on delete cascade not null,
    front_text jsonb not null,        -- {"en": "Term", "am": "ቃል"}
    back_text jsonb not null,         -- {"en": "Definition", "am": "ትርጉም"}
    image_url text,                  -- Language-neutral media link
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- =========================================================================
-- USER PROGRESS & METRICS SCHEMA (Synced Bidirectionally)
-- =========================================================================

-- 1. Step Progress Table
create table public.user_progress (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    step_id uuid references public.steps(id) on delete cascade not null,
    is_completed boolean default false not null,
    completed_at timestamp with time zone,
    last_synced_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    is_deleted boolean default false not null,
    unique(user_id, step_id)
);

-- 2. Quiz Attempts Table
create table public.quiz_attempts (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    step_id uuid references public.steps(id) on delete cascade not null, -- step of type 'quiz'
    score integer not null,
    max_score integer not null,
    answers_json text, -- Serialized quiz answers: [{"q_uuid":"...","selected":1,"correct":0,"is_correct":false}, ...]
    submitted_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    is_deleted boolean default false not null
);

-- 3. Exam Attempts Table
create table public.exam_attempts (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    exam_id uuid references public.exams(id) on delete cascade not null,
    score integer not null,
    max_score integer not null,
    duration_spent_seconds integer,
    answers_json text, -- Serialized exam answers
    submitted_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    is_deleted boolean default false not null
);

-- 4. User Flashcards Table (SuperMemo SM-2 Metrics)
create table public.user_flashcards (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    card_template_id uuid references public.flashcard_templates(id) on delete cascade not null,
    ease_factor double precision default 2.5 not null,
    interval_days integer default 0 not null,
    repetitions integer default 0 not null,
    next_review_at timestamp with time zone default timezone('utc'::text, now()) not null,
    is_deleted boolean default false not null,
    unique(user_id, card_template_id)
);

-- =========================================================================
-- PARENT-STUDENT & NEW LEARNING MATERIALS SCHEMA
-- =========================================================================

-- Parent-Student links table
create table public.parent_student_links (
    id uuid primary key default uuid_generate_v4(),
    parent_id uuid references auth.users(id) on delete cascade not null,
    student_id uuid references auth.users(id) on delete cascade not null,
    link_code varchar(6),
    linked_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(parent_id, student_id)
);

-- Textbooks table
create table public.textbooks (
    id uuid primary key default uuid_generate_v4(),
    subject_id uuid references public.subjects(id) on delete cascade not null,
    title jsonb not null,               -- {"en": "Textbook", "am": "መጽሐፍ"}
    pdf_url text not null,
    pdf_size_bytes bigint,
    cover_image_url text,
    total_pages integer,
    is_published boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Worksheet Questions table
create table public.worksheet_questions (
    id uuid primary key default uuid_generate_v4(),
    worksheet_id uuid references public.worksheets(id) on delete cascade not null,
    sequence_number integer not null,
    question_text jsonb not null,
    options jsonb not null,             -- {"en": ["A","B"], "am": ["ሀ","ለ"]}
    correct_option_index integer not null,
    explanation jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(worksheet_id, sequence_number)
);

-- Worksheet Attempts table
create table public.worksheet_attempts (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    worksheet_id uuid references public.worksheets(id) on delete cascade not null,
    score integer not null,
    max_score integer not null,
    answers_json text not null,         -- Serialized: [{"q_uuid":"...","selected":2,"correct":1,"is_correct":false}, ...]
    submitted_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    is_deleted boolean default false not null
);

-- =========================================================================
-- CONFIGURATION & DIAGNOSTICS SCHEMA (Developer Dashboard)
-- =========================================================================

-- 1. Feature Flags
create table public.feature_flags (
    id uuid primary key default uuid_generate_v4(),
    key varchar(100) not null unique,
    description text,
    is_enabled boolean default false not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Error/System Diagnostics Logs
create table public.app_diagnostics_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete set null,
    log_level varchar(10) not null, -- 'info', 'warn', 'error', 'fatal'
    message text not null,
    stack_trace text,
    device_info jsonb,               -- OS, App Version, Device Model
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Owner/Admin Audit Trail Logs
create table public.admin_audit_logs (
    id uuid primary key default uuid_generate_v4(),
    admin_id uuid references auth.users(id) on delete set null,
    action varchar(255) not null,    -- e.g., 'update_textbook', 'toggle_feature'
    details jsonb,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- =========================================================================
-- PERFORMANCE INDEXING
-- =========================================================================

-- Indexing foreign keys for fast joins
create index idx_subjects_grade on public.subjects(grade_id);
create index idx_units_subject on public.units(subject_id);
create index idx_lessons_unit on public.lessons(unit_id);
create index idx_steps_lesson on public.steps(lesson_id);
create index idx_quiz_questions_step on public.quiz_questions(step_id);
create index idx_flashcard_templates_unit on public.flashcard_templates(unit_id);
create index idx_worksheets_unit on public.worksheets(unit_id);
create index idx_exams_subject on public.exams(subject_id);
create index idx_exam_questions_exam on public.exam_questions(exam_id);

-- Indexes for sync queries (filtering by user_id and timestamp)
create index idx_user_progress_sync on public.user_progress(user_id, updated_at);
create index idx_quiz_attempts_sync on public.quiz_attempts(user_id, updated_at);
create index idx_exam_attempts_sync on public.exam_attempts(user_id, updated_at);
create index idx_user_flashcards_sync on public.user_flashcards(user_id, updated_at);

-- =========================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- =========================================================================

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.grades enable row level security;
alter table public.subjects enable row level security;
alter table public.units enable row level security;
alter table public.worksheets enable row level security;
alter table public.exams enable row level security;
alter table public.exam_questions enable row level security;
alter table public.lessons enable row level security;
alter table public.steps enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.flashcard_templates enable row level security;
alter table public.user_progress enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.exam_attempts enable row level security;
alter table public.user_flashcards enable row level security;
alter table public.feature_flags enable row level security;
alter table public.app_diagnostics_logs enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.parent_student_links enable row level security;
alter table public.textbooks enable row level security;
alter table public.worksheet_questions enable row level security;
alter table public.worksheet_attempts enable row level security;

-- Admin Check Helper Function
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'::user_role
  );
end;
$$ language plpgsql security definer;

-- Profiles Policies
create policy "Allow users to read profiles" on public.profiles for select using (
    true
);
create policy "Allow users to update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Admin manages all profiles" on public.profiles for all using (public.is_admin());

-- Read policies: Anyone (authenticated or not) can read content tables, unless unpublished.
create policy "Allow public read access to grades" on public.grades for select using (true);
create policy "Allow public read access to subjects" on public.subjects for select using (true);
create policy "Allow public read access to units" on public.units for select using (true);
create policy "Allow public read access to worksheets" on public.worksheets for select using (true);
create policy "Allow public read access to textbooks" on public.textbooks for select using (true);
create policy "Allow public read access to worksheet_questions" on public.worksheet_questions for select using (true);
create policy "Allow public read access to published exams" on public.exams for select using (is_published = true or public.is_admin());
create policy "Allow public read access to exam questions" on public.exam_questions for select using (exists (select 1 from public.exams where id = exam_id and (is_published = true or public.is_admin())));
create policy "Allow public read access to lessons" on public.lessons for select using (true);
create policy "Allow public read access to steps" on public.steps for select using (true);
create policy "Allow public read access to quiz_questions" on public.quiz_questions for select using (true);
create policy "Allow public read access to flashcard_templates" on public.flashcard_templates for select using (true);
create policy "Allow public read access to feature_flags" on public.feature_flags for select using (true);

-- Admin Write Policies for Content
create policy "Admin manages grades" on public.grades for all using (public.is_admin());
create policy "Admin manages subjects" on public.subjects for all using (public.is_admin());
create policy "Admin manages units" on public.units for all using (public.is_admin());
create policy "Admin manages worksheets" on public.worksheets for all using (public.is_admin());
create policy "Admin manages textbooks" on public.textbooks for all using (public.is_admin());
create policy "Admin manages worksheet_questions" on public.worksheet_questions for all using (public.is_admin());
create policy "Admin manages exams" on public.exams for all using (public.is_admin());
create policy "Admin manages exam questions" on public.exam_questions for all using (public.is_admin());
create policy "Admin manages lessons" on public.lessons for all using (public.is_admin());
create policy "Admin manages steps" on public.steps for all using (public.is_admin());
create policy "Admin manages quiz_questions" on public.quiz_questions for all using (public.is_admin());
create policy "Admin manages flashcard_templates" on public.flashcard_templates for all using (public.is_admin());
create policy "Admin manages feature_flags" on public.feature_flags for all using (public.is_admin());

-- User Progress & Attempt Policies (Including Parent access)
create policy "Users and parents can read step progress"
    on public.user_progress for select using (
        auth.uid() = user_id or 
        exists (select 1 from public.parent_student_links where parent_id = auth.uid() and student_id = user_id)
    );
create policy "Users can update own step progress"
    on public.user_progress for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users and parents can read quiz attempts"
    on public.quiz_attempts for select using (
        auth.uid() = user_id or 
        exists (select 1 from public.parent_student_links where parent_id = auth.uid() and student_id = user_id)
    );
create policy "Users can update own quiz attempts"
    on public.quiz_attempts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users and parents can read exam attempts"
    on public.exam_attempts for select using (
        auth.uid() = user_id or 
        exists (select 1 from public.parent_student_links where parent_id = auth.uid() and student_id = user_id)
    );
create policy "Users can update own exam attempts"
    on public.exam_attempts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users and parents can read worksheet attempts"
    on public.worksheet_attempts for select using (
        auth.uid() = user_id or 
        exists (select 1 from public.parent_student_links where parent_id = auth.uid() and student_id = user_id)
    );
create policy "Users can update own worksheet attempts"
    on public.worksheet_attempts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can perform all operations on their own flashcards"
    on public.user_flashcards for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Parent Student Links Policies
create policy "Parents can manage their links"
    on public.parent_student_links for all using (auth.uid() = parent_id) with check (auth.uid() = parent_id);
create policy "Students can view their links"
    on public.parent_student_links for select using (auth.uid() = student_id);

-- System & Audit Logs Policies
create policy "Users can write diagnostics logs" on public.app_diagnostics_logs for insert with check (true);
create policy "Admins see diagnostics logs" on public.app_diagnostics_logs for select using (public.is_admin());
create policy "Admins manage diagnostics logs" on public.app_diagnostics_logs for delete using (public.is_admin());

create policy "Admins see audit logs" on public.admin_audit_logs for select using (public.is_admin());
create policy "Admins write audit logs" on public.admin_audit_logs for insert with check (public.is_admin());
