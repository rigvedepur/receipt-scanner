#!/usr/bin/env python3
"""Convert OpenSCAD 2D SVG exports into cut-line SVGs for Snapmaker Luban.

OpenSCAD writes a whole 2D part as ONE filled path (fill="lightgray"), which
Luban treats as a shape to fill or engrave. This rewrites it as one closed
path per contour (outline, each hole, each slot) with no fill and a thin black
stroke, so Luban sees pure vector cut lines.

The viewBox and width/height (in mm) are kept exactly as exported, so 1 SVG
unit = 1 mm, and files that share a bounding box (the two CNC passes) still
line up when placed at the same X/Y.

Usage: svg_for_luban.py in.svg [in2.svg ...]   -> writes <name>_luban.svg next to each
"""
import re
import sys
from pathlib import Path


def convert(src: Path) -> Path:
    text = src.read_text()
    head = re.search(r'<svg[^>]*>', text)
    if not head:
        raise SystemExit(f"{src}: no <svg> element")
    svg_tag = head.group(0)
    paths = re.findall(r'<path\s+d="([^"]*)"', text)
    if not paths:
        raise SystemExit(f"{src}: no <path> found")

    contours = []
    for d in paths:
        # each contour is "M x,y L ... z"
        for sub in re.findall(r'M[^Mz]*z', d.replace('\n', ' ')):
            contours.append(' '.join(sub.split()))

    out = ['<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
           svg_tag,
           f'<title>{src.stem} (cut lines)</title>',
           '<g fill="none" stroke="#000000" stroke-width="0.1">']
    out += [f'  <path d="{c}"/>' for c in contours]
    out += ['</g>', '</svg>', '']

    dst = src.with_name(src.stem + '_luban.svg')
    dst.write_text('\n'.join(out))
    print(f"{dst.name}: {len(contours)} closed cut paths")
    return dst


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for f in sys.argv[1:]:
        if f.endswith('_luban.svg'):
            continue
        convert(Path(f))
