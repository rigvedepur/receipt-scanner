#!/usr/bin/env python3
"""stitch.py - stitch stop-and-go scan frames into one receipt image.

    python3 stitching/stitch.py data/scans/20261023-173922
    python3 stitching/stitch.py data/scans/20261023-173922 --band 80 335 --enhance

Steps
  0. Paper present: frames where the window is empty (before the receipt arrives
     or after it has left) look like the first/last frame; they're skipped.
  1. Flat field: for every pixel, the 90th percentile over all frames is "blank
     paper at this spot" (ink is dark and keeps moving past). Dividing each frame
     by it cancels the static things that show through the thin paper (the idler
     roller behind it, rods, uneven light). Paper becomes ~1.0, ink < 1.0.
  2. Window: the paper area between the two driven rollers is found
     automatically (bright in the flat field, and changing between frames).
     Rollers, O-rings and the background are masked out. Override with --band.
  3. Registration: the vertical shift between neighbouring frames is measured
     from the ink, comparing only valid (unmasked) pixels. Shifts that aren't
     confident fall back to the median step.
  4. Blend: frames are placed on one tall canvas and averaged, weighted towards
     the middle of the window, which hides seams and averages out sensor noise.

Writes into the scan folder: stitched.png, stitch_debug.png (mask + window),
stitch.json (per-frame shifts and confidences).
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def load_stack(folder):
    files = sorted((folder / "frames").glob("*.png"))
    if not files:
        files = sorted((folder / "frames").glob("*.npy"))
        return np.stack([np.load(f) for f in files]).astype(np.float32), files
    return np.stack([np.asarray(Image.open(f).convert("L")) for f in files]).astype(np.float32), files


def box_blur(a, k):
    """Separable box blur (radius k) over the last two axes, same size."""
    for ax in (a.ndim - 2, a.ndim - 1):
        pad = [(0, 0)] * a.ndim
        pad[ax] = (k, k)
        c = np.cumsum(np.pad(a, pad, mode="edge"), axis=ax)
        n = a.shape[ax]
        a = (np.take(c, np.arange(2 * k, 2 * k + n), axis=ax) - np.take(c, np.arange(0, n), axis=ax)) / (2 * k)
    return a


def paper_present(crops, frac=0.3):
    """True for frames whose window (crops: frames cut to the window) differs
    clearly from an empty window. The empty view is the first and last frame,
    which is why a scan should feed further than the receipt is long.
    Thresholds are relative to the biggest difference seen, so slow lighting
    drift between the two empty ends doesn't matter. If the ends don't look
    alike (paper still in view at one end), every frame counts."""
    d0 = np.abs(crops - crops[0][None]).mean(axis=(1, 2))
    dl = np.abs(crops - crops[-1][None]).mean(axis=(1, 2))
    dmin = np.minimum(d0, dl)                    # distance to the nearer empty end
    peak = dmin.max()
    if peak < 12 or d0[-1] > frac * peak:        # no clear receipt, or the ends differ
        return np.ones(len(crops), bool)
    present = dmin > frac * peak
    idx = np.where(present)[0]
    if len(idx):                     # keep one empty frame either side: the receipt's ends
        present[max(idx[0] - 1, 0):idx[-1] + 2] = True
    return present


def runs(mask_1d):
    """(start, end) of each run of True values."""
    out, start = [], None
    for i, v in enumerate(mask_1d):
        if v and start is None:
            start = i
        if not v and start is not None:
            out.append((start, i)); start = None
    if start is not None:
        out.append((start, len(mask_1d)))
    return out


def find_window(flat, motion, min_rows=40, bridge=20):
    """Rows of the paper window between the rollers, plus a per-pixel valid mask.
    Valid = clearly brighter than the rollers (the darkest large area) AND ink moves
    through it. Paper behind which a roller sits is darker but still valid."""
    dark = np.percentile(flat, 10)                          # rollers / O-rings
    bright_enough = flat > 1.6 * dark
    thr = np.percentile(motion[bright_enough], 30)
    valid = bright_enough & (motion > thr)
    cols = valid.mean(axis=0) > 0.3                         # columns where paper shows up
    row_frac = valid[:, cols].mean(axis=1) if cols.any() else valid.mean(axis=1)
    rowok = row_frac > 0.4
    for a, b in runs(~rowok):                               # bridge thin quiet rows (an edge behind the paper)
        if b - a <= bridge and a > 0 and b < len(rowok):
            rowok[a:b] = True
            valid[a:b] |= bright_enough[a:b]
    cands = [(a, b) for a, b in runs(rowok) if b - a >= min_rows]
    if not cands:
        raise SystemExit("couldn't find the paper window - pass --band ROW_START ROW_END")
    inner = [(a, b) for a, b in cands if a > 0 and b < len(row_frac)]   # bounded by rollers both sides
    a, b = max(inner or cands, key=lambda r: r[1] - r[0])
    return a, b, valid, cols


def ncc_curve(A, B, Ma, Mb, search, min_overlap=0.3):
    """{d: masked normalised cross-correlation of A[r] with B[r + d]}."""
    H = A.shape[0]
    scores = {}
    for d in search:
        if abs(d) >= H * (1 - min_overlap):
            continue
        if d >= 0:
            a, b, ma, mb = A[:H - d], B[d:], Ma[:H - d], Mb[d:]
        else:
            a, b, ma, mb = A[-d:], B[:H + d], Ma[-d:], Mb[:H + d]
        w = ma & mb
        n = w.sum()
        if n < 2000:
            continue
        x, y = a[w], b[w]
        x = x - x.mean(); y = y - y.mean()
        den = np.sqrt((x * x).sum() * (y * y).sum())
        scores[d] = float((x * y).sum() / den) if den > 0 else 0.0
    return scores


def subpixel(scores, best):
    """Parabola through the neighbours of the best integer shift."""
    if best - 1 in scores and best + 1 in scores:
        y0, y1, y2 = scores[best - 1], scores[best], scores[best + 1]
        den = y0 - 2 * y1 + y2
        if den < 0:
            return best + 0.5 * (y0 - y2) / den
    return float(best)


def shift_ncc(A, B, Ma, Mb, search, min_overlap=0.3):
    """Vertical shift d with B[r + d] ~ A[r]. Returns (d_subpixel, peak, second_best)."""
    scores = ncc_curve(A, B, Ma, Mb, search, min_overlap)
    if not scores:
        return None, 0.0, 0.0
    best = max(scores, key=scores.get)
    s = sorted(scores.values(), reverse=True)
    # sub-pixel refinement with a parabola through the neighbours
    sub = float(best)
    if best - 1 in scores and best + 1 in scores:
        y0, y1, y2 = scores[best - 1], scores[best], scores[best + 1]
        den = y0 - 2 * y1 + y2
        if den < 0:
            sub = best + 0.5 * (y0 - y2) / den
    second = max((v for k, v in scores.items() if abs(k - best) > 3), default=0.0)
    return sub, s[0], second


def main():
    ap = argparse.ArgumentParser(description="Stitch stop-and-go receipt frames.")
    ap.add_argument("scan", help="scan folder (contains frames/ and scan.json)")
    ap.add_argument("--band", type=int, nargs=2, metavar=("ROW0", "ROW1"), help="window rows (default: auto)")
    ap.add_argument("--max-shift", type=int, default=200, help="largest frame-to-frame shift to search (px)")
    ap.add_argument("--min-conf", type=float, default=0.3, help="NCC needed to trust a measured shift")
    ap.add_argument("--enhance", action="store_true", help="stretch contrast for a crisp black-on-white result")
    ap.add_argument("--sharpness", type=float, default=6,
                    help="blend weighting: higher = less ghosting, more visible seams (default 6)")
    args = ap.parse_args()
    folder = Path(args.scan)

    frames, files = load_stack(folder)
    print("%d frames, %dx%d" % (frames.shape[0], frames.shape[2], frames.shape[1]))
    def analyse(fr):
        flat = np.percentile(fr, 90, axis=0)
        ink = 1.0 - fr / np.maximum(flat, 1.0)[None]
        return flat, ink, (ink - ink.mean(axis=0)[None]).std(axis=0)

    flat0, _, motion0 = analyse(frames)                     # first pass: where is the window?
    w0, w1, _, cols0 = find_window(flat0, motion0)
    present = paper_present(frames[:, w0:w1][:, :, cols0])
    keep = np.where(present)[0]
    if len(keep) < len(frames):
        print("receipt in the window in frames %d-%d (%d of %d); the others show an empty window"
              % (keep[0], keep[-1], len(keep), len(frames)))
    frames = frames[keep]
    files = [files[i] for i in keep]
    n, H, W = frames.shape

    # 1. flat field
    flat, ink_all, motion = analyse(frames)                 # second pass: receipt frames only
    norm = 1.0 - ink_all                                    # paper ~1, ink < 1
    detail = ink_all - box_blur(ink_all, 6)                 # fine detail only: text strokes, not lighting
    moving = detail - detail.mean(axis=0)[None]             # minus whatever is identical in every frame

    # 2. window + mask
    if args.band:
        r0, r1 = args.band
        _, _, valid, cols = find_window(flat, motion)
    else:
        r0, r1, valid, cols = find_window(flat, motion)
    mask = np.zeros((H, W), bool)
    mask[r0:r1] = valid[r0:r1]
    mask[:, ~cols] = False
    c_idx = np.where(cols)[0]
    c0, c1 = int(c_idx.min()), int(c_idx.max()) + 1
    print("window rows %d-%d (%d px), paper columns %d-%d, %.0f%% of the window usable"
          % (r0, r1, r1 - r0, c0, c1, 100 * mask[r0:r1, c0:c1].mean()))

    # 3. registration on ink only (1 - norm), inside the window
    ink = moving[:, r0:r1, c0:c1]
    M = mask[r0:r1, c0:c1]
    # The motor moves the paper the same distance at every stop, so:
    #  pass 1 - search everything except "no move" (|d| < 6 px, which static
    #           patterns and blank paper would otherwise win) and take the median
    #           of the confident matches as the step;
    #  pass 2 - search only near that step; keep confident matches, else the step.
    wide = [d for d in range(-args.max_shift, args.max_shift + 1) if abs(d) >= 6]
    first = [shift_ncc(ink[i], ink[i + 1], M, M, wide) for i in range(n - 1)]
    good = [d for d, p, s in first if d is not None and p >= args.min_conf and p - s > 0.05]
    if len(good) < 2:
        raise SystemExit("no confident shifts - is there text in the window? try --min-conf 0.2")
    step = float(np.median(good))
    # paper can move LESS than the motor step (slip, or a leading edge being pushed
    # before the next rollers grab it), rarely more: search 6 px .. 1.25 x step
    sgn = 1 if step > 0 else -1
    near = [sgn * d for d in range(6, int(abs(step) * 1.25) + 3)]
    # each frame is matched against BOTH previous frames; a false match (e.g. the
    # second copy of a repeated line) rarely agrees with both
    shifts, confs, used = [], [], []
    off_run = [0.0]
    for i in range(1, n):
        prev1 = ncc_curve(ink[i - 1], ink[i], M, M, near)
        total = dict(prev1)
        if i >= 2 and prev1:
            gap = int(round(off_run[i - 1] - off_run[i - 2]))
            prev2 = ncc_curve(ink[i - 2], ink[i], M, M, [d + gap for d in prev1])
            total = {d: (v + prev2[d + gap]) / 2 if (d + gap) in prev2 else v for d, v in prev1.items()}
        if total:
            best = max(total, key=total.get)
            p = total[best]
            s = max((v for k, v in total.items() if abs(k - best) > 3), default=0.0)
            d = subpixel(prev1, best)
        else:
            d, p, s = None, 0.0, 0.0
        u = d if d is not None and p >= args.min_conf and p - s > 0.03 else step
        shifts.append(d); confs.append((p, s)); used.append(u)
        off_run.append(off_run[-1] + u)
    typical = step
    n_meas = sum(1 for d, u in zip(shifts, used) if d is not None and d == u)
    print("step %.1f px per stop (%.1f px/mm if the stop is 2.55 mm); %d/%d pairs measured, rest = step"
          % (step, abs(step) / 2.551, n_meas, n - 1))

    # offsets: frame i row r -> canvas row r - off[i]
    off = np.concatenate([[0.0], np.cumsum(used)])
    off_i = np.round(off).astype(int)

    # 4. blend
    top = min(r0 - o for o in off_i)
    bottom = max(r1 - o for o in off_i)
    Hc, Wc = bottom - top, c1 - c0
    acc = np.zeros((Hc, Wc), np.float64)
    wsum = np.zeros((Hc, Wc), np.float64)
    # sharp weighting: the frame that saw a line nearest the middle of the window
    # dominates, so a disagreeing frame (curled paper end) leaves only a faint ghost
    taper = np.hanning(r1 - r0 + 2)[1:-1][:, None] ** args.sharpness
    wband = (M * taper).astype(np.float64)
    win = norm[:, r0:r1, c0:c1]
    level = np.array([np.percentile(win[i][M], 75) for i in range(n)])   # each frame's paper brightness
    for i in range(n):
        y = r0 - off_i[i] - top
        acc[y:y + (r1 - r0)] += win[i] / max(level[i], 1e-3) * wband
        wsum[y:y + (r1 - r0)] += wband
    out = np.where(wsum > 0, acc / np.maximum(wsum, 1e-9), 1.0)
    # trim canvas rows that no frame covered well
    covered = (wsum > 0.05).mean(axis=1) > 0.5
    rows = np.where(covered)[0]
    out = out[rows.min():rows.max() + 1]

    if args.enhance:
        lo, hi = np.percentile(out, [1, 60])
        out = np.clip((out - lo) / max(hi - lo, 1e-6), 0, 1)
        img = (255 * out).astype(np.uint8)
    else:
        img = np.clip(out * 235, 0, 255).astype(np.uint8)
    Image.fromarray(img).save(folder / "stitched.png")

    # debug view: median frame with the mask tinted and the window outlined
    med = np.median(frames, axis=0).astype(np.uint8)
    dbg = np.stack([med] * 3, axis=-1).astype(np.float32)
    dbg[mask] = dbg[mask] * 0.5 + np.array([0, 160, 0]) * 0.5
    dbg[[r0, r1 - 1], :] = [255, 0, 0]
    Image.fromarray(dbg.astype(np.uint8)).save(folder / "stitch_debug.png")

    json.dump({"window_rows": [int(r0), int(r1)], "paper_cols": [c0, c1],
               "typical_shift_px": typical,
               "frames": [{"file": f.name, "offset_px": float(o)} for f, o in zip(files, off)],
               "pairs": [{"measured": (None if d is None else round(d, 2)), "ncc": round(p, 3),
                          "second": round(s, 3), "used": round(u, 2)}
                         for d, (p, s), u in zip(shifts, confs, used)]},
              open(folder / "stitch.json", "w"), indent=1)
    print("saved %s (%d x %d px), stitch_debug.png, stitch.json" % (folder / "stitched.png", img.shape[1], img.shape[0]))


if __name__ == "__main__":
    main()
