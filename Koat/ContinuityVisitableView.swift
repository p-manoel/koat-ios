//
//  ContinuityVisitableView.swift
//  Koat
//
//  Keeps the previous page visible during forward visits. The framework
//  covers the screen with the screenshot container at every visit start,
//  but a freshly pushed screen has never captured a screenshot, so the
//  cover is an empty white view — the blank flash between pages. Skipping
//  the cover in that case leaves the shared web view visible, still
//  showing the page the user came from, until Turbo renders the new one
//  (browser-like continuity). Screens that captured a real screenshot on
//  deactivation keep the stock behavior, which back-navigation relies on.
//

import HotwireNative
import UIKit

final class ContinuityVisitableView: VisitableView {
    private var hasScreenshot = false

    override func updateScreenshot() {
        // Mirrors the superclass guard: a capture only happens with an
        // attached web view.
        if webView != nil {
            hasScreenshot = true
        }
        super.updateScreenshot()
    }

    override func showScreenshot() {
        guard hasScreenshot else { return }
        super.showScreenshot()
    }

    override func clearScreenshot() {
        hasScreenshot = false
        super.clearScreenshot()
    }
}
