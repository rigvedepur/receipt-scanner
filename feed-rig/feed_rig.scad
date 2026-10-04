// =====================================================================
//  Receipt Scanner - Feed Rig (paper path + Pi Camera Module 3 Wide)
// =====================================================================
//  Vertical paper path: slot/funnel -> nip 1 -> nip 2 -> drop.
//  One NEMA17 drives both driven rollers through a single GT2 loop.
//  Idler rollers sit on pivoting arms loaded by springs / rubber bands.
//  A Pi Camera Module 3 Wide looks at the paper through the gap between
//  the two driven rollers (driven side, -X). Lighting is not modeled yet.
//
//  Units: mm.  Assembly coordinate frame:
//    X : across the paper path. The paper plane is X = 0.
//        Driven rollers are on the -X side, idlers on +X.
//    Y : along the roller axes (receipt width). Plate A (motor/pulleys) is at -Y.
//    Z : vertical. The nip 1 line is at Z = 0; paper travels toward -Z.
//
//  Pick a part with `part` (Customizer dropdown, or -D on the CLI).
//  Every part except "assembly" is placed in its print/cut orientation.
//  The ECHO console prints a design report (radii, belt length, rod
//  lengths, O-ring sizes, steps/mm). Read it after changing parameters.
// =====================================================================

/* [Part to render] */
part = "assembly"; // [assembly, side_plate, side_plate_2d, side_plate_cnc_inner, side_plate_cnc_outline, fit_coupon_2d, fit_coupon_cnc_inner, fit_coupon_cnc_outline, funnel, driven_roller, idler_roller, idler_arm, spacer, hub_washer, width_shim, camera_mount, pulley_shim]
show_plates   = true;  // turn off to see inside from the side
show_paper    = true;
show_hardware = true;  // shafts, bearings, motor, pulleys, belt (visual only)
show_shims    = false;
show_camera   = true;  // camera mount + board placeholder
show_fov      = true;  // camera field of view (yellow) and visible paper strip (green)

/* [Paper] */
paper_max_w     = 80;   // widest receipt roll (80 mm is standard)
paper_min_w     = 57;   // narrowest (57/58 mm is standard)
edge_clearance  = 1.5;  // per side, between the paper and the channel wall
min_receipt_len = 50;   // shortest receipt that must feed (parking stub)

/* [Paper path] */
nip_pitch        = 36;   // nip 1 -> nip 2 distance. MUST be < shortest receipt
throat_gap       = 2.0;  // funnel exit gap (the paper plane is centered in it)
throat_h         = 9;    // throat height above the nip 1 line
funnel_h         = 40;   // throat -> mouth height
funnel_mouth     = 30;   // mouth opening (X) at the top
funnel_wall      = 2.0;  // wall thickness at the mouth
funnel_tip       = 1.0;  // wall thickness at the throat tip
funnel_end_t     = 6;    // end caps (these also set the plate spacing)
roller_clearance = 0.6;  // funnel-to-roller clearance

/* [Roller surfaces] */
driven_surface     = "oring"; // [oring, tube, bare]
idler_surface      = "bare";  // [oring, tube, bare]
driven_core_d      = 22;      // printed hub OD
idler_core_d       = 28;      // printed hub OD (houses 608 bearings)
oring_cs           = 2.0;     // O-ring cross-section
oring_groove_depth = 1.4;     // leaves (cs - depth) = 0.6 mm proud
oring_count        = 4;       // all grooves sit inside paper_min_w
tube_wall          = 1.0;     // silicone tube wall (hub OD = tube ID)

/* [Idler loading] */
arm_pivot_dist = 22;   // pivot -> idler rod
arm_tail_len   = 18;   // pivot -> spring hole. Nip force = F_spring * tail/pivot
arm_t          = 5;
arm_w          = 10;
idler_travel   = 4;    // how far the idler can open (for thick/crumpled paper)
overtravel     = 1.0;  // slot room past contact, so the spring always loads the nip
anchor_offsets = [18, 26, 34, 42]; // spring anchor holes, measured +X from the arm tail
spring_anchor  = 1;    // [0:3] which anchor hole the spring uses (preview only)

/* [Hardware] */
shaft_d      = 8;     // driven shafts and idler rods (8 mm smooth rod)
bearing_od   = 22;    // 608 bearing
bearing_w    = 7;
bearing_press = 0.1;  // interference for the 608s pressed into the plates
motor_shaft_len = 20; // NEMA17 shaft length beyond the flange (17HS15-1704S: 20 mm, D-cut)
m3_head_d    = 5.5;   // socket-head diameter, for clearance checks
pivot_hole   = 3.5;   // arm pivot hole: printed holes shrink, and the arm must swing freely on M3
arm_rod_hole = 8.2;   // arm hole for the 8 mm idler rod (drill or ream to a snug fit)
m3_clear     = 3.4;
m3_tap       = 2.7;   // M3 self-tapping into plastic
m5_clear     = 5.5;   // M5 threaded-rod frame spacers
pulley_teeth = 20;    // GT2 20T on all three (1:1)
pulley_len   = 16;
pulley_hub_len = 7;   // set-screw hub; the rest is flange + teeth + flange
pulley_hub_in  = true; // hubs face the plate: lets a 20 mm motor shaft carry the hub fully

/* [Motor] */
motor_x     = -48;  // NEMA17 center. Defaults give a ~200 mm closed GT2 loop
motor_z     = -67;
motor_slot  = 3;    // +/- tensioning slot along X

/* [Camera - Pi Camera Module 3 Wide] */
cam_dist     = 55;    // paper plane -> lens front. The Wide lens focuses down to ~50 mm
cam_z_offset = 0;     // + moves the camera up from the height midway between the nips
cam_slot     = 6;     // +/- distance-adjustment slots in the plates
cam_hfov     = 102;   // horizontal FOV, along the receipt width (Y)
cam_vfov     = 67;    // vertical FOV, along the paper motion (Z)
cam_board_w  = 25;    // along Y
cam_board_h  = 24;    // along Z, ribbon connector at the bottom edge
cam_hole_dx  = 21;    // M2 hole spacing across the board
cam_hole_dz  = 12.5;  // M2 hole spacing top to bottom
cam_hole_top = 2;     // top hole row, measured from the board's top edge
cam_lens_top = 9.5;   // lens center, measured from the board's top edge (check the official drawing)
cam_depth    = 12.4;  // board back -> lens front
cam_standoff = 4;     // clears the parts on the back of the board
cam_holder_t = 3;
cam_bar_t    = 10;
m2_tap       = 1.8;

/* [CNC export (one bit, Luban "On the Path")] */
cnc_bit = 3.175;   // end mill diameter; every path is offset by its radius

/* [Side plates] */
plate_mode      = "laser"; // [laser, print]
plate_t         = 6;       // 6 mm plywood, or print at 6 mm
laser_kerf      = 0.15;    // holes are drawn smaller by the kerf
print_hole_comp = 0.2;     // holes are drawn larger for FDM shrink
plate_margin    = 8;
spacer_od       = 12;

$fn = 72;

// ---------------------------------------------------------------------
//  Derived geometry
// ---------------------------------------------------------------------
function eff_r(core_d, surf) =
    surf == "oring" ? core_d/2 - oring_groove_depth + oring_cs :
    surf == "tube"  ? core_d/2 + tube_wall :
                      core_d/2;

Rd = eff_r(driven_core_d, driven_surface);   // driven effective radius
Ri = eff_r(idler_core_d,  idler_surface);    // idler effective radius

channel_w  = paper_max_w + 2*edge_clearance;
plate_gap  = channel_w + 2*funnel_end_t;     // inner face to inner face
roller_len = channel_w - 1;
washer_t   = (plate_gap - roller_len)/2 - 0.5;

nips    = [0, -nip_pitch];  // Z of each nip line
arm_dir = [1, -1];          // nip 1 arm pivots above its nip, nip 2 below
drv_x   = -Rd;
idl_x   = Ri;               // rollers touch at X = 0

funnel_top = throat_h + funnel_h;
// The idler-side screw sits near the middle, not at the corner: the nip-1 arm
// tail and its spring hook are outside the plate at about x = idl_x, z = 40.
funnel_holes = [[0, throat_h + funnel_h*0.5],
                [-(funnel_mouth/2 - 3), funnel_top - 5],
                [3, funnel_top - 3]];

// O-ring grooves are spread across the central (paper_min_w - 6) mm,
// so even a narrow, centered receipt is gripped by every O-ring.
groove_keepout = (roller_len - (paper_min_w - 6))/2;

function pivot(i) = [idl_x, nips[i] + arm_dir[i]*arm_pivot_dist];
function tail(i)  = [idl_x, nips[i] + arm_dir[i]*(arm_pivot_dist + arm_tail_len)];
function rod_at(i, th) = pivot(i) + arm_pivot_dist*[sin(th), -arm_dir[i]*cos(th)];
th_min = -asin(overtravel/arm_pivot_dist);
th_max =  asin(idler_travel/arm_pivot_dist);

z_top   = max(funnel_top, tail(0)[1]) + plate_margin;
z_bot   = min(motor_z - 21, tail(1)[1]) - 22;
x_left  = motor_x - 21 - motor_slot;
x_right = idl_x + max(anchor_offsets);
spacers = [[x_left + 4,  z_top - 10],
           [x_left + 4,  z_bot + 10],
           [x_right - 4, z_bot + 10],
           [x_right - 4, (nips[0] + nips[1])/2]];

// Camera. Board faces +X, ribbon exits downward.
cam_zc   = -nip_pitch/2 + cam_z_offset;      // lens axis height
cam_xl   = -cam_dist;                        // lens front
cam_xb   = cam_xl - cam_depth;               // board back
cam_ztop = cam_zc + cam_lens_top;
cam_zbot = cam_ztop - cam_board_h;
cam_holes = [for (sy = [-1, 1]) for (dz = [0, cam_hole_dz])
                [sy*cam_hole_dx/2, cam_ztop - cam_hole_top - dz]];   // [y, z]
cam_hx   = cam_xb - cam_standoff;            // holder front face
cam_bx1  = cam_hx - cam_holder_t;            // bar front face
cam_bx0  = cam_bx1 - cam_bar_t;              // bar back face
cam_mz0  = cam_zbot + 6.5;                   // the ribbon connector stays clear below this
cam_mz1  = cam_ztop + 3;
cam_slot_x = (cam_bx0 + cam_bx1)/2;
cam_slot_z = [(cam_mz0 + cam_mz1)/2 - 5, (cam_mz0 + cam_mz1)/2 + 5];

cam_cover_w = 2*cam_dist*tan(cam_hfov/2);    // field width at the paper
cam_cover_h = 2*cam_dist*tan(cam_vfov/2);
cam_C = [cam_xl, cam_zc];
// Height where a ray from the lens, tangent to a driven roller, meets the paper.
// sgn = -1: lower tangent of the roller above; +1: upper tangent of the roller below.
function vis_edge(O, sgn) =
    let(v = O - cam_C, a = atan2(v[1], v[0]), b = asin(Rd/norm(v)))
    cam_C[1] + (0 - cam_C[0])*tan(a + sgn*b);
strip_hi = vis_edge([drv_x, nips[0]], -1);
strip_lo = vis_edge([drv_x, nips[1]],  1);
strip_h  = strip_hi - strip_lo;
function join(v, i = 0) = i >= len(v) ? "" : str(v[i], join(v, i + 1));
function cam_dpi(px) = px/(cam_cover_w/25.4);
cam_modes = [[1536, 864, 120], [2304, 1296, 56], [4608, 2592, 14]];  // IMX708 sensor modes
feed_v = 60;   // mm/s, for the report only

hc = plate_mode == "laser" ? -laser_kerf : print_hole_comp;
$hc = hc;                      // hole compensation; the CNC export sets it to 0
function hd(d) = d + $hc;

pulley_pd = pulley_teeth*2/PI;
function belt_len(mx) =
    let(a = [drv_x, nips[0]], b = [drv_x, nips[1]], m = [mx, motor_z])
    norm(a - b) + norm(b - m) + norm(m - a) + PI*pulley_pd;

driven_shaft_len = plate_gap + 2*plate_t + 2 + pulley_len + 4;
idler_rod_len    = plate_gap + 2*plate_t + 2*(arm_t + 1) + 4;

// ---------------------------------------------------------------------
//  Sanity checks
// ---------------------------------------------------------------------
assert(nip_pitch <= min_receipt_len - 10,
       "nip_pitch too long: short receipts would drop between the nips");
assert(nip_pitch > 2*Ri + 2,  "idler rollers collide: raise nip_pitch or shrink idler_core_d");
assert(nip_pitch > driven_core_d + 2, "driven rollers collide");
assert(idler_surface != "oring" || groove_keepout >= bearing_w + 2,
       "idler O-ring grooves overlap the bearing pockets");
assert(throat_h < Rd && throat_h < Ri, "throat_h must sit inside the roller wedge");
assert(strip_hi > strip_lo, "camera cannot see between the driven rollers: move it back or re-center it");
assert(cam_xl < drv_x - Rd - 3, "camera lens collides with the driven rollers");

drv_surface_at_throat = drv_x + sqrt(Rd*Rd - throat_h*throat_h);
idl_surface_at_throat = idl_x - sqrt(Ri*Ri - throat_h*throat_h);
tip_ok = -(throat_gap/2 + funnel_tip) > drv_surface_at_throat + roller_clearance &&
          (throat_gap/2 + funnel_tip) < idl_surface_at_throat - roller_clearance;

echo(str("\n\n======== FEED RIG REPORT ========",
  "\n Effective roller radius: driven ", Rd, " / idler ", Ri,
  "\n Nip pitch ", nip_pitch, " mm  (shortest receipt ", min_receipt_len, " mm)",
  "\n Wedge at throat: driven surface x=", drv_surface_at_throat,
       ", idler surface x=", idl_surface_at_throat,
       tip_ok ? "  -> funnel tips clear" : "  -> WARNING: tips get trimmed; lower throat_h or funnel_tip",
  "\n Plate inner gap ", plate_gap, " | roller length ", roller_len, " | hub washer t ", washer_t,
  "\n GT2 closed loop: ", belt_len(motor_x), " mm (slot range ",
       belt_len(motor_x + motor_slot), " .. ", belt_len(motor_x - motor_slot), ")",
  "\n   -> buy the standard loop inside that range (200 mm with the defaults)",
  "\n Driven shafts: 2 x 8 mm rod, ", driven_shaft_len, " mm",
  "\n Idler rods:    2 x 8 mm rod, ", idler_rod_len, " mm",
  driven_surface == "oring" ? str("\n Driven O-rings: ", oring_count*2, " x ID ~",
       driven_core_d - 2*oring_groove_depth - 1, " mm, CS ", oring_cs) : "",
  idler_surface == "oring" ? str("\n Idler O-rings:  ", oring_count*2, " x ID ~",
       idler_core_d - 2*oring_groove_depth - 1, " mm, CS ", oring_cs) : "",
  driven_surface == "tube" ? str("\n Driven tube: ID ", driven_core_d, " mm, wall ", tube_wall) : "",
  "\n Nip force per arm = spring force x ", arm_tail_len/arm_pivot_dist,
  "  (two arms per nip)",
  "\n Steps/mm at 8 microsteps: ", 200*8/(2*PI*Rd),
  "\n Plate size ~", round(x_right + plate_margin - min(x_left, cam_slot_x - cam_slot) + plate_margin), " x ", z_top - z_bot, " mm",
  "\n --- Camera (Module 3 Wide) ---",
  "\n Lens ", cam_dist, " mm from paper", cam_dist < 50 ? "  -> WARNING: closer than the ~50 mm minimum focus" : "",
  "\n Field at paper: ", cam_cover_w, " (width) x ", cam_cover_h, " mm",
  cam_cover_w < paper_max_w + 4 ? "  -> WARNING: does not cover the full receipt width" : "",
  "\n Visible strip between rollers: z ", strip_lo, " .. ", strip_hi, "  (", strip_h, " mm tall)",
  join([for (m = cam_modes) let(d = cam_dpi(m[0]), adv = feed_v/m[2])
     str("\n  ", m[0], "x", m[1], " @", m[2], "fps: ", round(d), " dpi | ",
         adv, " mm/frame at ", feed_v, " mm/s (", round(100*(1 - adv/strip_h)), "% overlap) | ",
         "1 px blur at exposure ", round(1e6*(25.4/d)/feed_v), " us")]),
  "\n=================================\n"));

// ---------------------------------------------------------------------
//  FIT CHECK: clearances recomputed from the parameters on every run
// ---------------------------------------------------------------------
// distance from point p to segment a-b
function seg_dist(p, a, b) = let(ab = b - a, t = max(0, min(1, (p - a)*ab/(ab*ab)))) norm(p - (a + t*ab));
// clearance between a circle (center p, radius r) and an arm (hull of 3 circles), at arm angle th
function arm_pts(i, th) = let(P = pivot(i), d = arm_dir[i])
    [rod_at(i, th), P, P + arm_tail_len*[-sin(th), d*cos(th)]];
function arm_clear(p, r, i, th) = let(q = arm_pts(i, th))
    min(seg_dist(p, q[0], q[1]) - (shaft_d + 8)/2, seg_dist(p, q[1], q[2]) - arm_w/2) - r;
function pass(c, need = 0.5) = c >= need ? "ok  " : "FAIL";

fc_funnel_arm = min([for (h = funnel_holes) for (th = [th_min, 0, th_max]) arm_clear(h, m3_head_d/2, 0, th)]);
fc_web       = min([for (i = [0:1]) for (k = [0:8]) let(th = th_min + (th_max - th_min)*k/8)
                    norm(rod_at(i, th) - [drv_x, nips[i]]) - bearing_od/2 - (shaft_d + 1)/2]);
// The motor pulley's hub (set screw) must sit fully on the shaft; teeth may overhang a little.
hub_end      = pulley_hub_in ? 2 + pulley_hub_len : 2 + pulley_len;   // from plate A's outer face
fc_pulley    = motor_shaft_len - plate_t - hub_end;
teeth_over   = max(0, 2 + pulley_len - (motor_shaft_len - plate_t) - (pulley_hub_in ? 1 : 0));
fc_cap_hole  = min([for (h = funnel_holes) funnel_top - h[1] - m3_tap/2]);
fc_cam_motor = (cam_mz0) - (motor_z + 21);
fc_play      = plate_gap - roller_len - 2*washer_t;   // total axial play per roller
fc_idl_gap   = nip_pitch - 2*Ri;
fc_anchor_head = min([for (i = [0:1]) for (s = anchor_offsets) for (th = [th_min, 0, th_max])
                    arm_clear([idl_x + s, tail(i)[1]], m3_head_d/2, i, th)]);

echo(str("\n======== FIT CHECK ========",
  "\n [", pass(fc_funnel_arm), "] funnel screw heads vs nip-1 arm (closed and open): ", fc_funnel_arm, " mm",
  "\n [", pass(fc_anchor_head, 0), "] nearest unused anchor screw head vs arm: ", fc_anchor_head, " mm",
  "\n [", pass(fc_web, 3), "] plywood web between driven-bearing hole and idler-rod slot: ", fc_web, " mm",
  "\n [", pass(fc_cap_hole, 1), "] funnel cap material above its screw holes: ", fc_cap_hole, " mm",
  "\n [", pass(fc_pulley, 0), "] motor pulley hub fully on the shaft: ", fc_pulley, " mm to spare (", motor_shaft_len, " mm shaft, hubs ", pulley_hub_in ? "toward" : "away from", " the plate)",
  teeth_over > 0 ? str("\n [", teeth_over <= 4 ? "ok  " : "FAIL", "] motor pulley teeth overhang the shaft end by ", teeth_over, " mm (fine up to ~4 mm)") : "",
  "\n [", pass(fc_cam_motor, 2), "] camera mount above motor body: ", fc_cam_motor, " mm",
  "\n [", fc_play >= 0.2 && fc_play <= 1.5 ? "ok  " : "FAIL", "] hub washers: axial play per roller ", fc_play, " mm (want 0.2-1.5)",
  "\n [", pass(fc_idl_gap, 3), "] gap between the two idler rollers: ", fc_idl_gap, " mm",
  "\n Plate holes as drawn (", plate_mode, "): bearing ", hd(bearing_od - bearing_press),
       " | M3 ", hd(m3_clear), " | M5 ", hd(m5_clear), " | motor boss ", hd(23),
       " | rod slot width ", hd(shaft_d + 1),
  "\n===========================\n"));

// ---------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------
// Extrude a 2D (x,z) profile symmetrically along Y.
module xz_extrude(h) rotate([90, 0, 0]) linear_extrude(height = h, center = true) children();

// ---------------------------------------------------------------------
//  Side plate (two identical plates; cut or print 2)
// ---------------------------------------------------------------------
module rod_slot(i) {
    steps = 8;
    for (k = [0 : steps - 1]) hull() {
        translate(rod_at(i, th_min + (th_max - th_min)*k/steps))       circle(d = hd(shaft_d + 1));
        translate(rod_at(i, th_min + (th_max - th_min)*(k + 1)/steps)) circle(d = hd(shaft_d + 1));
    }
}

module motor_cutouts() {
    translate([motor_x, motor_z]) {
        hull() for (dx = [-motor_slot, motor_slot]) translate([dx, 0]) circle(d = hd(23));
        for (sx = [-1, 1], sz = [-1, 1])
            hull() for (dx = [-motor_slot, motor_slot])
                translate([sx*15.5 + dx, sz*15.5]) circle(d = hd(m3_clear));
    }
}

module plate_outline() {
    pts = concat(
        [for (s = spacers) [s[0], s[1], spacer_od/2 + 4]],
        [for (sx = [-1, 1]) for (sz = [-1, 1])
            [motor_x + sx*(21 + motor_slot), motor_z + sz*21, 4]],
        [for (i = [0 : 1]) [tail(i)[0], tail(i)[1], plate_margin]],
        [for (i = [0 : 1]) for (s = anchor_offsets) [idl_x + s, tail(i)[1], plate_margin]],
        [for (h = funnel_holes) [h[0], h[1], plate_margin]],
        [for (z = nips) [drv_x, z, bearing_od/2 + plate_margin]],
        [for (z = cam_slot_z) for (dx = [-cam_slot, cam_slot]) [cam_slot_x + dx, z, plate_margin]],
        [[0, z_top - 1, 1]]
    );
    xmin = min([for (p = pts) p[0] - p[2]]);
    xmax = max([for (p = pts) p[0] + p[2]]);
    hull() {
        for (p = pts) translate([p[0], p[1]]) circle(r = p[2]);
        translate([xmin, z_bot]) square([xmax - xmin, 1]);   // flat feet
    }
}

module side_plate_2d() difference() { plate_outline(); plate_holes_2d(); }

module plate_holes_2d() {
    union() {
        for (z = nips) translate([drv_x, z]) circle(d = hd(bearing_od - bearing_press));  // 608 press fit
        for (i = [0 : 1]) {
            rod_slot(i);
            translate(pivot(i)) circle(d = hd(m3_clear));
            for (s = anchor_offsets) translate([idl_x + s, tail(i)[1]]) circle(d = hd(m3_clear));
        }
        for (s = spacers) translate(s) circle(d = hd(m5_clear));
        for (h = funnel_holes) translate(h) circle(d = hd(m3_clear));
        motor_cutouts();
        for (z = cam_slot_z)   // camera mount, slides along X to set distance
            hull() for (dx = [-cam_slot, cam_slot]) translate([cam_slot_x + dx, z]) circle(d = hd(m3_clear));
    }
}

// ---------------------------------------------------------------------
//  CNC export: ONE bit, every path cut with Luban "On the Path" (bit centre
//  on the line). Paths are pre-offset by the bit radius, so the cut lands on
//  the true edge: holes are drawn smaller, the outline larger. An M3 hole
//  becomes a 0.2 mm circle that the 3.175 mm bit sweeps out to 3.4 mm.
//  Both files carry the same two corner marks, so they share one bounding
//  box: place both at the same X/Y in Luban. Cut "inner" first, then
//  "outline" with tabs.
// ---------------------------------------------------------------------
module cnc_marks() {   // tiny marks at the outline-path bounding-box corners (in waste)
    b = cnc_bbox();
    for (p = [[b[0], b[1]], [b[2], b[3]]]) translate(p) square(0.05, center = true);
}
function cnc_bbox() = let(pts = concat(
        [for (s = spacers) [s[0], s[1], spacer_od/2 + 4]],
        [for (sx = [-1, 1]) for (sz = [-1, 1]) [motor_x + sx*(21 + motor_slot), motor_z + sz*21, 4]],
        [for (i = [0 : 1]) [tail(i)[0], tail(i)[1], plate_margin]],
        [for (i = [0 : 1]) for (s = anchor_offsets) [idl_x + s, tail(i)[1], plate_margin]],
        [for (h = funnel_holes) [h[0], h[1], plate_margin]],
        [for (z = nips) [drv_x, z, bearing_od/2 + plate_margin]],
        [for (z = cam_slot_z) for (dx = [-cam_slot, cam_slot]) [cam_slot_x + dx, z, plate_margin]],
        [[0, z_top - 1, 1]]), r = cnc_bit/2 + 0.5)
    [min([for (p = pts) p[0] - p[2]]) - r, z_bot - r,
     max([for (p = pts) p[0] + p[2]]) + r, max([for (p = pts) p[1] + p[2]]) + r];
// Small fit-test piece: one bearing hole, M5, two M3, one motor slot - same
// hole code as the plates, so a good fit here means a good fit there.
module coupon_outline() translate([-14, -20]) square([60, 40]);
module coupon_holes_2d() {
    circle(d = hd(bearing_od - bearing_press));                                  // 608 press fit
    translate([24, 10])  circle(d = hd(m5_clear));                                // M5
    translate([24, -10]) circle(d = hd(m3_clear));                                // M3
    translate([36, -10]) circle(d = hd(m3_clear));                                // M3
    translate([36, 10]) hull() for (dx = [-motor_slot, motor_slot]) translate([dx, 0]) circle(d = hd(m3_clear));   // motor slot
}
module fit_coupon_2d() difference() { coupon_outline(); coupon_holes_2d(); }
module coupon_marks() for (p = [[-14 - cnc_bit, -20 - cnc_bit], [46 + cnc_bit, 20 + cnc_bit]]) translate(p) square(0.05, center = true);
module fit_coupon_cnc_inner()   { offset(delta = -cnc_bit/2) coupon_holes_2d($hc = 0); coupon_marks(); }
module fit_coupon_cnc_outline() { offset(r = cnc_bit/2) coupon_outline(); coupon_marks(); }

module side_plate_cnc_inner()   { offset(delta = -cnc_bit/2) plate_holes_2d($hc = 0); cnc_marks(); }
module side_plate_cnc_outline() { offset(r = cnc_bit/2) plate_outline(); cnc_marks(); }

module side_plate() linear_extrude(plate_t) side_plate_2d();

// ---------------------------------------------------------------------
//  Rollers (axis along local Z, printed standing up)
// ---------------------------------------------------------------------
module roller_body(core_d, surf, bore) {
    difference() {
        cylinder(d = core_d, h = roller_len);
        translate([0, 0, -1]) cylinder(d = bore, h = roller_len + 2);
        if (surf == "oring")
            for (k = [0 : oring_count - 1])
                let(zc = groove_keepout + (roller_len - 2*groove_keepout)*
                         (oring_count == 1 ? 0.5 : k/(oring_count - 1)))
                translate([0, 0, zc - (oring_cs + 0.2)/2])
                    difference() {
                        cylinder(d = core_d + 1, h = oring_cs + 0.2);
                        translate([0, 0, -1])
                            cylinder(d = core_d - 2*oring_groove_depth, h = oring_cs + 2.2);
                    }
    }
}

// Fixed to the rotating 8 mm shaft with two M3 set screws (self-tapped).
module driven_roller() {
    difference() {
        roller_body(driven_core_d, driven_surface, shaft_d + 0.25);
        for (z = [4, roller_len - 4])
            translate([0, 0, z]) rotate([0, 90, 0]) cylinder(d = m3_tap, h = driven_core_d);
    }
}

// Spins on two 608 bearings on a stationary 8 mm rod.
module idler_roller() {
    difference() {
        roller_body(idler_core_d, idler_surface, shaft_d + 2);
        for (z = [-1, roller_len - bearing_w])
            translate([0, 0, z]) cylinder(d = bearing_od + 0.15, h = bearing_w + 1);
    }
}

// ---------------------------------------------------------------------
//  Idler arm (local 2D: rod at the origin, pivot at +Y, tail beyond it)
// ---------------------------------------------------------------------
module idler_arm() {
    difference() {
        linear_extrude(arm_t) difference() {
            hull() {
                circle(d = shaft_d + 8);
                translate([0, arm_pivot_dist]) circle(d = arm_w);
                translate([0, arm_pivot_dist + arm_tail_len]) circle(d = arm_w - 2);
            }
            circle(d = arm_rod_hole);
            translate([0, arm_pivot_dist]) circle(d = pivot_hole);
            translate([0, arm_pivot_dist + arm_tail_len]) circle(d = 3.0);
        }
        // M3 set screw to lock the idler rod
        translate([0, 0, arm_t/2]) rotate([0, -90, 0]) cylinder(d = m3_tap, h = shaft_d + 4);   // M3 x 4 grub
    }
}

// ---------------------------------------------------------------------
//  Funnel / slot (assembly coordinates; printed lying on one end cap)
// ---------------------------------------------------------------------
module funnel_wall_2d(side) {   // side: -1 driven, +1 idler
    polygon([[side*throat_gap/2, throat_h],
             [side*(throat_gap/2 + funnel_tip), throat_h],
             [side*(funnel_mouth/2 + funnel_wall), funnel_top],
             [side*funnel_mouth/2, funnel_top]]);
}

module roller_keepout_2d() {
    for (z = nips) {
        translate([drv_x, z]) circle(r = Rd + roller_clearance);
        hull() for (dx = [0, idler_travel])
            translate([idl_x + dx, z]) circle(r = Ri + roller_clearance);
    }
}

module funnel() {
    difference() {
        union() {
            xz_extrude(plate_gap) { funnel_wall_2d(-1); funnel_wall_2d(1); }
            for (s = [-1, 1])
                translate([0, s*(channel_w/2 + funnel_end_t/2), 0])
                    xz_extrude(funnel_end_t) hull() { funnel_wall_2d(-1); funnel_wall_2d(1); }
        }
        xz_extrude(plate_gap + 2) roller_keepout_2d();
        // M3 x 10 screws through the plate into the end caps (blind, so no tip in the channel)
        for (s = [-1, 1], h = funnel_holes)
            translate([h[0], s*plate_gap/2, h[1]])
                rotate([90, 0, 0]) cylinder(d = m3_tap, h = 2*funnel_end_t - 1, center = true);
    }
}

// Drop into each end of the channel to center 57/58 mm paper.
shim_w = (channel_w - (paper_min_w + 2*edge_clearance))/2;
module width_shim_2d() {
    offset(delta = -0.2) intersection() {
        polygon([[-throat_gap/2, throat_h], [throat_gap/2, throat_h],
                 [funnel_mouth/2, funnel_top], [-funnel_mouth/2, funnel_top]]);
        translate([-50, throat_h + 4]) square([100, 100]);
    }
    translate([-(funnel_mouth/2 + funnel_wall), funnel_top])   // lip hangs on the rim
        square([funnel_mouth + 2*funnel_wall, 2]);
}
module width_shim() linear_extrude(shim_w) width_shim_2d();

// ---------------------------------------------------------------------
//  Camera mount (assembly coordinates; printed bar-face down)
//  A bar spans plate to plate (2 x M3 per side into slots), with a holder
//  plate and 4 standoffs for the Module 3 board (M2 self-tapping).
// ---------------------------------------------------------------------
module camera_mount() {
    difference() {
        union() {
            translate([cam_bx0, -plate_gap/2 + 0.2, cam_mz0])
                cube([cam_bar_t, plate_gap - 0.4, cam_mz1 - cam_mz0]);
            translate([cam_bx1, -(cam_board_w/2 + 3), cam_mz0])
                cube([cam_holder_t, cam_board_w + 6, cam_mz1 - cam_mz0]);
            for (h = cam_holes) translate([cam_hx - 0.01, h[0], h[1]])
                rotate([0, 90, 0]) cylinder(d = 5, h = cam_standoff + 0.01);
        }
        for (h = cam_holes) translate([cam_bx1 - 1, h[0], h[1]])
            rotate([0, 90, 0]) cylinder(d = m2_tap, h = cam_holder_t + cam_standoff + 2, $fn = 24);
        for (s = [-1, 1], z = cam_slot_z)
            translate([cam_slot_x, s*plate_gap/2, z])
                rotate([90, 0, 0]) cylinder(d = m3_tap, h = 16, center = true);
    }
}

module camera_board() {   // visual only
    color("ForestGreen") translate([cam_xb, -cam_board_w/2, cam_zbot]) cube([1, cam_board_w, cam_board_h]);
    color("#222") translate([cam_xb + 1, 0, cam_zc]) rotate([0, 90, 0]) cylinder(d = 9, h = cam_depth - 1);
    color("Goldenrod") translate([cam_xb - 0.5, -8, cam_zbot - 20]) cube([0.2, 16, 20]);
}

module camera_fov() {     // visual only
    color("Yellow", 0.15) hull() {
        translate([cam_xl, 0, cam_zc]) cube(0.2, center = true);
        translate([-0.35, 0, cam_zc]) cube([0.1, cam_cover_w, cam_cover_h], center = true);
    }
    color("Lime", 0.8) translate([-0.3, -paper_max_w/2, strip_lo]) cube([0.1, paper_max_w, strip_h]);
}

// ---------------------------------------------------------------------
//  Small parts
// ---------------------------------------------------------------------
module spacer()     difference() { cylinder(d = spacer_od, h = plate_gap); translate([0,0,-1]) cylinder(d = m5_clear, h = plate_gap + 2); }
// 1 mm spacer between plate A's bearing and each driven pulley (touches the inner ring only)
module pulley_shim() difference() { cylinder(d = 12, h = 1); translate([0,0,-1]) cylinder(d = shaft_d + 0.4, h = 3); }
module hub_washer() difference() { cylinder(d = 12, h = washer_t);  translate([0,0,-1]) cylinder(d = shaft_d + 0.4, h = washer_t + 2); }

// ---------------------------------------------------------------------
//  Assembly preview
// ---------------------------------------------------------------------
module along_y(x, z, y0 = 0) translate([x, y0, z]) rotate([90, 0, 0]) children();

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


module belt_2d() {
    pts = [[drv_x, nips[0]], [drv_x, nips[1]], [motor_x, motor_z]];
    difference() {
        offset(r = 1.4) hull() for (p = pts) translate(p) circle(d = pulley_pd);
        hull() for (p = pts) translate(p) circle(d = pulley_pd);
    }
}

module assembly() {
    if (show_plates) color("BurlyWood")
        for (s = [-1, 1]) translate([0, s*(plate_gap/2 + plate_t/2), 0]) xz_extrude(plate_t) side_plate_2d();

    color("SteelBlue") funnel();

    for (z = nips) {
        color("DimGray") along_y(drv_x, z, roller_len/2) driven_roller();
        color("LightGray") along_y(idl_x, z, roller_len/2) idler_roller();
    }

    color("Orange")
        for (i = [0 : 1], s = [-1, 1])
            translate([idl_x, s*(plate_gap/2 + plate_t + 0.5 + arm_t/2), nips[i]])
                scale([1, 1, arm_dir[i]]) rotate([90, 0, 0])
                    translate([0, 0, -arm_t/2]) idler_arm();

    color("Tan") for (p = spacers) along_y(p[0], p[1], plate_gap/2) spacer();

    if (show_shims) color("Tomato")
        for (s = [-1, 1]) translate([0, s*(channel_w/2 - shim_w/2), 0]) xz_extrude(shim_w) width_shim_2d();

    if (show_hardware) {
        // springs: arm tail -> anchor screw, outside both plates
        for (i = [0 : 1], s = [-1, 1]) {
            ya = s*(plate_gap/2 + plate_t + 0.5 + arm_t/2);
            anc = [idl_x + anchor_offsets[spring_anchor], tail(i)[1]];
            color("Teal") coil_spring([tail(i)[0], ya, tail(i)[1]], [anc[0], ya, anc[1]]);
            color("DimGray") translate([anc[0], s*(plate_gap/2 + plate_t), anc[1]]) rotate([-s*90, 0, 0]) {
                cylinder(d = 3, h = arm_t + 4, $fn = 16);
                translate([0, 0, arm_t + 4]) cylinder(d = 5.5, h = 3, $fn = 16);
            }
        }
        pulley_y = -(plate_gap/2 + plate_t + 2 + pulley_len/2);
        belt_y   = -(plate_gap/2 + plate_t + 2 + (pulley_hub_in ? pulley_hub_len + 1 : 1) + 3.5);   // centre of the teeth
        color("Silver") {
            for (z = nips) {
                along_y(drv_x, z, plate_gap/2 + plate_t + 2)
                    cylinder(d = shaft_d, h = driven_shaft_len);
                along_y(idl_x, z, idler_rod_len/2) cylinder(d = shaft_d, h = idler_rod_len);
            }
            for (p = [[drv_x, nips[0]], [drv_x, nips[1]], [motor_x, motor_z]])
                along_y(p[0], p[1], pulley_y + pulley_len/2) cylinder(d = pulley_pd + 1.5, h = pulley_len);
        }
        color("Black") translate([0, belt_y, 0]) xz_extrude(6) belt_2d();
        color("#333") translate([motor_x - 21, -plate_gap/2, motor_z - 21]) cube([42, 40, 42]);
    }

    if (show_camera) { color("MediumPurple") camera_mount(); camera_board(); }
    if (show_fov) camera_fov();

    if (show_paper) color("White", 0.85)
        translate([-0.05, -paper_max_w/2, -80]) cube([0.1, paper_max_w, funnel_top + 95]);
}

// ---------------------------------------------------------------------
//  Part dispatch (print / cut orientation)
// ---------------------------------------------------------------------
if      (part == "assembly")      assembly();
else if (part == "side_plate")    side_plate();
else if (part == "side_plate_2d") side_plate_2d();              // export DXF/SVG for the laser
else if (part == "fit_coupon_2d")          fit_coupon_2d();            // laser fit test
else if (part == "fit_coupon_cnc_inner")   fit_coupon_cnc_inner();     // CNC fit test, pass 1
else if (part == "fit_coupon_cnc_outline") fit_coupon_cnc_outline();   // CNC fit test, pass 2
else if (part == "side_plate_cnc_inner")   side_plate_cnc_inner();     // CNC pass 1: holes + slots
else if (part == "side_plate_cnc_outline") side_plate_cnc_outline();   // CNC pass 2: outline, with tabs
else if (part == "funnel")        translate([0, 0, plate_gap/2]) rotate([90, 0, 0]) funnel();
else if (part == "driven_roller") driven_roller();
else if (part == "idler_roller")  idler_roller();
else if (part == "idler_arm")     idler_arm();
else if (part == "spacer")        spacer();
else if (part == "hub_washer")    hub_washer();
else if (part == "width_shim")    width_shim();
else if (part == "pulley_shim")   pulley_shim();
else if (part == "camera_mount")  translate([0, 0, -cam_bx0]) rotate([0, -90, 0]) camera_mount();
