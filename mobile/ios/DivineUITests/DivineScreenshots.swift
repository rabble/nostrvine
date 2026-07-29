//
//  DivineScreenshots.swift
//  DivineUITests
//
//  App Store screenshot suite driven by fastlane snapshot.
//
//  Every capture launches the app fresh with SCREENSHOT_INITIAL_ROUTE; the
//  app reads that value during screenshot-mode startup and navigates to the
//  target screen. Elements are located by the accessibility identifiers the
//  Flutter side exposes via `SemanticIds` (lib/constants/semantic_ids.dart).
//
//  Test methods run alphabetically; `test00Warmup` runs first so the
//  throwaway account exists before any screen is captured.

import XCTest

@MainActor
final class DivineScreenshots: XCTestCase {

    // MARK: - Capture subjects

    /// Lele Pons' "VINE IS BACK!" post — the OG-creator shot (03).
    static let creatorPostVideoId =
        "4f3123c6468b1f87865c8e3baedbcca149c54b9d9acd17ebbaa6029b76fff7ea"

    /// Video whose About sheet shows the Human-Made badge and all four
    /// verification checkmarks (device attestation, PGP, C2PA, manifest):
    /// "Sharp Nails" by andrinG. Chosen because it has zero reposts, so the
    /// About sheet is short and the verification checklist sits high enough
    /// to be legible at export scale (02_verification).
    static let verifiedVideoId =
        "dd6ba512d5c3ed9490db9cd15986fb5c88347cb4aeeef6220331e8b06ca3c510"

    /// Profile captured for 07_profile (Travis / imrtravis — a verified
    /// creator with a clean bio).
    static let profileNpub =
        "npub1x5ses3yutlmw0e62v6j469a6flz2pgqc5tt4dmjcndj4mq3ldsns93jzec"

    // MARK: - Launch helpers

    /// First-launch account creation + relay warm-up can be slow.
    private static let warmupTimeout: TimeInterval = 180
    /// Regular content loads. Every content screen fetches live production
    /// data (funnelcake / relays), so the wait must absorb network variance
    /// — a too-tight bound is the main source of flaky captures.
    private static let contentTimeout: TimeInterval = 180

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launchApp(
        route: String? = nil,
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        if let route {
            app.launchEnvironment["SCREENSHOT_INITIAL_ROUTE"] = route
        }
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        // Auto-dismiss system permission alerts (camera, notifications).
        addUIInterruptionMonitor(withDescription: "System permissions") {
            alert in
            for label in ["Allow", "OK", "Allow While Using App"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
        app.launch()
        return app
    }

    private func element(
        _ app: XCUIApplication,
        _ identifier: String
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func waitFor(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = DivineScreenshots.contentTimeout
    ) {
        let target = element(app, identifier)
        XCTAssertTrue(
            target.waitForExistence(timeout: timeout),
            "Timed out waiting for element '\(identifier)'"
        )
    }

    /// Waits for a `/video/:id` detail screen to leave its loading state and
    /// its player to render a first frame — without this the capture catches
    /// the branded loading spinner or a black, still-decoding video texture.
    private func waitForVideoLoaded(
        _ app: XCUIApplication,
        settle: TimeInterval = 6
    ) {
        let loading = element(app, "video_detail_loading")
        // The spinner should exist briefly, then disappear once the event
        // and its player are ready. Missing entirely (fast load) is fine.
        _ = loading.waitForExistence(timeout: 5)
        let gone = loading.waitForNonExistence(
            timeout: DivineScreenshots.warmupTimeout
        )
        XCTAssertTrue(gone, "Video detail stayed on the loading spinner")
        // No element signals "first frame decoded", so give the native
        // player a bounded settle to paint before the snapshot. A short
        // settle lands on the opening / poster frame (the curated, flattering
        // one); a longer settle lands mid-clip.
        Thread.sleep(forTimeInterval: settle)
    }

    // MARK: - Warm-up

    /// Creates (or restores) the throwaway account and publishes the
    /// creator follows before any screen is captured. No snapshot here.
    func test00Warmup() {
        let app = launchApp(route: "/explore")
        waitFor(app, "explore_tab", timeout: DivineScreenshots.warmupTimeout)
        // Nudge so any pending permission alert is delivered to the monitor.
        app.tap()
    }

    // MARK: - Captures

    func test01Classics() {
        let app = launchApp(route: "/explore/tab/classics")
        waitFor(app, "classic_viners_row")
        waitFor(app, "classic_video_tile_0")
        // The OG-Viner avatars and tile thumbnails are network images; give
        // them time to download so they render instead of placeholder circles.
        Thread.sleep(forTimeInterval: 6)
        snapshot("01_classics")
    }

    func test02CreatorPost() {
        let app = launchApp(
            route: "/video/\(DivineScreenshots.creatorPostVideoId)"
        )
        waitForVideoLoaded(app)
        // The on-video caption ("VINE IS BACK!") is the reliable anchor;
        // the loop-count badge renders on the same screen but isn't a
        // stable wait target.
        waitFor(app, "video_title")
        snapshot("03_creator_post")
    }

    func test03Verification() {
        let app = launchApp(
            route: "/video/\(DivineScreenshots.verifiedVideoId)"
        )
        waitForVideoLoaded(app)
        waitFor(app, "video_title")
        element(app, "video_title").tap()
        // The About sheet's proof data is fetched separately and can lag
        // the video load, so allow the longer warm-up timeout here.
        waitFor(app, "human_made_badge", timeout: DivineScreenshots.warmupTimeout)
        // The 4-signal ProofMode checklist (device attestation, PGP, C2PA,
        // manifest) is the LAST section of the scrollable About sheet. Its
        // proof data is fetched separately and can lag — best-effort: when
        // it's present, scroll it into view; if the fetch flakes, still
        // capture the sheet rather than aborting the whole 45-min run.
        // The verified video is chosen to have zero reposts, so the About
        // sheet is short and the checklist sits high. Scroll only until the
        // checklist first becomes visible, then stop — keeps the Human-Made
        // badge and the four green checks in the upper half of the sheet.
        let verification = element(app, "verification_section")
        if verification.waitForExistence(
            timeout: DivineScreenshots.warmupTimeout
        ) {
            var swipes = 0
            while !verification.isHittable && swipes < 8 {
                app.swipeUp()
                swipes += 1
            }
        }
        // Let the scroll settle before the snapshot.
        Thread.sleep(forTimeInterval: 1)
        snapshot("02_verification")
    }

    func test04Capture() {
        let app = launchApp(route: "/video-recorder")
        waitFor(app, "camera_record_button")
        snapshot("04_capture")
    }

    func test05Lists() {
        let app = launchApp(route: "/discover-lists")
        waitFor(app, "list_card_0")
        snapshot("06_lists")
    }

    func test06Discover() {
        // Explore → Categories: a distinct discovery surface, not a second
        // camera shot. 04_capture already covers the recorder.
        let app = launchApp(route: "/explore/tab/categories")
        waitFor(app, "category_tile_0")
        snapshot("05_discover")
    }

    func test07Profile() {
        let app = launchApp(
            route: "/profile-view/\(DivineScreenshots.profileNpub)"
        )
        waitFor(app, "profile_stats_row")
        // Settle so the avatar + banner images download before capture.
        Thread.sleep(forTimeInterval: 4)
        snapshot("07_profile")
    }

    func test08Editor() {
        let app = launchApp(
            route: "/video-editor",
            extraEnvironment: ["SCREENSHOT_SEED_CLIPS": "1"]
        )
        waitFor(app, "editor_timeline")
        snapshot("08_editor")
    }

    // MARK: - Preview-video recordings
    //
    // Not snapshot tests. Run one at a time via `-only-testing` while
    // `simctl io recordVideo` captures the screen. Each drives the UI, then
    // HOLDS so the recording has clean, steady B-roll for the App Store
    // preview cut (Clip B scroll, Clip C verification sheet).

    func testRecClassics() {
        let app = launchApp(route: "/explore/tab/classics")
        waitFor(app, "classic_viners_row")
        waitFor(app, "classic_video_tile_0")
        Thread.sleep(forTimeInterval: 6)
        // Gentle scroll down the loop grid for ~5s of usable footage.
        for _ in 0..<4 {
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 1.2)
        }
        Thread.sleep(forTimeInterval: 2)
    }

    func testRecVerification() {
        let app = launchApp(
            route: "/video/\(DivineScreenshots.verifiedVideoId)"
        )
        waitForVideoLoaded(app, settle: 2)
        waitFor(app, "video_title")
        element(app, "video_title").tap()
        waitFor(app, "human_made_badge", timeout: DivineScreenshots.warmupTimeout)
        let verification = element(app, "verification_section")
        if verification.waitForExistence(
            timeout: DivineScreenshots.warmupTimeout
        ) {
            var tries = 0
            while !verification.isHittable && tries < 8 {
                app.swipeUp(velocity: .slow)
                Thread.sleep(forTimeInterval: 0.9)
                tries += 1
            }
        }
        // Hold on the badge + four checkmarks.
        Thread.sleep(forTimeInterval: 5)
    }
}
