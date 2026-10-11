-- =========================================================================
-- PREP-ETHIOPIA MOCK SEED DATA
-- Purpose: Populates base curriculum, exams, worksheets, and default feature flags
-- Languages: Amharic ('am') and English ('en')
-- =========================================================================

-- Clear existing data if necessary (order respects dependencies)
truncate public.admin_audit_logs cascade;
truncate public.app_diagnostics_logs cascade;
truncate public.feature_flags cascade;
truncate public.user_flashcards cascade;
truncate public.exam_attempts cascade;
truncate public.quiz_attempts cascade;
truncate public.user_progress cascade;
truncate public.flashcard_templates cascade;
truncate public.quiz_questions cascade;
truncate public.steps cascade;
truncate public.lessons cascade;
truncate public.exam_questions cascade;
truncate public.exams cascade;
truncate public.worksheets cascade;
truncate public.units cascade;
truncate public.subjects cascade;
truncate public.grades cascade;

-- Generate deterministic UUIDs for references
do $main_seed$
declare
    g9_id uuid := '99999999-9999-4999-8999-999999999909';
    g10_id uuid := '10101010-1010-4010-8010-101010101010';
    
    sub_math_id uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01';
    sub_physics_id uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb02';
    
    unit1_id uuid := 'cccccccc-cccc-4ccc-8ccc-cccccccccc01';
    worksheet1_id uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
    
    exam1_id uuid := 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeee01';
    
    lesson1_id uuid := 'ffffffff-ffff-4fff-8fff-ffffffffff01';
    step_read_id uuid := '11111111-1111-4111-8111-111111111101';
    step_quiz_id uuid := '22222222-2222-4222-8222-222222222201';
    step_fc_id uuid := '33333333-3333-4333-8333-333333333301';
begin

    -- 1. Seed Grades
    insert into public.grades (id, level, name) values
    (g9_id, 9, '{"en": "Grade 9", "am": "ክፍል 9"}'),
    (g10_id, 10, '{"en": "Grade 10", "am": "ክፍል 10"}');

    -- 2. Seed Subjects
    insert into public.subjects (id, grade_id, name, slug, icon_url, color_code) values
    (sub_math_id, g9_id, '{"en": "Mathematics", "am": "ሒሳብ"}', 'math', 'subjects/math_icon.png', '#0F172A'),
    (sub_physics_id, g9_id, '{"en": "Physics", "am": "ፊዚክስ"}', 'physics', 'subjects/physics_icon.png', '#0F172A');

    -- 3. Seed Units
    insert into public.units (id, subject_id, sequence_number, title, description, textbook_pdf_url, textbook_pdf_size) values
    (unit1_id, sub_math_id, 1, 
     '{"en": "Unit 1: Quadratic Equations", "am": "ምዕራፍ 1: ኳድራቲክ እኩልታዎች"}',
     '{"en": "Learn methods to solve quadratic equations including factoring, completing the square, and the quadratic formula.", "am": "ኳድራቲክ እኩልታዎችን በፋክተሪንግ፣ ሙሉ ስኩዌር በመሙላት እና በኳድራቲክ ፎርሙላ መፍታት ይማሩ።"}',
     '{"en": "https://assets.prepethiopia.com/textbooks/g9_math_unit1_en.pdf", "am": "https://assets.prepethiopia.com/textbooks/g9_math_unit1_am.pdf"}',
     '{"en": 12450000, "am": 13500000}');

    -- 4. Seed Worksheets
    insert into public.worksheets (id, unit_id, title, pdf_url, pdf_size) values
    (worksheet1_id, unit1_id, 
     '{"en": "Practice Worksheet 1.1", "am": "የመልመጃ ወረቀት 1.1"}',
     '{"en": "https://assets.prepethiopia.com/worksheets/g9_math_ws1_en.pdf", "am": "https://assets.prepethiopia.com/worksheets/g9_math_ws1_am.pdf"}',
     '{"en": 1250000, "am": 1350000}');

    -- 5. Seed Exams
    insert into public.exams (id, subject_id, title, description, duration_minutes, is_published) values
    (exam1_id, sub_math_id, 
     '{"en": "Grade 9 Mathematics Final Exam Prep", "am": "ክፍል 9 ሒሳብ ማጠቃለያ ፈተና"}',
     '{"en": "A comprehensive prep exam covering all units of Grade 9 Math.", "am": "ሁሉንም የክፍል 9 ሒሳብ ምዕራፎች የሚያጠቃልል የዝግጅት ፈተና።"}',
     60, true);

    -- 6. Seed Exam Questions
    insert into public.exam_questions (exam_id, question_text, options, correct_option_index, explanation, points) values
    (exam1_id, 
     '{"en": "What are the roots of x^2 - 4 = 0?", "am": "የ x^2 - 4 = 0 ሥሮች (roots) የትኞቹ ናቸው?"}',
     '{"en": ["2 and -2", "4 and -4", "0 and 4", "2 and 0"], "am": ["2 እና -2", "4 እና -4", "0 እና 4", "2 እና 0"]}',
     0,
     '{"en": "Factoring x^2 - 4 gives (x-2)(x+2) = 0, so x = 2 or x = -2.", "am": "x^2 - 4 በፋክተር ሲቀመጥ (x-2)(x+2) = 0 ይሆናል፣ ስለዚህ x = 2 ወይም x = -2 ነው።"}',
     10),
    (exam1_id,
     '{"en": "Solve for x in 2x - 6 = 0.", "am": "በ 2x - 6 = 0 ውስጥ የ x ዋጋን ፈልግ።"}',
     '{"en": ["x = 2", "x = 3", "x = 6", "x = -3"], "am": ["x = 2", "x = 3", "x = 6", "x = -3"]}',
     1,
     '{"en": "Add 6 to both sides: 2x = 6. Divide by 2: x = 3.", "am": "በሁለቱም በኩል 6 መደመር: 2x = 6. ለ 2 ማካፈል: x = 3 ነው።"}',
     10);

    -- 7. Seed Lessons
    insert into public.lessons (id, unit_id, sequence_number, title, estimated_minutes) values
    (lesson1_id, unit1_id, 1, 
     '{"en": "Lesson 1.1: Intro to Quadratic Equations", "am": "ትምህርት 1.1: ወደ ኳድራቲክ እኩልታዎች መግቢያ"}',
     12);

    -- 8. Seed Lesson Steps
    insert into public.steps (id, lesson_id, sequence_number, title, type, content_markdown) values
    (step_read_id, lesson1_id, 1,
     '{"en": "Reading: Definition of Quadratic Equations", "am": "ንባብ: የኳድራቲክ እኩልታዎች ትርጉም"}',
     'read',
     '{"en": "# Introduction\n\nA quadratic equation is a second-degree polynomial equation in a single variable x, with a non-zero coefficient for x^2.\n\n## Standard Form\n\n$$ax^2 + bx + c = 0$$\n\nwhere $a \\neq 0$.", "am": "# መግቢያ\n\nኳድራቲክ እኩልታ ባለ ሁለት ዲግሪ ፖሊኖሚአል እኩልታ ሲሆን የ x^2 ኮፊሸንት ከዜሮ የተለየ መሆን አለበት።\n\n## መደበኛ ፎርም\n\n$$ax^2 + bx + c = 0$$\n\nእዚህ ላይ $a \\neq 0$ መሆን አለበት።"}'),
    (step_quiz_id, lesson1_id, 2,
     '{"en": "Quick Practice Quiz", "am": "ፈጣን መለማመጃ ጥያቄዎች"}',
     'quiz',
     null),
    (step_fc_id, lesson1_id, 3,
     '{"en": "Unit 1 Flashcards Review", "am": "የምዕራፍ 1 ፍላሽ ካርዶች ክለሳ"}',
     'flashcard_review',
     null);

    -- 9. Seed Quiz Questions for Step 2
    insert into public.quiz_questions (step_id, question_text, options, correct_option_index, explanation, points) values
    (step_quiz_id,
     '{"en": "Which of the following is a quadratic equation?", "am": "ከሚከተሉት ውስጥ የትኛው ነው ኳድራቲክ እኩልታ የሆነው?"}',
     '{"en": ["2x + 5 = 0", "x^2 + 3x + 2 = 0", "x^3 - x = 0", "y = 5"], "am": ["2x + 5 = 0", "x^2 + 3x + 2 = 0", "x^3 - x = 0", "y = 5"]}',
     1,
     '{"en": "A quadratic equation must have a highest power of 2.", "am": "ኳድራቲክ እኩልታ ከፍተኛው ፓወር (ዲግሪ) 2 መሆን አለበት።"}',
     10);

    -- 10. Seed Flashcards for Unit 1
    insert into public.flashcard_templates (unit_id, front_text, back_text, image_url) values
    (unit1_id, 
     '{"en": "Standard Form of a Quadratic Equation", "am": "የኳድራቲክ እኩልታ መደበኛ ፎርም"}',
     '{"en": "ax^2 + bx + c = 0, where a != 0", "am": "ax^2 + bx + c = 0, a != 0 ሲሆን"}',
     null),
    (unit1_id,
     '{"en": "Discriminant Formula", "am": "የዲስክሪሚናንት ፎርሙላ"}',
     '{"en": "D = b^2 - 4ac", "am": "D = b^2 - 4ac"}',
     null);

    -- 11. Seed Feature Flags
    insert into public.feature_flags (key, description, is_enabled) values
    ('enable_flashcards', 'Enables gamified spaced repetition cards at the end of units', true),
    ('enable_sms_auth', 'Toggle SMS OTP Login logic (preserves email login as fallback)', false),
    ('enable_achievements', 'Display gamified user badges and study streak notifications', true);

    -- 12. Create Sample Accounts
    -- Note: We use crypt() to hash passwords so they work with Supabase Auth (GoTrue).
    -- All accounts use the default password: 'Password123'

    -- Student: Abebe Bikila
    insert into auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role)
    values (
        'd290f1ee-6c54-4b01-90e6-d701748f0851',
        'student@prepethiopia.com',
        crypt('Password123', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name": "Abebe Bikila", "preferred_language": "am"}',
        'authenticated',
        'authenticated'
    );

    -- Admin: System Manager
    insert into auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role)
    values (
        'a110f1ee-6c54-4b01-90e6-d701748f0852',
        'admin@prepethiopia.com',
        crypt('Password123', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name": "System Manager", "preferred_language": "en"}',
        'authenticated',
        'authenticated'
    );

    -- Parent: Parent User
    insert into auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role)
    values (
        'e330f1ee-6c54-4b01-90e6-d701748f0853',
        'parent@prepethiopia.com',
        crypt('Password123', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name": "Parent User", "preferred_language": "am"}',
        'authenticated',
        'authenticated'
    );

    -- Teacher: Teacher User
    insert into auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role)
    values (
        'f440f1ee-6c54-4b01-90e6-d701748f0854',
        'teacher@prepethiopia.com',
        crypt('Password123', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name": "Teacher User", "preferred_language": "en"}',
        'authenticated',
        'authenticated'
    );

    -- Manually adjust roles (since trigger defaults to 'student')
    update public.profiles set role = 'admin' where id = 'a110f1ee-6c54-4b01-90e6-d701748f0852';
    update public.profiles set role = 'parent' where id = 'e330f1ee-6c54-4b01-90e6-d701748f0853';
    update public.profiles set role = 'teacher' where id = 'f440f1ee-6c54-4b01-90e6-d701748f0854';

    -- Link Parent to Student
    insert into public.parent_student_links (parent_id, student_id, link_code)
    values ('e330f1ee-6c54-4b01-90e6-d701748f0853', 'd290f1ee-6c54-4b01-90e6-d701748f0851', 'XYZ123');

end $main_seed$;
