# feed_controller.py - Raspberry Pi Pico firmware for the receipt-scanner feed rig
# (MicroPython)
#
# - STEP pulses come from a PIO state machine: exact timing, no jitter.
# - Every move ramps up and down smoothly, so the motor doesn't stall or jerk.
# - The motor is switched off (EN high) when idle, so nothing runs warm.
# - Text commands over USB: type them in Thonny's shell now; the Raspberry Pi
#   sends the same lines over USB serial later.
#
# To start automatically on power-up, save it on the Pico as main.py.
#
# Wiring (DRV8825):
#   GP2 (pin 4) -> STEP      GP3 (pin 5) -> DIR      GP4 (pin 6) -> EN
#   RESET + SLEEP -> 3V3 (pin 36)                    GND (pin 38) -> driver GND
#   Microstepping: M0-M2 open = full step (MICROSTEPS = 1, current wiring)
#                  M2 -> 3V3, M0 + M1 -> GND = 1/16 (MICROSTEPS = 16, smoother)
#   Optional IR break-beam sensors: GP6 (pin 9) = entry, GP7 (pin 10) = exit
#
# Commands (one per line):
#   feed <mm> [mm/s]   feed a distance; negative = reverse
#   run [mm/s]         run until "stop"
#   stop               ramp down and stop (also works mid-move)
#   speed <mm/s>       default speed            (starts at 40)
#   accel <mm/s2>      acceleration             (starts at 200)
#   on | off           motor powered and holding | off and free
#   auto on|off        sensor mode: feed each receipt through automatically
#   status             settings, position, sensor states
#   help

import sys
import select
import time
import math
import rp2
from machine import Pin

# ---------------------------------------------------------------- settings
MICROSTEPS  = 1         # must match M0-M2: open = 1, M2 high only = 16
ROLLER_R_MM = 11.6      # driven roller effective radius (OpenSCAD report)
FORWARD     = 1         # DIR level that feeds paper DOWN; flip to 0 if it's backwards
START_MM_S  = 4.0       # speed the motor can jump to from standstill
MAX_MM_S    = 120.0     # refuse anything faster
IDLE_OFF    = True      # switch the motor off after each move

STEP_PIN, DIR_PIN, EN_PIN = 2, 3, 4
SENSORS     = False     # set True once the IR break-beams are wired
ENTRY_PIN, EXIT_PIN = 6, 7
BEAM_BROKEN = 0         # input level when a beam is blocked (check your sensors)
TAIL_MM     = 15.0      # keep feeding this far after the exit beam clears
MAX_FEED_MM = 400.0     # auto mode gives up after this much (jam guard)

speed_mm_s  = 40.0
accel_mm_s2 = 200.0

STEPS_PER_MM = 200 * MICROSTEPS / (2 * math.pi * ROLLER_R_MM)
SEG = max(2, MICROSTEPS * 2)      # steps per speed segment of a ramp
SM_FREQ = 1_000_000               # PIO clock: 1 tick = 1 us


# ------------------------------------------------- PIO step-pulse generator
# Takes pairs of words from Python: (pulses - 1, half-period in ticks) and
# emits that many evenly spaced pulses on STEP, then waits for the next pair.
@rp2.asm_pio(set_init=rp2.PIO.OUT_LOW, fifo_join=rp2.PIO.JOIN_TX)
def step_pio():
    pull()
    mov(x, osr)             # pulse count - 1
    pull()                  # OSR = half-period, reused for every pulse
    label("pulse")
    set(pins, 1)
    mov(y, osr)
    label("high")
    jmp(y_dec, "high")
    set(pins, 0)
    mov(y, osr)
    label("low")
    jmp(y_dec, "low")
    jmp(x_dec, "pulse")


step_pin = Pin(STEP_PIN, Pin.OUT, value=0)
dir_pin = Pin(DIR_PIN, Pin.OUT, value=FORWARD)
en_pin = Pin(EN_PIN, Pin.OUT, value=1)          # EN is active low: 1 = off
entry = Pin(ENTRY_PIN, Pin.IN, Pin.PULL_UP)
exit_ = Pin(EXIT_PIN, Pin.IN, Pin.PULL_UP)
sm = None


def start_sm():
    """(Re)start the state machine with an empty FIFO and STEP low."""
    global sm
    if sm is not None:
        sm.active(0)
        sm.exec("set(pins, 0)")
    sm = rp2.StateMachine(0, step_pio, freq=SM_FREQ, set_base=step_pin)
    sm.active(1)


start_sm()


def motor(on):
    en_pin.value(0 if on else 1)
    if on:
        time.sleep_ms(2)        # let the driver power the coils first


def blocked(pin):
    return SENSORS and pin.value() == BEAM_BROKEN


# ------------------------------------------------------- serial line input
poller = select.poll()
poller.register(sys.stdin, select.POLLIN)
_buf = ""


def read_line():
    """Return one complete input line, or None. Never blocks."""
    global _buf
    while poller.poll(0):
        c = sys.stdin.read(1)
        if c in "\r\n":
            if _buf:
                line, _buf = _buf.strip(), ""
                return line
        else:
            _buf += c
    return None


# ---------------------------------------------------------------- motion
pos_mm = 0.0


def push(n, sps):
    """Queue n pulses at sps steps/s. Waits only while the FIFO is full."""
    half = max(0, int(SM_FREQ / (2 * sps)) - 3)    # PIO overhead ~3 ticks/half
    while sm.tx_fifo() > 6:                        # 8-word FIFO, 2 words per segment
        time.sleep_ms(1)
    sm.put(n - 1)
    sm.put(half)


def move(total_steps, vmax_mm_s, until=None):
    """Ramped move. total_steps=None runs until 'stop' or until(s) is True.
    Returns the number of steps actually made."""
    a = accel_mm_s2 * STEPS_PER_MM
    v0 = START_MM_S * STEPS_PER_MM
    vmax = max(v0, min(vmax_mm_s, MAX_MM_S) * STEPS_PER_MM)
    s, v, braking = 0, v0, False
    while True:
        line = read_line()
        if line:
            if line.lower() == "stop":
                braking = True
            else:
                print('err busy - send "stop" first')
        if not braking and until is not None and until(s):
            braking = True
        if braking:                                 # ramp down from the current speed
            v = math.sqrt(max(0.0, v * v - 2 * a * SEG))
            if v < v0:
                break
            n = SEG
        else:
            if total_steps is not None and s >= total_steps:
                break
            n = SEG if total_steps is None else min(SEG, total_steps - s)
            v = min(vmax, math.sqrt(v0 * v0 + 2 * a * s))
            if total_steps is not None:             # start braking in time to stop
                v = min(v, math.sqrt(v0 * v0 + 2 * a * (total_steps - s)))
        push(n, v)
        s += n
    while sm.tx_fifo():                             # let the queued pulses finish
        time.sleep_ms(1)
    time.sleep_ms(int(1000 * SEG / max(v, v0)) + 2)
    return s


def run_move(direction, steps, mm_s, until=None):
    global pos_mm
    dir_pin.value(FORWARD if direction > 0 else 1 - FORWARD)
    time.sleep_us(5)                                # DIR setup before the first STEP
    motor(True)
    try:
        done = move(steps, mm_s, until)
    finally:
        if IDLE_OFF:
            motor(False)
    mm = done / STEPS_PER_MM
    pos_mm += mm if direction > 0 else -mm
    return mm


def auto_feed():
    """Entry beam blocked: feed until the receipt has passed the exit beam."""
    state = {"seen_exit": False, "clear_at": None}
    tail = TAIL_MM * STEPS_PER_MM
    limit = MAX_FEED_MM * STEPS_PER_MM

    def until(s):
        if blocked(exit_):
            state["seen_exit"], state["clear_at"] = True, None
        elif state["seen_exit"] and state["clear_at"] is None:
            state["clear_at"] = s
        if state["clear_at"] is not None and s - state["clear_at"] >= tail:
            return True
        return s >= limit

    print("auto: receipt in")
    mm = run_move(1, None, speed_mm_s, until)
    print("auto: done %.1f mm%s" % (mm, "" if mm < MAX_FEED_MM else " (JAM? hit the limit)"))


# ------------------------------------------------------------- commands
auto = False


def status():
    print("microsteps %d | %.2f steps/mm | speed %.0f mm/s | accel %.0f mm/s2 | pos %.1f mm"
          % (MICROSTEPS, STEPS_PER_MM, speed_mm_s, accel_mm_s2, pos_mm))
    print("motor %s | auto %s | sensors %s%s" % (
        "on" if en_pin.value() == 0 else "off", "on" if auto else "off",
        "enabled" if SENSORS else "disabled",
        (" | entry %s, exit %s" % ("blocked" if blocked(entry) else "clear",
                                   "blocked" if blocked(exit_) else "clear")) if SENSORS else ""))


def handle(line):
    global speed_mm_s, accel_mm_s2, auto
    parts = line.split()
    cmd, args = parts[0].lower(), parts[1:]
    try:
        if cmd == "feed":
            mm = float(args[0])
            mm_s = float(args[1]) if len(args) > 1 else speed_mm_s
            done = run_move(1 if mm >= 0 else -1, round(abs(mm) * STEPS_PER_MM), mm_s)
            print("done feed %.1f mm" % (done if mm >= 0 else -done))
        elif cmd == "run":
            mm_s = float(args[0]) if args else speed_mm_s
            print("running at %.0f mm/s - send stop" % mm_s)
            print("done run %.1f mm" % run_move(1, None, mm_s))
        elif cmd == "stop":
            motor(False)
            print("ok stopped")
        elif cmd == "speed":
            speed_mm_s = max(START_MM_S, min(MAX_MM_S, float(args[0])))
            print("ok speed %.0f mm/s" % speed_mm_s)
        elif cmd == "accel":
            accel_mm_s2 = max(10.0, float(args[0]))
            print("ok accel %.0f mm/s2" % accel_mm_s2)
        elif cmd in ("on", "off"):
            motor(cmd == "on")
            print("ok motor " + cmd)
        elif cmd == "auto":
            if not SENSORS:
                print("err sensors disabled - set SENSORS = True once they're wired")
            else:
                auto = args[0].lower() == "on"
                print("ok auto " + ("on" if auto else "off"))
        elif cmd == "status":
            status()
        else:
            print("commands: feed <mm> [mm/s] | run [mm/s] | stop | speed <mm/s> | "
                  "accel <mm/s2> | on | off | auto on|off | status")
    except (IndexError, ValueError):
        print("err bad arguments: " + line)


# ---------------------------------------------------------------- main loop
print("feed controller ready - type help")
status()
try:
    while True:
        line = read_line()
        if line:
            handle(line)
        if auto and blocked(entry):
            auto_feed()
        time.sleep_ms(2)
finally:
    sm.active(0)
    motor(False)                # never leave the coils powered after Ctrl+C
