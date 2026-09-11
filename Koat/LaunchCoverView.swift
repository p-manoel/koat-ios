import UIKit

/// The in-app continuation of `LaunchScreen.storyboard`: the same mark on the
/// same canvas, placed by `LaunchArtwork`, so the system snapshot and the app's
/// first frame are indistinguishable. From there the cover does two things a
/// static storyboard cannot. While the first page loads, a soft light travels
/// along the K's stroke. When the page is ready, the mark lifts away along that
/// stroke and the canvas melts behind it.
///
/// With Reduce Motion the mark stays still and the cover only cross-fades.
final class LaunchCoverView: UIView {
    static let sheenAnimationKey = "sheen"

    let markView = UIImageView(image: UIImage(named: "KoatLogo"))
    private let sheen = CAGradientLayer()
    private let glyphMask = CALayer()
    private let reducesMotion: Bool
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var isDismissing = false

    init(reducesMotion: Bool = UIAccessibility.isReduceMotionEnabled) {
        self.reducesMotion = reducesMotion
        super.init(frame: .zero)
        accessibilityIdentifier = "launchCover"
        accessibilityViewIsModal = true
        backgroundColor = LaunchArtwork.canvas
        translatesAutoresizingMaskIntoConstraints = false

        markView.contentMode = .scaleAspectFit
        markView.accessibilityLabel = "Koat"
        markView.isAccessibilityElement = true
        markView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(markView)
        NSLayoutConstraint.activate([
            markView.centerXAnchor.constraint(equalTo: centerXAnchor),
            NSLayoutConstraint(item: markView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: LaunchArtwork.markCenterYMultiplier, constant: 0),
            markView.widthAnchor.constraint(equalToConstant: LaunchArtwork.markSize),
            markView.heightAnchor.constraint(equalToConstant: LaunchArtwork.markSize)
        ])

        // The highlight is a narrow gradient band running bottom-left to
        // top-right, along the stroke and toward the light, clipped to the
        // glyph's own alpha so only the K ever catches it.
        let tint = LaunchArtwork.sheenTint
        sheen.colors = [
            tint.withAlphaComponent(0).cgColor,
            tint.withAlphaComponent(LaunchArtwork.sheenPeakAlpha).cgColor,
            tint.withAlphaComponent(0).cgColor
        ]
        sheen.startPoint = CGPoint(x: 0, y: 1)
        sheen.endPoint = CGPoint(x: 1, y: 0)
        sheen.locations = Self.sheenLocations(at: 0)
        glyphMask.contents = markView.image?.cgImage
        glyphMask.contentsGravity = .resizeAspect
        sheen.mask = glyphMask
        markView.layer.addSublayer(sheen)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

    /// Whether the highlight sweep is installed on the mark. It is scheduled as
    /// soon as the cover is on screen and begins after `LaunchArtwork.sheenLeadIn`.
    var isSheenActive: Bool { sheen.animation(forKey: Self.sheenAnimationKey) != nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            sheen.removeAnimation(forKey: Self.sheenAnimationKey)
            return
        }
        startSheen()
        // Core Animation drops running animations when the app is backgrounded.
        // A launch interrupted by a call should come back to a living mark.
        if didBecomeActiveObserver == nil {
            didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.startSheen()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheen.frame = markView.bounds
        glyphMask.frame = markView.bounds
        CATransaction.commit()
    }

    /// The first page is ready underneath. The mark lifts along its stroke and
    /// the canvas melts a beat behind it; the view removes itself when done.
    /// Callers should drop their reference at once so later loads never bring
    /// the cover back.
    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        isUserInteractionEnabled = false

        if reducesMotion {
            UIView.animate(withDuration: LaunchArtwork.handoffFadeDuration, delay: 0, options: .curveEaseOut) {
                self.alpha = 0
            } completion: { _ in
                self.removeFromSuperview()
            }
            return
        }

        let travel = LaunchArtwork.handoffTravel
        let direction = LaunchArtwork.strokeDirection
        let lift = CGAffineTransform(translationX: travel * direction.dx, y: travel * direction.dy)
            .scaledBy(x: LaunchArtwork.handoffScale, y: LaunchArtwork.handoffScale)
        UIView.animate(springDuration: LaunchArtwork.handoffDuration, bounce: 0) {
            self.markView.transform = lift
            self.markView.alpha = 0
        }
        UIView.animate(springDuration: LaunchArtwork.handoffDuration, bounce: 0, delay: LaunchArtwork.handoffCanvasDelay, animations: {
            self.backgroundColor = LaunchArtwork.canvas.withAlphaComponent(0)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    private func startSheen() {
        guard !reducesMotion, !isDismissing, window != nil, !isSheenActive else { return }
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = Self.sheenLocations(at: 0)
        sweep.toValue = Self.sheenLocations(at: 1)
        sweep.duration = LaunchArtwork.sheenSweepDuration
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        // The group outlasts the sweep, which leaves a rest between passes. Both
        // ends of the sweep park the band off the glyph, so the reset is invisible.
        let cadence = CAAnimationGroup()
        cadence.animations = [sweep]
        cadence.duration = LaunchArtwork.sheenPeriod
        cadence.repeatCount = .infinity
        cadence.beginTime = CACurrentMediaTime() + LaunchArtwork.sheenLeadIn
        sheen.add(cadence, forKey: Self.sheenAnimationKey)
    }

    /// Gradient stops for the band at `progress`: 0 parks it just short of the
    /// bottom-left corner, 1 just past the top-right corner.
    private static func sheenLocations(at progress: CGFloat) -> [NSNumber] {
        let half = LaunchArtwork.sheenBandWidth / 2
        let center = -half + progress * (1 + 2 * half)
        return [center - half, center, center + half].map { NSNumber(value: Double($0)) }
    }
}
