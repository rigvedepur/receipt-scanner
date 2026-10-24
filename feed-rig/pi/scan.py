#!/usr/bin/env python3
"""scan.py - one command: feed a receipt AND record lossless camera frames.

Runs on the Raspberry Pi 4. The Pico (running feed_controller.py as main.py)
is plugged into the Pi's USB and drives the stepper; the Pi drives the camera.

    python3 scan.py              # feed 150 mm at the Pico's default speed
    python3 scan.py 200 -s 30    # feed 200 mm at 30 mm/s
    python3 scan.py 150 --color  # keep colour (3x the memory and disk)
    python3 scan.py 200 -s 30 --stop-go      # stop-and-go: 2.5 mm moves, a still frame at each stop
    python3 scan.py 200 --stop-go 4 --per-stop 3   # 4 mm moves, 3 still frames per stop

Stop-and-go removes motion blur completely: the Pico feeds a short distance,
the paper settles, and only frames whose exposure STARTED after the paper
stopped are kept (the camera's own exposure-start timestamp decides that).

Sequence: start camera -> lock exposure -> start recording -> send "feed" to the
Pico -> wait for its "done" -> record a little longer -> stop -> write frames.

Output: ~/scans/<date-time>/frames/000000.png ... plus scan.json with every
frame's timestamps and the feed start/done times (same clock), for stitching.

Frames are held in RAM while the paper moves (writing PNGs is too slow to keep
up with 42 fps) and saved afterwards. Default is the lossless Y (brightness)
plane: 1.26 MB per frame, about 250 frames for a 150 mm feed.

Needs: picamera2 (preinstalled on Raspberry Pi OS), pyserial
(sudo apt install python3-serial), Pillow (python3-pil, usually preinstalled).
"""
import argparse
import json
import math
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

WIDTH, HEIGHT, FPS = 1296, 972, 42          # OV5647 binned mode
PRE_ROLL_S = 0.4                             # record before the paper moves
POST_ROLL_S = 0.4                            # and after the Pico reports done


def now_ns():
    return time.monotonic_ns()


def boot_ns():
    """Clock used by the camera's SensorTimestamp (time since boot)."""
    try:
        return time.clock_gettime_ns(time.CLOCK_BOOTTIME)
    except AttributeError:          # not Linux
        return time.monotonic_ns()


# ------------------------------------------------------------------ Pico link
class Pico:
    def __init__(self, port):
        import serial
        self.ser = serial.Serial(port, 115200, timeout=0.1)
        time.sleep(0.2)
        self.ser.reset_input_buffer()

    def send(self, line):
        self.ser.write((line.strip() + "\n").encode())

    def read_line(self):
        raw = self.ser.readline()
        return raw.decode(errors="replace").strip() if raw else None

    def check(self):
        """Make sure feed_controller (not the bare MicroPython prompt) is answering."""
        self.send("status")
        t0 = time.time()
        while time.time() - t0 < 2:
            line = self.read_line()
            if line and line.startswith("microsteps"):
                return line
            if line and (">>>" in line or "Traceback" in line):
                break
        sys.exit("Pico isn't running feed_controller. Save it on the Pico as main.py, "
                 "replug it, and close Thonny (it holds the port).")

    def feed(self, mm, speed=None, timeout_s=None):
        """Send one feed command and wait for the Pico's reply. Returns (reply, mm_done)."""
        cmd = "feed %g" % mm + (" %g" % speed if speed else "")
        self.send(cmd)
        t0 = time.time()
        limit = timeout_s or abs(mm) / (speed or 10) * 2 + 5
        while time.time() - t0 < limit:
            line = self.read_line()
            if line and (line.startswith("done") or line.startswith("err")):
                try:
                    return line, float(line.split()[2])
                except (IndexError, ValueError):
                    return line, 0.0
        self.send("stop")
        return "timeout - sent stop", 0.0

    def close(self):
        self.ser.close()


# ------------------------------------------------------------------ camera
class Recorder:
    def __init__(self, color, exposure_us, gain):
        from picamera2 import Picamera2
        self.color = color
        self.cam = Picamera2()
        fmt = "RGB888" if color else "YUV420"
        frame_us = int(1e6 / FPS)
        common = dict(main={"size": (WIDTH, HEIGHT), "format": fmt},
                      controls={"FrameDurationLimits": (frame_us, frame_us)},
                      buffer_count=6)
        try:    # newer picamera2: pick the sensor mode directly
            cfg = self.cam.create_video_configuration(sensor={"output_size": (WIDTH, HEIGHT)}, **common)
        except TypeError:   # older picamera2: ask for a raw stream of that size
            cfg = self.cam.create_video_configuration(raw={"size": (WIDTH, HEIGHT)}, **common)
        self.cam.configure(cfg)
        self.cam.start()
        time.sleep(1.5)                                  # let exposure settle
        md = self.cam.capture_metadata()
        exp = exposure_us or md["ExposureTime"]
        gn = gain or md["AnalogueGain"]
        lock = {"AeEnable": False, "ExposureTime": int(exp), "AnalogueGain": float(gn)}
        if color:
            lock["AwbEnable"] = False
        self.cam.set_controls(lock)                      # same brightness on every frame
        time.sleep(0.3)
        self.exposure_us, self.gain = int(exp), float(gn)
        self.frames, self.meta = [], []
        self._stop = threading.Event()
        self._thread = None

    def _frame_from(self, req):
        arr = req.make_array("main")
        md = req.get_metadata()
        if self.color:
            frame = arr[:HEIGHT, :WIDTH, ::-1].copy()       # BGR -> RGB
        else:
            frame = arr[:HEIGHT, :WIDTH].copy()             # Y plane of YUV420
        meta = {"recv_ns": now_ns(), "sensor_ns": md.get("SensorTimestamp"),
                "exposure_us": md.get("ExposureTime"), "gain": md.get("AnalogueGain")}
        return frame, meta

    def grab_after(self, t_boot_ns):
        """Return the first frame whose exposure started at or after t_boot_ns."""
        skipped = 0
        while True:
            req = self.cam.capture_request()
            try:
                frame, meta = self._frame_from(req)
            finally:
                req.release()
            ts = meta["sensor_ns"]
            if ts is None:              # no timestamp: drop two frames to be safe
                skipped += 1
                if skipped < 3:
                    continue
                return frame, meta
            if ts >= t_boot_ns:
                return frame, meta

    def start(self, max_frames):
        self.max_frames = max_frames
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def _loop(self):
        while not self._stop.is_set():
            req = self.cam.capture_request()
            try:
                arr = req.make_array("main")
                md = req.get_metadata()
            finally:
                req.release()
            if self.color:
                frame = arr[:HEIGHT, :WIDTH, ::-1].copy()   # BGR -> RGB
            else:
                frame = arr[:HEIGHT, :WIDTH].copy()         # Y plane of YUV420
            self.frames.append(frame)
            self.meta.append({"recv_ns": now_ns(),
                              "sensor_ns": md.get("SensorTimestamp"),
                              "exposure_us": md.get("ExposureTime"),
                              "gain": md.get("AnalogueGain")})
            if len(self.frames) >= self.max_frames:
                print("  frame limit reached (%d) - stopping capture early" % self.max_frames)
                break

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)
        self.cam.stop()
        self.cam.close()


def max_frames_for_ram(frame_bytes):
    """Use at most ~60% of the RAM that is free right now."""
    try:
        with open("/proc/meminfo") as f:
            avail_kb = next(int(l.split()[1]) for l in f if l.startswith("MemAvailable"))
        return max(50, int(avail_kb * 1024 * 0.6 / frame_bytes))
    except (OSError, StopIteration):
        return 600


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser(description="Feed a receipt and record lossless frames.")
    ap.add_argument("mm", nargs="?", type=float, default=150, help="feed distance (default 150)")
    ap.add_argument("-s", "--speed", type=float, help="mm/s (default: the Pico's setting)")
    ap.add_argument("--port", default="/dev/ttyACM0", help="Pico serial port")
    ap.add_argument("--out", default=str(Path.home() / "scans"), help="output folder")
    ap.add_argument("--color", action="store_true", help="save RGB instead of grayscale")
    ap.add_argument("--exposure", type=int, help="fixed exposure in us (default: auto, then locked)")
    ap.add_argument("--gain", type=float, help="fixed analogue gain (default: auto, then locked)")
    ap.add_argument("--npy", action="store_true", help="save .npy instead of .png (faster, bigger)")
    ap.add_argument("--stop-go", type=float, nargs="?", const=2.5, metavar="STEP_MM",
                    help="stop-and-go: move STEP_MM (default 2.5), stop, grab still frame(s)")
    ap.add_argument("--settle-ms", type=float, default=80, help="stop-and-go: wait after each stop (default 80)")
    ap.add_argument("--per-stop", type=int, default=1, help="stop-and-go: still frames per stop (default 1)")
    args = ap.parse_args()

    out = Path(args.out) / datetime.now().strftime("%Y%m%d-%H%M%S")
    (out / "frames").mkdir(parents=True)

    print("Pico:", end=" ")
    pico = Pico(args.port)
    status = pico.check()
    print(status)
    try:    # "microsteps 1 | 2.74 steps/mm | ..." -> exact value from the microstep count
        micro = int(status.split()[1])
        args.steps_per_mm = 200 * micro / (2 * math.pi * 11.6)
    except (IndexError, ValueError):
        args.steps_per_mm = None

    print("Camera: %dx%d @ %d fps, %s" % (WIDTH, HEIGHT, FPS, "color" if args.color else "grayscale"))
    rec = Recorder(args.color, args.exposure, args.gain)
    print("  exposure locked at %d us, gain %.2f" % (rec.exposure_us, rec.gain))
    frame_bytes = WIDTH * HEIGHT * (3 if args.color else 1)
    limit = max_frames_for_ram(frame_bytes)

    events = {}
    reply = None
    cmd = "feed %g" % args.mm + (" %g" % args.speed if args.speed else "")
    stops = []
    if args.stop_go:
        cmd = "stop-go %g mm in %g mm steps" % (args.mm, args.stop_go) + (" at %g mm/s" % args.speed if args.speed else "")
        try:
            run_stop_go(args, pico, rec, events, stops)
            reply = "stop-go done %.1f mm" % (stops[-1]["pos_mm"] if stops else 0)
        finally:
            rec.cam.stop()
            rec.cam.close()
            pico.close()
    else:
        reply = run_continuous(args, cmd, pico, rec, events, limit)

    n = len(rec.frames)
    secs = (rec.meta[-1]["recv_ns"] - rec.meta[0]["recv_ns"]) / 1e9 if n > 1 else 0
    print("Captured %d frames in %.1f s" % (n, secs))
    save(args, out, rec, cmd, reply, events, stops)


def run_stop_go(args, pico, rec, events, stops):
    """Move, stop, settle, keep only frames exposed after the stop. Repeat."""
    step = math.copysign(args.stop_go, args.mm)
    n_moves = int(math.ceil(abs(args.mm) / args.stop_go - 1e-9))
    settle_ns = int(args.settle_ms * 1e6)
    pos = 0.0
    events["start_ns"] = now_ns()
    print("Stop-and-go: %d moves of %.1f mm, %d frame(s) per stop, settle %d ms"
          % (n_moves, abs(step), args.per_stop, args.settle_ms))
    spm = args.steps_per_mm

    def actual(mm):
        """The distance the Pico really moves: a whole number of motor steps."""
        return round(abs(mm) * spm) / spm * (1 if mm >= 0 else -1) if spm else mm

    for i in range(n_moves + 1):
        t_still = boot_ns() + settle_ns             # paper has stopped; allow it to settle
        for k in range(args.per_stop):
            frame, meta = rec.grab_after(t_still)
            meta.update(stop=i, pos_mm=round(pos, 3))
            rec.frames.append(frame)
            rec.meta.append(meta)
            t_still = meta["sensor_ns"] + 1 if meta["sensor_ns"] else t_still
        stops.append({"stop": i, "pos_mm": round(pos, 3), "t_ns": now_ns()})
        if i == n_moves:
            break
        d = step if i < n_moves - 1 else args.mm - pos      # last move: whatever is left
        if d * args.mm <= 0 or abs(actual(d)) < 1e-9:         # never reverse, never a zero move
            break
        reply, done = pico.feed(d, args.speed)
        if not reply.startswith("done"):
            print("  Pico:", reply, "- stopping")
            break
        pos += actual(d)            # exact; the Pico's reply is rounded to 0.1 mm
        if i % 10 == 0:
            print("  stop %d / %d  at %.1f mm" % (i + 1, n_moves, pos))
    events["done_ns"] = now_ns()


def run_continuous(args, cmd, pico, rec, events, limit):
    """Record continuously while the Pico feeds the whole distance in one move."""
    reply = None
    timeout_s = abs(args.mm) / (args.speed or 10) * 2 + 15
    try:
        rec.start(limit)
        time.sleep(PRE_ROLL_S)
        events["feed_sent_ns"] = now_ns()
        pico.send(cmd)
        print("Sent:", cmd)
        t0 = time.time()
        while time.time() - t0 < timeout_s:
            line = pico.read_line()
            if not line:
                continue
            if line.startswith("done") or line.startswith("err"):
                events["done_ns"] = now_ns()
                reply = line
                break
        else:
            pico.send("stop")
            reply = "timeout - sent stop"
        print("Pico:", reply)
        time.sleep(POST_ROLL_S)
    finally:
        rec.stop()
        pico.close()
    return reply


def save(args, out, rec, cmd, reply, events, stops):
    n = len(rec.frames)
    print("Writing frames to", out / "frames", "...")
    t0 = time.time()
    if args.npy:
        import numpy as np
        for i, f in enumerate(rec.frames):
            np.save(out / "frames" / ("%06d.npy" % i), f)
    else:
        from PIL import Image
        for i, f in enumerate(rec.frames):
            Image.fromarray(f).save(out / "frames" / ("%06d.png" % i), compress_level=1)
            if i % 50 == 0:
                print("  %d / %d" % (i, n))
    print("  done in %.1f s" % (time.time() - t0))

    log = {
        "command": cmd, "pico_reply": reply,
        "width": WIDTH, "height": HEIGHT, "fps_requested": FPS,
        "color": args.color, "exposure_us": rec.exposure_us, "gain": rec.gain,
        "clock": "time.monotonic_ns (recv_ns, events); sensor_ns = camera SensorTimestamp",
        "mode": "stop-go" if args.stop_go else "continuous",
        "stop_go_step_mm": args.stop_go, "settle_ms": args.settle_ms if args.stop_go else None,
        "per_stop": args.per_stop if args.stop_go else None,
        "events": events, "stops": stops, "frames": rec.meta,
    }
    with open(out / "scan.json", "w") as f:
        json.dump(log, f, indent=1)
    print("Saved", out)


if __name__ == "__main__":
    main()
