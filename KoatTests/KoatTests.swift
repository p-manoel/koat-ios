//
//  KoatTests.swift
//  KoatTests
//
//  Created by Pedro Manoel on 10/04/25.
//

import Testing
@testable import Koat

struct KoatTests {

    @Test func pushRegistrationIncludesCurrentTimeZone() throws {
        let payload = PushNotificationManager.registrationPayload(
            token: "device-token",
            deviceId: "device-id",
            timeZoneIdentifier: "America/Fortaleza"
        )

        let subscription = try #require(payload["push_subscription"] as? [String: String])
        #expect(subscription["platform"] == "ios")
        #expect(subscription["device_token"] == "device-token")
        #expect(subscription["device_id"] == "device-id")
        #expect(subscription["time_zone"] == "America/Fortaleza")
    }

    @Test func mealReminderDeepLinkUsesAppOrigin() throws {
        let url = try #require(
            App.deepLinkURL(
                for: "/meal_reminders/42",
                baseURL: "https://app.koat.io"
            )
        )

        #expect(url.absoluteString == "https://app.koat.io/meal_reminders/42")
    }

}
