//
//  KoatSpinnerView.swift
//  Koat
//
//  Native twin of the web app's standard loading spinner (the Tailwind
//  `animate-spin` ring: 25%-opacity full circle + 75%-opacity quarter arc
//  in Koat blue), shown while a screen's visit is loading.
//

import UIKit

final class KoatSpinnerView: UIView {
    private static let size: CGFloat = 28
    private static let lineWidth: CGFloat = 4
    // Tailwind blue-600, the brand color used across the web app.
    private static let brandBlue = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)

    private let ringLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()

    private(set) var isAnimating = false

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        isHidden = true

        for (shapeLayer, opacity) in [(ringLayer, Float(0.25)), (arcLayer, Float(0.75))] {
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = Self.brandBlue.cgColor
            shapeLayer.lineWidth = Self.lineWidth
            shapeLayer.opacity = opacity
            layer.addSublayer(shapeLayer)
        }
        arcLayer.strokeEnd = 0.25
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.size, height: Self.size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: (Self.size - Self.lineWidth) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        for shapeLayer in [ringLayer, arcLayer] {
            shapeLayer.frame = bounds
            shapeLayer.path = path.cgPath
        }
    }

    // Core Animation drops animations whenever the view leaves the window
    // (screen pop, app backgrounding), so re-add on re-attach.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isAnimating {
            addRotation()
        }
    }

    func startAnimating() {
        isAnimating = true
        isHidden = false
        addRotation()
    }

    func stopAnimating() {
        isAnimating = false
        isHidden = true
        layer.removeAnimation(forKey: "rotation")
    }

    private func addRotation() {
        guard layer.animation(forKey: "rotation") == nil else { return }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 1
        rotation.repeatCount = .infinity
        layer.add(rotation, forKey: "rotation")
    }
}
