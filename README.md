# InterviewIQ

We built InterviewIQ, a native iOS app for structured, offline-first interview scoring and evaluation.

This is our project for **ALP MAD — Semester 4**, UC.

---

## Overview

We let interviewers score candidates against a weighted rubric, with every score saved locally first and synced to the cloud once connectivity returns. Any authenticated user can create a session — when they do, they become that session's owner (its "admin") and can build the rubric, assign panelists by email, and review a weighted candidate ranking once interviews are complete. Ownership is scoped per session, so the same person can own one session while serving as a panelist in another.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 26.0+) |
| Language | Swift 5.0 |
| State management | `@Observable` (Swift 5.9 macro) |
| Database | Firebase Realtime Database |
| Auth | Firebase Authentication |
| Offline queue | `NWPathMonitor` + UserDefaults |
| Reporting | `UIGraphicsPDFRenderer` (PDF) + plain-text CSV |
| Dependency management | Swift Package Manager (SPM) |

---

## Architecture

We follow a strict **Multitier + MVVM** pattern. Our views never touch the database directly — every call goes through the service layer.

```
View → ViewModel → Service → Repository → Firebase Realtime Database / UserDefaults
```

| Tier | Location | Role |
|---|---|---|
| Models | `Core/Models/` | Plain `Codable` structs, no business logic |
| Repositories | `Core/Repositories/` | Raw read/write to Realtime Database and local storage |
| Services | `Core/Services/` | Business rules, validation, orchestration |
| ViewModels | `Features/**/` | `@Observable` classes; own all UI state and async calls |
| Views | `Features/**/` | SwiftUI views; receive a ViewModel, trigger actions |

---

## Features

We have all four core use cases working end to end.

| Use Case | Module | Key types |
|---|---|---|
| Authentication & profile | `Features/Authentication/`, `Features/Profile/` | `LoginView`, `RegisterView`, `AuthViewModel`, `ProfileView` |
| Session & rubric management | `Features/SessionSetup/` | `SessionDashboardView`, `CreateEditSessionView`, `CreateEditRubricView` |
| User & panelist management | `Features/UserManagement/` | `UserManagementView`, `UserManagementVM`, `UserAccessService` |
| Live interview conduction | `Features/InterviewRating/` | `LiveRatingScreen`, `LiveRatingVM`, `InterviewConductorService` |
| Candidate ranking & reporting | `Features/CandidateDashboard/` | `DashboardComparisonView`, `CandidateRankingService`, `ReportExportService` |

### Authentication & roles

- We sign users in and register them through Firebase Auth (`AuthViewModel`), persisting each profile at `users/{uid}` via `UserRepository`.
- `ContentView` is our auth gate: it watches the Firebase auth state, loads the user's profile, and routes everyone to a unified `SessionDashboardView`. Deactivated or unloadable accounts get a dedicated recovery screen.
- Roles are `admin` and `interviewer` (`UserRole`), and ownership is decided per session rather than by a global privilege.

### Session & rubric management

- Any user can create and edit sessions (`CreateEditSessionView` / `CreateEditSessionVM`), defining the title and date.
- We build weighted, ordered rubric questions in `CreateEditRubricView`, and `SessionManagementService` locks rubric edits once a session is active so results stay comparable.
- We block deleting a session that already has submitted scores.

### Panelist management

- Session owners assign panelists **by email** in `UserManagementView`; we look the user up and attach them to the session.
- `UserAccessService` runs `verifyAdminRights()` before any change to confirm the requester actually owns that session.

### Live interview conduction

- A panelist selects a candidate and we acquire a 2-hour exclusive lock in the Realtime Database, so two panelists can never score the same candidate at once.
- We save each rubric-question score to UserDefaults immediately. On submit, we require every question to be answered, then mark the record immutable and sync it.
- `OfflineSyncManager` watches connectivity with `NWPathMonitor` and retries any `PENDING` / `FAILED` writes when the network returns.

### Candidate ranking & reporting

- Once scores are in, `DashboardComparisonView` shows a ranked, color-coded leaderboard with summary stats (candidate count, average, top score).
- `CandidateRankingService` computes the weighted score and sorts candidates.
- We export the report as **PDF** or **CSV** through `ReportExportService` and share it via the system share sheet.

### Weighted score formula

```
totalScore = Σ(score × weight) / Σ(maxScore × weight) × 100
```

This produces the 0–100 integer we use for both submission and dashboard ranking.

---

## Database Schema

```
users/
  {userId}/         userId, fullName, emailAddress, role (admin | interviewer), isActive

sessions/
  {sessionId}/      id, title, date, adminId, interviewerIds[]
    candidates/
      {candidateId}/    id, name, sessionId
    rubricQuestions/
      {questionId}/     id, prompt, maxScore, weight, order, isRequired
    scoreRecords/
      {candidateId}/    id, candidateId, interviewerId, totalScore, status,
                        syncStatus, isImmutable, submittedAt, lockedAt,
                        questionScores[] { id, questionId, score, notes }
    candidateLocks/
      {candidateId}/    candidateId, interviewerId, lockedAt, expiresAt, isLocked
```

---

## Getting Started

### Prerequisites

- Xcode 16+ with the iOS 26.0 SDK
- A Firebase project with Realtime Database and Authentication enabled
- `GoogleService-Info.plist` placed under `InterviewIQ/`

### Setup

1. Clone the repository.
2. Open `InterviewIQ.xcodeproj` in Xcode — SPM resolves the Firebase dependencies automatically on first open.
3. Build and run on the iPhone 16 simulator or a physical device.

```bash
# Build via CLI
xcodebuild -project InterviewIQ.xcodeproj \
           -scheme InterviewIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build

# Run tests
xcodebuild test \
           -project InterviewIQ.xcodeproj \
           -scheme InterviewIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Project Structure

```
InterviewIQ/
├── App/
│   ├── InterviewIQApp.swift       # App entry point, FirebaseApp.configure()
│   └── ContentView.swift          # Auth gate → unified SessionDashboard
├── Core/
│   ├── Models/                    # UserProfile, Session, Candidate, ScoreRecord, CandidateLock, AuditLog, …
│   ├── Repositories/              # User, Session, Rubric, Candidate, Score, AuditLog
│   ├── Services/                  # InterviewConductorService, OfflineSyncManager, SessionManagementService,
│   │                              #   UserAccessService, AuditLogger
│   ├── UIComponents/              # PrimaryButton, StarRatingView
│   └── Extrensions/               # Color+Brand
└── Features/
    ├── Authentication/            # LoginView, RegisterView, AuthViewModel
    ├── Profile/                   # ProfileView
    ├── SessionSetup/              # SessionDashboard, CreateEditSession, CreateEditRubric
    ├── UserManagement/            # Per-session panelist assignment
    ├── InterviewRating/           # Live scoring + candidate locking
    └── CandidateDashboard/        # Ranking dashboard + PDF/CSV export
```

---

## Contributing

We follow the [Conventional Commits](https://www.conventionalcommits.org/) format for every commit:

```
type(scope): short description
```

Common types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`, `test`, `perf`
Common scopes: `session-setup`, `live-rating`, `dashboard`, `auth`, `offline-sync`, `candidate-lock`, `rubric`, `infra`
