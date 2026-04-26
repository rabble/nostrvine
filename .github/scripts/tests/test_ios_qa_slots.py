"""Tests for ios_qa_slots.py — pure functions and CLI surfaces."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

THIS_DIR = Path(__file__).resolve().parent
SCRIPT_DIR = THIS_DIR.parent
SCRIPT_PATH = SCRIPT_DIR / "ios_qa_slots.py"
SLOTS_JSON = SCRIPT_DIR.parent / "ios_qa_slots.json"

sys.path.insert(0, str(SCRIPT_DIR))

import ios_qa_slots as lib  # noqa: E402

ALL_15 = [
    {
        "slot": f"qa{i:02d}",
        "label": f"ios-qa-slot-{i:02d}",
        "enabled": True,
        "bundleId": f"co.openvine.app.qa{i:02d}",
        "extensionBundleId": f"co.openvine.app.qa{i:02d}.NotificationServiceExtension",
        "appGroup": f"group.co.openvine.app.qa{i:02d}",
        "displayName": f"Divine QA {i:02d}",
        "firebaseAppId": f"1:972941478875:ios:fakeqa{i:02d}",
    }
    for i in range(1, 16)
]


class TrustChecks(unittest.TestCase):
    def test_internal_pr_trusted(self):
        self.assertTrue(lib.is_trusted_pr("divinevideo", author_is_org_member=False))

    def test_org_member_fork_trusted(self):
        self.assertTrue(lib.is_trusted_pr("contributor", author_is_org_member=True))

    def test_outside_fork_non_member_not_trusted(self):
        self.assertFalse(
            lib.is_trusted_pr("contributor", author_is_org_member=False),
        )


class EligibilityChecks(unittest.TestCase):
    def test_non_draft_eligible(self):
        self.assertTrue(lib.is_eligible_pr(is_draft=False, labels=[]))

    def test_draft_with_needs_label_eligible(self):
        self.assertTrue(
            lib.is_eligible_pr(is_draft=True, labels=["needs-ios-qa", "wip"]),
        )

    def test_draft_without_needs_label_not_eligible(self):
        self.assertFalse(lib.is_eligible_pr(is_draft=True, labels=["wip"]))


class CurrentSlot(unittest.TestCase):
    def test_returns_slot_for_label(self):
        self.assertEqual(
            lib.current_slot(["docs", "ios-qa-slot-03", "ios-qa:building"]),
            "qa03",
        )

    def test_returns_none_when_no_slot_label(self):
        self.assertIsNone(lib.current_slot(["docs", "needs-ios-qa"]))


class RelevantChanges(unittest.TestCase):
    def test_mobile_change_is_relevant(self):
        self.assertTrue(lib.relevant_changes(["mobile/lib/main.dart"]))

    def test_codemagic_yaml_is_relevant(self):
        self.assertTrue(lib.relevant_changes(["codemagic.yaml"]))

    def test_unrelated_change_is_not_relevant(self):
        self.assertFalse(
            lib.relevant_changes(["README.md", "docs/foo.md"]),
        )


class DecideAction(unittest.TestCase):
    def test_closed_pr_always_cleanup(self):
        action = lib.decide_action(
            is_closed=True,
            has_relevant_changes=False,
            labels=["ios-qa-slot-01", "ios-qa:ready"],
        )
        self.assertEqual(action, "cleanup")

    def test_open_no_changes_no_qa_label_skip(self):
        action = lib.decide_action(
            is_closed=False,
            has_relevant_changes=False,
            labels=["docs"],
        )
        self.assertEqual(action, "skip")

    def test_open_no_changes_with_qa_label_cleanup(self):
        action = lib.decide_action(
            is_closed=False,
            has_relevant_changes=False,
            labels=["ios-qa-slot-02", "ios-qa:ready"],
        )
        self.assertEqual(action, "cleanup")

    def test_open_with_changes_allocate(self):
        action = lib.decide_action(
            is_closed=False,
            has_relevant_changes=True,
            labels=[],
        )
        self.assertEqual(action, "allocate")


class EnabledSlots(unittest.TestCase):
    def test_filters_out_disabled(self):
        slots = [
            {**ALL_15[0], "enabled": False},
            ALL_15[1],
        ]
        result = lib.enabled_slots(slots)
        self.assertEqual([s["slot"] for s in result], ["qa02"])

    def test_filters_out_empty_firebase_app_id(self):
        slots = [
            {**ALL_15[0], "firebaseAppId": ""},
            ALL_15[1],
        ]
        result = lib.enabled_slots(slots)
        self.assertEqual([s["slot"] for s in result], ["qa02"])


class ChooseSlot(unittest.TestCase):
    def test_first_free_enabled_slot_assigned(self):
        slots = ALL_15[:3]
        result = lib.choose_slot(
            slots,
            [{"number": 1, "labels": [], "eligibility_at": "2026-01-01"}],
        )
        self.assertEqual(result, {1: "qa01"})

    def test_existing_slot_label_preserved(self):
        slots = ALL_15[:3]
        result = lib.choose_slot(
            slots,
            [
                {
                    "number": 1,
                    "labels": ["ios-qa-slot-02"],
                    "eligibility_at": "2026-01-01",
                },
            ],
        )
        self.assertEqual(result, {1: "qa02"})

    def test_disabled_slot_label_replaced(self):
        # PR has slot label for qa10 but qa10 is disabled now: should reassign
        slots = ALL_15[:3]
        result = lib.choose_slot(
            slots,
            [
                {
                    "number": 1,
                    "labels": ["ios-qa-slot-10"],
                    "eligibility_at": "2026-01-01",
                },
            ],
        )
        self.assertEqual(result, {1: "qa01"})

    def test_queued_when_all_slots_occupied(self):
        slots = ALL_15[:2]
        result = lib.choose_slot(
            slots,
            [
                {
                    "number": 1,
                    "labels": ["ios-qa-slot-01"],
                    "eligibility_at": "2026-01-01",
                },
                {
                    "number": 2,
                    "labels": ["ios-qa-slot-02"],
                    "eligibility_at": "2026-01-02",
                },
                {"number": 3, "labels": [], "eligibility_at": "2026-01-03"},
            ],
        )
        self.assertEqual(result, {1: "qa01", 2: "qa02", 3: "queued"})

    def test_queued_ordering_oldest_eligibility_first(self):
        slots = ALL_15[:1]
        result = lib.choose_slot(
            slots,
            [
                {"number": 9, "labels": [], "eligibility_at": "2026-01-02"},
                {"number": 5, "labels": [], "eligibility_at": "2026-01-01"},
            ],
        )
        self.assertEqual(result, {5: "qa01", 9: "queued"})

    def test_queued_ordering_tiebreak_by_pr_number(self):
        slots = ALL_15[:1]
        result = lib.choose_slot(
            slots,
            [
                {"number": 9, "labels": [], "eligibility_at": "2026-01-01"},
                {"number": 5, "labels": [], "eligibility_at": "2026-01-01"},
            ],
        )
        self.assertEqual(result, {5: "qa01", 9: "queued"})


class StateMarker(unittest.TestCase):
    def test_round_trip_preserves_full_payload(self):
        state = {
            "slot": "qa01",
            "pr_number": 123,
            "sha": "abcdef0123456789abcdef0123456789abcdef01",
            "status": "ready",
            "codemagic_build_id": "build-xyz",
            "codemagic_build_url": "https://codemagic.io/app/X/build/Y",
            "firebase_testing_uri": "https://appdistribution.firebase.google.com/testing/abc",
            "failure_reason": None,
            "updated_at": "2026-04-26T16:30:00Z",
        }
        rendered = lib.render_state_marker(state)
        body = "Comment body\n" + rendered + "\nmore stuff"
        self.assertEqual(lib.parse_state_marker(body), state)

    def test_returns_none_when_marker_missing(self):
        self.assertIsNone(lib.parse_state_marker("just text, no marker"))

    def test_full_sha_never_truncated_in_marker(self):
        state = {
            "sha": "abcdef0123456789abcdef0123456789abcdef01",
            "slot": "qa01",
            "pr_number": 1,
            "status": "ready",
        }
        marker = lib.render_state_marker(state)
        self.assertIn("abcdef0123456789abcdef0123456789abcdef01", marker)


class RequiredLabels(unittest.TestCase):
    def test_returns_all_15_slots_plus_4_states_plus_needs(self):
        labels = lib.required_labels(ALL_15)
        for i in range(1, 16):
            self.assertIn(f"ios-qa-slot-{i:02d}", labels)
        for state in (
            "ios-qa:building",
            "ios-qa:ready",
            "ios-qa:queued",
            "ios-qa:failed",
        ):
            self.assertIn(state, labels)
        self.assertIn("needs-ios-qa", labels)
        self.assertEqual(len(labels), 20)


class FirebaseDistributionParser(unittest.TestCase):
    def test_top_level_testing_uri(self):
        self.assertEqual(
            lib.extract_firebase_testing_uri({"testing_uri": "https://x"}),
            "https://x",
        )

    def test_result_wrapper(self):
        self.assertEqual(
            lib.extract_firebase_testing_uri(
                {"result": {"testing_uri": "https://x"}},
            ),
            "https://x",
        )

    def test_result_release_wrapper(self):
        self.assertEqual(
            lib.extract_firebase_testing_uri(
                {"result": {"release": {"testing_uri": "https://x"}}},
            ),
            "https://x",
        )

    def test_rejects_only_binary_download_uri(self):
        self.assertIsNone(
            lib.extract_firebase_testing_uri(
                {"binary_download_uri": "https://expires.in/1h"},
            ),
        )
        self.assertIsNone(
            lib.extract_firebase_testing_uri(
                {"result": {"binary_download_uri": "https://x"}},
            ),
        )

    def test_rejects_when_uri_missing(self):
        self.assertIsNone(lib.extract_firebase_testing_uri({"result": {}}))


class StatusCommentRenderer(unittest.TestCase):
    SHA = "abcdef0123456789abcdef0123456789abcdef01"

    def test_includes_full_sha_pr_slot_links_and_marker(self):
        body = lib.render_status_comment(
            status="ready",
            pr_number=42,
            slot="qa01",
            sha=self.SHA,
            codemagic_build_url="https://codemagic.io/app/X/build/Y",
            firebase_testing_uri="https://appdist.firebase.google.com/testing/Z",
        )
        self.assertIn(self.SHA, body)
        self.assertIn("qa01", body)
        self.assertIn("PR #42", body)
        self.assertIn("https://appdist.firebase.google.com/testing/Z", body)
        self.assertIn("https://codemagic.io/app/X/build/Y", body)
        self.assertIn(lib.STATE_MARKER_PREFIX.strip(), body)

    def test_failed_status_renders_reason(self):
        body = lib.render_status_comment(
            status="failed",
            pr_number=42,
            slot="qa01",
            sha=self.SHA,
            codemagic_build_url="https://codemagic.io/app/X/build/Y",
            failure_reason="Codemagic build failed",
        )
        self.assertIn("Codemagic build failed", body)

    def test_stale_status_does_not_require_firebase_uri(self):
        body = lib.render_status_comment(
            status="stale",
            pr_number=42,
            slot="qa01",
            sha=self.SHA,
            codemagic_build_url="https://codemagic.io/app/X/build/Y",
        )
        self.assertIn("stale", body.lower())


class CleanupForClosedPr(unittest.TestCase):
    def test_returns_labels_to_remove_and_branch_to_delete(self):
        result = lib.cleanup_for_closed_pr(
            pr_number=42,
            labels=[
                "ios-qa-slot-03",
                "ios-qa:ready",
                "needs-ios-qa",
                "documentation",
            ],
        )
        self.assertEqual(
            sorted(result["labels_to_remove"]),
            sorted(["ios-qa-slot-03", "ios-qa:ready", "needs-ios-qa"]),
        )
        self.assertEqual(result["mirror_branch"], "ios-qa/pr-42")
        self.assertNotIn("documentation", result["labels_to_remove"])


class DirectoryRenderer(unittest.TestCase):
    SHA1 = "1111111111111111111111111111111111111111"
    SHA2 = "2222222222222222222222222222222222222222"

    def test_lists_active_queued_failed_with_links(self):
        rows = [
            {
                "slot": "qa01",
                "pr_number": 10,
                "sha": self.SHA1,
                "status": "ready",
                "firebase_testing_uri": "https://fb/Z",
                "codemagic_build_url": "https://cm/Y",
            },
            {
                "slot": None,
                "pr_number": 11,
                "sha": self.SHA2,
                "status": "queued",
                "firebase_testing_uri": None,
                "codemagic_build_url": None,
            },
        ]
        body = lib.render_directory(rows, updated_at="2026-04-26T17:00:00Z")
        self.assertIn(self.SHA1, body)
        self.assertIn(self.SHA2, body)
        self.assertIn("qa01", body)
        self.assertIn("https://fb/Z", body)
        self.assertIn("https://cm/Y", body)
        self.assertIn("PR #10", body)
        self.assertIn("PR #11", body)
        self.assertIn("Updated", body)
        self.assertIn(lib.DIRECTORY_MARKER_PREFIX.strip(), body)


class CodemagicPayload(unittest.TestCase):
    def test_includes_required_environment_variables(self):
        slot = ALL_15[0]
        pr = {
            "number": 7,
            "head_sha": "deadbeef" * 5,
            "head_repo": "fork/divine-mobile",
            "head_ref": "feature-x",
        }
        payload = lib.render_codemagic_payload(
            app_id="codemagic-app",
            workflow_id="ios-qa-pr-build",
            branch="ios-qa/pr-7",
            pr=pr,
            slot=slot,
            default_env="STAGING",
        )
        self.assertEqual(payload["appId"], "codemagic-app")
        self.assertEqual(payload["workflowId"], "ios-qa-pr-build")
        self.assertEqual(payload["branch"], "ios-qa/pr-7")
        env = payload["environment"]["variables"]
        for key in (
            "PR_NUMBER",
            "PR_HEAD_SHA",
            "PR_HEAD_REPO",
            "PR_HEAD_REF",
            "QA_SLOT",
            "QA_BUNDLE_ID",
            "QA_EXTENSION_BUNDLE_ID",
            "QA_APP_GROUP",
            "QA_DISPLAY_NAME",
            "QA_FIREBASE_APP_ID",
            "DEFAULT_ENV",
            "CODEMAGIC_APP_ID",
        ):
            self.assertIn(key, env, f"missing env var {key}")
        self.assertEqual(env["QA_SLOT"], "qa01")
        self.assertEqual(env["DEFAULT_ENV"], "STAGING")
        self.assertEqual(env["PR_HEAD_SHA"], pr["head_sha"])


class CliRenderLabelBootstrap(unittest.TestCase):
    def test_outputs_jsonl_for_workflow(self):
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "render-label-bootstrap",
                "--slots-file",
                str(SLOTS_JSON),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        labels = json.loads(result.stdout)
        self.assertEqual(len(labels), 20)
        names = {item["name"] for item in labels}
        self.assertIn("needs-ios-qa", names)
        needs = next(item for item in labels if item["name"] == "needs-ios-qa")
        self.assertEqual(needs["color"], "5319E7")
        self.assertTrue(needs.get("description"))


class CliParseFirebaseDistribution(unittest.TestCase):
    def test_extracts_uri_from_result_release(self):
        import tempfile

        firebase_json = {
            "result": {
                "release": {
                    "testing_uri": "https://appdist.firebase.google.com/testing/abc",
                },
            },
        }
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fp:
            json.dump(firebase_json, fp)
            path = fp.name
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "parse-firebase-distribution",
                "--json-file",
                path,
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        out = json.loads(result.stdout)
        self.assertEqual(
            out["testing_uri"],
            "https://appdist.firebase.google.com/testing/abc",
        )

    def test_require_testing_uri_fails_when_only_binary_link(self):
        import tempfile

        firebase_json = {"result": {"binary_download_uri": "https://expires.in/1h"}}
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fp:
            json.dump(firebase_json, fp)
            path = fp.name
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "parse-firebase-distribution",
                "--json-file",
                path,
                "--require-testing-uri",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)


class AllocateForTarget(unittest.TestCase):
    SLOTS = ALL_15[:2]

    def _trusted_open_pr(self, **overrides):
        base = {
            "number": 1,
            "is_draft": False,
            "is_closed": False,
            "labels": [],
            "head_repo_owner": "divinevideo",
            "author_is_org_member": True,
            "changed_files": ["mobile/lib/main.dart"],
            "eligibility_at": "2026-01-01T00:00:00Z",
        }
        base.update(overrides)
        return base

    def test_internal_pr_with_changes_gets_first_slot(self):
        prs = [self._trusted_open_pr(number=42)]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=42,
        )
        self.assertEqual(result["action"], "allocate")
        self.assertEqual(result["status"], "building")
        self.assertEqual(result["slot"]["slot"], "qa01")

    def test_outside_fork_non_member_skipped(self):
        prs = [
            self._trusted_open_pr(
                number=42,
                head_repo_owner="random",
                author_is_org_member=False,
            ),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=42,
        )
        self.assertEqual(result["action"], "skip")
        self.assertIn("trusted", result["reason"])

    def test_pr_without_relevant_changes_with_qa_label_cleans_up(self):
        prs = [
            self._trusted_open_pr(
                number=42,
                changed_files=["docs/foo.md"],
                labels=["ios-qa-slot-01", "ios-qa:ready"],
            ),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=42,
        )
        self.assertEqual(result["action"], "cleanup")
        self.assertEqual(result["mirror_branch"], "ios-qa/pr-42")
        self.assertIn("ios-qa-slot-01", result["labels_to_remove"])

    def test_pr_without_relevant_changes_without_qa_label_skipped(self):
        prs = [
            self._trusted_open_pr(
                number=42,
                changed_files=["docs/foo.md"],
            ),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=42,
        )
        self.assertEqual(result["action"], "skip")

    def test_target_not_in_open_list_treated_as_cleanup(self):
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=[],
            target_number=99,
            target_labels_fallback=["ios-qa-slot-04", "ios-qa:building"],
        )
        self.assertEqual(result["action"], "cleanup")
        self.assertIn("ios-qa-slot-04", result["labels_to_remove"])

    def test_third_pr_queued_when_two_slots_full(self):
        prs = [
            self._trusted_open_pr(
                number=1,
                labels=["ios-qa-slot-01"],
                eligibility_at="2026-01-01T00:00:00Z",
            ),
            self._trusted_open_pr(
                number=2,
                labels=["ios-qa-slot-02"],
                eligibility_at="2026-01-02T00:00:00Z",
            ),
            self._trusted_open_pr(
                number=3,
                eligibility_at="2026-01-03T00:00:00Z",
            ),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=3,
        )
        self.assertEqual(result["action"], "allocate")
        self.assertEqual(result["status"], "queued")
        self.assertIsNone(result["slot"])

    def test_existing_slot_label_occupies_slot_even_when_non_target_files_unknown(self):
        prs = [
            self._trusted_open_pr(
                number=1,
                labels=["ios-qa-slot-01", "ios-qa:building"],
                changed_files=[],
                eligibility_at="2026-01-01T00:00:00Z",
            ),
            self._trusted_open_pr(
                number=2,
                labels=[],
                changed_files=["mobile/lib/main.dart"],
                eligibility_at="2026-01-02T00:00:00Z",
            ),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=2,
        )
        self.assertEqual(result["action"], "allocate")
        self.assertEqual(result["status"], "building")
        self.assertEqual(result["slot"]["slot"], "qa02")

    def test_reassignment_reports_stale_slot_labels_to_remove(self):
        prs = [
            self._trusted_open_pr(
                number=42,
                labels=["ios-qa-slot-10", "ios-qa:failed"],
            ),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=42,
        )
        self.assertEqual(result["action"], "allocate")
        self.assertEqual(result["slot"]["slot"], "qa01")
        self.assertEqual(result["labels_to_remove"], ["ios-qa-slot-10"])

    def test_reconcile_cleans_up_labeled_pr_without_relevant_changes(self):
        prs = [
            self._trusted_open_pr(
                number=42,
                labels=["ios-qa-slot-01", "ios-qa:ready"],
                changed_files=["docs/foo.md"],
            ),
        ]
        result = lib.reconcile_assignments(slots=self.SLOTS, prs=prs)
        self.assertEqual(result[42]["action"], "cleanup")
        self.assertIn("ios-qa-slot-01", result[42]["labels_to_remove"])

    def test_draft_without_needs_label_skipped(self):
        prs = [
            self._trusted_open_pr(number=42, is_draft=True),
        ]
        result = lib.allocate_for_target(
            slots=self.SLOTS,
            prs=prs,
            target_number=42,
        )
        self.assertEqual(result["action"], "skip")


class NotifyStatus(unittest.TestCase):
    def test_stale_status_ignores_firebase_files(self):
        result = lib.resolve_notify_status(
            stale=True,
            firebase_distribution_json_exists=True,
            firebase_links_json={"testing_uri": "https://appdist.firebase/x"},
        )
        self.assertEqual(result, {"status": "stale", "firebase_json": None})

    def test_missing_parsed_testing_uri_reports_failed_even_with_distribution_json(self):
        result = lib.resolve_notify_status(
            stale=False,
            firebase_distribution_json_exists=True,
            firebase_links_json=None,
        )
        self.assertEqual(result, {"status": "failed", "firebase_json": None})

    def test_valid_parsed_testing_uri_reports_ready(self):
        result = lib.resolve_notify_status(
            stale=False,
            firebase_distribution_json_exists=True,
            firebase_links_json={"testing_uri": "https://appdist.firebase/x"},
        )
        self.assertEqual(
            result,
            {"status": "ready", "firebase_json": "firebase-distribution.json"},
        )


class DirectoryRows(unittest.TestCase):
    SHA = "abcdef0123456789abcdef0123456789abcdef01"

    def test_uses_matching_sticky_comment_state_for_ready_links(self):
        reconcile = {
            42: {
                "action": "allocate",
                "status": "building",
                "slot": {"slot": "qa01"},
            },
        }
        prs = {
            42: {
                "head_sha": self.SHA,
                "qa_comment_state": {
                    "slot": "qa01",
                    "sha": self.SHA,
                    "status": "ready",
                    "firebase_testing_uri": "https://appdist.firebase/x",
                    "codemagic_build_url": "https://codemagic.io/app/a/build/b",
                },
            },
        }
        rows = lib.directory_rows_from_reconcile(reconcile, prs)
        self.assertEqual(rows[0]["status"], "ready")
        self.assertEqual(rows[0]["firebase_testing_uri"], "https://appdist.firebase/x")
        self.assertEqual(
            rows[0]["codemagic_build_url"],
            "https://codemagic.io/app/a/build/b",
        )

    def test_ignores_sticky_comment_state_for_old_sha(self):
        reconcile = {
            42: {
                "action": "allocate",
                "status": "building",
                "slot": {"slot": "qa01"},
            },
        }
        prs = {
            42: {
                "head_sha": self.SHA,
                "qa_comment_state": {
                    "slot": "qa01",
                    "sha": "1111111111111111111111111111111111111111",
                    "status": "ready",
                    "firebase_testing_uri": "https://appdist.firebase/old",
                    "codemagic_build_url": "https://codemagic.io/app/a/build/old",
                },
            },
        }
        rows = lib.directory_rows_from_reconcile(reconcile, prs)
        self.assertEqual(rows[0]["status"], "building")
        self.assertIsNone(rows[0]["firebase_testing_uri"])


if __name__ == "__main__":
    unittest.main()
