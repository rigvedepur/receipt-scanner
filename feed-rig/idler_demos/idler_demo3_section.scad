// ============================================================
//  Idler demo 3 of 4: cross-section of the whole idler side
// ============================================================
//  Everything is cut in half along the rod, so you see every layer
//  from the left arm to the right arm:
//
//   arm | plate (slot) | washer | bearing | roller tube | bearing | washer | plate (slot) | arm
//
//  The plates only have a SLOT here (no bearing): the rod passes
//  through it without touching, so the arms can swing the idler
//  toward/away from the paper (demo 4).
//
//  ORANGE = spins, GRAY = still. Animate: FPS 15, Steps 60.
// ============================================================
include <idler_common.scad>
show_gallery = false;   // hide the library's parts gallery

spin = 0;   // [0:10:360]
a = spin + 360*$t;
xa = plate_gap/2;

$vpt = [0, 0, 8]; $vpr = [80, 0, 8]; $vpd = 250;

module plate_2d() difference() {
    translate([-22, -16]) square([48, 62]);
    hull() for (y = [-1, 4]) translate([y, 0]) circle(d = rod_d + 1);   // slot for the rod
    translate([0, a_piv]) circle(d = 3.4);                               // arm pivot hole
}

// plates (fixed frame)
for (s = [-1, 1])
    color(C_WOOD) translate([s > 0 ? xa : -xa - plate_t, 0, 0]) rotate([90, 0, 90]) linear_extrude(plate_t) keep_back_2d(true) plate_2d();
// pivot bolts
color("DimGray") for (s = [-1, 1]) translate([s*(xa + plate_t/2 + 1), 0, a_piv]) rotate([0, 90, 0]) cylinder(d = 3, h = plate_t + arm_t + 5, center = true, $fn = 16);

rod();
idler_roller_unit(a, true);
for (s = [-1, 1]) translate([s > 0 ? xa - washer_t : -xa, 0, 0]) washer(true);
for (s = [-1, 1]) translate([s > 0 ? xa + plate_t + 0.5 : -xa - plate_t - 0.5 - arm_t, 0, 0]) arm(true);

label("roller tube SPINS", [0, -30, 20], 3, "DarkOrange");
label("rod STILL", [0, -30, -8], 3, "DimGray");
label("bearing", [-37.5, -30, -16], 2.4, "DimGray");
label("bearing", [ 37.5, -30, -16], 2.4, "DimGray");
label("washer", [-44.5, -30, -22], 2.4, "DimGray");
label("washer", [ 44.5, -30, -22], 2.4, "DimGray");
label("plate: slot only", [-50.5, -30, 50], 2.4, "SaddleBrown");
label("plate: slot only", [ 50.5, -30, 50], 2.4, "SaddleBrown");
label("arm", [-58, -30, 44], 2.4, "DarkGoldenrod");
label("arm", [ 58, -30, 44], 2.4, "DarkGoldenrod");
