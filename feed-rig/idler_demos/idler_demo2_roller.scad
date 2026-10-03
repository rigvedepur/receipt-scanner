// ============================================================
//  Idler demo 2 of 4: the idler roller on its rod
// ============================================================
//  The idler roller is a hollow tube with a 608 bearing pressed
//  into each end (demo 1). The rod passes through both bearings.
//  The roller's bore (10 mm) is bigger than the rod (8 mm), so
//  the tube only touches the bearings, never the rod.
//
//  The rod ends are clamped in the two arms by set screws, so the
//  rod CANNOT turn. The washers keep the roller centered.
//
//  ORANGE = spins (tube + bearing outer rings + balls)
//  GRAY   = still (rod, bearing inner rings, washers)
//  Animate: View > Animate, FPS 15, Steps 60.
// ============================================================
include <idler_common.scad>
show_gallery = false;   // hide the library's parts gallery

spin    = 0;     // [0:10:360]
cutaway = true;
a = spin + 360*$t;

$vpt = [0, 0, 0]; $vpr = [70, 0, 15]; $vpd = 260;

rod();
idler_roller_unit(a, cutaway);
for (s = [-1, 1]) translate([s > 0 ? roller_len/2 + 0.5 : -roller_len/2 - 0.5 - washer_t, 0, 0]) washer(cutaway);

// arms clamp the rod ends (plates are left out here; see demo 3)
for (s = [-1, 1]) translate([s > 0 ? 54 : -54 - arm_t, 0, 0]) {
    arm();
    color("Red") translate([arm_t/2, 0, -rod_d/2 - 5]) cylinder(d = 3, h = 5, $fn = 16);   // set screw
}

label("idler roller (hollow tube) -> SPINS",          [0, -20, 22], 3.2, "DarkOrange");
label("608 bearing",                                  [-roller_len/2 + 4, -20, -20], 2.6, "DimGray");
label("608 bearing",                                  [ roller_len/2 - 4, -20, -20], 2.6, "DimGray");
label("rod -> STILL (clamped in both arms)",          [0, -20, -28], 3.2, "DimGray");
label("arm",                                          [-56, -20, 46], 2.6, "DarkGoldenrod");
label("arm",                                          [ 56, -20, 46], 2.6, "DarkGoldenrod");
label("set screw",                                    [-56, -20, -16], 2.4, "Red");
label("set screw",                                    [ 56, -20, -16], 2.4, "Red");
