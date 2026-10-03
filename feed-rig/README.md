# Feed Rig (Test 1)

This rig tests only the paper path: funnel, then two roller pairs, then a drop. There's no camera and no sensors.
It answers one question: **can the rig grab and move real household receipts without jamming?**

```
   slot / funnel (printed)
        │  throat 2 mm, 9 mm above the nip
     (D)(I)   nip 1   D = driven roller (O-rings), I = idler on a spring arm
        │  36 mm pitch (shorter than a 50 mm parking stub)
     (D)(I)   nip 2
        ▼  drop
```

## Files

| File | What it is |
|---|---|
| `feed_rig.scad` | Every part, parametric. Choose one with `part`. The console prints a design report. |
| `feed_test/feed_test.ino` | Constant-speed stepper driver controlled over serial |
| `test_log.csv` | One row per receipt fed |

## Export the parts

In the OpenSCAD GUI, open `feed_rig.scad`, open the Customizer, pick a `part`, press F6 to render, then export.
From the command line:

```bash
for p in funnel driven_roller idler_roller idler_arm spacer hub_washer width_shim; do openscad -D "part=\"$p\"" -o "$p.stl" feed_rig.scad; done
```

```bash
openscad -D 'part="side_plate_2d"' -o side_plate.svg feed_rig.scad
```

Read the ECHO report after every parameter change. It prints the belt loop length, rod lengths, O-ring sizes and steps/mm.

## What to make

| Part | Qty | How |
|---|---|---|
| side_plate | 2 | Laser-cut 6 mm plywood from the SVG (`plate_mode="laser"`), or print with `plate_mode="print"` |
| funnel | 1 | PETG, printed lying on one end cap. The top cap bridges about 30 mm; add supports if your bridging is weak. |
| driven_roller | 2 | PETG, standing up, 4+ perimeters |
| idler_roller | 2 | PETG, standing up |
| idler_arm | 4 | PETG, flat, 100% infill |
| spacer | 4 | Any material |
| hub_washer | 8 | Any material |
| width_shim | 2 | Only for 57/58 mm receipts |
| camera_mount | 1 | PETG, bar face down (the orientation it exports in), standoffs up |

The 10W diode laser cuts plywood fine. Don't try clear acrylic with it.

## Parts to buy (~$60–80)

- NEMA17 stepper + TMC2209 driver + a 12V 2A supply
- 3× GT2 20T pulleys: 2 with 8 mm bore (driven shafts), 1 with 5 mm bore (motor)
- 1× GT2 closed belt loop, 6 mm wide, length from the report (200 mm with the defaults)
- 8 mm smooth rod, cut into 2 driven shafts and 2 idler rods (lengths from the report)
- 8× 608 bearings (4 in the plates, 4 in the idler hubs)
- 8× O-rings, 2 mm cross-section, about 18 mm ID (Nitrile or silicone; a cheap assortment box is fine)
- 4× M5 threaded rod pieces + nuts (frame spacers)
- M3 screws and nuts: pivots, spring anchors, funnel (M3×10), set screws
- Small extension springs, about 20–40 mm long, or rubber bands to start
- Any Arduino or ESP32
- Raspberry Pi Camera Module 3 **Wide**, plus a Raspberry Pi 4 or 5 and a 300 mm ribbon cable
- 4× M2×6 screws (camera board) and 4× M3×10 (mount to the plates)

## Assembly

1. Press 4× 608 bearings into the round plate holes. These are the driven shafts. If they're loose, adjust `laser_kerf` or `print_hole_comp`.
2. Fit O-rings on both driven rollers, slide the rollers onto the shafts, and lock them with M3 set screws.
3. Press 608s into both ends of each idler hub. The 8 mm rod passes through the plate slots, with a hub washer on each side.
4. Bolt the arms to the pivot holes on the outside of both plates (M3 bolt, nylock nut, loose enough to swing freely). Lock the idler rod in the arms with set screws.
5. Screw the funnel between the plates (M3×10 through the plates into the end caps). Add the 4 spacers on M5 rod and square the frame.
6. Bolt the motor to the inside face of plate A. Fit the pulleys, **line up all three pulleys in the same plane**, fit the belt, and tension it by sliding the motor along its slot.
7. Hook a spring from each arm tail to an anchor hole. Anchors further out mean more stretch and more nip force.

**Check:** with the springs on and the motor unpowered, turning one driven shaft by hand should turn the other. Both idlers should spin, pressed against the driven rollers.

## Camera (added after test 1)

The Module 3 Wide sits on the driven side and looks at the paper through the gap between the two driven rollers. With the defaults, the report shows:
- Lens 55 mm from the paper, with a field 136 mm wide (covers the full 80 mm receipt).
- A strip of paper about **16 mm tall** visible between the rollers.
- At 1536×864 @120 fps: about 287 dpi, with 97% overlap between frames at 60 mm/s.
- To keep motion blur under 1 px at 60 mm/s, the exposure must be under about 1.5 ms. That's a requirement for the lighting.

- The mount's plate slots allow ±6 mm of distance adjustment (`cam_slot`). Autofocus handles the rest.
- **Check `cam_lens_top`** (lens center measured from the board's top edge) against the official Module 3 mechanical drawing before printing.
- **Ribbon:** it exits the board downward and has to bend back (−X) under the mount bar. The NEMA17 sits directly below it.
- The idlers are behind the paper, so with no paper present the camera sees the gap between the idlers. Keep that in mind when designing the lighting and background.
- To see inside: `-D show_plates=false`. `show_fov` draws the camera's field of view (yellow) and the visible strip (green).

## Running it

Flash `feed_test.ino`. Wiring: STEP → pin 2, DIR → pin 3, EN → pin 4. Set `ROLLER_R_MM` to the driven radius from the report. Then open the serial monitor at 115200 baud:

```
v 60     speed 60 mm/s
r        run
x        stop
d        reverse (to back a jam out)
```

If the paper moves upward, press `d` or swap one motor coil pair.

## Test protocol

**Receipt set (50):** save real receipts from home for a week or two, then sort them into these groups:

| Category | Count | Notes |
|---|---|---|
| flat | 15 | the baseline |
| curled | 10 | fresh off the roll; don't flatten them |
| creased | 10 | folded once or twice, in a wallet or pocket |
| crumpled | 5 | lightly crumpled and smoothed by hand, the way a user would do it |
| short | 5 | under 80 mm |
| long | 5 | over 300 mm |

**Each run:** motor running at a steady speed, insert until nip 1 grabs, let go. Log one of these results:
- `ok`: clean feed
- `skew`: fed but at an angle; estimate the angle
- `stall`: stopped in the path
- `jam`: crumpled or buckled in the path
- `no_grab`: nip 1 never took it
- `double`: pulled two receipts in at once

**Pass:** under 1 failure per 50 on flat, curled and creased receipts, and short and long receipts all feed. Crumpled receipts are for information only.

## Tuning knobs (change one at a time and log it in `config_note`)

| Symptom | Try |
|---|---|
| no_grab | More nip force (anchor hole further out). Lower `throat_h` so the throat is closer to the nip. Grippier driven surface (`tube`). |
| buckling above nip 1 | Smaller `throat_gap` (1.5). Shorter `throat_h`. Slower speed. |
| skew | Width shims for narrow paper. Check the nip force is equal on both arms. `oring_count` 5–6. |
| short receipts stall | Shorter `nip_pitch` (the report checks the rollers still fit). |
| curl catches the funnel lip | Wider `funnel_mouth`. |
| creases jam | More `idler_travel`. Softer springs with more speed. |
| slipping / uneven speed | Fine for now: the CV side will measure real paper motion. Only fix it if the paper actually stops. |

The main variables to sweep, each against feed rate: **nip force** (spring hole 1–4), **speed** (30 / 60 / 100 mm/s) and **driven surface** (O-ring or tube).
