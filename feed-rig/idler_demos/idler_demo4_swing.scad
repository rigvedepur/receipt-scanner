// ============================================================
//  Idler demo 4 of 4: end view - the nip and the swinging arm
// ============================================================
//  Looking along the rollers, from outside plate A.
//
//  * Paper moves DOWN between the driven roller (left, motor turns
//    it) and the idler roller (right). Both rollers SPIN (orange).
//  * The idler rod (center of the right roller) has a red mark that
//    NEVER rotates: the rod only MOVES. When thick paper comes
//    through, the arm swings on its pivot and carries the rod and
//    roller away from the paper, then the spring pulls them back.
//
//  The plate is drawn see-through so you can see the rollers behind it.
//  Animate: View > Animate, FPS 15, Steps 120.  Or drag the sliders.
// ============================================================
include <idler_common.scad>
show_gallery = false;   // hide the library's parts gallery

spin = 0;      // [0:10:360]
open = 0;      // [0:0.05:1] extra opening on top of the animation
a     = spin + 720*$t;
openf = min(1, open + (0.5 - 0.5*cos(360*$t)));    // animation: closes -> opens -> closes
th    = openf*asin(4/a_piv);                        // up to 4 mm of travel
pivot = [0, a_piv];
anchor = [26, a_piv + a_tail];

$vpt = [0, -5, 14]; $vpr = [90, 0, 90]; $vpd = 230;

// text facing a viewer on the +X side
module xlabel(txt, yz, size = 2.8, col = "Black") color(col) translate([12, yz[0], yz[1]]) rotate([90, 0, 90])
    linear_extrude(0.2) text(txt, size = size, halign = "center", valign = "center");
module about_pivot(t) translate([0, 0, a_piv]) rotate([t, 0, 0]) translate([0, 0, -a_piv]) children();

// driven roller (motor side): spins the other way
color("DimGray") translate([-20, -(Rd + Ri), 0]) rotate([-a*Ri/Rd, 0, 0]) rotate([0, 90, 0]) cylinder(r = Rd, h = 18);   // spins in place
color("Red") translate([-2, -(Rd + Ri), 0]) rotate([-a*Ri/Rd, 0, 0]) translate([0, -0.7, Rd - 2]) cube([0.4, 1.4, 2]);

// paper moving down through the nip
color("White") translate([-20, -Ri - 0.3, -40]) cube([18, 0.3, 90]);
color("Black") for (k = [0 : 8]) translate([-2, -Ri - 0.4, 45 - ((k*12 + 24*$t*12) % 96)]) cube([0.2, 0.2, 3]);

// plate (see-through), with the pivot bolt
color(C_WOOD, 0.35) translate([-6, -45, -22]) cube([6, 80, 92]);
color("DimGray") translate([0, pivot[0], pivot[1]]) rotate([0, 90, 0]) cylinder(d = 3, h = 14, center = true, $fn = 16);

// everything that swings with the arm
about_pivot(th) {
    translate([-20, 0, 0]) rotate([a, 0, 0]) {                     // idler roller end: SPINS
        color(C_SPIN) rotate([0, 90, 0]) ring(roller_d, bore, 14);
        color("Red") translate([10, -0.7, Ri - 2]) cube([0.4, 1.4, 2]);
    }
    translate([-6, 0, 0]) bearing(a);                               // bearing in the roller end
    color(C_STILL) translate([-30, 0, 0]) rotate([0, 90, 0]) cylinder(d = rod_d, h = 39);   // rod
    color("Red") translate([9, -0.7, 0]) cube([0.4, 1.4, rod_d/2 - 0.4]);                    // rod mark: never turns
    translate([0.5, 0, 0]) arm();
}

// spring: arm tail -> anchor screw on the plate
tail = pivot + a_tail*[-sin(th), cos(th)];
color("Teal") hull() for (p = [tail, anchor]) translate([3, p[0], p[1]]) sphere(d = 2.5, $fn = 12);
color("DimGray") translate([4, anchor[0], anchor[1]]) rotate([0, 90, 0]) cylinder(d = 5.5, h = 3, center = true, $fn = 16);

xlabel("driven roller (motor)", [-(Rd + Ri), -18], 2.6, "DimGray");
xlabel("idler roller", [8, -20], 2.6, "DarkOrange");
xlabel("paper moves down", [-Ri - 12, 46], 2.6);
xlabel("pivot", [-9, a_piv], 2.4);
xlabel("spring", [14, a_piv + a_tail + 5], 2.4, "Teal");
xlabel("red mark on the rod NEVER rotates - the rod only moves", [-5, -32], 2.6, "Red");
