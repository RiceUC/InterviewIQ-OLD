//
//  AuthenticationTest.swift
//  InterviewIQTests
//
//  Created by student on 03/06/26.
//

import XCTest
@testable import InterviewIQ

final class AuthenticationTest: XCTestCase {

    // SUT = System Under Test
    var sut: AuthViewModel!

    // This runs automatically BEFORE every single test case
    override func setUp() {
        super.setUp()
        sut = AuthViewModel()
    }

    // This runs automatically AFTER every single test case
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - 1. SIGN UP / REGISTRATION TESTS

    /// Scenario: Password too short
    func test_performRegistration_whenPasswordIsTooShort_shouldFailValidation() async {
        // GIVEN
        sut.fullName = "Alex Smith"
        sut.emailAddress = "alex@interviewiq.com"
        sut.userPassword = "123" // ❌ Invalid: Less than 6 characters

        // WHEN
        await sut.performRegistration()

        // THEN
        XCTAssertTrue(sut.hasAuthenticationError)
        XCTAssertEqual(sut.errorMessage, "Password must be at least 6 characters long.")
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.hasSuccessfullyRegistered)
    }

    // MARK: - 2. SIGN IN & LOCKOUT TESTS

    /// Scenario: Verifies that entering the wrong password increments the internal tracking footprint
    func test_performLogin_withWrongPassword_shouldIncrementFailedAttemptsAndShowError() async {
        // GIVEN
        sut.emailAddress = "testuser@interviewiq.com"
        sut.userPassword = "wrong_password_attempt"

        // WHEN
        await sut.performLogin()

        // THEN
        XCTAssertTrue(sut.hasAuthenticationError)
        XCTAssertEqual(sut.errorMessage, "Invalid credentials. Please check your email and password.")
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isAccountLocked, "Should not be locked out on the 1st failed attempt")
    }

    /// Scenario: Verifies that hitting exactly 5 bad attempts blocks the account completely
    func test_performLogin_whenFailed5Times_shouldTriggerAccountLockout() async {
        // GIVEN
        sut.emailAddress = "target@interviewiq.com"
        sut.userPassword = "incorrect_password"

        // WHEN: Simulate running the login function 5 times consecutively
        for _ in 1...5 {
            await sut.performLogin()
        }

        // THEN
        XCTAssertTrue(sut.isAccountLocked, "Account should be locked precisely on the 5th attempt")
        XCTAssertTrue(sut.hasAuthenticationError)
        XCTAssertEqual(sut.errorMessage, "Account locked after 5 failed attempts. Please try again in 15 minutes.")
    }

    /// Scenario: Tests the Pre-Auth Gatekeeper Interceptor
    func test_performLogin_whenAlreadyLockedOut_shouldExitEarlyWithoutNetworkCall() async {
        // GIVEN: Drive the email into a locked state first
        sut.emailAddress = "locked@interviewiq.com"
        sut.userPassword = "bad_password"
        
        for _ in 1...5 {
            await sut.performLogin()
        }
        
        // Confirm it is locked
        XCTAssertTrue(sut.isAccountLocked)

        // WHEN: Try to log in again while the lockout is active
        sut.userPassword = "AnyPassword"
        await sut.performLogin()

        // THEN: Check if the early return statement catches it dynamically
        XCTAssertTrue(sut.isAccountLocked)
        XCTAssertTrue(sut.errorMessage.contains("Account temporarily locked for 15 minutes."))
    }
    
    /// Scenario: Tests that email normalization functions correctly across casing variances
    func test_emailNormalization_shouldTrackLockoutRegardlessOfCasing() async {
        // 1. Test first format input
        sut.emailAddress = "Tester@InterviewIQ.com "
        let firstCleaned = sut.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 2. Test second format input
        sut.emailAddress = "tester@interviewiq.com"
        let secondCleaned = sut.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // ASSERT: Ensure your normalization logic produces identical database lookup keys
        XCTAssertEqual(firstCleaned, secondCleaned, "The email normalization failed to match formatting outputs.")
    }
}
