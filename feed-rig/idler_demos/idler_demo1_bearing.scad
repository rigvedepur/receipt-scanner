// ============================================================
//  Idler demo 1 of 4: how ONE 608 ball bearing works
// ============================================================
//  The front half is cut away so you can see inside.
//  ORANGE outer ring + balls move.  GRAY inner ring + rod stay still.
//  In the rig, the outer ring is pressed into the idler roller and
//  the inner ring sits on the rod. So the roller can spin while the
//  rod stays perfectly still.
//
//  Animate: View > Animate, FPS 15, Steps 60.  Or drag `spin`.
// ============================================================
include <idler_common.scad>
show_gallery = false;   // hide the library's parts gallery

spin = 0;   // [0:10:360]
a = spin + 360*$t;

$vpt = [0, 0, 0]; $vpr = [75, 0, 20]; $vpd = 140;

translate([-b_w/2, 0, 0]) bearing(a, cut = true);
rod(30);

label("OUTER ring: pressed into the roller -> SPINS",  [0, -12, 17], 2.2, "DarkOrange");
label("balls roll between the two rings",              [0, -12, 13.5], 2.2, "DimGray");
label("INNER ring: sits on the rod -> STILL",          [0, -12, -15], 2.2, "DimGray");
label("rod -> STILL (red mark never moves)",           [0, -12, -18.5], 2.2, "DimGray");
