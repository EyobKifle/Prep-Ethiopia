Plan
Issue 1: "Same page when clicked student but not for parent/teacher"
Root cause to investigate: The student card calls _nextStep() which advances the PageView, while parent/teacher cards navigate to /signup directly. This is by design in the code, but the user sees "same page repeated" - need to understand if it's actually advancing or if something is preventing it.

Investigation steps:

Trace what happens when student card is tapped - _nextStep() sets _currentStep++ (to 1), animates PageView to language step.
Check if _isAnimating blocks rapid taps.
Look at initState() - _resumeFromExistingProfile() might set _currentStep to a value that affects initial state, and jumpToPage() is called after.
Check if there's an existing profile (guest) in auth provider that causes _resumeFromExistingProfile() to jump to a later step.
Issue 2: "After clicking student select your role page is repeated"
Root cause to investigate: This suggests after tapping student, the UI still shows the welcome/role step (step 0). Possible causes:

_resumeFromExistingProfile() might be overriding state. For example, if a guest profile exists with certain fields, it might reset _currentStep.
PageView animation issue - nextPage().then() sets _isAnimating=false but maybe state doesn't sync.
jumpToPage in initState might interfere if called after setState.
Check when _resumeFromExistingProfile() runs - it reads authProvider state. If auth state updates after build, could cause issues.
Investigation steps:

Look up auth provider state - is there a guest profile persisted?
Simulate: fresh start vs returning user flow.
Check if _currentStep is being modified after navigation starts.
Issue 3: "In select your language page it doesn't move to actual page instead says select your grade"
Root cause to investigate: When language is selected (Amharic/English), both cards call setLocale() then _nextStep(). _nextStep() should move to step 2 (grade). But user says it stays on language UI but shows "select your grade" text - this is confusing.

Investigation steps:

Look up the actual step titles: language step shows selectLanguage (line ~393), grade step shows selectGrade (line ~497). So text is correct per step.
Possible: it's actually advancing to grade step (step 2) but UI looks similar? Or maybe the step index is off.
Check the progress indicator - it shows 3 bars for steps 1,2,3 (when _currentStep > 0, it highlights up to _currentStep-1). So moving to step 2 means 2 bars highlighted.
Maybe the PageView isn't actually moving - animation glitch? Or physics disabled.
Also note: in language step, both options call _nextStep() immediately - no guard. That’s fine.
Additional investigation areas
Localization strings: Read translation files to confirm keys exist and match expectations (selectLanguage, selectGrade, pleaseSelectGrade, etc.)
Auth/Profile state: Check if guest profiles are persisted. If a guest was created before with incomplete data, _resumeFromExistingProfile() might behave unexpectedly.
PageView controller: Check if there are any other places modifying _currentStep or calling jumpToPage.
# Offline Lesson Tutor Implementation Roadmap

## Product scope

Build an offline tutor that helps a student understand the lesson they are currently studying. The student can ask questions such as “Can you explain this part?” The tutor should restate the concept more simply, give a relevant example, and optionally ask a short follow-up question.

The app interface will be translated into English, Amharic, Oromo, and Tigrinya. Lesson content stays in its original language for this project; translating lesson content is out of scope. Tutor response languages should only be promised after they have been evaluated for quality.

The first implementation should support guest students and the existing mock database. Student settings and tutor history can be stored locally. Account creation and cloud sync are not required for the tutor MVP.

## Phase 0 — Confirm the target and collect lesson material

1. Choose one pilot grade, one subject, and a small set of representative lessons.
2. Identify the minimum Android phone and available storage the app must support.
3. Confirm the language of the pilot lesson material and the language the first tutor version should answer in.
4. Ask teachers to provide common student questions and acceptable explanations for those lessons.
5. Record constraints: model download size, whether first download can use Wi-Fi, and whether iOS is part of the first release.

**Complete when:** the pilot lessons, target devices, tutor response language, and teacher reviewers are agreed.

## Phase 1 — Improve the student entry and lesson flow

1. Let a student continue as a guest without signing up.
2. Keep onboarding choices short and clear: role, app language, grade, then learning content.
3. Clearly label the selected app language and grade and allow the student to change them later.
4. Route the student directly to the selected grade and available lessons.
5. Save guest preferences locally so they persist when the app restarts.

**Complete when:** a new guest can reach a lesson, restart the app, and return with their choices intact.

## Phase 2 — Prepare offline lesson data

1. Store pilot lesson text and examples in the local database or downloadable offline pack.
2. Divide long lessons into useful sections with stable lesson and section identifiers.
3. Attach grade, subject, lesson title, and original content language to each section.
4. Add a way to update packs when the student is online, without requiring a sign-in.
5. Show download size and download status; do not download large packs over mobile data without the student choosing to.

**Complete when:** the pilot lesson opens and can be searched or retrieved with the device offline.

## Phase 3 — Prototype and evaluate the on-device text tutor

1. Compare suitable small on-device language models on the target phones. Measure answer quality, response time, memory use, battery use, and model download size.
2. Build a prototype that receives the current lesson section and the student's question.
3. Instruct the tutor to explain the lesson simply, use examples grounded in that lesson, and ask a short check-for-understanding question when useful.
4. Add a scope check so the feature redirects unrelated questions back to school learning.
5. If the lesson does not support an answer, have the tutor say that it cannot find the answer in the current material rather than inventing one.
6. Keep the tutor text-only for this phase. Do not add lesson translation, speech, or live teacher calls.
7. Have teachers review a fixed set of student questions and score correctness, clarity, relevance, and unsupported claims.

**Complete when:** teacher-reviewed answers meet agreed quality thresholds and the prototype works acceptably on the minimum supported phone while offline.

## Phase 4 — Integrate tutor into lessons

1. Add an “Explain this” action to a lesson section and a way to ask a typed question.
2. Pass only the relevant lesson section and necessary metadata to the tutor.
3. Display the answer as a conversation with clear loading, retry, and unavailable states.
4. Let students ask a follow-up question while keeping the same lesson context.
5. Store recent tutor conversations locally and provide a clear way to clear them.
6. Keep the student’s content and tutor history on the device unless a later product decision explicitly adds sync.

**Complete when:** a guest can ask about a lesson, get a grounded explanation, ask a follow-up, and repeat the flow offline.

## Phase 5 — Translate the app interface

1. Inventory interface text separately from lesson content and tutor prompts.
2. Translate navigation, onboarding, settings, buttons, and common error messages into English, Amharic, Oromo, and Tigrinya.
3. Have fluent reviewers check the translations, including script, terminology, and layout on small screens.
4. Preserve the original language of lesson packs.
5. Make app language selection independent from lesson language and tutor response language.

**Complete when:** the supported screens can be used in all four interface languages and lesson content remains unchanged.

## Phase 6 — Pilot, measure, and expand

1. Pilot with a small group of students and teachers using the selected grade and lessons.
2. Collect consented feedback about confusing answers, unsupported claims, speed, usability, and phone performance.
3. Fix issues and repeat the teacher-reviewed question set after model or prompt changes.
4. Expand one grade or subject at a time; prepare and review its lesson sections before release.
5. Track crashes and performance without collecting student questions unless there is an explicit, consented product decision to do so.

**Complete when:** the pilot meets the agreed quality and performance criteria and there is a reviewed content pack for each newly supported area.

## Later phases — Voice and online teacher sessions

These are separate projects after the text tutor is proven:

- **Voice input:** add push-to-talk speech-to-text, then evaluate recognition quality for each language and target phone.
- **Spoken answers:** add text-to-speech only where an acceptable offline voice is available; keep written answers as fallback.
- **Teacher sessions:** first pilot scheduling and one-to-one online calls, then consider group classes. Budget for video infrastructure, bandwidth, safety controls, teacher verification, and parent consent. These calls require an internet connection and are not part of offline tutor functionality.

## Decisions to revisit before each phase

- Which grade, subject, and lesson pack is next?
- Which devices and operating-system versions are supported?
- Which language should the tutor answer in for this release?
- What teacher-review score is required before release?
- What is the acceptable model download size and response time?
- Is the feature still fully offline after its initial model and lesson downloads?
