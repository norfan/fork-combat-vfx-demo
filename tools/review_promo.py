"""Decode the delivered edit, check durations and produce real-frame review sheets."""
from __future__ import annotations
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw
import build_promo as p

def main():
    timeline = json.loads((p.OUT / "edit/timeline.json").read_text(encoding="utf-8"))
    final = p.OUT / "combat_vfx_promo.mp4"
    decoded = p.run([p.FF, "-hide_banner", "-i", final, "-progress", "pipe:1", "-f", "null", "-"], timeout=180)
    frame_counts = re.findall(r"^frame=(\d+)$", decoded.stdout, re.M)
    expected = round(sum(item["duration"] for item in timeline) * 60)
    if not frame_counts or abs(int(frame_counts[-1]) - expected) > 2:
        raise RuntimeError(f"Expected {expected} frames, decoded {frame_counts[-1:]}")
    if "1920x1080" not in decoded.stderr or "60 fps" not in decoded.stderr or "Audio: aac" not in decoded.stderr or "48000 Hz" not in decoded.stderr:
        raise RuntimeError("Unexpected delivery format\n" + decoded.stderr[-2000:])
    sheets = []
    for i, item in enumerate(timeline):
        # Meaningful action moments, not just settled end frames.
        local = 1.0 if i not in (3, 9, 12) else {3: 10.8, 9: 2.6, 12: 1.2}[i]
        stamp = item["start"] + min(local, item["duration"] - .1)
        shot = p.OUT / "edit" / f"review_{i:02d}.png"
        p.ff(["-ss", str(stamp), "-i", str(final), "-frames:v", "1", str(shot)])
        img = Image.open(shot).convert("RGB").resize((640, 360), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (640, 392), "#111820")
        tile.paste(img, (0, 32))
        d = ImageDraw.Draw(tile)
        p.text(d, (8, 3), f"{i+1:02d} / {stamp:.2f}s / {item['chapter']}", 20)
        sheets.append(tile)
    for k, group in enumerate([sheets[:6], sheets[6:12], sheets[12:]]):
        canvas = Image.new("RGB", (1920, 392* (2 if len(group) > 3 else 1)), "#111820")
        for j, tile in enumerate(group): canvas.paste(tile, ((j%3)*640, (j//3)*392))
        canvas.save(p.OUT / f"review_{k+1}.jpg", quality=92)
    measured = p.run([p.FF, "-hide_banner", "-i", final, "-vn", "-af", "volumedetect", "-f", "null", "-"], timeout=60)
    peak = re.search(r"max_volume: ([\-\d.]+) dB", measured.stderr)
    if not peak or float(peak.group(1)) > -0.1:
        raise RuntimeError("Audio peak is missing or clips")
    report = {"format": "H.264 / AAC, 1920x1080, 60fps, 48kHz", "seconds": expected / 60, "decoded_frames": int(frame_counts[-1]), "audio_peak_dbfs": float(peak.group(1)), "subtitle_alignment": "TTS word boundaries", "demos": list(p.DEMO_NAMES), "narrator": "Microsoft Yunxi neural Chinese synthetic voice via edge-tts", "human_voice_clone": False}
    (p.OUT / "quality_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PASS: full video decodes, 1080p60, AAC narration, expected duration and no clipped audio")

if __name__ == "__main__": main()
