#!/usr/bin/env python3
"""compose.py <bg.png> <out.mp4> <slide1.mp4> <slide2.mp4> ...

Puts each 1320x2868 slide video, scaled to 884x1920, centred on a 1080x1920 background
(the paper grid of the slides, aligned so the side bands are invisible), then joins the
slides with 0.7 s smooth slides and holds the last frame for 1 s.
"""
import subprocess, sys
from pathlib import Path

FADE = 0.7
if len(sys.argv) < 4:
    sys.exit(__doc__.strip().splitlines()[0])
bg, out, *slides = sys.argv[1:]

def run(*a):
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', *a])

def duration(f):
    return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                                          '-of', 'csv=p=0', f]).strip())

framed = []
for s in slides:
    f = str(Path(s).with_suffix('.framed.mp4'))
    run('-loop', '1', '-i', bg, '-i', s, '-filter_complex',
        '[1]scale=884:1920:flags=lanczos[s];[0][s]overlay=98:0:shortest=1,format=yuv420p',
        '-r', '30', '-c:v', 'libx264', '-crf', '17', f)
    framed.append(f)

chain, offset, prev = [], 0.0, '0'
for i in range(1, len(framed)):
    offset += duration(framed[i - 1]) - FADE
    label = f'x{i}'
    chain.append(f'[{prev}][{i}]xfade=transition=smoothleft:duration={FADE}:offset={offset:.3f}[{label}]')
    prev = label
chain.append(f'[{prev}]tpad=stop_mode=clone:stop_duration=1,format=yuv420p[v]')
inputs = sum([['-i', f] for f in framed], [])
run(*inputs, '-filter_complex', ';'.join(chain), '-map', '[v]', '-c:v', 'libx264', '-crf', '17',
    '-movflags', '+faststart', out)
