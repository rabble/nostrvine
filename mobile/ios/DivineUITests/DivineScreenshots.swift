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

    /// Lele Pons' "VINE IS BACK!" post — the hero creator shot (02).
    static let creatorPostVideoId =
        "4f3123c6468b1f87865c8e3baedbcca149c54b9d9acd17ebbaa6029b76fff7ea"

    /// Video whose About sheet shows the Human-Made badge and all four
    /// verification checkmarks (device attestation, PGP, C2PA, manifest):
    /// "#LNICPuppetShow" by Travis & Sallie Mae. Featured on 03 to spread
    /// the creators beyond Lele.
    static let verifiedVideoId =
        "0b0d32021d70a6df1a9c70afa3f6337a7b1c6e3849609e25d550accd7e957537"

    /// Profile captured for 07_profile (andrinG).
    static let profileNpub =
        "npub18k9xv7mdal2fqecq540kf7exkqz0s6qlmekc7tm4qxgrhtqdffvqmz4mmq"

    /// Video whose share sheet is captured for 09 (andrinG — "i said
    /// DRIVE!!!!"), so Lele isn't the subject of every screen.
    static let shareVideoId =
        "5de2fb46103e57ff8ee27d6d4fc667ad1d7b2b7c3081814a3edad7e6ac680f93"

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
        snapshot("01_classics")
    }

    func test02CreatorPost() {
        let app = launchApp(
            route: "/video/\(DivineScreenshots.creatorPostVideoId)"
        )
        // The on-video caption ("VINE IS BACK!") is the reliable anchor;
        // the loop-count badge renders on the same screen but isn't a
        // stable wait target.
        waitFor(app, "video_title")
        snapshot("02_creator_post")
    }

    func test03Verification() {
        let app = launchApp(
            route: "/video/\(DivineScreenshots.verifiedVideoId)"
        )
        waitFor(app, "video_title")
        element(app, "video_title").tap()
        // The About sheet's proof data is fetched separately and can lag
        // the video load, so allow the longer warm-up timeout here.
        waitFor(app, "human_made_badge", timeout: DivineScreenshots.warmupTimeout)
        waitFor(
            app,
            "verification_section",
            timeout: DivineScreenshots.warmupTimeout
        )
        snapshot("03_verification")
    }

    func test04Capture() {
        let app = launchApp(route: "/video-recorder")
        waitFor(app, "camera_record_button")
        snapshot("04_capture")
    }

    func test05Lists() {
        let app = launchApp(route: "/discover-lists")
        waitFor(app, "list_card_0")
        snapshot("05_lists")
    }

    func test06Modes() {
        let app = launchApp(route: "/video-recorder")
        waitFor(app, "camera_record_button")
        waitFor(app, "camera_mode_capture")
        snapshot("06_modes")
    }

    func test07Profile() {
        let app = launchApp(
            route: "/profile-view/\(DivineScreenshots.profileNpub)"
        )
        waitFor(app, "profile_stats_row")
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

    func test09Share() {
        let app = launchApp(
            route: "/video/\(DivineScreenshots.shareVideoId)"
        )
        waitFor(app, "share_button")
        element(app, "share_button").tap()
        waitFor(app, "share_with_section")
        waitFor(app, "share_contact_0")
        snapshot("09_share")
    }
}
