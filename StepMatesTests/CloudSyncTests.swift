//
//  CloudSyncTests.swift
//  StepMatesTests
//

import Testing
@testable import StepMates

struct CloudSyncTests {
    @Test func pinkyPromiseRequestRoundTripsThroughJSON() throws {
        let request = PinkyPromiseRequest(
            reason: "Trailing by 1,800 steps",
            requestedAt: Date(timeIntervalSince1970: 1_700_000_000),
            requestedByRole: .partner,
            resolution: nil
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PinkyPromiseRequest.self, from: data)
        #expect(decoded == request)
    }

    @Test func pinkyPromiseResolutionRoundTripsThroughJSON() throws {
        var request = PinkyPromiseRequest(
            reason: "Cut me some slack",
            requestedAt: .now,
            requestedByRole: .owner,
            resolution: nil
        )
        request.resolution = .approved
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PinkyPromiseRequest.self, from: data)
        #expect(decoded.resolution == .approved)
    }

    @Test func activeWagerRoundTripsThroughJSONForCloudKitStorage() throws {
        let wager = Wager.mockVersusSprint
        let data = try JSONEncoder().encode(wager)
        let decoded = try JSONDecoder().decode(Wager.self, from: data)
        #expect(decoded == wager)
    }
}
