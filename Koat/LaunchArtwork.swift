import UIKit

/// The launch artwork is drawn twice: first by the system from
/// `LaunchScreen.storyboard`, then by `AppWebViewController` as a cover that
/// stays until the first document finishes. Both must place the mark
/// identically so the handoff has no seam. The storyboard mirrors these values
/// by hand; `WebNavigationTests` checks that the two stay in step.
enum LaunchArtwork {
    /// Square frame of the K mark. The asset fills the frame's height.
    static let markSize: CGFloat = 120

    /// The mark sits at the optical centre: 5% of the screen height above the
    /// geometric centre, on every device size.
    static let markCenterYMultiplier: CGFloat = 0.9

    /// The web shell's `<body>` is white too, so nothing flashes when the cover
    /// dissolves into the first page.
    static let canvas = UIColor.white

    /// Handoff: a critically damped spring, so the mark lifts away without a
    /// bounce. Springboard zoomed the icon into this artwork; the mark keeps
    /// growing as it fades, so the system's motion and ours read as one gesture.
    static let handoffDuration: TimeInterval = 0.45
    static let handoffScale: CGFloat = 1.08
}
