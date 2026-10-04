// =====================================================================
//  Drive detail: how ONE driven roller is mounted and belted to the motor
// =====================================================================
//  A visual explainer, not a part file. The dimensions match the
//  feed_rig.scad defaults. Drag `explode` (0 = assembled, 1 = exploded).
//
//  Stack along the shaft, from plate B (left) to the pulley (right):
//    plate B + 608 bearing | hub washer | ROLLER (set screws) | hub washer |
//    plate A + 608 bearing | shim washer | GT2 pulley, HUB TOWARD THE PLATE (set screws)
//
//  How it holds together:
//   * The 608 bearings are pressed into the plates. The shaft spins in them.
//   * The roller is locked to the shaft with 2 set screws, so roller and shaft turn together.
//   * The hub washers sit between the roller ends and the bearing INNER races.
//     That traps the shaft axially: it can't slide left or right.
//   * The pulley is locked to the shaft end (outside plate A) with 2 set screws.
//     All three pulleys face hub-in (hub toward the plate): the 17HS15-1704S has
//     a 20 mm D-shaft, and only this way does the motor pulley's hub sit fully on it.
//     The shim washer keeps it from rubbing the bearing's outer race.
//   * The motor bolts to the INSIDE face of plate A. Its shaft pokes through the
//     plate, and its pulley sits in the same plane as the roller pulley.
//   * The belt wraps both pulleys. Slide the motor along its slots to tension it.
//   (In the real rig, the same belt also wraps the 2nd driven shaft; omitted here.)
//
//  Axes here: X = shaft axis (plate A / pulley side at +X), Z = up.
// =====================================================================

explode     = 0.6;   // [0:0.05:1]
show_labels = true;
show_motor  = true;
plate_alpha = 0.55;  // [0.2:0.05:1]

$fn = 64;
// default view: from the pulley side, above
$vpt = [20, -10, -25]; $vpr = [65, 0, 35]; $vpd = 380;

// ---- dimensions (feed_rig.scad defaults) ----
plate_gap   = 95;     // inner face to inner face
plate_t     = 6;
roller_len  = 82;
roller_d    = 22;
groove_z    = [-25.5, -8.5, 8.5, 25.5];
shaft_d     = 8;
shaft_x     = [-55.5, 73.5];   // 129 mm rod
b_od = 22; b_id = 8; b_w = 7;  // 608
washer_t    = 6;
pulley_x0   = 55.5;            // inner face of the pulley
motor_off   = [-36.4, -67];    // motor axis relative to this shaft, in (Y, Z)
pd          = 20*2/PI;         // GT2 20T pitch diameter

xa = plate_gap/2;              // inner face of plate A (+X)

// explode offsets along the shaft
function ex(k) = explode*k;

module along_x(x0, len) translate([x0, 0, 0]) rotate([0, 90, 0]) children();

// ---- parts ----
module bearing_608() {      // local: axis along X, x in [0, b_w]
    color("Silver") along_x(0) difference() { cylinder(d = b_od, h = b_w); translate([0,0,-1]) cylinder(d = 19, h = b_w + 2); }
    color("Gainsboro") along_x(0.5) difference() { cylinder(d = 19, h = b_w - 1); translate([0,0,-1]) cylinder(d = 12, h = b_w + 2); }
    color("Silver") along_x(0) difference() { cylinder(d = 12, h = b_w); translate([0,0,-1]) cylinder(d = b_id, h = b_w + 2); }
}

module washer(t, od = 12) color("Tan") along_x(0) difference() { cylinder(d = od, h = t); translate([0,0,-1]) cylinder(d = shaft_d + 0.4, h = t + 2); }

module set_screw(len = 4) color("Red") cylinder(d = 3, h = len, $fn = 16);

module driven_roller() {    // local: x in [-roller_len/2, roller_len/2]
    color("DimGray") along_x(-roller_len/2) difference() {
        cylinder(d = roller_d, h = roller_len);
        translate([0,0,-1]) cylinder(d = shaft_d + 0.25, h = roller_len + 2);
        for (g = groove_z) translate([0, 0, roller_len/2 + g - 1.1])
            difference() { cylinder(d = roller_d + 1, h = 2.2); translate([0,0,-1]) cylinder(d = roller_d - 2.8, h = 4.2); }
    }
    color("Black") for (g = groove_z) translate([g, 0, 0]) rotate([0, 90, 0])
        rotate_extrude($fn = 48) translate([(roller_d - 2.8)/2 + 1, 0]) circle(d = 2, $fn = 16);
    for (x = [-roller_len/2 + 4, roller_len/2 - 4])
        translate([x, 0, roller_d/2 - 3 + ex(10)]) set_screw(3);
}

module gt2_teeth_2d() difference() {
    circle(d = pd - 0.5);
    for (i = [0 : 19]) rotate(i*18) translate([(pd - 0.5)/2, 0]) circle(d = 1.1, $fn = 12);
}

// local: x in [0, 16]; flange | teeth | flange | hub. Belt runs at x = 1..8.
module gt2_pulley(bore = 8) translate([16, 0, 0]) mirror([1, 0, 0]) gt2_pulley_hub_out(bore);   // hub toward the plate
module gt2_pulley_hub_out(bore = 8) {
    color("LightSteelBlue") {
        along_x(0)  difference() { cylinder(d = 16, h = 1); translate([0,0,-1]) cylinder(d = bore, h = 3); }
        along_x(1)  linear_extrude(7) difference() { gt2_teeth_2d(); circle(d = bore); }
        along_x(8)  difference() { cylinder(d = 16, h = 1); translate([0,0,-1]) cylinder(d = bore, h = 3); }
        along_x(9)  difference() { cylinder(d = 13, h = 7); translate([0,0,-1]) cylinder(d = bore, h = 9); }
    }
    for (a = [0, 90]) rotate([a, 0, 0]) translate([12.5, 0, 6.5 - 3 + ex(8)]) set_screw();
}

module belt(x0) {           // in the plane x0..x0+6, around both pitch circles
    pts = [[0, 0], motor_off];
    color("#111") translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(6)
        difference() {
            offset(r = 1.4) hull() for (p = pts) translate(p) circle(d = pd);
            hull() for (p = pts) translate(p) circle(d = pd);
        }
}

module plate_piece(y0, z0, w, h, holes) {   // inner face at x = 0, extends +X by plate_t
    color("BurlyWood", plate_alpha) translate([0, 0, 0]) rotate([90, 0, 90])
        linear_extrude(plate_t) difference() {
            translate([y0, z0]) square([w, h]);
            for (c = holes) translate([c[0], c[1]]) circle(d = c[2]);
        }
}

module nema17() {           // flange face at x = 0, body extends -X
    color("#2b2b2b") translate([-40, motor_off[0] - 21, motor_off[1] - 21]) cube([40, 42, 42]);
    color("Silver") translate([-0.01, motor_off[0], motor_off[1]]) rotate([0, 90, 0]) cylinder(d = 22, h = 2);
    color("Silver") translate([0, motor_off[0], motor_off[1]]) rotate([0, 90, 0]) cylinder(d = 5, h = 20);   // 20 mm D-shaft
}

module label(txt, pos, size = 3.2) {
    if (show_labels) color("Black") translate(pos) rotate([90, 0, 0])
        linear_extrude(0.3) text(txt, size = size, halign = "center", valign = "bottom");
}

// ---- assembled positions (+ explode offsets) ----
plateA_dx  = ex(30);
bearA_dx   = ex(42);
shim_dx    = ex(58);
pulley_dx  = ex(72);
washA_dx   = ex(18);

// shaft
color("Silver") along_x(shaft_x[0]) cylinder(d = shaft_d, h = shaft_x[1] - shaft_x[0]);
label("8 mm shaft (129 mm)", [shaft_x[0] + 14, 0, 5], 2.6);

// roller
driven_roller();
label("driven roller", [0, 0, 16]);
label("2 set screws lock it to the shaft", [0, 0, 21], 2.6);

// plate B side (-X)
translate([-xa - plate_t - ex(30), 0, 0])
    plate_piece(-22, -22, 44, 44, [[0, 0, b_od]]);
translate([-xa - plate_t - 1 - ex(42), 0, 0]) bearing_608();
translate([-xa - ex(18), 0, 0]) washer(washer_t);
label("plate B", [-xa - ex(30), 0, 25]);
label("608 bearing", [-xa - 4 - ex(42), 0, -18], 2.6);
label("hub washer", [-xa + 3 - ex(18), 0, -14], 2.6);

// plate A side (+X)
translate([xa - washer_t + washA_dx, 0, 0]) washer(washer_t);
translate([xa + plateA_dx, 0, 0])
    plate_piece(-64, -95, 86, 118,
        [[0, 0, b_od], [motor_off[0], motor_off[1], 23],
         for (sy = [-1, 1], sz = [-1, 1]) [motor_off[0] + sy*15.5, motor_off[1] + sz*15.5, 3.4]]);
translate([xa + bearA_dx, 0, 0]) bearing_608();
translate([xa + plate_t + 1 + shim_dx, 0, 0]) washer(1);
translate([pulley_x0 + pulley_dx, 0, 0]) gt2_pulley(8);
label("hub washer", [xa - 3 + washA_dx, 0, -14], 2.6);
label("plate A", [xa + 3 + plateA_dx, 0, 33]);
label("608 bearing (pressed into plate)", [xa + 4 + bearA_dx, 0, 14 + explode*6], 2.6);
label("shim", [xa + plate_t + 1.5 + shim_dx, 0, 9 + explode*6], 2.6);
label("GT2 20T pulley, 8 mm bore, hub toward plate", [pulley_x0 + 8 + pulley_dx, 0, 20 + explode*8], 2.6);

// motor + its pulley + belt
if (show_motor) {
    translate([xa + plateA_dx, 0, 0]) nema17();
    translate([pulley_x0 + pulley_dx, motor_off[0], motor_off[1]]) gt2_pulley(5);
    label("NEMA17, bolted to the INSIDE of plate A", [xa - 45 + plateA_dx, motor_off[0], motor_off[1] + 24], 2.8);
    label("motor pulley, 5 mm bore, hub toward plate (20 mm shaft)", [pulley_x0 + 8 + pulley_dx, motor_off[0], motor_off[1] - 16], 2.6);
}
belt(pulley_x0 + 8.5 + pulley_dx);   // on the teeth, now the outer part of each pulley
label("GT2 belt, 6 mm", [pulley_x0 + 4 + pulley_dx, motor_off[0]/2 - 8, motor_off[1]/2]);
