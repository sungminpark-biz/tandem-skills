#!/bin/sh
"true" '''\'
exec python3 "$0" "$@"
'''
"""100%-Vertex headless runner for /team read-only agents (team-reviewer, team-survey).

Usage:
  run-agent.sh --preflight
  run-agent.sh <model> <agent> <prompt_file> <out_json_file> [conversation_id]
"""
import json
import os
import pathlib
import subprocess
import sys

ALLOWED_MODELS = {
    "gemini-4-carbon-medium",
    "gemini-4-carbon-high",
    "gemini-4-hydrogen-high",
    "gemini-4-hydrogen-xhigh",
    "gemini-4-hydrogen-medium",
}
ALLOWED_AGENTS = {"team-reviewer", "team-survey"}
MAX_PROMPT_BYTES = 200_000


def fail(msg: str, code: int = 2) -> None:
    sys.stderr.write(f"run-agent error: {msg}\n")
    sys.exit(code)


def check_vertex_billing() -> tuple[str, str]:
    if os.environ.get("GOOGLE_GENAI_USE_VERTEXAI", "").lower() != "true":
        fail("GOOGLE_GENAI_USE_VERTEXAI is not 'true'; refusing non-Vertex execution")
    project = os.environ.get("GOOGLE_CLOUD_PROJECT", "").strip()
    if not project:
        fail("GOOGLE_CLOUD_PROJECT is unset; refusing execution without Vertex billing project")
    for key_var in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        if os.environ.get(key_var):
            fail(f"{key_var} is set in environment; refusing execution to prevent non-Vertex API key billing")

    settings_file = pathlib.Path.home() / ".gemini" / "antigravity-cli" / "settings.json"
    active_ui_model = ""
    if settings_file.is_file():
        try:
            cfg = json.loads(settings_file.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(f"could not parse {settings_file}: {exc}")
        provider = str(cfg.get("modelProvider") or "").strip().lower()
        if provider not in ("", "vertex", "vertex-ai"):
            fail(f"settings.json has non-Vertex modelProvider='{provider}'; refusing execution")
        active_ui_model = str(cfg.get("model") or "").strip()
        low = active_ui_model.lower()
        if active_ui_model and not ("gemini 4" in low or low.startswith("gemini-4-")):
            fail(
                f"settings.json default model '{active_ui_model}' is not Gemini 4; "
                "switch /model to Gemini 4 Carbon or Hydrogen for 100% Vertex Gemini 4 execution"
            )
    return project, active_ui_model


def parse_agy_json(stdout: str) -> dict:
    stripped = stdout.strip()
    if not stripped:
        raise ValueError("empty stdout from agy")
    try:
        obj = json.loads(stripped)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass
    for line in reversed(stripped.splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                obj = json.loads(line)
                if isinstance(obj, dict):
                    return obj
            except Exception:
                continue
    raise ValueError("no valid JSON object found in agy stdout")


def main() -> None:
    skill_dir = pathlib.Path(__file__).resolve().parent
    config_root = skill_dir.parent.parent  # ~/.gemini/config

    if len(sys.argv) == 2 and sys.argv[1] == "--preflight":
        project, active_ui_model = check_vertex_billing()
        for rel in ("skills/ponytail-review/SKILL.md", "agents/team-reviewer.md", "agents/team-survey.md"):
            if not (config_root / rel).is_file():
                fail(f"missing required /team asset: {config_root / rel}")
        tier = "default"
        cfg_file = config_root / "config.json"
        if cfg_file.is_file():
            try:
                tier = json.loads(cfg_file.read_text(encoding="utf-8")).get("userSettings", {}).get("vertexServiceTier", "default")
            except Exception:
                pass
        print(f"VERTEX_OK project={project} tier={tier} default_ui_model={active_ui_model or 'default'}")
        return

    if len(sys.argv) not in (5, 6):
        fail("usage: run-agent.sh [--preflight | <model> <agent> <prompt_file> <out_json_file> [conversation_id]]")

    model, agent, prompt_path, out_path = sys.argv[1:5]
    conv_id = sys.argv[5].strip() if len(sys.argv) == 6 else ""

    if model not in ALLOWED_MODELS:
        fail(f"blocked model '{model}': allowed models are {sorted(ALLOWED_MODELS)} (100% Vertex credits)")
    if agent not in ALLOWED_AGENTS:
        fail(f"blocked agent '{agent}': allowed read-only agents are {sorted(ALLOWED_AGENTS)}")

    check_vertex_billing()

    prompt_file = pathlib.Path(prompt_path)
    if not prompt_file.is_file():
        fail(f"prompt file not found: {prompt_path}")
    raw_bytes = prompt_file.read_bytes()
    if not raw_bytes.strip():
        fail(f"prompt file is empty: {prompt_path}")
    if len(raw_bytes) > MAX_PROMPT_BYTES:
        fail(
            f"prompt file exceeds {MAX_PROMPT_BYTES} bytes ({len(raw_bytes)}B): "
            "write diffs/listings to /tmp/team/<slug>/ files and pass their paths instead of inlining"
        )
    prompt_text = raw_bytes.decode("utf-8")

    env = os.environ.copy()
    for key in (
        "ORCA_PANE_KEY",
        "ORCA_TAB_ID",
        "ORCA_AGENT_LAUNCH_TOKEN",
        "ORCA_AGENT_HOOK_ENDPOINT",
        "ORCA_AGENT_HOOK_PORT",
        "ORCA_AGENT_HOOK_TOKEN",
    ):
        env.pop(key, None)

    cmd = [
        "agy",
        "--dangerously-skip-permissions",
        "--model",
        model,
        "--agent",
        agent,
        "--output-format",
        "json",
    ]
    if conv_id:
        cmd.extend(["--conversation", conv_id])
    cmd.append(f"-p={prompt_text}")

    timeout_sec = int(os.environ.get("TEAM_AGENT_TIMEOUT_SEC", "600"))
    out_file = pathlib.Path(out_path)
    out_file.parent.mkdir(parents=True, exist_ok=True)

    try:
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=timeout_sec)
    except FileNotFoundError:
        fail("'agy' executable not found on PATH", code=127)
    except subprocess.TimeoutExpired as exc:
        out_file.write_text(
            json.dumps({"status": "TIMEOUT", "timeout_sec": timeout_sec, "stdout": exc.stdout or "", "stderr": exc.stderr or ""}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        fail(f"agy timed out after {timeout_sec}s", code=124)

    if proc.returncode != 0:
        out_file.write_text(
            json.dumps({"status": "ERROR", "returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        sys.stderr.write(proc.stderr or proc.stdout)
        sys.exit(proc.returncode)

    try:
        data = parse_agy_json(proc.stdout)
    except ValueError as exc:
        out_file.write_text(
            json.dumps({"status": "PARSE_ERROR", "error": str(exc), "stdout": proc.stdout, "stderr": proc.stderr}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        fail(f"invalid JSON output from agy: {exc}", code=1)

    status = str(data.get("status", ""))
    response = str(data.get("response") or "")
    if status != "SUCCESS" or not response.strip():
        out_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        fail(f"agent returned status='{status}' with empty or failed response", code=1)

    out_file.write_text(json.dumps(data, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"conversation_id: {data.get('conversation_id', '')}")
    print(f"status: {status}")
    print("---")
    print(response)


if __name__ == "__main__":
    main()
