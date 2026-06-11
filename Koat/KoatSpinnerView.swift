//
//  KoatSpinnerView.swift
//  Koat
//
//  Branded loading indicator: the Koat "K" logo with the web app's standard
//  loading ring spinning around it (the Tailwind `animate-spin` ring:
//  25%-opacity full circle + 75%-opacity quarter arc in Koat blue).
//

import UIKit

final class KoatSpinnerView: UIView {
    private static let size: CGFloat = 64
    private static let lineWidth: CGFloat = 4
    private static let logoSize: CGFloat = 32
    // Tailwind blue-600, the brand color used across the web app.
    private static let brandBlue = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)

    // Ring + arc live in their own rotor layer so the rotation animation
    // spins only the ring, leaving the centered logo still.
    private let rotorLayer = CALayer()
    private let ringLayer = CAShapeLayer()
    private let arcLayer = CAShapeLayer()
    private let logoView = UIImageView(image: UIImage(named: "KoatLogo"))

    private(set) var isAnimating = false

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        isHidden = true

        layer.addSublayer(rotorLayer)
        for (shapeLayer, opacity) in [(ringLayer, Float(0.25)), (arcLayer, Float(0.75))] {
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = Self.brandBlue.cgColor
            shapeLayer.lineWidth = Self.lineWidth
            shapeLayer.opacity = opacity
            rotorLayer.addSublayer(shapeLayer)
        }
        arcLayer.strokeEnd = 0.25

        logoView.contentMode = .scaleAspectFit
        addSubview(logoView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.size, height: Self.size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rotorLayer.frame = bounds

        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: (Self.size - Self.lineWidth) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        for shapeLayer in [ringLayer, arcLayer] {
            shapeLayer.frame = rotorLayer.bounds
            shapeLayer.path = path.cgPath
        }

        logoView.frame = CGRect(
            x: bounds.midX - Self.logoSize / 2,
            y: bounds.midY - Self.logoSize / 2,
            width: Self.logoSize,
            height: Self.logoSize
        )
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
        rotorLayer.removeAnimation(forKey: "rotation")
    }

    private func addRotation() {
        guard rotorLayer.animation(forKey: "rotation") == nil else { return }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 1
        rotation.repeatCount = .infinity
        rotorLayer.add(rotation, forKey: "rotation")
    }
}
