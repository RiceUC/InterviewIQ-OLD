# InterviewIQ

A native iOS app for structured, offline-first interview scoring and evaluation.

Built for **ALP MAD — Semester 4**, UC.

---

## Overview

InterviewIQ enables interview panelists to score candidates against a weighted rubric, with scores persisted locally and synced to the cloud once connectivity is restored. Admins manage sessions, rubrics, and panelist assignments; the dashboard surfaces a weighted ranking of all candidates after interviews complete.

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
| Dependency management | Swift Package Manager (SPM) |

---

## Architecture

The app follows a strict **Multitier + MVVM** pattern. Views never touch the database directly.

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

| Use Case | Status | Module |
|---|---|---|
| UC-03 Session & Rubric Management (Admin) | In progress | `Features/SessionSetup/` |
| UC-04 Live Interview Conduction (Panelist) | Implemented | `Features/InterviewRating/` |
| UC-05 Candidate Ranking Dashboard (Admin) | Stub | `Features/CandidateDashboard/` |
| User & Panelist Management (Admin) | Stub | `Features/UserManagement/` |

### UC-04 — Live Interview Conduction (fully implemented)

- Panelist selects a candidate; the app acquires a 2-hour exclusive lock in the Realtime Database (prevents two panelists from scoring the same candidate simultaneously).
- Panelist scores each rubric question; scores are saved to UserDefaults immediately.
- On submit, all questions must be answered; the score record is marked immutable and synced.
- `OfflineSyncManager` retries any pending writes (`PENDING` / `FAILED`) when connectivity returns.

### Weighted Score Formula

```
totalScore = Σ(score × weight) / Σ(maxScore × weight) × 100
```

Produces a 0–100 integer used for both submission and dashboard ranking.

---

## Database Schema

```
users/
  {userId}/         id, name, email, role (admin | panelist)

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

- Xcode 16+ with iOS 26.0 SDK
- A Firebase project with Realtime Database and Authentication enabled
- `GoogleService-Info.plist` placed under `InterviewIQ/`

### Setup

1. Clone the repository.
2. Open `InterviewIQ.xcodeproj` in Xcode — SPM resolves Firebase dependencies automatically on first open.
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
│   └── ContentView.swift          # Temporary dev harness (will be replaced by auth flow)
├── Core/
│   ├── Models/                    # Candidate, Session, ScoreRecord, CandidateLock, …
│   ├── Repositories/              # CandidateRepository, ScoreRepository, SessionRepository
│   ├── Services/                  # InterviewConductorService, OfflineSyncManager, AuthService, …
│   └── UIComponents/              # PrimaryButton, StarRatingView
└── Features/
    ├── InterviewRating/           # UC-04 — fully implemented
    ├── SessionSetup/              # UC-03 — in progress
    ├── CandidateDashboard/        # Admin ranking — stub
    └── UserManagement/            # Panelist assignment — stub
```

---

## Contributing

Follow the [Conventional Commits](https://www.conventionalcommits.org/) format for all commits:

```
type(scope): short description
```

Common types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`, `test`, `perf`  
Common scopes: `session-setup`, `live-rating`, `dashboard`, `auth`, `offline-sync`, `candidate-lock`
