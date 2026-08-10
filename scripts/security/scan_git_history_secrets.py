from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

DETECTORS: tuple[tuple[str, str], ...] = (
    ("PRIVATE_KEY_BLOCK", r"-----BEGIN[[:space:]]+(RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    ("OPENAI_PROJECT_KEY", r"sk-proj-[A-Za-z0-9_-]{20,}"),
    ("GITHUB_CLASSIC_PAT", r"ghp_[A-Za-z0-9]{30,}"),
    ("GITHUB_FINE_GRAINED_PAT", r"github_pat_[A-Za-z0-9_]{30,}"),
    ("SLACK_BOT_TOKEN", r"xoxb-[A-Za-z0-9-]{20,}"),
    ("TELEGRAM_BOT_TOKEN", r"[0-9]{6,12}:[A-Za-z0-9_-]{30,}"),
    ("GOOGLE_API_KEY", r"AIza[A-Za-z0-9_-]{30,}"),
    ("AWS_ACCESS_KEY_ID", r"A(KIA|SIA)[A-Z0-9]{16}"),
    ("STRIPE_LIVE_SECRET", r"sk_live_[A-Za-z0-9]{16,}"),
    ("STRIPE_RESTRICTED_KEY", r"rk_live_[A-Za-z0-9]{16,}"),
    ("GENERIC_SECRET_ASSIGNMENT", r"(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{12,}['\"]"),
)

SAFE_PATH = re.compile(r"^[^\x00\r\n]+$")


def run_git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        capture_output=True,
        text=True,
        errors="replace",
        env=env,
    )


def require_repository(repo: Path) -> None:
    result = run_git(repo, "rev-parse", "--is-inside-work-tree", check=False)
    if result.returncode != 0 or result.stdout.strip() != "true":
        raise SystemExit(f"Not a Git worktree: {repo}")


def list_commits(repo: Path, max_commits: int | None) -> list[str]:
    result = run_git(repo, "rev-list", "--all")
    commits = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if max_commits is not None:
        commits = commits[:max_commits]
    return commits


def scan(repo: Path, max_commits: int | None) -> dict[str, object]:
    commits = list_commits(repo, max_commits)
    findings: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()

    for detector_name, pattern in DETECTORS:
        for commit in commits:
            result = run_git(
                repo,
                "grep",
                "-I",
                "-l",
                "-E",
                "-e",
                pattern,
                commit,
                "--",
                ".",
                check=False,
            )
            if result.returncode not in {0, 1}:
                raise RuntimeError(
                    f"git grep failed for detector {detector_name} at {commit[:12]}"
                )
            if result.returncode == 1:
                continue

            for raw in result.stdout.splitlines():
                prefix = f"{commit}:"
                path = raw[len(prefix):] if raw.startswith(prefix) else raw
                path = path.strip()
                if not path or not SAFE_PATH.fullmatch(path):
                    continue
                key = (detector_name, commit, path)
                if key in seen:
                    continue
                seen.add(key)
                findings.append(
                    {
                        "detector": detector_name,
                        "commit": commit,
                        "path": path,
                    }
                )

    return {
        "schema_version": "btrades.git-history-secret-preflight.v1",
        "commit_count_scanned": len(commits),
        "detector_count": len(DETECTORS),
        "finding_count": len(findings),
        "secret_values_emitted": False,
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scan Git history for credential classes without printing matched secret values."
    )
    parser.add_argument("repository", nargs="?", default=".")
    parser.add_argument("--max-commits", type=int, default=None)
    parser.add_argument("--json-out", type=Path, default=None)
    args = parser.parse_args()

    repo = Path(args.repository).expanduser().resolve()
    require_repository(repo)
    report = scan(repo, args.max_commits)

    print("GIT_HISTORY_SECRET_PREFLIGHT=PASS")
    print(f"COMMITS_SCANNED={report['commit_count_scanned']}")
    print(f"FINDING_COUNT={report['finding_count']}")
    print("SECRET_VALUES_EMITTED=false")

    for finding in report["findings"]:
        print(
            "FINDING "
            f"detector={finding['detector']} "
            f"commit={finding['commit']} "
            f"path={finding['path']}"
        )

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"EVIDENCE={args.json_out}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
