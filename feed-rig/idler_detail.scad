// =====================================================================
//  Idler detail: why the idler ROD never turns
// =====================================================================
//  A visual explainer, not a part file. Dimensions match feed_rig.scad.
//
//  COLOR CODE
//    ORANGE = spins with the paper: roller shell + bearing OUTER rings
//    GRAY   = never spins: rod, bearing INNER rings, washers, arms, plates
//    (red stripes mark rotation: the roller stripe moves with `spin`,
//     the stripe on the rod end never does)
//
//  HOW IT WORKS
//   * The rod is clamped in the two arms by set screws, so it can't rotate.
//   * A 608 bearing is pressed into each end of the idler roller.
//     The bearing's inner ring sits on the rod (still); its outer ring is
//     in the roller (spins). The balls between them let the roller spin
//     freely around the still rod.
//   * The roller bore is 10 mm, so the roller only touches the bearings,
//     never the rod.
//   * The arms pivot on M3 bolts. Springs pull the arm tails outward,
//     which presses the idler against the driven roller (the nip).
//     When thick paper comes through, the whole idler (rod + roller)
//     swings away, sliding along the arc slots in the plates.
//
//  Sliders: spin (roller rotation), open (arm swing), explode.
//  Animate (View > Animate, FPS 10, Steps 60): spin follows $t.
//  Axes: X = rod axis, Y = across the paper (driven roller at -Y), Z = up.
// =====================================================================

spin        = 0;     // [0:5:360] roller rotation, degrees
open        = 0;     // [0:0.05:1] 0 = rollers touching, 1 = fully open (4 mm)
explode     = 0;     // [0:0.05:1]
cutaway     = true;  // cut a window in the roller to show the bearings
show_labels = true;
show_driven = true;  // the driven roller + paper opposite the idler
plate_alpha = 0.45;  // [0.2:0.05:1]

$fn = 64;
$vpt = [0, 0, 8]; $vpr = [62, 0, 205]; $vpd = 330;   // viewed from the idler side (+Y)

// ---- dimensions (feed_rig.scad defaults) ----
plate_gap  = 95;
plate_t    = 6;
roller_len = 82;
idler_d    = 28;
bore       = 10;
rod_d      = 8;
rod_len    = 123;
b_od = 22; b_id = 8; b_w = 7;     // 608
washer_t   = 6;
arm_t      = 5;
arm_w      = 10;
a_piv      = 22;      // pivot -> rod
a_tail     = 18;      // pivot -> spring hole
travel     = 4;
overtravel = 1;
Rd         = 11.6;    // driven roller effective radius
Ri         = idler_d/2;
anchors    = [18, 26, 34, 42];
spring_anchor = 1;    // which anchor hole (index) the spring uses

xa  = plate_gap/2;
th_max = asin(travel/a_piv);
th_min = -asin(overtravel/a_piv);
th  = open*th_max;
spin_a = spin + 360*$t;
pivot = [0, a_piv];   // (y, z), pivot above the rod
function ex(k) = explode*k;

C_SPIN   = "DarkOrange";
C_STATIC = "Silver";

// ---- helpers ----
module along_x(x0) translate([x0, 0, 0]) rotate([0, 90, 0]) children();
module yz_extrude(h) rotate([90, 0, 90]) linear_extrude(h) children();   // 2D (y,z) -> extrude +X
module about_pivot(a) translate([0, 0, a_piv]) rotate([a, 0, 0]) translate([0, 0, -a_piv]) children();

module label(txt, pos, size = 3) {
    if (show_labels) color("Black") translate(pos) rotate([90, 0, 180])   // reads from +Y
        linear_extrude(0.3) text(txt, size = size, halign = "center", valign = "bottom");
}

// ---- parts (local: rod axis along X through the origin) ----
module bearing_608() {   // x in [0, b_w]
    color(C_SPIN)   along_x(0)   difference() { cylinder(d = b_od, h = b_w); translate([0,0,-1]) cylinder(d = 19, h = b_w + 2); }
    color("DimGray") along_x(0.6) difference() { cylinder(d = 19, h = b_w - 1.2); translate([0,0,-1]) cylinder(d = 12, h = b_w + 2); }
    color(C_STATIC) along_x(0)   difference() { cylinder(d = 12, h = b_w); translate([0,0,-1]) cylinder(d = b_id, h = b_w + 2); }
}

module idler_shell() {   // x in [-L/2, L/2], spins
    color(C_SPIN) rotate([spin_a, 0, 0]) difference() {
        along_x(-roller_len/2) difference() {
            cylinder(d = idler_d, h = roller_len);
            translate([0, 0, -1]) cylinder(d = bore, h = roller_len + 2);
            for (z = [-1, roller_len - b_w]) translate([0, 0, z]) cylinder(d = b_od, h = b_w + 1);
        }
        if (cutaway)   // open the top-front quarter
            translate([-roller_len/2 - 1, 0, 0]) cube([roller_len + 2, idler_d, idler_d]);
    }
    color("Red") rotate([spin_a, 0, 0])   // rotation marker
        rotate([-35, 0, 0]) translate([-roller_len/2 + 10, Ri - 0.3, -1]) cube([roller_len - 20, 0.8, 2]);
}

module rod() {
    color(C_STATIC) along_x(-rod_len/2) cylinder(d = rod_d, h = rod_len);
    color("Red") for (s = [-1, 1])   // fixed marker on each rod end: never moves
        translate([s*rod_len/2 + (s > 0 ? 0 : -0.4), -0.6, 0]) cube([0.4, 1.2, rod_d/2 - 0.5]);
}

module washer(t) color(C_STATIC) along_x(0) difference() { cylinder(d = 12, h = t); translate([0,0,-1]) cylinder(d = rod_d + 0.4, h = t + 2); }

module arm_2d() difference() {
    hull() {
        circle(d = rod_d + 8);
        translate(pivot) circle(d = arm_w);
        translate([0, a_piv + a_tail]) circle(d = arm_w - 2);
    }
    circle(d = rod_d + 0.1);
    translate(pivot) circle(d = 3.3);
    translate([0, a_piv + a_tail]) circle(d = 3);
}
module arm() {
    color("Goldenrod") yz_extrude(arm_t) arm_2d();
    color("Red") translate([arm_t/2, 0, rod_d/2 + 0.5]) cylinder(d = 3, h = 5, $fn = 16);   // set screw clamps the rod
}

module slot_2d() {   // arc slot the rod end passes through
    steps = 8;
    for (k = [0 : steps - 1]) hull() for (j = [k, k + 1])
        let(a = th_min + (th_max - th_min)*j/steps)
        translate(pivot + a_piv*[sin(a), -cos(a)]) circle(d = rod_d + 1);
}
module plate_piece() {
    color("BurlyWood", plate_alpha) yz_extrude(plate_t) difference() {
        translate([-40, -18]) square([90, 70]);
        slot_2d();
        translate(pivot) circle(d = 3.4);
        for (a = anchors) translate([a, a_piv + a_tail]) circle(d = 3.4);
        translate([-(Rd + Ri), 0]) circle(d = b_od);   // driven-shaft bearing hole
    }
}

// Extension spring between two 3D points: a coil with a hook loop at each end.
// The loops sit exactly on p0 and p1 (the arm's tail hole and the anchor screw).
module coil_spring(p0, p1, d = 5, wire = 0.8, turns = 10, hook = 4.5) {
    v = p1 - p0;
    L = norm(v);
    body = max(L - 2*hook, 1);
    seg = 10;
    n = turns*seg;
    translate(p0) rotate([0, acos(v[2]/L), atan2(v[1], v[0])]) {
        for (i = [0 : n - 1]) hull()
            for (j = [i, i + 1])
                translate([d/2*cos(360*j/seg), d/2*sin(360*j/seg), hook + body*j/n]) sphere(d = wire, $fn = 8);
        for (z = [1.6, L - 1.6])   // hook loops
            translate([0, 0, z]) rotate([90, 0, 0])
                rotate_extrude($fn = 16) translate([1.6, 0]) circle(d = wire, $fn = 8);
        for (leg = [[[0, 0, 3.2], [d/2, 0, hook]], [[d/2, 0, hook + body], [0, 0, L - 3.2]]])
            hull() for (p = leg) translate(p) sphere(d = wire, $fn = 8);
    }
}

// ---------------------------------------------------------------------
//  Scene
// ---------------------------------------------------------------------
// plates (fixed)
for (s = [-1, 1]) translate([s > 0 ? xa + ex(25) : -xa - plate_t - ex(25), 0, 0]) plate_piece();

// pivot bolts (fixed)
color("DimGray") for (s = [-1, 1])
    translate([s*(xa + plate_t/2), 0, a_piv]) rotate([0, 90, 0]) cylinder(d = 3, h = plate_t + arm_t + 6, center = true);

// everything that swings with the arms
about_pivot(th) {
    rod();
    idler_shell();
    for (s = [-1, 1]) {
        translate([s > 0 ? roller_len/2 - b_w + ex(12) : -roller_len/2 - ex(12), 0, 0]) bearing_608();
        translate([s > 0 ? xa - washer_t + ex(20) : -xa - ex(20), 0, 0]) washer(washer_t);
        translate([s > 0 ? xa + plate_t + 0.5 + ex(40) : -xa - plate_t - 0.5 - arm_t - ex(40), 0, 0]) arm();
    }
}

// springs: arm tail (swings) -> fixed anchor screw
tail_yz = let(a = th) pivot + a_tail*[-sin(a), cos(a)];
anchor_yz = [anchors[spring_anchor], a_piv + a_tail];
for (s = [-1, 1]) {
    xs = s*(xa + plate_t + 0.5 + arm_t/2 + ex(40));
    color("Teal") coil_spring([xs, tail_yz[0], tail_yz[1]], [xs, anchor_yz[0], anchor_yz[1]]);
    // M3 anchor screw sticking out of the plate; the spring hooks over it
    color("DimGray") translate([s*(xa + plate_t/2 + ex(25)), anchor_yz[0], anchor_yz[1]]) rotate([0, 90, 0]) {
        cylinder(d = 3, h = plate_t + 2*(arm_t + 3), center = true, $fn = 16);
        translate([0, 0, s*(plate_t/2 + arm_t + 3)]) cylinder(d = 5.5, h = 3, center = true, $fn = 16);
    }
}

// driven roller + paper, for context
if (show_driven) {
    color("DimGray", 0.5) translate([0, -(Rd + Ri), 0]) along_x(-roller_len/2) cylinder(d = 2*Rd, h = roller_len);
    color("White", 0.35) translate([-40, -Ri - 0.05, -35]) cube([80, 0.1, 70]);
}

// ---- labels ----
label("ROD: clamped in the arms, never turns", [0, 20, -24], 3.2);
label("idler roller shell SPINS on 2 bearings", [0, 20, Ri + 8], 3.2);
label("608 inside roller", [-roller_len/2 + 6 - ex(12), 15, -18], 2.6);
label("608 inside roller", [roller_len/2 - 6 + ex(12), 15, -18], 2.6);
label("arm (pivots on M3 bolt)", [xa + plate_t + 3 + ex(40), 5, a_piv + a_tail + 6], 2.6);
label("set screw locks rod", [xa + plate_t + 3 + ex(40), 5, -14], 2.4);
label("extension spring -> anchor screw", [xa + plate_t + 3 + ex(40), anchors[spring_anchor]/2, a_piv + a_tail + 5], 2.4);
label("plate A: arc slot, no bearing", [xa + 3 + ex(25), 52, -14], 2.6);
if (show_driven) label("driven roller (motor side)", [0, -(Rd + Ri), Rd + 4], 2.8);
