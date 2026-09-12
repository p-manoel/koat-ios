import UIKit

/// The launch artwork is drawn twice: first by the system from
/// `LaunchScreen.storyboard`, then by `LaunchCoverView` as a cover that stays
/// until the first document finishes. Both must place the mark identically so
/// the handoff has no seam. The storyboard mirrors these values by hand;
/// `WebNavigationTests` checks that the two stay in step.
///
/// The K uses the app icon's outlined geometry in brand blue on white.
/// Its upper stroke points up and to the right. While the
/// page loads, light travels along the stroke. When the page is ready, the mark
/// leaves along the stroke. Nothing else moves.
enum LaunchArtwork {
    /// Square frame of the K mark. The asset fills the frame's height.
    static let markSize: CGFloat = 120

    /// The mark sits at the geometric centre of the screen on every device size.
    /// Expressed as a centerY multiplier so the storyboard can mirror it exactly.
    static let markCenterYMultiplier: CGFloat = 1.0

    /// The web shell's `<body>` is white too, so nothing flashes when the cover
    /// dissolves into the first page.
    static let canvas = UIColor.white

    /// Direction of the K's final flick, from the stem to the top-right tip, as a
    /// unit vector in view coordinates (y grows downward).
    static let strokeDirection = CGVector(dx: 0.7071, dy: -0.7071)

    // MARK: Waiting: light travels along the stroke

    /// A soft highlight climbs the mark from bottom-left to top-right, along its
    /// upper stroke. It is clipped to the glyph, so the
    /// canvas itself never shimmers.
    static let sheenTint = UIColor.white
    static let sheenPeakAlpha: CGFloat = 0.5

    /// Width of the highlight band as a fraction of the mark's diagonal.
    static let sheenBandWidth: CGFloat = 0.35

    /// One pass of the highlight across the mark.
    static let sheenSweepDuration: TimeInterval = 1.1

    /// Sweep plus rest. The rest keeps the cadence calm; this is not a spinner.
    static let sheenPeriod: TimeInterval = 2.4

    /// Fast launches stay still. The first sweep begins only if the page has not
    /// arrived by then, so a cached page never shows motion that then aborts.
    static let sheenLeadIn: TimeInterval = 0.4

    // MARK: Handoff: the mark leaves along the stroke

    /// A critically damped spring, so the mark lifts away without a bounce. It
    /// grows a little and drifts along the stroke; the canvas melts a beat behind
    /// it, so the mark reads as an object leaving, not a picture fading.
    static let handoffDuration: TimeInterval = 0.42
    static let handoffScale: CGFloat = 1.08

    /// Points the mark travels along `strokeDirection` while it fades.
    static let handoffTravel: CGFloat = 18

    /// The canvas starts fading this long after the mark starts lifting.
    static let handoffCanvasDelay: TimeInterval = 0.07

    /// With Reduce Motion the whole cover only cross-fades, in this time.
    static let handoffFadeDuration: TimeInterval = 0.3
}
