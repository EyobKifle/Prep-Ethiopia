# Prep-Ethiopia Onboarding & Auth Flow

## Current Architecture

### Routes
- `/onboarding` — Entry point, multi-step wizard
- `/login` — Email/password sign-in
- `/signup?role=student|parent|teacher` — Account creation with role

### Onboarding Steps (Student Only)
1. **Welcome** — Role selection (Student / Parent / Teacher)
2. **Language** — Amharic or English
3. **Grade** — Grades 7–12 grid selection
4. **Download** — Simulated sync + progress bar → redirect to `/student`

### Auth Provider State
- `AppUser` — holds `id` + `token` (signed-in user)
- `ProfileLocal` — holds `uuid`, `role`, `fullName`, `phoneNumber`, `preferredLanguage`, `selectedGradeLevel`, `isDirty`
- `setGuestSession()` — creates an anonymous local profile without Supabase auth
- `signIn()` / `signUp()` — full backend flow via `RemoteApiService`

---

## Current Flow Diagram

```
/onboarding
├── Student selected
│   ├── Language step
│   ├── Grade step
│   ├── Download step (creates guest ProfileLocal if no auth)
│   └── → /student
│
├── Parent selected
│   └── → /signup?role=parent
│       ├── Sign Up (full name, email, phone, password, language)
│       ├── Success → /parent
│       └── requireSignin → /login (after 2s delay)
│
└── Teacher selected
    └── → /signup?role=teacher
        ├── Sign Up (same fields)
        ├── Success → /admin
        └── requireSignin → /login (after 2s delay)

/login
├── Sign In (email + password)
├── Success → role-based dashboard
└── "New to Lumo? Get Started" → /onboarding
```

---

## Identified Gaps & Problems

### 1. No "Sign In" path from onboarding
- Student flow has no way to say "I already have an account"
- Parent/Teacher flows jump straight to signup with no login option
- Login screen exists but is disconnected from the onboarding experience

### 2. Guest session is implicit
- Download step silently creates a guest session if `auth.profile == null`
- User has no indication they're in "guest mode" vs "signed in"
- No clear upgrade path from guest → authenticated

### 3. No "Continue as Guest" explicit option
- Student must select a grade to proceed, forcing data entry
- Some users may want to browse before committing

### 4. No password recovery
- Login screen has no "Forgot Password" link
- Signup screen has no password confirmation field

### 5. No email verification handling
- Backend may return `requireSignin: true` after signup
- UI shows a generic message then redirects after 2s
- No retry/resend verification option

### 6. Inconsistent signup fields
- `fullName` is required on signup but not used during onboarding
- `phoneNumber` is optional but no validation/formatting
- `preferredLanguage` defaults to `'en'` even though onboarding asks first

### 7. Parent/Teacher onboarding is minimal
- They skip the language/grade/download steps entirely
- No guided setup for their specific use case
- No child-linking flow for parents during initial setup

---

## Proposed Improvements

### A. Unified Auth Entry Point

**Option A1: Single Auth Stack**
```
/onboarding (or /auth)
├── Welcome step
│   ├── "Get Started" → continues onboarding wizard
│   ├── "Sign In" → login form inline
│   └── Role cards → if not signed in, show signup form inline
```

**Option A2: Keep Separate Screens, Improve Navigation**
```
/onboarding
├── Student → Language → Grade → Download → /student
├── Parent/Teacher → /signup?role=X
│   └── Add "Already have an account? Sign In" link
└── Add "Already have an account? Sign In" link on Welcome step
```

**Recommendation: A2** — Less disruptive, keeps existing routing intact.

### B. Guest Mode UX

**Add to OnboardingScreen:**
1. Show a subtle "Continue as Guest" button on the Welcome step
2. When guest mode is active, show a banner/badge on the student dashboard
3. Provide "Sign In to Save Progress" prompt from guest dashboard
4. On sign-in with existing account, offer to merge guest progress

### C. Password Recovery

**Add to LoginScreen:**
- "Forgot Password?" link below the password field
- Navigate to `/forgot-password` or show a modal
- Backend should support password reset email

### D. Signup Improvements

**Add to SignupScreen:**
1. Password confirmation field
2. Password strength indicator
3. Terms of Service + Privacy Policy checkbox (required before submit)
4. Remove `preferredLanguage` dropdown if onboarding already captured it
5. Show role-specific branding (e.g., "Parent Account" header is good)

### E. Post-Signup Flow

**Current:** Backend returns `requireSignin: true` → wait 2s → redirect to login

**Proposed:**
1. Show clear message: "Account created! Please check your email to verify, then sign in."
2. Provide "Resend Email" button (if backend supports it)
3. Auto-fill email on login screen when redirected from signup
4. Remove the 2-second delay — let user tap "Sign In" when ready

### F. Session Persistence & Resume

**Current:** `loadInitialSession()` checks Supabase on app start

**Proposed:**
1. If Supabase session exists but no local profile → pull from remote
2. If Supabase session exists AND local profile exists AND grade not selected → redirect to grade selection step
3. If fully onboarded → go straight to dashboard
4. Show a brief splash/loading screen while auth initializes

### G. Role-Specific Onboarding (Post-Login)

**For Parents:**
```
After signup/login:
1. Welcome + brief tutorial
2. Link child account (enter child's code / invite)
3. Dashboard
```

**For Teachers:**
```
After signup/login:
1. Welcome + brief tutorial
2. Create/join classroom
3. Admin dashboard
```

---

## Implementation Priority

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| P0 | Add "Sign In" link to onboarding Welcome step | Low | High |
| P0 | Auto-fill email on login when redirected from signup | Low | Medium |
| P1 | Add "Forgot Password" flow | Medium | High |
| P1 | Password confirmation + strength on signup | Low | Medium |
| P1 | Show guest mode indicator on dashboard | Low | Medium |
| P2 | Guest → Sign In merge flow | Medium | Low |
| P2 | Role-specific post-login onboarding | High | Medium |
| P2 | Terms of Service acceptance | Low | Medium |
| P3 | Resume incomplete onboarding for returning users | Medium | Low |

---

## Suggested File Changes

### New Files
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/guest_prompt_dialog.dart`

### Modified Files
- `lib/features/auth/presentation/onboarding_screen.dart` — add sign-in link, guest mode
- `lib/features/auth/presentation/login_screen.dart` — add forgot password, email prefill
- `lib/features/auth/presentation/signup_screen.dart` — password confirmation, remove language dropdown
- `lib/features/auth/auth_provider.dart` — add `mergeGuestProgress()`, `resetPassword()`
- `lib/core/router/app_router.dart` — add `/forgot-password` route, redirect logic

---

## Auth Flow State Machine

```
                    ┌─────────────┐
                    │   App Start  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ Loading Auth │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         ┌────▼────┐  ┌───▼────┐  ┌───▼─────┐
         │ Session │  │ Guest  │  │  None   │
         │  Found  │  │  Only  │  │         │
         └────┬────┘  └───┬────┘  └───┬─────┘
              │            │            │
         ┌────▼────┐  ┌───▼────┐  ┌───▼─────┐
         │ Onboard │  │ Onboard│  │ Onboard │
         │ Complete│  │Incomplete│ │  Start  │
         └────┬────┘  └───┬────┘  └───┬─────┘
              │            │            │
         ┌────▼────┐  ┌───▼────┐  ┌───▼─────┐
         │Dashboard│  │Grade/  │  │Welcome  │
         │         │  │Subject │  │Screen   │
         └─────────┘  └────────┘  └─────────┘
```

---

## Notes

- Supabase auth is used for session management but the app wraps it in a custom `AuthNotifier`
- `ProfileLocal` is the source of truth for role/grade/language locally
- `isDirty` flag tracks local changes pending sync
- All auth screens currently use `ConsumerStatefulWidget` with Riverpod
- The app supports offline-first operation with Isar local database
