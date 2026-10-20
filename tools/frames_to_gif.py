"""Turn a test's per-frame screenshots (60 fps) into a real-time GIF and a half-speed GIF.

Usage:
    python frames_to_gif.py <frame_dir> <name> [--crop x0 y0 x1 y1] [--width 736] [--skip N] [--keep]

Reads <frame_dir>/frame_*.png in name order, writes <frame_dir>/<name>_realtime.gif and
<name>_halfspeed.gif, then deletes the frames unless --keep. Nearest-neighbour scaling
keeps pixel edges crisp; the last frame is held for half a second. --skip drops leading
frames (for example leftovers from an earlier test section) from both GIFs.
"""
import argparse
import glob
import os
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('frame_dir')
    parser.add_argument('name')
    parser.add_argument('--crop', type=int, nargs=4, default=None)
    parser.add_argument('--width', type=int, default=736)
    parser.add_argument('--skip', type=int, default=0)
    parser.add_argument('--keep', action='store_true')
    args = parser.parse_args()
    files = sorted(glob.glob(os.path.join(args.frame_dir, 'frame_*.png')))
    if not files:
        raise SystemExit('no frame_*.png in ' + args.frame_dir)
    frames = []
    for path in files[args.skip:]:
        image = Image.open(path).convert('RGB')
        if args.crop:
            image = image.crop(tuple(args.crop))
        height = round(image.height * args.width / image.width)
        frames.append(image.resize((args.width, height), Image.NEAREST).quantize(64))
    hold = [frames[-1]] * 15
    real = frames[::2] + hold
    real[0].save(os.path.join(args.frame_dir, args.name + '_realtime.gif'), save_all=True, append_images=real[1:], duration=33, loop=0)
    half = frames + hold
    half[0].save(os.path.join(args.frame_dir, args.name + '_halfspeed.gif'), save_all=True, append_images=half[1:], duration=33, loop=0)
    if not args.keep:
        for path in files:
            os.remove(path)
    print('wrote', args.name + '_realtime.gif', 'and', args.name + '_halfspeed.gif', 'from', len(files), 'frames')


if __name__ == '__main__':
    main()
