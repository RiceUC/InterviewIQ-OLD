# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**InterviewIQ** is a native iOS app for structured interview scoring and evaluation. Built with SwiftUI + Firebase (Realtime Database + Auth), targeting **iOS 26.0**, Swift 5.0. The app is offline-first: scores are persisted locally before any network write.

---

## Build & Run

This is an Xcode project — there is no CLI build script. All building, running, and testing is done through Xcode or `xcodebuild`.

```bash
# Build from CLI (simulator)
xcodebuild -project InterviewIQ.xcodeproj \
           -scheme InterviewIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build

# Run tests
xcodebuild test \
           -project InterviewIQ.xcodeproj \
           -scheme InterviewIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test \
           -project InterviewIQ.xcodeproj \
           -scheme InterviewIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           -only-testing:InterviewIQTests/YourTestClass
```

Firebase SDK is integrated via Swift Package Manager (SPM). Open `InterviewIQ.xcodeproj` in Xcode to resolve packages on first checkout.

---

## Architecture

The app enforces a strict **Multitier + MVVM** separation. Never let Views call repositories or the Realtime Database directly — always go through the service layer.

```
View  →  ViewModel  →  Service  →  Repository  →  Realtime Database / UserDefaults
```

### Tiers

| Tier | Location | Role |
|---|---|---|
| **Models** | `Core/Models/` | Plain Swift structs, `Codable`, no business logic |
| **Repositories** | `Core/Repositories/` | Raw read/write to Realtime Database and local storage |
| **Services** | `Core/Services/` | Business rules, validation, orchestration |
| **ViewModels** | `Features/**/` | `@Observable` classes; own all UI state and async calls |
| **Views** | `Features/**/` | SwiftUI views; receive a ViewModel, trigger actions |

### Realtime Database node paths

| Node | Path |
|---|---|
| Sessions | `sessions/{sessionId}` |
| Candidates | `sessions/{sessionId}/candidates/{candidateId}` |
| Rubric questions | `sessions/{sessionId}/rubricQuestions/{id}` |
| Score records | `sessions/{sessionId}/scoreRecords/{candidateId}` |
| Candidate locks | `sessions/{sessionId}/candidateLocks/{candidateId}` |

### Realtime Database Schema (Structure B)

```json
{
  "users": {
    "{userId}": {
      "id": "String",
      "name": "String",
      "email": "String",
      "role": "admin | panelist"
    }
  },
  "sessions": {
    "{sessionId}": {
      "id": "String",
      "title": "String",
      "date": "Timestamp",
      "adminId": "String",
      "interviewerIds": ["String"],
      "candidates": {
        "{candidateId}": {
          "id": "String",
          "name": "String",
          "sessionId": "String"
        }
      },
      "rubricQuestions": {
        "{rubricQuestionId}": {
          "id": "String",
          "prompt": "String",
          "maxScore": "Int",
          "weight": "Double",
          "order": "Int",
          "isRequired": "Bool"
        }
      },
      "scoreRecords": {
        "{candidateId}": {
          "id": "String",
          "candidateId": "String",
          "interviewerId": "String",
          "sessionId": "String",
          "totalScore": "Int (0–100)",
          "notes": "String",
          "status": "in_progress | submitted",
          "syncStatus": "SYNCED | PENDING | FAILED",
          "isImmutable": "Bool",
          "submittedAt": "Timestamp?",
          "lockedAt": "Timestamp?",
          "questionScores": [
            {
              "id": "String",
              "questionId": "String",
              "score": "Int (1–maxScore; 0 = unanswered)",
              "notes": "String"
            }
          ]
        }
      },
      "candidateLocks": {
        "{candidateId}": {
          "candidateId": "String",
          "interviewerId": "String",
          "sessionId": "String",
          "lockedAt": "Timestamp",
          "expiresAt": "Timestamp",
          "isLocked": "Bool"
        }
      }
    }
  }
}
```

---

## Key Systems

### Offline-First Persistence (NFR-07)

`ScoreRepository` always writes to **UserDefaults** first (key: `pending_score_records`), then attempts a Realtime Database write. `OfflineSyncManager` (`@Observable`) wraps `NWPathMonitor`; when connectivity is restored it flushes all pending `ScoreRecord`s via `syncPending()`. ViewModels call `syncManager.enqueue(_:)` — never write to the Realtime Database directly from a ViewModel.

### 1:1 Candidate Locking (UC-04)

Before a panelist can score a candidate, `InterviewConductorService.lockCandidate()` writes a `CandidateLock` node to the Realtime Database. The lock expires after 2 hours (`lockDuration`). A lock is denied if another interviewer holds a non-expired lock. `releaseLock()` must be called on submit or cancel. Score `0` means unanswered; `QuestionScore.isAnswered` is the canonical check.

### Score Immutability

`ScoreRecord.isImmutable = true` and `status = "submitted"` are set at submission time. `ScoreRepository.markAsImmutable()` writes this flag to the Realtime Database. Once immutable, a record must never be overwritten.

### Weighted Score Calculation

`InterviewConductorService.calculateTotalScore()` computes: `Σ(score × weight) / Σ(maxScore × weight) × 100`. This produces a 0–100 integer. The same formula will be used by `CandidateRankingService` for the dashboard ranking.

---

## Feature Modules

### `Features/InterviewRating/` — UC-04 (Panelist flow, fully implemented)

- `InterviewRatingView` — root navigator; switches between `CandidateListView` and the inline rating screen based on `viewModel.isInRatingPhase`
- `InterviewRatingViewModel` — single shared `@Observable` class; owns the full UC-04 state machine (candidate list → lock → score → submit → release)
- `CandidateListView` — pulls candidate status from local UserDefaults (no extra network call)
- `QuestionScoringView` / `ScoreButtonRow` — stateless scoring card; score is a `@Binding`

### `Features/SessionSetup/` — UC-03 (stub)

`CreateSessionView` and `CreateSessionViewModel` are currently empty stubs.

### `Features/CandidateDashboard/` — Admin ranking (stub)

`DashboardView`, `DashboardViewModel`, and `CandidateRangkingService` are currently empty stubs.

---

## State Management Pattern

All ViewModels use **`@Observable`** (Swift 5.9 macro, not `ObservableObject`). Views use `@State private var viewModel = MyViewModel()` at the root and pass it as `@Bindable` or a plain reference to child views. There are no `@StateObject` or `@EnvironmentObject` usages; avoid introducing them.

---

## Current Entry Point

`ContentView.swift` is a **temporary dev harness** that hard-codes `mockSessionId` and `mockInterviewerId` and goes straight to `InterviewRatingView`. It will be replaced by the auth flow once branches are merged. Do not build permanent logic on top of `ContentView`.

---

## Shared UI Components (`Core/UIComponents/`)

- `PrimaryButton` — full-width button with loading state and destructive variant
- `StarRatingView` — 1–N star picker (binding to `Int`); not currently used in UC-04 (UC-04 uses `ScoreButtonRow` instead)
- `StatusBannerView` — inline private struct in `InterviewRatingView`; auto-dismisses after 3 seconds

---

## Firebase

`GoogleService-Info.plist` is present in the repo. `FirebaseApp.configure()` is called from `AppDelegate`. The database in use is **Firebase Realtime Database** (not Firestore). All writes go through `DatabaseReference.setValue(_:)` or `updateChildValues(_:)` for partial updates; use `setValue` for full node writes and `updateChildValues` when only specific fields change.

---

## Git Commit Convention

This project follows **Conventional Commits**. Every commit must use this format:

```
type(scope): short description

[optional body]
```

### Types

| Type | Use when |
|---|---|
| `feat` | Adding a new feature or capability |
| `fix` | Fixing a bug |
| `refactor` | Restructuring code without changing behavior |
| `style` | Formatting, whitespace, naming — no logic change |
| `docs` | Documentation only (comments, README, and similar) |
| `chore` | Build config, SPM packages, Xcode project settings |
| `test` | Adding or fixing tests |
| `perf` | Performance improvement |

### Scopes (use the UC or feature name)

Common scopes in this project: `session-setup`, `live-rating`, `dashboard`, `auth`, `offline-sync`, `rubric`, `candidate-lock`, `infra`.

### Rules

- **Subject line**: lowercase, imperative mood, no period, max 72 characters.
- **Scope**: match the feature module or use-case (e.g. `feat(live-rating): ...`). Omit only for truly cross-cutting changes.
- **One logical change per commit** — do not bundle unrelated changes.
- **Commit at every meaningful checkpoint**: completing a feature, fixing a bug, finishing a refactor. Do not leave meaningful work uncommitted at the end of a session.
- **No AI/tooling references**: never mention AI agent files (e.g. `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) or agentic tooling characteristics in commit messages. Describe the actual change to the project, not the tooling used to make it.

### Examples

```
feat(session-setup): add CreateEditSessionView and ViewModel stubs
fix(candidate-lock): deny lock if existing lock has not expired
refactor(offline-sync): extract syncRecord into private helper
docs: update architecture documentation and commit conventions
chore: configure project build settings and package dependencies
```
