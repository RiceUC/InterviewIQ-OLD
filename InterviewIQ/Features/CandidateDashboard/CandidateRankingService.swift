//
//  CandidateRankingService.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto
//

import Foundation
import FirebaseDatabase

// MARK: - Ranked Candidate Model

struct RankedCandidate: Identifiable {
    let id: String          // candidateId
    let name: String
    let totalScore: Int     // 0–100 weighted percentage
    let rank: Int
    let submittedAt: Date?
    let interviewerId: String
    let questionScores: [QuestionScore]
    let notes: String
}

// MARK: - Service

// CandidateRankingService (C-03): fetches score records and rubric for a session,
// computes weighted totals, and returns candidates sorted highest -> lowest.
// Tie-breaker: earlier submittedAt wins (lower rank number = better).
final class CandidateRankingService {
    private let db = Database.database().reference()

    // Returns a ranked list of candidates for a given session.
    // Candidates with no submitted score record are excluded.
    func fetchRankedCandidates(sessionId: String) async throws -> [RankedCandidate] {
        // 1. Fetch rubric questions (needed for weighted recalculation as source of truth)
        let questions = try await fetchRubricQuestions(sessionId: sessionId)

        // 2. Fetch all candidates so we can map ids → names
        let candidates = try await fetchCandidates(sessionId: sessionId)
        let candidateMap: [String: String] = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.id, $0.name) }
        )

        // 3. Fetch all submitted score records
        let scoreRecords = try await fetchSubmittedScoreRecords(sessionId: sessionId)

        // 4. Compute weighted total for each record and build RankedCandidate list
        var ranked: [RankedCandidate] = scoreRecords.compactMap { record in
            guard let name = candidateMap[record.candidateId] else { return nil }

            // Re-compute from question scores using the same formula as InterviewConductorService
            let total = calculateWeightedScore(questions: questions, questionScores: record.questionScores)

            return RankedCandidate(
                id: record.candidateId,
                name: name,
                totalScore: total,
                rank: 0, // assigned below after sorting
                submittedAt: record.submittedAt,
                interviewerId: record.interviewerId,
                questionScores: record.questionScores,
                notes: record.notes
            )
        }

        // 5. Sort and assign rank numbers
        return sortCandidates(ranked)
    }

    // Sorts candidates highest-score first (tie-break: earlier submittedAt wins)
    // and assigns 1-indexed rank numbers.
    func sortCandidates(_ candidates: [RankedCandidate]) -> [RankedCandidate] {
        var sorted = candidates
        sorted.sort {
            if $0.totalScore != $1.totalScore { return $0.totalScore > $1.totalScore }
            let lhs = $0.submittedAt ?? Date.distantFuture
            let rhs = $1.submittedAt ?? Date.distantFuture
            return lhs < rhs
        }
        return sorted.enumerated().map { index, candidate in
            RankedCandidate(
                id: candidate.id,
                name: candidate.name,
                totalScore: candidate.totalScore,
                rank: index + 1,
                submittedAt: candidate.submittedAt,
                interviewerId: candidate.interviewerId,
                questionScores: candidate.questionScores,
                notes: candidate.notes
            )
        }
    }

    // MARK: - Weighted Score Formula
    // Σ(score × weight) / Σ(maxScore × weight) × 100  →  0–100 Int
    // Matches InterviewConductorService.calculateTotalScore exactly.

    func calculateWeightedScore(questions: [RubricQuestion], questionScores: [QuestionScore]) -> Int {
        guard !questions.isEmpty else { return 0 }
        let scoreMap = Dictionary(uniqueKeysWithValues: questionScores.map { ($0.questionId, $0) })
        var weightedSum = 0.0
        var maxPossible = 0.0
        for q in questions {
            maxPossible += Double(q.maxScore) * q.weight
            if let qs = scoreMap[q.id], qs.isAnswered {
                weightedSum += Double(qs.score) * q.weight
            }
        }
        guard maxPossible > 0 else { return 0 }
        return Int((weightedSum / maxPossible) * 100)
    }

    // MARK: - Private Fetchers

    private func fetchRubricQuestions(sessionId: String) async throws -> [RubricQuestion] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
            .child("rubricQuestions")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.values.compactMap { value -> RubricQuestion? in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let prompt = entry["prompt"] as? String,
                  let maxScore = entry["maxScore"] as? Int,
                  let weight = entry["weight"] as? Double,
                  let order = entry["order"] as? Int,
                  let isRequired = entry["isRequired"] as? Bool
            else { return nil }
            return RubricQuestion(id: id, prompt: prompt, maxScore: maxScore,
                                  weight: weight, order: order, isRequired: isRequired)
        }.sorted { $0.order < $1.order }
    }

    private func fetchCandidates(sessionId: String) async throws -> [Candidate] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
            .child("candidates")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.values.compactMap { value -> Candidate? in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let name = entry["name"] as? String,
                  let sessionId = entry["sessionId"] as? String
            else { return nil }
            return Candidate(id: id, name: name, sessionId: sessionId)
        }
    }

    private func fetchSubmittedScoreRecords(sessionId: String) async throws -> [ScoreRecord] {
        let snapshot = try await db
            .child("sessions").child(sessionId)
            .child("scoreRecords")
            .getData()

        guard let dict = snapshot.value as? [String: Any] else { return [] }
        return dict.values.compactMap { value -> ScoreRecord? in
            guard let entry = value as? [String: Any],
                  let id = entry["id"] as? String,
                  let candidateId = entry["candidateId"] as? String,
                  let interviewerId = entry["interviewerId"] as? String,
                  let sessionId = entry["sessionId"] as? String,
                  let status = entry["status"] as? String,
                  status == "submitted"           // only fully submitted records
            else { return nil }

            var record = ScoreRecord(
                id: id,
                candidateId: candidateId,
                interviewerId: interviewerId,
                sessionId: sessionId
            )
            record.totalScore = entry["totalScore"] as? Int ?? 0
            record.notes = entry["notes"] as? String ?? ""
            record.status = status
            record.isImmutable = entry["isImmutable"] as? Bool ?? false

            if let ts = entry["submittedAt"] as? TimeInterval {
                record.submittedAt = Date(timeIntervalSince1970: ts)
            }
            if let ts = entry["lockedAt"] as? TimeInterval {
                record.lockedAt = Date(timeIntervalSince1970: ts)
            }

            // Parse questionScores array
            if let qsArray = entry["questionScores"] as? [[String: Any]] {
                record.questionScores = qsArray.compactMap { qs -> QuestionScore? in
                    guard let qid = qs["id"] as? String,
                          let questionId = qs["questionId"] as? String,
                          let score = qs["score"] as? Int
                    else { return nil }
                    return QuestionScore(
                        id: qid,
                        questionId: questionId,
                        score: score,
                        notes: qs["notes"] as? String ?? ""
                    )
                }
            }

            return record
        }
    }
}
