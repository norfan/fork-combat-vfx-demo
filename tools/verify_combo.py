"""Check a combo scene with Godot and render a screenshot, GIFs and a frame sheet.

Usage:
  python verify_combo.py NAME [--project DIR] [--godot PATH] [--gif] [--no-render]
                         [--keep-frames] [--media]

Runs res://combos/NAME/NAME.tscn. Outputs go to PROJECT/verification/NAME/; --media also
copies the realtime GIF and the sheet to PROJECT/media/NAME.gif and NAME_sheet.png (the
pictures the README shows).

1. Headless self-test (`-- --verify`): plays the combo and checks that every "hit" event in
   combo.json landed. Exit code 0 means it passed.
2. Renders combo.png mid-combo in a real window (headless Godot draws nothing) into --shots
   (PROJECT/verification/NAME).
3. With --gif, records the whole combo and writes combo_realtime.gif, combo_halfspeed.gif and
   combo_sheet.png (every few frames in a grid, to judge rhythm at a glance; needs Pillow).

Godot is looked up in --godot, then $GODOT, then `godot4` / `godot` on PATH.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent


def find_godot(explicit: str | None) -> str:
    for candidate in (explicit, os.environ.get("GODOT"), shutil.which("godot4"), shutil.which("godot")):
        if candidate and Path(candidate).exists():
            return candidate
    raise SystemExit("Godot not found: pass --godot PATH or set $GODOT")


SETTLE = 1.1  # FightComboDemo.SETTLE: seconds after the last event


def combo_seconds(combo: Path) -> float:
    """Real length of the combo: last event time, plus every hit-stop (the clock stops), plus the settle."""
    events = json.loads(combo.read_text(encoding="utf-8")).get("events", [])
    last = max((float(e.get("t", 0)) for e in events), default=0.0)
    stops = sum(float(e.get("stop", 0.05)) for e in events if e.get("do") == "hit")
    stops += sum(0.1 for e in events if e.get("do") == "flash_step")
    return last + stops + SETTLE


def run(godot: str, project: Path, scene: str, user_args: list[str], headless: bool, timeout: int = 180) -> subprocess.CompletedProcess:
    command = [godot] + (["--headless"] if headless else []) + ["--path", str(project), scene, "--fixed-fps", "60", "--", *user_args]
    return subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("name")
    parser.add_argument("--project", type=Path, default=SKILL)
    parser.add_argument("--godot")
    parser.add_argument("--media", action="store_true", help="copy the GIF and sheet into PROJECT/media/")
    parser.add_argument("--gif", action="store_true")
    parser.add_argument("--no-render", action="store_true", help="only the headless self-test")
    parser.add_argument("--keep-frames", action="store_true", help="keep verification/frames for frames_to_review.py")
    args = parser.parse_args(argv)
    project = args.project.resolve()
    if not (project / "project.godot").is_file():
        raise SystemExit(f"{project} is not a Godot project")
    folder = project / "combos" / args.name
    if not (folder / f"{args.name}.tscn").is_file():
        raise SystemExit(f"no scene {folder / (args.name + '.tscn')}; create it with new_combo.py")
    scene = f"res://combos/{args.name}/{args.name}.tscn"
    godot = find_godot(args.godot)
    shots = project / "verification" / args.name
    shots.mkdir(parents=True, exist_ok=True)
    (project / "verification" / ".gdignore").touch()  # keep Godot from importing the PNGs

    if not (project / ".godot").is_dir():
        # A project Godot has never opened: import it first so the vfx/ classes are registered.
        subprocess.run([godot, "--headless", "--path", str(project), "--import"], capture_output=True, timeout=300)
    result = run(godot, project, scene, ["--verify"], headless=True)
    passed = result.returncode == 0 and "PASS:" in result.stdout
    print("self-test:", next((l for l in result.stdout.splitlines() if l.startswith("PASS:")), "FAIL"))
    if not passed:
        for line in (result.stdout + result.stderr).splitlines():
            if "ERROR" in line or "Expected" in line:
                print("  " + line)
        return 1
    if args.no_render:
        return 0

    seconds = combo_seconds(folder / "combo.json")
    target = shots / "combo.png"
    shot = run(godot, project, scene, [f"--capture={target}", f"--capture-at={(seconds - SETTLE) * 0.6:.2f}"], headless=False)
    print("combo.png:", "ok" if shot.returncode == 0 and target.is_file() else f"failed ({shot.returncode})")
    if args.gif:
        frames = shots / "frames"
        shutil.rmtree(frames, ignore_errors=True)
        run(godot, project, scene, [f"--frames={frames}", f"--duration={seconds:.2f}"], headless=False, timeout=300)
        count = len(list(frames.glob("frame_*.png")))
        step = max(1, math.ceil(count / 18))  # frames_to_review shows at most 18 tiles
        subprocess.run([sys.executable, str(HERE / "frames_to_review.py"), str(frames), str(shots / "combo_sheet.png"),
                        "--every", str(step), "--columns", "6", "--scale", "0.35"], check=False)
        subprocess.run([sys.executable, str(HERE / "frames_to_gif.py"), str(frames), "combo"], check=False)
        for gif in frames.glob("*.gif"):
            shutil.move(str(gif), shots / gif.name)
        if not args.keep_frames:
            shutil.rmtree(frames, ignore_errors=True)
        if args.media:
            media = project / "media"
            media.mkdir(exist_ok=True)
            (media / ".gdignore").touch()
            shutil.copy(shots / "combo_realtime.gif", media / f"{args.name}.gif")
            shutil.copy(shots / "combo_sheet.png", media / f"{args.name}_sheet.png")
        print("gif/sheet:", ", ".join(sorted(p.name for p in shots.glob("combo_*"))))
    print(f"Outputs in {shots}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
