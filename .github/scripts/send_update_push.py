"""새 버전이 나오면 회원 폰에 푸시 알림을 보내요 (Firebase Cloud Messaging).

필요한 것: 환경 변수 FIREBASE_SERVICE_ACCOUNT (Firebase 서비스 계정 키 JSON 전체)
사용법:   python send_update_push.py v1.0.8 notes.md
"""
import json
import os
import re
import sys

import google.auth.transport.requests
import requests
from google.oauth2 import service_account


def short_notes(body: str, limit: int = 2) -> list[str]:
    """GitHub 릴리즈 노트에서 바뀐 내용만 뽑아요 (앱의 ReleaseInfo.parseNotes와 같은 규칙)."""
    out, skip = [], False
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("#"):
            skip = "new contributors" in line.lower()
            continue
        if skip or not line or line.startswith("**Full Changelog"):
            continue
        line = re.sub(r"^[-*•]\s*", "", line)
        line = re.sub(r"\s+by @\S+\s+in\s+\S+$", "", line).replace("**", "")
        if line:
            out.append(line)
    return out[:limit]


def main() -> None:
    tag = sys.argv[1]
    body = open(sys.argv[2], encoding="utf-8").read() if len(sys.argv) > 2 else ""
    info = json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT"])
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=["https://www.googleapis.com/auth/firebase.messaging"]
    )
    creds.refresh(google.auth.transport.requests.Request())

    notes = short_notes(body)
    text = " · ".join(notes) if notes else "눌러서 바로 업데이트하세요"
    message = {
        "message": {
            "topic": "updates",
            "notification": {"title": f"회비장부 새 버전 {tag} 나왔어요 🎉", "body": text},
            "data": {"type": "update", "version": tag.lstrip("vV")},
            "android": {
                "priority": "high",
                "notification": {
                    "channel_id": "updates",
                    "tag": "app-update",  # 새 알림이 오면 예전 업데이트 알림을 대신해요
                    "notification_count": 1,  # 숫자 뱃지를 지원하는 폰은 1로 보여요
                },
            },
        }
    }
    r = requests.post(
        f"https://fcm.googleapis.com/v1/projects/{info['project_id']}/messages:send",
        headers={"Authorization": f"Bearer {creds.token}"},
        json=message,
        timeout=30,
    )
    print(r.status_code, r.text)
    r.raise_for_status()


if __name__ == "__main__":
    main()
