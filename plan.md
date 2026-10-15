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