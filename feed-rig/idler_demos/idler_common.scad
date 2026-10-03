// Shared parts library for the idler demo files (demos 1-4 `include` it).
// Opened on its own, it shows a labeled gallery of the parts below.
// Each demo sets `show_gallery = false;` after including this file, and
// OpenSCAD uses the last assignment, so the gallery doesn't appear there.
//
// COLOR CODE (the same in every demo)
//   ORANGE = SPINS     gray = NEVER TURNS     red stripe = rotation marker
//
// "cut" draws the back half only (y >= 0), so a viewer in front (-Y)
// sees inside. Round parts are built as true half-solids (rotate_extrude
// with angle = 180) rather than by subtracting a box, so every cut face
// keeps its part's color in the preview.
//
// Dimensions match feed_rig.scad defaults.

$fn = 64;

C_SPIN  = "DarkOrange";
C_STILL = "Silver";
C_WOOD  = "BurlyWood";

rod_d = 8;   rod_len = 123;
b_od = 22;   b_id = 8;   b_w = 7;              // 608 bearing
ball_d = 3.97; ball_n = 7; ball_pr = 7.6;      // 608 balls
roller_d = 28; roller_len = 82; bore = 10;     // idler roller
washer_od = 12; washer_t = 6;
plate_gap = 95; plate_t = 6;
arm_t = 5; a_piv = 22; a_tail = 18;
Rd = 11.6; Ri = roller_d/2;                    // driven / idler radius

// ---- helpers ----
module along_x(x0 = 0) translate([x0, 0, 0]) rotate([0, 90, 0]) children();
module ring(od, id, h) difference() { cylinder(d = od, h = h); translate([0, 0, -1]) cylinder(d = id, h = h + 2); }

// Revolve a 2D (r, x) profile around the X axis; half (y >= 0) when cut.
module revolve_x(cut) along_x() rotate_extrude(angle = cut ? 180 : 360) children();

// Keep only the y >= 0 half of a 2D profile that will be extruded in the YZ plane.
module keep_back_2d(cut) {
    if (cut) intersection() { children(); translate([0, -200]) square([400, 400]); }
    else children();
}

// A rotation marker at angle `a` is on the visible (back) half when sin(a) <= 0.
function marker_visible(a, cut) = !cut || sin(a) <= 0.02;

// Text facing a viewer on the -Y side
module label(txt, pos, size = 3, col = "Black") color(col) translate(pos) rotate([90, 0, 0])
    linear_extrude(0.2) text(txt, size = size, halign = "center", valign = "center");

// ---- parts (axis along X) ----

// 608 bearing, x in [0, b_w]. `spin` turns the outer ring; the balls orbit at
// ~40% of that speed (like a real bearing); the inner ring never moves.
module bearing(spin = 0, cut = false) {
    color(C_SPIN) revolve_x(cut) translate([18.4/2, 0]) square([(b_od - 18.4)/2, b_w]);
    if (marker_visible(spin, cut))
        color("Red") rotate([spin, 0, 0]) translate([0.5, -0.6, b_od/2 - 0.1]) cube([b_w - 1, 1.2, 0.5]);
    color("DimGray") rotate([0.4*spin, 0, 0])
        for (i = [0 : ball_n - 1]) rotate([i*360/ball_n, 0, 0]) translate([b_w/2, 0, ball_pr]) sphere(d = ball_d, $fn = 24);
    color(C_STILL) revolve_x(cut) translate([b_id/2, 0]) square([(11.6 - b_id)/2, b_w]);
}

// The idler rod. The red stripe on its end faces never moves.
module rod(len = rod_len) {
    color(C_STILL) along_x(-len/2) cylinder(d = rod_d, h = len);
    color("Red") for (s = [-1, 1])
        translate([s*len/2 + (s > 0 ? 0 : -0.4), -0.7, 0]) cube([0.4, 1.4, rod_d/2 - 0.4]);
}

// Idler roller shell (no bearings), x in [-L/2, L/2]. Spins.
module roller_shell(spin = 0, cut = false) {
    color(C_SPIN) translate([-roller_len/2, 0, 0]) revolve_x(cut) difference() {
        translate([bore/2, 0]) square([(roller_d - bore)/2, roller_len]);
        translate([0, -1]) square([b_od/2, b_w + 1]);                 // bearing pocket
        translate([0, roller_len - b_w]) square([b_od/2, b_w + 1]);   // bearing pocket
    }
    if (marker_visible(spin - 40, cut))
        color("Red") rotate([spin - 40, 0, 0])
            translate([-roller_len/2 + 8, -0.7, Ri - 0.2]) cube([roller_len - 16, 1.4, 0.6]);
}

// Roller + its two bearings, as one spinning unit.
module idler_roller_unit(spin = 0, cut = false) {
    roller_shell(spin, cut);
    for (x = [-roller_len/2, roller_len/2 - b_w]) translate([x, 0, 0]) bearing(spin, cut);
}

module washer(cut = false) color(C_STILL) revolve_x(cut) translate([(rod_d + 0.4)/2, 0]) square([(washer_od - rod_d - 0.4)/2, washer_t]);

// Arm profile: rod hole at the origin, pivot a_piv up, spring hole a_tail beyond.
module arm_2d() difference() {
    hull() {
        circle(d = rod_d + 8);
        translate([0, a_piv]) circle(d = 10);
        translate([0, a_piv + a_tail]) circle(d = 8);
    }
    circle(d = rod_d + 0.1);
    translate([0, a_piv]) circle(d = 3.3);
    translate([0, a_piv + a_tail]) circle(d = 3);
}
// Arm extruded along +X from x = 0 (arm lies in the YZ plane).
module arm(cut = false) color("Goldenrod") rotate([90, 0, 90]) linear_extrude(arm_t) keep_back_2d(cut) arm_2d();

// ---- parts gallery (only when this file is opened directly) ----
show_gallery = true;
if (show_gallery) {
    $vpt = [0, 0, 0]; $vpr = [70, 0, 15]; $vpd = 300;
    translate([-80, 0, 30]) { translate([-b_w/2, 0, 0]) bearing(0, true); label("bearing (608), cut open", [0, -15, -18], 3); }
    translate([-20, 0, 30]) { rod(40); label("rod", [0, -15, -10], 3, "DimGray"); }
    translate([45, 0, 30])  { translate([-washer_t/2, 0, 0]) washer(); label("washer", [0, -15, -12], 3, "DimGray"); }
    translate([0, 0, -20])  { roller_shell(0, true); label("roller shell (tube), cut open", [0, -15, -22], 3, "DarkOrange"); }
    translate([85, 0, -35]) { arm(); label("arm", [2, -15, -14], 3, "DarkGoldenrod"); }
    label("ORANGE = spins     GRAY = never turns", [0, -15, 62], 4);
}
