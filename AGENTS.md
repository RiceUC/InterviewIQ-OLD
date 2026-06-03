# InterviewIQ - System Features & Architecture Mapping

## Overview
**InterviewIQ** is an offline-first, native iOS application designed for structured interview scoring and evaluation. It utilizes a strict Multitier Architecture combined with the MVVM (Model-View-ViewModel) pattern to ensure offline reliability, data integrity, and strict concurrency control during active interview sessions.

---

## 1. Session & Rubric Management (Session Creator)
Any authenticated user can create an interview session. By doing so, they automatically become the **session owner** — referred to throughout as the "admin" of that session. This is a session-scoped role, not a global privilege; the same user can own one session while participating as a panelist in another.

* **View Active Sessions:** Each user sees only the sessions they own via the **`SessionDashboard`**, which binds to the **`SessionDashboardVM`** and filters by the creator's user ID.
* **Create/Edit Sessions:** The session creator can define the event's `title` and `date` using the **`CreateEditSessionView`** and **`CreateEditSessionVM`**.
* **Define Scoring Rubrics:** Admins can create **`RubricQuestion`** objects, defining specific prompts and weight multipliers using the **`CreateEditRubricView`** and **`CreateEditRubricVM`**.
* **Business Logic:** The **`SessionManagementService`** intercepts these actions to ensure data validity. Crucially, it enforces the `lockRubricEdits()` rule, ensuring that once a session is active, the rubric cannot be modified.
* **Data Access:** Data is routed through the **`SessionRepository`** and **`RubricRepository`**.

## 2. User & Panelist Management (Session Owner)
The owner of a session (the user who created it) has the authority to assign other existing users as panelists for that specific session.

* **Assign Roles:** The **`UserManagementView`** (driven by **`UserManagementVM`**) provides the UI for selecting users and assigning them as panelists for a session.
* **Business Logic:** The **`UserAccessService`** handles this flow. It first runs `verifyAdminRights()` to confirm the requesting user is the owner of the target session (not a system-wide role check), and then executes `attachPanelist()` to grant the selected **`User`** access to the session.
* **Data Access:** Changes to user roles and session assignments are managed by the **`UserRepository`**.

## 3. Live Interview Conduction (Panelist)
Panelists use the app to conduct interviews, leveraging offline-first capabilities and concurrency locking to prevent data overlap.

* **Active Scoring UI:** Panelists evaluate a **`Candidate`** using the **`LiveRatingScreen`**. Input is managed by the **`LiveRatingVM`**, which holds the `currentCandidate` state and triggers `submitRating()`.
* **Concurrency Locking (The 1:1 Rule):** When a panelist selects a candidate, the **`InterviewConductorService`** immediately executes `lockCandidate()` to ensure no other panelist can interview the same person simultaneously.
* **Score Immutability:** Before an interview can be submitted, the `InterviewConductorService` runs `validateAllQuestionsAnswered()`. Once validated, `finalizeInterview()` locks the **`Score`** records permanently.
* **Data Access & Offline Sync:** The **`ScoreRepository`** attempts to save the data. It writes to the **`LocalPersistenceController`** first. If the device is offline, the **`OfflineSyncManager`** uses `queueOfflineData()` to hold the payload, continually running `monitorConnectivity()` until it can successfully `pushQueuedData()` to the **`NetworkAPIClient`**.

## 4. Candidate Ranking & Dashboard (Session Owner)
After interviews are completed, the session owner can review objective, mathematically weighted rankings for the candidates in their session.

* **Dashboard Display:** The **`DashboardComparisonView`** displays the final list of candidates. The UI simply observes the `rankedCandidates` list provided by the **`DashboardComparisonVM`**.
* **Calculation Engine:** The ViewModel relies on the **`CandidateRankingService`**. This service acts as the mathematical core, running `calculateWeightedScore()` by combining raw scores with rubric weights, and then executing `sortCandidates()` to generate the final hierarchy.
* **Data Access:** The service pulls the necessary raw data (candidates and their aggregated scores) seamlessly from the **`CandidateRepository`** and **`ScoreRepository`**.

---

## Infrastructure Tier Summary
All repositories strictly follow the offline-first mandate by interacting with two infrastructure controllers:
1.  **`LocalPersistenceController`:** Acts as the primary CoreData/SwiftData interface (`saveContext()`, `fetch()`, `delete()`) ensuring the app works flawlessly without an internet connection.
2.  **`NetworkAPIClient`:** Acts as the gateway to the cloud backend, handling standard REST HTTP methods (`get()`, `post()`, `put()`, `delete()`) when syncing data.

@CLAUDE.md