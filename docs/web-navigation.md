# iOS web shell

Koat displays the Rails mobile interface in one persistent `WKWebView`.
Browser Turbo owns links, forms, page previews, its progress bar and history.
The current page stays visible while a first-time destination loads. There is
no native navigation stack or path configuration. The Koat mark appears in the
system launch storyboard, and `LaunchCoverView` keeps it above the web view, in
the same composition, until the first document finishes loading (`LaunchArtwork`
holds the shared values; a test checks the two stay in step). One idea governs
the cover's motion: the K is a stroke that flicks up and to the right. If the
page has not arrived within 0.4s, a soft highlight clipped to the glyph travels
along that stroke every 2.4s. When the page is ready the mark lifts along the
stroke on a critically damped spring and the canvas melts a beat behind it; with
Reduce Motion the mark stays still and the cover only cross-fades. The cover is
removed permanently for that web view; ordinary page visits, sign-in redirects
and recovery do not recreate it.

`AppWebViewController` hosts the web view, installs Hotwire's **bridge only**,
and supplies native capabilities. Do not create a Hotwire `Session`/`Navigator`
or register its Turbo adapter: doing so takes navigation away from browser Turbo.
The Hotwire package remains a dependency for the Apple and Google bridge components.

Native entry points use `navigate(to:)`. Warm push links call `Turbo.visit` with
WebKit-serialized arguments; cold links load directly, and links received during
a document load wait for it to finish. Apple/Google handoff redemption uses
`location.replace`, starting a fresh document and Turbo cache while retaining the
shared cookie store. Cookie changes and page-render completion trigger a push-token
registration refresh when the `session_id` changes.

WebKit's back/forward gestures operate on browser history. Same-origin new-window
links open in the existing web view. External HTTP(S) pages open in Safari's in-app
browser; phone, email and SMS links go to their system handlers. Top-level redirects
are also checked against the app's origin. Remote frames can still display media.

PDF export keeps its JavaScript message interface and native share sheet, using the
same cookie store as the page. A native progress bar covers full document loads;
Turbo owns progress during its visits. Network failures offer retry. Web-process
termination reloads the current URL when the shell is visible and active.

## Verification

Run `WebNavigationTests` and `LaunchCoverTests` in the Koat test target on an iOS
simulator. `LaunchCoverTests` covers the cover's waiting and handoff motion and
its Reduce Motion variant. The navigation tests
host a loopback HTTP server and bundled Turbo 8.0.23; Rails and a user login are not
required. They cover delayed first visits, document identity, browser history,
bridge messages/replies, deep links, handoff redirects/cookies, push-registration
callbacks, authenticated PDF sharing, new windows, origin boundaries and recovery.

The real Apple/Google account authorization sheets and APNs delivery still require
an appropriately signed build and device/account smoke test. The automated tests
exercise the integration on either side of those external services.

Also smoke-test the physical edge-swipe on a device: automated back/forward
API tests pass, but the simulator mouse-drag did not verify that gesture.
