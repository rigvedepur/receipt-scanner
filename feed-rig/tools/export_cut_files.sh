#!/bin/bash
# Export every 2D cut file from feed_rig.scad and convert each into a
# Luban-friendly cut-line SVG (*_luban.svg). Run from anywhere.
set -e
cd "$(dirname "$0")/.."
OPENSCAD=/Applications/OpenSCAD-2021.01.app/Contents/MacOS/OpenSCAD
for p in side_plate_2d fit_coupon_2d side_plate_cnc_inner side_plate_cnc_outline fit_coupon_cnc_inner fit_coupon_cnc_outline; do
  out="stl/$p.svg"; [ "$p" = side_plate_2d ] && out=stl/side_plate_laser.svg
  "$OPENSCAD" -D "part=\"$p\"" -o "$out" feed_rig.scad 2>/dev/null
  python3 tools/svg_for_luban.py "$out"
done
