# Best Ball Madness (FattyGolf)

Best Ball Madness is a mobile-first weekly fantasy golf game built with Flutter (using Riverpod for state management) and backed by Supabase (PostgreSQL, Authentication, Realtime, and Edge Functions).

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- Supabase CLI
- Dart SDK

### Installation
1. Clone the repository.
2. Copy `.env.example` to `.env` and fill in the required project credentials.
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Start the local development server (Web/iOS/Android):
   ```bash
   flutter run --dart-define-from-file=.env
   ```

---

## Repository Conventions

### Branching Model
We use short-lived branches off `main` following these prefixes:
*   `feature/` — New features or visual changes (e.g., `feature/dashboard-drafting`)
*   `fix/` — Bug fixes (e.g., `fix/leaderboard-tiebreaker`)
*   `chore/` — Documentation, dependencies, or configuration changes (e.g., `chore/ci-vercel-config`)

### Commit Message Format
We enforce the standard semantic commit message conventions:
```
type(scope): description
```
*   **Types:** `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`
*   **Scope:** Optional context about what is being changed (e.g., `auth`, `scorecard`, `db`)
*   **Description:** Clear, imperative tone description (e.g., `feat(auth): implement profile-completion gate`)
*   *Example:* `feat(db): create database migration for teams and tournament_golfers`