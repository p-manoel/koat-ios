import XCTest
@testable import Koat

@MainActor
final class LaunchCoverTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.makeKeyAndVisible()
    }

    override func tearDown() async throws {
        window.isHidden = true
        window = nil
    }

    func testLightTravelsAlongTheStrokeWhileWaiting() async throws {
        let cover = LaunchCoverView(reducesMotion: false)
        install(cover)
        try await waitUntil { cover.isSheenActive }

        let sheen = try XCTUnwrap(cover.markView.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        XCTAssertEqual(sheen.frame, cover.markView.bounds)
        XCTAssertNotNil(sheen.mask?.contents, "the highlight is clipped to the glyph")
        XCTAssertEqual(sheen.startPoint, CGPoint(x: 0, y: 1), "runs from the bottom-left")
        XCTAssertEqual(sheen.endPoint, CGPoint(x: 1, y: 0), "toward the top-right, along the stroke")
        let resting = try XCTUnwrap(sheen.locations?.map(\.doubleValue))
        XCTAssertLessThanOrEqual(resting.max() ?? 1, 0, "between sweeps the band rests off the glyph")

        let cadence = try XCTUnwrap(sheen.animation(forKey: LaunchCoverView.sheenAnimationKey) as? CAAnimationGroup)
        XCTAssertEqual(cadence.duration, LaunchArtwork.sheenPeriod)
        XCTAssertEqual(cadence.repeatCount, .infinity)
        XCTAssertGreaterThan(cadence.beginTime, CACurrentMediaTime() - LaunchArtwork.sheenLeadIn - 1, "a fast launch never sees the sweep begin")
        XCTAssertEqual(cadence.animations?.first?.duration, LaunchArtwork.sheenSweepDuration)
    }

    func testReduceMotionKeepsTheMarkStillAndOnlyCrossFades() async throws {
        let cover = LaunchCoverView(reducesMotion: true)
        install(cover)
        try await Task.sleep(for: .seconds(LaunchArtwork.sheenLeadIn + 0.2))
        XCTAssertFalse(cover.isSheenActive)

        cover.dismiss()
        XCTAssertEqual(cover.markView.transform, .identity)
        XCTAssertEqual(cover.alpha, 0)
        try await waitUntil { cover.superview == nil }
    }

    func testHandoffLiftsTheMarkAlongTheStrokeThenRemovesTheCover() async throws {
        let cover = LaunchCoverView(reducesMotion: false)
        install(cover)

        cover.dismiss()
        let lift = cover.markView.transform
        XCTAssertGreaterThan(lift.tx, 0, "drifts right")
        XCTAssertLessThan(lift.ty, 0, "and up")
        XCTAssertEqual(lift.tx, -lift.ty, accuracy: 0.01, "along the K's 45° flick")
        XCTAssertEqual(hypot(lift.tx, lift.ty), LaunchArtwork.handoffTravel, accuracy: 0.05)
        XCTAssertEqual(lift.a, LaunchArtwork.handoffScale, accuracy: 0.001)
        XCTAssertEqual(cover.markView.alpha, 0)
        XCTAssertFalse(cover.isUserInteractionEnabled)

        try await waitUntil { cover.superview == nil }
        cover.dismiss()
        XCTAssertNil(cover.superview, "a second dismissal is a no-op")
    }

    private func install(_ cover: LaunchCoverView) {
        window.addSubview(cover)
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            cover.topAnchor.constraint(equalTo: window.topAnchor),
            cover.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        window.layoutIfNeeded()
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Timed out waiting for the launch cover", file: file, line: line)
    }
}
