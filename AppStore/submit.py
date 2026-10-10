#!/usr/bin/env python3
"""Upload build and submit Bins 1.0.3 to App Store Connect."""
import json
import sys
import time
from pathlib import Path

import jwt
import requests

KEY_ID = "PFVCG3GWZ5"
ISSUER_ID = "f72efd70-c801-416b-8f1b-419ab60091f6"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys/AuthKey_PFVCG3GWZ5.p8"
BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.beppe.BinsApp"
VERSION = "1.0.4"
BUILD = "16"
ROOT = Path(__file__).resolve().parents[1]


def token() -> str:
    key = KEY_PATH.read_text()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def api(method, path, body=None, ok=(200, 201, 204)):
    headers = {"Authorization": f"Bearer {token()}"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    response = requests.request(method, BASE + path, headers=headers, json=body, timeout=60)
    if response.status_code not in ok:
        raise RuntimeError(f"{method} {path} -> {response.status_code}: {response.text[:1500]}")
    return response.json() if response.text else {}


def read(name: str) -> str:
    return (ROOT / "AppStore" / name).read_text().strip()


def find_app_id() -> str:
    data = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    apps = data.get("data", [])
    if not apps:
        raise RuntimeError(f"No App Store Connect app for bundle id {BUNDLE_ID}")
    return apps[0]["id"]


def find_or_create_version(app_id: str) -> str:
    data = api(
        "GET",
        f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10",
    )
    for version in data.get("data", []):
        attrs = version["attributes"]
        if attrs.get("versionString") == VERSION:
            return version["id"]
        if attrs.get("appStoreState") in {
            "PREPARE_FOR_SUBMISSION",
            "DEVELOPER_REJECTED",
            "REJECTED",
            "METADATA_REJECTED",
            "WAITING_FOR_REVIEW",
            "IN_REVIEW",
        }:
            raise RuntimeError(
                f"Version {attrs.get('versionString')} is already {attrs.get('appStoreState')}"
            )

    created = api(
        "POST",
        "/v1/appStoreVersions",
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": VERSION,
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                },
            }
        },
    )
    return created["data"]["id"]


def update_localization(version_id: str):
    data = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    locs = data.get("data", [])
    if not locs:
        raise RuntimeError("No localizations on app store version")
    loc_id = locs[0]["id"]
    api(
        "PATCH",
        f"/v1/appStoreVersionLocalizations/{loc_id}",
        {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": loc_id,
                "attributes": {
                    "whatsNew": read("whats_new.txt"),
                },
            }
        },
    )


def wait_for_build(app_id: str, timeout_s: int = 1800) -> str:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        data = api(
            "GET",
            f"/v1/builds?filter[app]={app_id}&filter[version]={BUILD}&limit=5",
        )
        for build in data.get("data", []):
            attrs = build["attributes"]
            if attrs.get("version") == BUILD and attrs.get("processingState") == "VALID":
                return build["id"]
        time.sleep(30)
    raise RuntimeError(f"Build {BUILD} not ready after {timeout_s}s")


def attach_build(version_id: str, build_id: str):
    api(
        "PATCH",
        f"/v1/appStoreVersions/{version_id}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build_id}},
                },
            }
        },
    )


def update_review_notes(version_id: str):
    detail = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
    if detail.get("data"):
        detail_id = detail["data"]["id"]
        api(
            "PATCH",
            f"/v1/appStoreReviewDetails/{detail_id}",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": detail_id,
                    "attributes": {"notes": read("review_notes.txt")},
                }
            },
        )
        return

    created = api(
        "POST",
        "/v1/appStoreReviewDetails",
        {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": {"notes": read("review_notes.txt")},
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id},
                    }
                },
            }
        },
    )
    return created["data"]["id"]


def submit(version_id: str, app_id: str):
    submission = api(
        "POST",
        "/v1/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                },
            }
        },
    )
    submission_id = submission["data"]["id"]

    api(
        "POST",
        "/v1/reviewSubmissionItems",
        {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {
                        "data": {"type": "reviewSubmissions", "id": submission_id},
                    },
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id},
                    },
                },
            }
        },
    )

    api(
        "PATCH",
        f"/v1/reviewSubmissions/{submission_id}",
        {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        },
    )
    return submission_id


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "submit"
    app_id = find_app_id()
    print(f"app_id={app_id}")

    if action == "lookup":
        print(json.dumps(api("GET", f"/v1/apps/{app_id}"), indent=2)[:4000])
        return

    version_id = find_or_create_version(app_id)
    print(f"version_id={version_id}")
    update_localization(version_id)
    print("updated whats new")
    update_review_notes(version_id)
    print("updated review notes")

    if action == "metadata-only":
        return

    build_id = wait_for_build(app_id)
    print(f"build_id={build_id}")
    attach_build(version_id, build_id)
    print("attached build")
    submission_id = submit(version_id, app_id)
    print(f"submitted {VERSION} ({BUILD}) for review via submission {submission_id}")


if __name__ == "__main__":
    main()
