"""Capture actual Godot demos and edit the approved first-person Chinese promo.

Run with the bundled Python and PYTHONPATH=.local-data/promo_deps.
Dependencies are installed locally, never into the shared runtime.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import math
import os
import re
import subprocess
import sys
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT.parent / "homeing-star-temp-assert/Promotion/combat_vfx_maker_20261020"
RAW = PROJECT / ".local-data/promo_raw"
GODOT = Path("E:/Godot Hub/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
FF = imageio_ffmpeg.get_ffmpeg_exe()
FONT = "C:/Windows/Fonts/msyh.ttc"
BOLD = "C:/Windows/Fonts/msyhbd.ttc"
FPS = 60
LAYOUT = "full_envelope"
W, H = 1920, 1080
VOICE = "zh-CN-YunxiNeural"

# The human-approved wording is retained, including the singular first person.
BLOCKS = [
    ("开场", "技能特效制作器", "三种风格 / 同一个工具", ["neon_ronin", "frost_swordsman", "ink_forms"], "同学们好呀！今天给大家看点干货——我做了一个技能特效制作器，准备把它开源给大家玩！先看效果！"),
    ("01 / 冰雪", "冰霜剑士", "CLAUDE · 招式编排", ["frost_swordsman"], "这套冰雪连斩，是 Claude 做的。连续突刺、旋转、挑飞，再追到空中一套连招，最后砸回地面。"),
    ("02 / 赛博朋克", "三套霓虹连招", "DEEPSEEK · 招式编排", ["neon_ronin", "neon_iaido", "neon_overdrive"], "这边的赛博朋克，是 DeepSeek 做的。这个出刀、这个停顿，再接最后一下——大家觉得这套打击感怎么样？"),
    ("03 / 水墨", "墨势六式", "CODEX · 出招表 / 节奏表 / 水墨绘制器", ["ink_forms"], "最后是 Codex 做的水墨。这套先排了出招表和节奏表：探锋、折枝、三点雨，接一个回卷，然后停一下——断江！干笔、飞白、墨滴，全都安排上。"),
    ("怎么用", "把你想要的招式，告诉 AI", "招式 / 风格 / 节奏", ["neon_iaido"], "那这些东西怎么做呢？你可以直接跟 AI 说，你想要什么招式、什么风格、什么节奏。"),
    ("描述招式", "慢 · 慢 · 快 · 快 · 快 · 重", "用自然语言编排技能", ["neon_ronin", "neon_overdrive"], "比如：先来两刀慢的，再接三刀快的，停一拍，最后给我一记重劈。"),
    ("运行预览", "在 Godot 里直接运行", "刀光 / 命中 / 击退 / 顿帧 / 震屏", ["frost_swordsman", "ember_launcher"], "它就会根据你的描述，把招式和特效编排成一个能在 Godot 里直接运行的 DEMO。刀光、命中反馈、击退、顿帧、震屏，都可以继续调整。"),
    ("打磨节奏", "这一刀收快一点，下一刀晚半拍", "先看效果，再调整", ["neon_iaido", "ink_forms"], "当然，想做得顺眼，还是得看效果、改节奏。有时候一句再帅一点，还不如明确告诉它：这一刀收快一点，下一刀晚半拍。"),
    ("扩展风格", "加上你喜欢的风格绘制器", "欢迎自由扩展", ["ink_forms", "ember_launcher", "neon_overdrive"], "大家也可以往这个项目里加自己喜欢的风格绘制器，想做什么风格，就放手试试！"),
    ("手工精修", "导出序列帧，再加上自己的风格", "ASEPRITE / 逐帧调整", ["ink_forms", "frost_swordsman"], "想再打磨一下呢，就把序列帧导出来，拿到 Aseprite 这类软件里修一修、画一画，加上你自己的风格。让 AI 帮你打个底，再自己动手调整，也是个挺好玩的过程。"),
    ("开发分享", "我的游戏，开始前期推广啦", "后续分享游戏开发过程", ["ember_launcher", "neon_ronin"], "我自己的游戏最近也进入前期推广阶段了，后面会陆续跟大家分享开发过程。"),
    ("准备开源", "试着搓一套自己的技能", "COMBAT VFX DEMO / GODOT", ["neon_overdrive", "frost_swordsman", "ink_forms"], "这次就先把这个特效制作器拿出来，准备开源，让大家也能试着搓一套自己的技能！"),
    ("评论区见", "冰雪 · 赛博 · 水墨，你选哪套？", "欢迎分享你的招式", ["frost_swordsman", "neon_iaido", "ink_forms"], "冰雪、赛博、水墨，你们最喜欢哪套？评论区聊聊！"),
]
DEMO_NAMES = {
    "frost_swordsman": ("冰霜剑士", "Claude"),
    "neon_ronin": ("赛博浪人 · 五连斩", "DeepSeek"),
    "neon_iaido": ("电磁居合 · 一闪", "DeepSeek"),
    "neon_overdrive": ("过载突刺 · 七连", "DeepSeek"),
    "ink_forms": ("墨势六式", "Codex"),
    "ember_launcher": ("烈焰上挑", "项目附带示例"),
}

def run(args: list[str], **kw) -> subprocess.CompletedProcess:
    result = subprocess.run([str(x) for x in args], capture_output=True, encoding="utf-8", errors="replace", **kw)
    if result.returncode:
        raise RuntimeError(f"Command failed: {args[:6]}\n{result.stdout[-1500:]}\n{result.stderr[-5000:]}")
    return result

def ff(args: list[str], timeout=600) -> subprocess.CompletedProcess:
    return run([FF, "-hide_banner", "-loglevel", "warning", "-y", *args], timeout=timeout)

def seconds(name: str) -> float:
    events = json.loads((PROJECT / "combos" / name / "combo.json").read_text(encoding="utf-8"))["events"]
    return max(e["t"] for e in events) + sum(e.get("stop", .05) for e in events if e["do"] == "hit") + sum(.1 for e in events if e["do"] == "flash_step") + 1.35

def capture() -> None:
    env = os.environ.copy()
    env["APPDATA"] = str(PROJECT / "verification/runtime")
    for name in DEMO_NAMES:
        movie = RAW / (name + ".avi")
        # Existing capture is reused only if it decodes successfully.
        if not movie.exists():
            print("CAPTURE", name, flush=True)
            result = run([GODOT, "--path", PROJECT, "--script", "res://tools/capture_promo.gd", "--write-movie", movie, "--fixed-fps", "60", "--", f"--combo={name}", f"--movie-duration={seconds(name):.3f}"], env=env, timeout=300)
            (OUT / "edit" / (name + "_capture.log")).write_text(result.stdout + result.stderr, encoding="utf-8")
        target = OUT / "source" / (name + ".mp4")
        if not target.exists():
            ff(["-i", str(movie), "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)])
        print("READY", name, flush=True)

async def narrate() -> None:
    import edge_tts
    semaphore = asyncio.Semaphore(2)
    async def one(i, block):
        path = OUT / "audio" / f"{i:02d}.mp3"
        if path.exists() and path.stat().st_size > 1000: return
        async with semaphore:
            for attempt in range(3):
                try:
                    speech = edge_tts.Communicate(block[4], VOICE, rate="+5%", connect_timeout=12, receive_timeout=35, boundary="WordBoundary")
                    await speech.save(path, path.with_suffix(".jsonl"))
                    print("VOICE", i, flush=True)
                    return
                except Exception:
                    if attempt == 2: raise
                    await asyncio.sleep(2)
    await asyncio.gather(*(one(i, block) for i, block in enumerate(BLOCKS)))

def font(size: int, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)

def text(draw, xy, content, size=32, fill="#e8edf3", bold=False):
    draw.text(xy, content, font=font(size, bold), fill=fill)

def make_art(i: int) -> None:
    block = BLOCKS[i]
    image = Image.new("RGB", (W, H), "#111820")
    d = ImageDraw.Draw(image)
    d.rectangle((0, 0, W, 8), fill="#73d7c8")
    text(d, (64, 32), "COMBAT VFX  /  " + block[0], 26, "#76d8c8")
    size = 58
    while d.textlength(block[1], font=font(size, True)) > 1730: size -= 2
    text(d, (64, 80), block[1], size, bold=True)
    text(d, (66, 152), block[2], 25, "#9baab8")
    if i == 12:
        for j, (label, maker, color) in enumerate([("冰雪", "Claude", "#97dbed"), ("赛博朋克", "DeepSeek", "#dc75e9"), ("水墨", "Codex", "#dad8bd")]):
            x = 64 + j * 616
            text(d, (x+15, 285), label, 44, color, True)
            d.rounded_rectangle((x-4, 356, x+564, 654), 12, fill="#26313d")
            text(d, (x+15, 690), maker, 34, color)
        text(d, (392, 823), "也欢迎加上你自己的风格绘制器", 44)
    elif 4 <= i <= 9:
        d.rounded_rectangle((64, 224, 754, 934), 18, fill="#1a2631", outline="#304351", width=2)
        d.rounded_rectangle((796, 274, 1864, 834), 14, fill="#26313d")
        text(d, (805, 866), "GODOT 实际运行画面", 25, "#8fabb9")
        if i == 4:
            text(d, (104, 266), "先把想法说清楚", 39, bold=True)
            for j, (a, b) in enumerate([("01  招式", "横斩、突刺、旋转、挑飞"), ("02  风格", "冰雪、赛博、水墨……"), ("03  节奏", "哪里快，哪里停，哪里重")]):
                y = 365 + j * 155
                text(d, (108, y), a, 30, "#76d8c8", True)
                text(d, (108, y + 54), b, 31)
        elif i == 5:
            text(d, (104, 268), "描述示例", 37, bold=True)
            for j, ch in enumerate("慢慢快快快重"):
                x = 130 + j * 99
                col = "#edba72" if j == 5 else ("#76d8c8" if j >= 2 else "#9fb3c2")
                d.ellipse((x-29, 380, x+29, 438), fill=col)
                text(d, (x-17, 386), ch, 30, "#111820", True)
            for j, line in enumerate(["先来两刀慢的", "再接三刀快的", "停一拍", "最后给我一记重劈"]):
                text(d, (111, 505+j*78), line, 34)
            text(d, (108, 855), "不是一句“再帅一点”", 26, "#8fabb9")
        elif i == 6:
            text(d, (104, 265), "从描述到可运行场景", 36, bold=True)
            text(d, (108, 370), "combo.json", 35, "#76d8c8", True)
            text(d, (108, 423), "招式事件 / 命中时间 / 顿帧", 28)
            text(d, (108, 520), "style.json", 35, "#76d8c8", True)
            text(d, (108, 573), "颜色 / 笔宽 / 绘制器", 28)
            text(d, (108, 695), "生成 .tscn 场景", 33)
            text(d, (108, 757), "Godot 里按 F6 运行", 33)
            text(d, (108, 855), "本片右侧均为实际运行录制", 25, "#8fabb9")
        elif i == 7:
            text(d, (104, 268), "打击感，也藏在时间里", 36, bold=True)
            for j, line in enumerate(["出手方向", "每一击之间的间隔", "命中的那一下停多久"]):
                text(d, (108, 387+j*108), f"0{j+1}", 28, "#76d8c8", True)
                text(d, (180, 382+j*108), line, 30)
            text(d, (108, 786), "看一遍 → 调整 → 再看一遍", 28, "#edba72")
        elif i == 8:
            text(d, (104, 265), "风格可以继续往外长", 36, bold=True)
            for j, (label, col) in enumerate([("冰雪 / 刀光与碎片", "#97dbed"), ("赛博 / 霓虹与闪切", "#dc75e9"), ("水墨 / 干笔与飞白", "#dad8bd")]):
                y = 391+j*132
                d.rounded_rectangle((108,y,136,y+55), 5, fill=col)
                text(d, (165, y+5), label, 30)
            text(d, (108, 842), "添加你喜欢的风格绘制器", 29, "#76d8c8")
        else:
            text(d, (104, 260), "导出序列帧", 36, bold=True)
            # Thumbnails are extracted from the real Godot capture, not painted substitutes.
            for j, stamp in enumerate([.57, 1.3, 1.9, 2.15, 2.84, 4.62]):
                thumb = OUT / "edit" / f"frame_{j}.png"
                if not thumb.exists() or thumb.stat().st_mtime < (OUT / "source/ink_forms.mp4").stat().st_mtime:
                    ff(["-ss", str(stamp), "-i", str(OUT / "source/ink_forms.mp4"), "-frames:v", "1", "-vf", "crop=510:320:380:240,scale=270:169", str(thumb)])
                image.paste(Image.open(thumb).convert("RGB"), (108+(j%2)*297, 335+(j//2)*180))
            text(d, (108, 879), "Aseprite：修形 / 调色 / 补细节", 25, "#76d8c8")
    else:
        d.rounded_rectangle((226, 196, 1694, 954), radius=12, fill="#26313d")
    d.rectangle((0, 963, W, H), fill="#0b1016")
    text(d, (64, 1041), "技能特效制作器  ·  开源预告", 20, "#7b8c9a")
    text(d, (1600, 1041), f"{i + 1:02d} / {len(BLOCKS):02d}", 20, "#7b8c9a")
    bg_path = OUT / "edit" / f"bg_{i:02d}.png"
    if not bg_path.exists() or Image.open(bg_path).convert("RGB").tobytes() != image.tobytes():
        image.save(bg_path)

def subtitle_chunks(s: str):
    # Keep each readable Chinese subtitle below 24 visible characters.
    parts = [x for x in re.split(r"(?<=[，。！？：；])", s) if x.strip()]
    chunks = []
    for p in parts:
        if len(p) <= 25: chunks.append(p)
        else:
            # English words stay intact when possible.
            words = re.findall(r"[A-Za-z]+|.", p)
            line = ""
            for word in words:
                if len(line) + len(word) > 24:
                    chunks.append(line)
                    line = ""
                line += word
            if line: chunks.append(line)
    return chunks

def ass_time(t):
    n = round(t * 100)
    return f"{n // 360000}:{n // 6000 % 60:02d}:{n // 100 % 60:02d}.{n % 100:02d}"

def srt_time(t):
    n = round(t * 1000)
    return f"{n // 3600000:02d}:{n // 60000 % 60:02d}:{n // 1000 % 60:02d},{n % 1000:03d}"

def norm(s):
    return re.sub(r"[^\w\u4e00-\u9fff]", "", s).lower()

def prepare_timeline():
    narration = bytearray()
    all_cues = []
    timeline = []
    rate = 48000
    offset = 0.0
    for i, block in enumerate(BLOCKS):
        pcm = subprocess.check_output([FF, "-v", "error", "-i", str(OUT / "audio" / f"{i:02d}.mp3"), "-ac", "1", "-ar", str(rate), "-f", "s16le", "-"])
        audio_seconds = len(pcm) / (2 * rate)
        duration = math.ceil((audio_seconds + .32) * FPS) / FPS
        narration.extend(pcm)
        narration.extend(bytes(round(duration * rate) * 2 - len(pcm)))
        chunks = subtitle_chunks(block[4])
        boundaries = [json.loads(line) for line in (OUT / "audio" / f"{i:02d}.jsonl").read_text(encoding="utf-8").splitlines()]
        boundaries = [b for b in boundaries if b.get("type") == "WordBoundary"]
        cue_list = []
        cursor = 0
        boundary_cursor = 0
        char_clock = []
        for b in boundaries:
            chars = norm(b.get("text", ""))
            start = b["offset"] / 1e7
            length = b["duration"] / 1e7
            for n in range(len(chars)):
                char_clock.append(start + length * n / max(1, len(chars)))
        whole = norm(block[4])
        for n, chunk in enumerate(chunks):
            count = len(norm(chunk))
            if len(char_clock) == len(whole):
                start = char_clock[min(cursor, len(char_clock) - 1)]
                end = char_clock[cursor + count] if cursor + count < len(char_clock) else audio_seconds
            else:
                start = audio_seconds * cursor / max(1, len(whole))
                end = audio_seconds * (cursor + count) / max(1, len(whole))
            cue_list.append((start, end, chunk))
            all_cues.append((offset + start, offset + end, chunk))
            cursor += count
        ass = "[Script Info]\nPlayResX: 1920\nPlayResY: 1080\nWrapStyle: 2\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Microsoft YaHei,43,&H00FFFFFF,&H000000FF,&H00100D09,&H90000000,0,0,0,0,100,100,0,0,1,2,0,2,100,100,68,1\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
        for start, end, chunk in cue_list:
            ass += f"Dialogue: 0,{ass_time(start)},{ass_time(end)},Default,,0,0,0,,{chunk}\n"
        (OUT / "edit" / f"sub_{i:02d}.ass").write_text(ass, encoding="utf-8-sig")
        timeline.append({"index": i, "start": offset, "duration": duration, "audio_duration": audio_seconds, "chapter": block[0], "title": block[1], "demos": block[3], "text": block[4], "subtitle_alignment": "word_boundary" if len(char_clock) == len(whole) else "character_weighted"})
        make_art(i)
        offset += duration
    with wave.open(str(OUT / "audio/narration.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(narration)
    (OUT / "narration.srt").write_text("\n\n".join(f"{i+1}\n{srt_time(a)} --> {srt_time(b)}\n{s}" for i, (a, b, s) in enumerate(all_cues)) + "\n", encoding="utf-8-sig")
    (OUT / "edit/timeline.json").write_text(json.dumps(timeline, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "narration.txt").write_text("\n\n".join(b[4] for b in BLOCKS) + "\n", encoding="utf-8")
    return timeline

def safe_filter_path(path):
    return str(path).replace("\\", "/").replace(":", "\\:")

def render(timeline):
    # Cut to each demo at least once, then selectively replay at half speed.
    # Each shot has a source/model label independent from narration subtitles.
    all_edit_shots = []
    for item in timeline:
        i = item["index"]
        duration = item["duration"]
        names = BLOCKS[i][3]
        if i == 12:
            chapter = OUT / "edit" / f"chapter_{i:02d}_{LAYOUT}.mp4"
            if not chapter.exists() or chapter.stat().st_mtime < max([(OUT / "source" / (name + ".mp4")).stat().st_mtime for name in names] + [(OUT / "edit" / f"bg_{i:02d}.png").stat().st_mtime]):
                inputs = []
                for name in names:
                    inputs.extend(["-stream_loop", "-1", "-i", str(OUT / "source" / (name + ".mp4"))])
                inputs.extend(["-loop", "1", "-framerate", "60", "-i", str(OUT / "edit" / f"bg_{i:02d}.png")])
                graph = ";".join(f"[{j}:v]crop=1100:570:100:90,scale=560:290:flags=lanczos,setsar=1,fps=60[d{j}]" for j in range(3))
                graph += ";[3:v][d0]overlay=64:360[a];[a][d1]overlay=680:360[b];[b][d2]overlay=1296:360,ass='" + safe_filter_path(OUT / 'edit' / f'sub_{i:02d}.ass') + "',format=yuv420p[v]"
                ff([*inputs, "-filter_complex", graph, "-map", "[v]", "-t", str(duration), "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-threads", "4", str(chapter)])
            all_edit_shots.append({"chapter": i, "source": names, "start": item["start"], "duration": duration, "speed": 1, "file": str(chapter)})
            print("SHOT", i, "triptych", flush=True)
            continue
        # Break longer explanations into 3-5 second visual cuts.
        ncuts = max(len(names), math.ceil(duration / 4.8))
        # Water-ink demonstration needs its long authored pause intact.
        if i == 3: ncuts = max(1, round(duration / seconds("ink_forms")))
        bounds = [round(j * duration / ncuts * FPS) / FPS for j in range(ncuts+1)]
        if i == 1: bounds = [0, 3.15, duration]
        if i == 3: bounds = [0, 5.2, 11.62, duration]
        pieces = []
        for j in range(len(bounds)-1):
            start, end = bounds[j:j+2]
            name = names[j % len(names)]
            speed = 1.0
            # All first demonstrations run in real time. Extra explanation shots can slow down.
            if i not in [0, 1, 2, 3] and j % 2 == 1: speed = 0.65
            if i == 1 and j == 1: speed = 0.6
            if i == 3 and j == 1: speed = 0.8
            path = OUT / "edit" / f"shot_{i:02d}_{j:02d}_{LAYOUT}.mp4"
            length = end - start
            if not path.exists() or path.stat().st_mtime < max((OUT / "source" / (name + ".mp4")).stat().st_mtime, (OUT / "edit" / f"bg_{i:02d}.png").stat().st_mtime):
                # Loop from a fresh attack, with the source tempo explicitly shown on screen.
                name_label, author = DEMO_NAMES[name]
                tag = f"{name_label}  |  {author}  |  {'原速' if speed == 1 else f'{speed:.2g}x 慢放'}"
                label = OUT / "edit" / f"label_{i:02d}_{j:02d}.png"
                demo_w, demo_h, demo_x, demo_y = (1060, 550, 800, 278) if 4 <= i <= 9 else (1460, 758, 230, 196)
                overlay = Image.new("RGBA", (demo_w, 80), (0, 0, 0, 0))
                d = ImageDraw.Draw(overlay)
                d.rounded_rectangle((12, 12, 30 + d.textlength(tag, font=font(25)), 65), 12, fill=(12, 18, 24, 220))
                text(d, (25, 22), tag, 25)
                overlay.save(label)
                vf = f"[0:v]setpts=(PTS-STARTPTS)/{speed},crop=1100:570:100:90,scale={demo_w}:{demo_h}:flags=lanczos,setsar=1,fps=60[demo];[1:v][demo]overlay={demo_x}:{demo_y}[canvas];[canvas][2:v]overlay={demo_x}:{demo_y+4},format=yuv420p[v]"
                ff(["-stream_loop", "-1", "-i", str(OUT / "source" / (name + ".mp4")), "-loop", "1", "-framerate", "60", "-i", str(OUT / "edit" / f"bg_{i:02d}.png"), "-loop", "1", "-framerate", "60", "-i", str(label), "-filter_complex", vf, "-map", "[v]", "-an", "-t", f"{length:.6f}", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-threads", "4", "-movflags", "+faststart", str(path)])
            pieces.append(path)
            all_edit_shots.append({"chapter": i, "source": name, "start": item["start"] + start, "duration": length, "speed": speed, "file": str(path)})
            print("SHOT", i, j, name, flush=True)
        concat = OUT / "edit" / f"concat_{i:02d}.txt"
        concat.write_text("".join("file '" + str(p).replace("\\", "/") + "'\n" for p in pieces), encoding="utf-8")
        chapter = OUT / "edit" / f"chapter_{i:02d}_{LAYOUT}.mp4"
        if not chapter.exists() or chapter.stat().st_mtime < max(p.stat().st_mtime for p in pieces):
            ff(["-f", "concat", "-safe", "0", "-i", str(concat), "-vf", f"ass='{safe_filter_path(OUT / 'edit' / f'sub_{i:02d}.ass')}'", "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-threads", "4", str(chapter)])
    (OUT / "edit/shots.json").write_text(json.dumps(all_edit_shots, ensure_ascii=False, indent=2), encoding="utf-8")
    concat = OUT / "edit/all_chapters.txt"
    concat.write_text("".join("file '" + str(OUT / 'edit' / f'chapter_{i:02d}_{LAYOUT}.mp4').replace("\\", "/") + "'\n" for i in range(len(timeline))), encoding="utf-8")
    clean = OUT / "combat_vfx_promo_no_voice.mp4"
    ff(["-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(clean)])
    final = OUT / "combat_vfx_promo.mp4"
    ff(["-i", str(clean), "-i", str(OUT / "audio/narration.wav"), "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-af", "loudnorm=I=-16:TP=-1.5:LRA=9", "-ar", "48000", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(final)])
    print("FINAL", final, flush=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["capture", "voice", "edit", "all"])
    args = parser.parse_args()
    for folder in [RAW, OUT / "source", OUT / "audio", OUT / "edit"]: folder.mkdir(parents=True, exist_ok=True)
    if args.phase in ["capture", "all"]: capture()
    if args.phase in ["voice", "all"]: asyncio.run(narrate())
    if args.phase in ["edit", "all"]:
        timeline = prepare_timeline()
        print("DURATION", round(sum(t["duration"] for t in timeline), 2), flush=True)
        render(timeline)

if __name__ == "__main__": main()
