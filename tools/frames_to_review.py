"""Contact sheet of chosen frames, labelled with frame number and seconds, for self-review.

Usage:
    python frames_to_review.py <frame_dir> <out.png> [--every 4] [--frames 2 4 8 ...]
                               [--crop x0 y0 x1 y1] [--columns 6] [--scale 0.5]

Picks every Nth frame (default 4) or the listed frame numbers, at most 18 tiles.
Look for: crescents that don't reach the target, hits without a target reaction, a
finisher that doesn't stand out.
"""
import argparse
import glob
import os
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('frame_dir')
    parser.add_argument('out')
    parser.add_argument('--every', type=int, default=4)
    parser.add_argument('--frames', type=int, nargs='*')
    parser.add_argument('--crop', type=int, nargs=4, default=None)
    parser.add_argument('--columns', type=int, default=6)
    parser.add_argument('--scale', type=float, default=0.5)
    args = parser.parse_args()
    files = sorted(glob.glob(os.path.join(args.frame_dir, 'frame_*.png')))
    if not files:
        raise SystemExit('no frame_*.png in ' + args.frame_dir)
    picks = args.frames if args.frames else list(range(0, len(files), args.every))
    picks = [i for i in picks if i < len(files)][:18]
    tiles = []
    for i in picks:
        image = Image.open(files[i]).convert('RGB')
        if args.crop:
            image = image.crop(tuple(args.crop))
        image = image.resize((int(image.width * args.scale), int(image.height * args.scale)), Image.NEAREST)
        ImageDraw.Draw(image).text((4, 4), 'f%d  %.2fs' % (i, i / 60.0), fill='yellow')
        tiles.append(image)
    w, h = tiles[0].size
    rows = (len(tiles) + args.columns - 1) // args.columns
    sheet = Image.new('RGB', (w * args.columns, h * rows))
    for j, tile in enumerate(tiles):
        sheet.paste(tile, ((j % args.columns) * w, (j // args.columns) * h))
    sheet.save(args.out)
    print('wrote', args.out, 'with', len(tiles), 'tiles')


if __name__ == '__main__':
    main()
