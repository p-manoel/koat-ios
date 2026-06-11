//
//  ChromelessNavigationController.swift
//  Koat
//
//  Navigation controller with a permanently hidden navigation bar.
//

import HotwireNative
import UIKit

final class ChromelessNavigationController: HotwireNavigationController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        // UIKit disables the interactive pop (swipe-back) gesture when the
        // navigation bar is hidden. Re-enable it via a custom delegate.
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && transitionCoordinator == nil
    }
}
