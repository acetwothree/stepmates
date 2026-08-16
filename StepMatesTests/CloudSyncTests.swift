//
//  CloudSyncTests.swift
//  StepMatesTests
//

import Testing
@testable import StepMates

struct CloudSyncTests {
    @Test func activeWagerRoundTripsThroughJSONForCloudKitStorage() throws {
        let wager = Wager.mockVersusSprint
        let data = try JSONEncoder().encode(wager)
        let decoded = try JSONDecoder().decode(Wager.self, from: data)
        #expect(decoded == wager)
    }
}
