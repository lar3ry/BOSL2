//////////////////////////////////////////////////////////////////////
// LibFile: geometry.scad
//   Geometry helpers.
//   To use, add the following lines to the beginning of your file:
//   ```
//   use <BOSL2/std.scad>
//   ```
//////////////////////////////////////////////////////////////////////


// Section: Lines, Rays, and Segments

// Function: point_on_segment2d()
// Usage:
//   point_on_segment2d(point, edge);
// Description:
//   Determine if the point is on the line segment between two points.
//   Returns true if yes, and false if not.
// Arguments:
//   point = The point to test.
//   edge = Array of two points forming the line segment to test against.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function point_on_segment2d(point, edge, eps=EPSILON) =
    approx(point,edge[0],eps=eps) || approx(point,edge[1],eps=eps) ||  // The point is an endpoint
    sign(edge[0].x-point.x)==sign(point.x-edge[1].x)  // point is in between the
        && sign(edge[0].y-point.y)==sign(point.y-edge[1].y)  // edge endpoints
        && approx(point_left_of_segment2d(point, edge),0,eps=eps);  // and on the line defined by edge


// Function: point_left_of_segment2d()
// Usage:
//   point_left_of_segment2d(point, edge);
// Description:
//   Return >0 if point is left of the line defined by edge.
//   Return =0 if point is on the line.
//   Return <0 if point is right of the line.
// Arguments:
//   point = The point to check position of.
//   edge = Array of two points forming the line segment to test against.
function point_left_of_segment2d(point, edge) =
    (edge[1].x-edge[0].x) * (point.y-edge[0].y) - (point.x-edge[0].x) * (edge[1].y-edge[0].y);


// Internal non-exposed function.
function _point_above_below_segment(point, edge) =
    edge[0].y <= point.y? (
        (edge[1].y > point.y && point_left_of_segment2d(point, edge) > 0)? 1 : 0
    ) : (
        (edge[1].y <= point.y && point_left_of_segment2d(point, edge) < 0)? -1 : 0
    );


// Function: collinear()
// Usage:
//   collinear(a, b, c, [eps]);
// Description:
//   Returns true if three points are co-linear.
// Arguments:
//   a = First point.
//   b = Second point.
//   c = Third point.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function collinear(a, b, c, eps=EPSILON) =
    approx(a,b,eps=eps)? true :
    distance_from_line([a,b], c) < eps;


// Function: collinear_indexed()
// Usage:
//   collinear_indexed(points, a, b, c, [eps]);
// Description:
//   Returns true if three points are co-linear.
// Arguments:
//   points = A list of points.
//   a = Index in `points` of first point.
//   b = Index in `points` of second point.
//   c = Index in `points` of third point.
//   eps = Acceptable max angle variance.  Default: EPSILON (1e-9) degrees.
function collinear_indexed(points, a, b, c, eps=EPSILON) =
    let(
        p1=points[a],
        p2=points[b],
        p3=points[c]
    ) collinear(p1, p2, p3, eps);


// Function: points_are_collinear()
// Usage:
//   points_are_collinear(points);
// Description:
//   Given a list of points, returns true if all points in the list are collinear.
// Arguments:
//   points = The list of points to test.
//   eps = How much variance is allowed in testing that each point is on the same line.  Default: `EPSILON` (1e-9)
function points_are_collinear(points, eps=EPSILON) =
    let(
        a = furthest_point(points[0], points),
        b = furthest_point(points[a], points),
        pa = points[a],
        pb = points[b]
    ) all([for (pt = points) collinear(pa, pb, pt, eps=eps)]);


// Function: distance_from_line()
// Usage:
//   distance_from_line(line, pt);
// Description:
//   Finds the perpendicular distance of a point `pt` from the line `line`.
// Arguments:
//   line = A list of two points, defining a line that both are on.
//   pt = A point to find the distance of from the line.
// Example:
//   distance_from_line([[-10,0], [10,0]], [3,8]);  // Returns: 8
function distance_from_line(line, pt) =
    let(a=line[0], n=unit(line[1]-a), d=a-pt)
    norm(d - ((d * n) * n));


// Function: line_normal()
// Usage:
//   line_normal([P1,P2])
//   line_normal(p1,p2)
// Description:
//   Returns the 2D normal vector to the given 2D line. This is otherwise known as the perpendicular vector counter-clockwise to the given ray.
// Arguments:
//   p1 = First point on 2D line.
//   p2 = Second point on 2D line.
// Example(2D):
//   p1 = [10,10];
//   p2 = [50,30];
//   n = line_normal(p1,p2);
//   stroke([p1,p2], endcap2="arrow2");
//   color("green") stroke([p1,p1+10*n], endcap2="arrow2");
//   color("blue") move_copies([p1,p2]) circle(d=2, $fn=12);
function line_normal(p1,p2) =
    is_undef(p2)? line_normal(p1[0],p1[1]) :
    unit([p1.y-p2.y,p2.x-p1.x]);


// 2D Line intersection from two segments.
// This function returns [p,t,u] where p is the intersection point of
// the lines defined by the two segments, t is the proportional distance
// of the intersection point along s1, and u is the proportional distance
// of the intersection point along s2.  The proportional values run over
// the range of 0 to 1 for each segment, so if it is in this range, then
// the intersection lies on the segment.  Otherwise it lies somewhere on
// the extension of the segment.  Result is undef for coincident lines.
function _general_line_intersection(s1,s2,eps=EPSILON) =
    let(
        denominator = det2([s1[0],s2[0]]-[s1[1],s2[1]])
    ) approx(denominator,0,eps=eps)? [undef,undef,undef] : let(
        t = det2([s1[0],s2[0]]-s2) / denominator,
        u = det2([s1[0],s1[0]]-[s2[0],s1[1]]) / denominator
    ) [s1[0]+t*(s1[1]-s1[0]), t, u];


// Function: line_intersection()
// Usage:
//   line_intersection(l1, l2);
// Description:
//   Returns the 2D intersection point of two unbounded 2D lines.
//   Returns `undef` if the lines are parallel.
// Arguments:
//   l1 = First 2D line, given as a list of two 2D points on the line.
//   l2 = Second 2D line, given as a list of two 2D points on the line.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function line_intersection(l1,l2,eps=EPSILON) =
    let(isect = _general_line_intersection(l1,l2,eps=eps)) isect[0];


// Function: line_ray_intersection()
// Usage:
//   line_ray_intersection(line, ray);
// Description:
//   Returns the 2D intersection point of an unbounded 2D line, and a half-bounded 2D ray.
//   Returns `undef` if they do not intersect.
// Arguments:
//   line = The unbounded 2D line, defined by two 2D points on the line.
//   ray = The 2D ray, given as a list `[START,POINT]` of the 2D start-point START, and a 2D point POINT on the ray.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function line_ray_intersection(line,ray,eps=EPSILON) =
    let(
        isect = _general_line_intersection(line,ray,eps=eps)
    ) isect[2]<0-eps? undef : isect[0];


// Function: line_segment_intersection()
// Usage:
//   line_segment_intersection(line, segment);
// Description:
//   Returns the 2D intersection point of an unbounded 2D line, and a bounded 2D line segment.
//   Returns `undef` if they do not intersect.
// Arguments:
//   line = The unbounded 2D line, defined by two 2D points on the line.
//   segment = The bounded 2D line segment, given as a list of the two 2D endpoints of the segment.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function line_segment_intersection(line,segment,eps=EPSILON) =
    let(
        isect = _general_line_intersection(line,segment,eps=eps)
    ) isect[2]<0-eps || isect[2]>1+eps ? undef : isect[0];


// Function: ray_intersection()
// Usage:
//   ray_intersection(s1, s2);
// Description:
//   Returns the 2D intersection point of two 2D line rays.
//   Returns `undef` if they do not intersect.
// Arguments:
//   r1 = First 2D ray, given as a list `[START,POINT]` of the 2D start-point START, and a 2D point POINT on the ray.
//   r2 = Second 2D ray, given as a list `[START,POINT]` of the 2D start-point START, and a 2D point POINT on the ray.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function ray_intersection(r1,r2,eps=EPSILON) =
    let(
        isect = _general_line_intersection(r1,r2,eps=eps)
    ) isect[1]<0-eps || isect[2]<0-eps? undef : isect[0];


// Function: ray_segment_intersection()
// Usage:
//   ray_segment_intersection(ray, segment);
// Description:
//   Returns the 2D intersection point of a half-bounded 2D ray, and a bounded 2D line segment.
//   Returns `undef` if they do not intersect.
// Arguments:
//   ray = The 2D ray, given as a list `[START,POINT]` of the 2D start-point START, and a 2D point POINT on the ray.
//   segment = The bounded 2D line segment, given as a list of the two 2D endpoints of the segment.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function ray_segment_intersection(ray,segment,eps=EPSILON) =
    let(
        isect = _general_line_intersection(ray,segment,eps=eps)
    ) isect[1]<0-eps || isect[2]<0-eps || isect[2]>1+eps ? undef : isect[0];


// Function: segment_intersection()
// Usage:
//   segment_intersection(s1, s2);
// Description:
//   Returns the 2D intersection point of two 2D line segments.
//   Returns `undef` if they do not intersect.
// Arguments:
//   s1 = First 2D segment, given as a list of the two 2D endpoints of the line segment.
//   s2 = Second 2D segment, given as a list of the two 2D endpoints of the line segment.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function segment_intersection(s1,s2,eps=EPSILON) =
    let(
        isect = _general_line_intersection(s1,s2,eps=eps)
    ) isect[1]<0-eps || isect[1]>1+eps || isect[2]<0-eps || isect[2]>1+eps ? undef : isect[0];


// Function: line_closest_point()
// Usage:
//   line_closest_point(line,pt);
// Description:
//   Returns the point on the given `line` that is closest to the given point `pt`.
// Arguments:
//   line = A list of two points that are on the unbounded line.
//   pt = The point to find the closest point on the line to.
function line_closest_point(line,pt) =
    let(
        n = line_normal(line),
        isect = _general_line_intersection(line,[pt,pt+n])
    ) isect[0];


// Function: segment_closest_point()
// Usage:
//   segment_closest_point(seg,pt);
// Description:
//   Returns the point on the given line segment `seg` that is closest to the given point `pt`.
// Arguments:
//   seg = A list of two points that are the endpoints of the bounded line segment.
//   pt = The point to find the closest point on the segment to.
function segment_closest_point(seg,pt) =
    let(
        n = line_normal(seg),
        isect = _general_line_intersection(seg,[pt,pt+n])
    )
    norm(n)==0? seg[0] :
    isect[1]<=0? seg[0] :
    isect[1]>=1? seg[1] :
    isect[0];


// Section: 2D Triangles

// Function: tri_calc()
// Usage:
//   tri_calc(ang,ang2,adj,opp,hyp);
// Description:
//   Given a side length and an angle, or two side lengths, calculates the rest of the side lengths
//   and angles of a right triangle.  Returns [ADJACENT, OPPOSITE, HYPOTENUSE, ANGLE, ANGLE2] where
//   ADJACENT is the length of the side adjacent to ANGLE, and OPPOSITE is the length of the side
//   opposite of ANGLE and adjacent to ANGLE2.  ANGLE and ANGLE2 are measured in degrees.
//   This is certainly more verbose and slower than writing your own calculations, but has the nice
//   benefit that you can just specify the info you have, and don't have to figure out which trig
//   formulas you need to use.
// Figure(2D):
//   color("#ccc") {
//       stroke(closed=false, width=0.5, [[45,0], [45,5], [50,5]]);
//       stroke(closed=false, width=0.5, arc(N=6, r=15, cp=[0,0], start=0, angle=30));
//       stroke(closed=false, width=0.5, arc(N=6, r=14, cp=[50,30], start=212, angle=58));
//   }
//   color("black") stroke(closed=true, [[0,0], [50,30], [50,0]]);
//   color("#0c0") {
//       translate([10.5,2.5]) text(size=3,text="ang",halign="center",valign="center");
//       translate([44.5,22]) text(size=3,text="ang2",halign="center",valign="center");
//   }
//   color("blue") {
//       translate([25,-3]) text(size=3,text="Adjacent",halign="center",valign="center");
//       translate([53,15]) rotate(-90) text(size=3,text="Opposite",halign="center",valign="center");
//       translate([25,18]) rotate(30) text(size=3,text="Hypotenuse",halign="center",valign="center");
//   }
// Arguments:
//   ang = The angle in degrees of the primary corner of the triangle.
//   ang2 = The angle in degrees of the other non-right corner of the triangle.
//   adj = The length of the side adjacent to the primary corner.
//   opp = The length of the side opposite to the primary corner.
//   hyp = The length of the hypotenuse.
// Example:
//   tri = tri_calc(opp=15,hyp=30);
//   echo(adjacent=tri[0], opposite=tri[1], hypotenuse=tri[2], angle=tri[3], angle2=tri[4]);
// Examples:
//   adj = tri_calc(ang=30,opp=10)[0];
//   opp = tri_calc(ang=20,hyp=30)[1];
//   hyp = tri_calc(ang2=50,adj=20)[2];
//   ang = tri_calc(adj=20,hyp=30)[3];
//   ang2 = tri_calc(adj=20,hyp=40)[4];
function tri_calc(ang,ang2,adj,opp,hyp) =
    assert(ang==undef || ang2==undef,"You cannot specify both ang and ang2.")
    assert(num_defined([ang,ang2,adj,opp,hyp])==2, "You must specify exactly two arguments.")
    let(
        ang = ang!=undef? assert(ang>0&&ang<90) ang :
            ang2!=undef? (90-ang2) :
            adj==undef? asin(constrain(opp/hyp,-1,1)) :
            opp==undef? acos(constrain(adj/hyp,-1,1)) :
            atan2(opp,adj),
        ang2 = ang2!=undef? assert(ang2>0&&ang2<90) ang2 : (90-ang),
        adj = adj!=undef? assert(adj>0) adj :
            (opp!=undef? (opp/tan(ang)) : (hyp*cos(ang))),
        opp = opp!=undef? assert(opp>0) opp :
            (adj!=undef? (adj*tan(ang)) : (hyp*sin(ang))),
        hyp = hyp!=undef? assert(hyp>0) assert(adj<hyp) assert(opp<hyp) hyp :
            (adj!=undef? (adj/cos(ang)) : (opp/sin(ang)))
    )
    [adj, opp, hyp, ang, ang2];


// Function: hyp_opp_to_adj()
// Usage:
//   adj = hyp_opp_to_adj(hyp,opp);
// Description:
//   Given the lengths of the hypotenuse and opposite side of a right triangle, returns the length
//   of the adjacent side.
// Arguments:
//   hyp = The length of the hypotenuse of the right triangle.
//   opp = The length of the side of the right triangle that is opposite from the primary angle.
// Example:
//   hyp = hyp_opp_to_adj(5,3);  // Returns: 4
function hyp_opp_to_adj(hyp,opp) =
    assert(is_num(hyp)&&hyp>=0)
    assert(is_num(opp)&&opp>=0)
    sqrt(hyp*hyp-opp*opp);


// Function: hyp_ang_to_adj()
// Usage:
//   adj = hyp_ang_to_adj(hyp,ang);
// Description:
//   Given the length of the hypotenuse and the angle of the primary corner of a right triangle,
//   returns the length of the adjacent side.
// Arguments:
//   hyp = The length of the hypotenuse of the right triangle.
//   ang = The angle in degrees of the primary corner of the right triangle.
// Example:
//   adj = hyp_ang_to_adj(8,60);  // Returns: 4
function hyp_ang_to_adj(hyp,ang) =
    assert(is_num(hyp)&&hyp>=0)
    assert(is_num(ang)&&ang>0&&ang<90)
    hyp*cos(ang);


// Function: opp_ang_to_adj()
// Usage:
//   adj = opp_ang_to_adj(opp,ang);
// Description:
//   Given the angle of the primary corner of a right triangle, and the length of the side opposite of it,
//   returns the length of the adjacent side.
// Arguments:
//   opp = The length of the side of the right triangle that is opposite from the primary angle.
//   ang = The angle in degrees of the primary corner of the right triangle.
// Example:
//   adj = opp_ang_to_adj(8,30);  // Returns: 4
function opp_ang_to_adj(opp,ang) =
    assert(is_num(opp)&&opp>=0)
    assert(is_num(ang)&&ang>0&&ang<90)
    opp/tan(ang);


// Function: hyp_adj_to_opp()
// Usage:
//   opp = hyp_adj_to_opp(hyp,adj);
// Description:
//   Given the length of the hypotenuse and the adjacent side, returns the length of the opposite side.
// Arguments:
//   hyp = The length of the hypotenuse of the right triangle.
//   adj = The length of the side of the right triangle that is adjacent to the primary angle.
// Example:
//   opp = hyp_adj_to_opp(5,4);  // Returns: 3
function hyp_adj_to_opp(hyp,adj) =
    assert(is_num(hyp)&&hyp>=0)
    assert(is_num(adj)&&adj>=0)
    sqrt(hyp*hyp-adj*adj);


// Function: hyp_ang_to_opp()
// Usage:
//   opp = hyp_ang_to_opp(hyp,adj);
// Description:
//   Given the length of the hypotenuse of a right triangle, and the angle of the corner, returns the length of the opposite side.
// Arguments:
//   hyp = The length of the hypotenuse of the right triangle.
//   ang = The angle in degrees of the primary corner of the right triangle.
// Example:
//   opp = hyp_ang_to_opp(8,30);  // Returns: 4
function hyp_ang_to_opp(hyp,ang) =
    assert(is_num(hyp)&&hyp>=0)
    assert(is_num(ang)&&ang>0&&ang<90)
    hyp*sin(ang);


// Function: adj_ang_to_opp()
// Usage:
//   opp = adj_ang_to_opp(adj,ang);
// Description:
//   Given the length of the adjacent side of a right triangle, and the angle of the corner, returns the length of the opposite side.
// Arguments:
//   adj = The length of the side of the right triangle that is adjacent to the primary angle.
//   ang = The angle in degrees of the primary corner of the right triangle.
// Example:
//   opp = adj_ang_to_opp(8,45);  // Returns: 8
function adj_ang_to_opp(adj,ang) =
    assert(is_num(adj)&&adj>=0)
    assert(is_num(ang)&&ang>0&&ang<90)
    adj*tan(ang);


// Function: adj_opp_to_hyp()
// Usage:
//   hyp = adj_opp_to_hyp(adj,opp);
// Description:
//   Given the length of the adjacent and opposite sides of a right triangle, returns the length of thee hypotenuse.
// Arguments:
//   adj = The length of the side of the right triangle that is adjacent to the primary angle.
//   opp = The length of the side of the right triangle that is opposite from the primary angle.
// Example:
//   hyp = adj_opp_to_hyp(3,4);  // Returns: 5
function adj_opp_to_hyp(adj,opp) =
    assert(is_num(adj)&&adj>=0)
    assert(is_num(opp)&&opp>=0)
    norm([opp,adj]);


// Function: adj_ang_to_hyp()
// Usage:
//   hyp = adj_ang_to_hyp(adj,ang);
// Description:
//   For a right triangle, given the length of the adjacent side, and the corner angle, returns the length of the hypotenuse.
// Arguments:
//   adj = The length of the side of the right triangle that is adjacent to the primary angle.
//   ang = The angle in degrees of the primary corner of the right triangle.
// Example:
//   hyp = adj_ang_to_hyp(4,60);  // Returns: 8
function adj_ang_to_hyp(adj,ang) =
    assert(is_num(adj)&&adj>=0)
    assert(is_num(ang)&&ang>=0&&ang<90)
    adj/cos(ang);


// Function: opp_ang_to_hyp()
// Usage:
//   hyp = opp_ang_to_hyp(opp,ang);
// Description:
//   For a right triangle, given the length of the opposite side, and the corner angle, returns the length of the hypotenuse.
// Arguments:
//   opp = The length of the side of the right triangle that is opposite from the primary angle.
//   ang = The angle in degrees of the primary corner of the right triangle.
// Example:
//   hyp = opp_ang_to_hyp(4,30);  // Returns: 8
function opp_ang_to_hyp(opp,ang) =
    assert(is_num(opp)&&opp>=0)
    assert(is_num(ang)&&ang>0&&ang<=90)
    opp/sin(ang);


// Function: hyp_adj_to_ang()
// Usage:
//   ang = hyp_adj_to_ang(hyp,adj);
// Description:
//   For a right triangle, given the lengths of the hypotenuse and the adjacent sides, returns the angle of the corner.
// Arguments:
//   hyp = The length of the hypotenuse of the right triangle.
//   adj = The length of the side of the right triangle that is adjacent to the primary angle.
// Example:
//   ang = hyp_adj_to_ang(8,4);  // Returns: 60 degrees
function hyp_adj_to_ang(hyp,adj) =
    assert(is_num(hyp)&&hyp>0)
    assert(is_num(adj)&&adj>=0)
    acos(adj/hyp);


// Function: hyp_opp_to_ang()
// Usage:
//   ang = hyp_opp_to_ang(hyp,opp);
// Description:
//   For a right triangle, given the lengths of the hypotenuse and the opposite sides, returns the angle of the corner.
// Arguments:
//   hyp = The length of the hypotenuse of the right triangle.
//   opp = The length of the side of the right triangle that is opposite from the primary angle.
// Example:
//   ang = hyp_opp_to_ang(8,4);  // Returns: 30 degrees
function hyp_opp_to_ang(hyp,opp) =
    assert(is_num(hyp)&&hyp>0)
    assert(is_num(opp)&&opp>=0)
    asin(opp/hyp);


// Function: adj_opp_to_ang()
// Usage:
//   ang = adj_opp_to_ang(adj,opp);
// Description:
//   For a right triangle, given the lengths of the adjacent and opposite sides, returns the angle of the corner.
// Arguments:
//   adj = The length of the side of the right triangle that is adjacent to the primary angle.
//   opp = The length of the side of the right triangle that is opposite from the primary angle.
// Example:
//   ang = adj_opp_to_ang(sqrt(3)/2,0.5);  // Returns: 30 degrees
function adj_opp_to_ang(adj,opp) =
    assert(is_num(adj)&&adj>=0)
    assert(is_num(opp)&&opp>=0)
    atan2(opp,adj);


// Function: triangle_area()
// Usage:
//   triangle_area(a,b,c);
// Description:
//   Returns the area of a triangle formed between three 2D or 3D vertices.
//   Result will be negative if the points are 2D and in clockwise order.
// Examples:
//   triangle_area([0,0], [5,10], [10,0]);  // Returns -50
//   triangle_area([10,0], [5,10], [0,0]);  // Returns 50
function triangle_area(a,b,c) =
    len(a)==3? 0.5*norm(cross(c-a,c-b)) : (
        a.x * (b.y - c.y) +
        b.x * (c.y - a.y) +
        c.x * (a.y - b.y)
    ) / 2;



// Section: Planes

// Function: plane3pt()
// Usage:
//   plane3pt(p1, p2, p3);
// Description:
//   Generates the cartesian equation of a plane from three non-collinear points on the plane.
//   Returns [A,B,C,D] where Ax + By + Cz = D is the equation of a plane.
// Arguments:
//   p1 = The first point on the plane.
//   p2 = The second point on the plane.
//   p3 = The third point on the plane.
function plane3pt(p1, p2, p3) =
    let(
        p1=point3d(p1),
        p2=point3d(p2),
        p3=point3d(p3),
        normal = unit(cross(p3-p1, p2-p1))
    ) concat(normal, [normal*p1]);


// Function: plane3pt_indexed()
// Usage:
//   plane3pt_indexed(points, i1, i2, i3);
// Description:
//   Given a list of points, and the indices of three of those points,
//   generates the cartesian equation of a plane that those points all
//   lie on.  Requires that the three indexed points be non-collinear.
//   Returns [A,B,C,D] where Ax+By+Cz=D is the equation of a plane.
// Arguments:
//   points = A list of points.
//   i1 = The index into `points` of the first point on the plane.
//   i2 = The index into `points` of the second point on the plane.
//   i3 = The index into `points` of the third point on the plane.
function plane3pt_indexed(points, i1, i2, i3) =
    let(
        p1 = points[i1],
        p2 = points[i2],
        p3 = points[i3]
    ) plane3pt(p1,p2,p3);


// Function: plane_from_normal()
// Usage:
//   plane_from_normal(normal, [pt])
// Description:
//   Returns a plane defined by a normal vector and a point.
// Example:
//   plane_from_normal([0,0,1], [2,2,2]);  // Returns the xy plane passing through the point (2,2,2)
function plane_from_normal(normal, pt=[0,0,0]) =
  concat(normal, [normal*pt]);


// Function: plane_from_points()
// Usage:
//   plane_from_points(points, [fast], [eps]);
// Description:
//   Given a list of 3 or more coplanar points, returns the cartesian equation of a plane.
//   Returns [A,B,C,D] where Ax+By+Cz=D is the equation of the plane.
//   If not all the points in the points list are coplanar, then `undef` is returned.
//   If `fast` is true, then a list where not all points are coplanar will result
//   in an invalid plane value, as all coplanar checks are skipped.
// Arguments:
//   points = The list of points to find the plane of.
//   fast = If true, don't verify that all points in the list are coplanar.  Default: false
//   eps = How much variance is allowed in testing that each point is on the same plane.  Default: `EPSILON` (1e-9)
// Example(3D):
//   xyzpath = rot(45, v=[-0.3,1,0], p=path3d(star(n=6,id=70,d=100), 70));
//   plane = plane_from_points(xyzpath);
//   #stroke(xyzpath,closed=true);
//   cp = centroid(xyzpath);
//   move(cp) rot(from=UP,to=plane_normal(plane)) anchor_arrow();
function plane_from_points(points, fast=false, eps=EPSILON) =
    let(
        points = deduplicate(points),
        indices = sort(find_noncollinear_points(points)),
        p1 = points[indices[0]],
        p2 = points[indices[1]],
        p3 = points[indices[2]],
        plane = plane3pt(p1,p2,p3),
        all_coplanar = fast || all([
            for (pt = points) coplanar(plane,pt,eps=eps)
        ])
    ) all_coplanar? plane : undef;


// Function: plane_from_polygon()
// Usage:
//   plane_from_polygon(points, [fast], [eps]);
// Description:
//   Given a 3D planar polygon, returns the cartesian equation of a plane.
//   Returns [A,B,C,D] where Ax+By+Cz=D is the equation of the plane.
//   If not all the points in the polygon are coplanar, then `undef` is returned.
//   If `fast` is true, then a polygon where not all points are coplanar will
//   result in an invalid plane value, as all coplanar checks are skipped.
// Arguments:
//   poly = The planar 3D polygon to find the plane of.
//   fast = If true, don't verify that all points in the polygon are coplanar.  Default: false
//   eps = How much variance is allowed in testing that each point is on the same plane.  Default: `EPSILON` (1e-9)
// Example(3D):
//   xyzpath = rot(45, v=[0,1,0], p=path3d(star(n=5,step=2,d=100), 70));
//   plane = plane_from_polygon(xyzpath);
//   #stroke(xyzpath,closed=true);
//   cp = centroid(xyzpath);
//   move(cp) rot(from=UP,to=plane_normal(plane)) anchor_arrow();
function plane_from_polygon(poly, fast=false, eps=EPSILON) =
    let(
        poly = deduplicate(poly),
        n = polygon_normal(poly),
        plane = [n.x, n.y, n.z, n*poly[0]]
    ) fast? plane : let(
        all_coplanar = [
            for (pt = poly)
            if (!coplanar(plane,pt,eps=eps)) 1
        ] == []
    ) all_coplanar? plane :
    undef;


// Function: plane_normal()
// Usage:
//   plane_normal(plane);
// Description:
//   Returns the unit length normal vector for the given plane.
function plane_normal(plane) = unit([for (i=[0:2]) plane[i]]);


// Function: plane_offset()
// Usage:
//   d = plane_offset(plane);
// Description:
//   Returns D, or the scalar offset of the plane from the origin. This can be a negative value.
//   The absolute value of this is the distance of the plane from the origin at its closest approach.
function plane_offset(plane) = plane[3];


// Function: plane_transform()
// Usage:
//   mat = plane_transform(plane);
// Description:
//   Given a plane definition `[A,B,C,D]`, where `Ax+By+Cz=D`, returns a 3D affine
//   transformation matrix that will rotate and translate from points on that plane
//   to points on the XY plane.  You can generally then use `path2d()` to drop the
//   Z coordinates, so you can work with the points in 2D.
// Arguments:
//   plane = The `[A,B,C,D]` plane definition where `Ax+By+Cz=D` is the formula of the plane.
// Example(3D):
//   xyzpath = move([10,20,30], p=yrot(25, p=path3d(circle(d=100))));
//   plane = plane_from_points(xyzpath);
//   mat = plane_transform(plane);
//   xypath = path2d(apply(mat, xyzpath));
//   #stroke(xyzpath,closed=true);
//   stroke(xypath,closed=true);
function plane_transform(plane) =
    let(
        n = plane_normal(plane),
        cp = n * plane[3]
    ) rot(from=n, to=UP) * move(-cp);


// Function: plane_point_nearest_origin()
// Usage:
//   pt = plane_point_nearest_origin(plane);
// Description:
//   Returns the point on the plane that is closest to the origin.
function plane_point_nearest_origin(plane) =
    plane_normal(plane) * plane[3];


// Function: distance_from_plane()
// Usage:
//   distance_from_plane(plane, point)
// Description:
//   Given a plane as [A,B,C,D] where the cartesian equation for that plane
//   is Ax+By+Cz=D, determines how far from that plane the given point is.
//   The returned distance will be positive if the point is in front of the
//   plane; on the same side of the plane as the normal of that plane points
//   towards.  If the point is behind the plane, then the distance returned
//   will be negative.  The normal of the plane is the same as [A,B,C].
// Arguments:
//   plane = The [A,B,C,D] values for the equation of the plane.
//   point = The point to test.
function distance_from_plane(plane, point) =
    [plane.x, plane.y, plane.z] * point3d(point) - plane[3];


// Function: closest_point_on_plane()
// Usage:
//   pt = closest_point_on_plane(plane, point);
// Description:
//   Takes a point, and a plane [A,B,C,D] where the equation of that plane is `Ax+By+Cz=D`.
//   Returns the coordinates of the closest point on that plane to the given `point`.
// Arguments:
//   plane = The [A,B,C,D] values for the equation of the plane.
//   point = The 3D point to find the closest point to.
function closest_point_on_plane(plane, point) =
    let(
        n = unit(plane_normal(plane)),
        d = distance_from_plane(plane, point)
    ) point - n*d;


// Returns [POINT, U] if line intersects plane at one point.
// Returns [LINE, undef] if the line is on the plane.
// Returns undef if line is parallel to, but not on the given plane.
function _general_plane_line_intersection(plane, line, eps=EPSILON) =
    let(
        p0 = line[0],
        p1 = line[1],
        n = plane_normal(plane),
        u = p1 - p0,
        d = n * u
    ) abs(d)<eps? (
        coplanar(plane, p0)? [line,undef] :  // Line on plane
        undef  // Line parallel to plane
    ) : let(
        v0 = closest_point_on_plane(plane, [0,0,0]),
        w = p0 - v0,
        s1 = (-n * w) / d,
        pt = s1 * u + p0
    ) [pt, s1];


// Function: plane_line_angle()
// Usage: plane_line_angle(plane,line)
// Description:
//   Compute the angle between a plane [A, B, C, D] and a line, specified as a pair of points [p1,p2].
//   The resulting angle is signed, with the sign positive if the vector p2-p1 lies on 
//   the same side of the plane as the plane's normal vector.  
function plane_line_angle(plane, line) =
    let(
        vect = line[1]-line[0],
        zplane = plane_normal(plane),
        sin_angle = vect*zplane/norm(zplane)/norm(vect)
    ) asin(constrain(sin_angle,-1,1));


// Function: plane_line_intersection()
// Usage:
//   pt = plane_line_intersection(plane, line, [eps]);
// Description:
//   Takes a line, and a plane [A,B,C,D] where the equation of that plane is `Ax+By+Cz=D`.
//   If `line` intersects `plane` at one point, then that intersection point is returned.
//   If `line` lies on `plane`, then the original given `line` is returned.
//   If `line` is parallel to, but not on `plane`, then `undef` is returned.
// Arguments:
//   plane = The [A,B,C,D] values for the equation of the plane.
//   line = A list of two 3D points that are on the line.
//   bounded = If false, the line is considered unbounded.  If true, it is treated as a bounded line segment.  If given as `[true, false]` or `[false, true]`, the boundedness of the points are specified individually, allowing the line to be treated as a half-bounded ray.  Default: false (unbounded)
//   eps = The epsilon error value to determine whether the line is too close to parallel to the plane.  Default: `EPSILON` (1e-9)
function plane_line_intersection(plane, line, bounded=false, eps=EPSILON) =
    assert(is_vector(plane)&&len(plane)==4, "Invalid plane value.")
    assert(is_path(line)&&len(line)==2, "Invalid line value.")
    assert(!approx(line[0],line[1]), "The two points defining the line must not be the same point.")
    let(
        bounded = is_list(bounded)? bounded : [bounded, bounded],
        res = _general_plane_line_intersection(plane, line, eps=eps)
    )
    is_undef(res)? undef :
    is_undef(res[1])? res[0] :
    bounded[0]&&res[1]<0? undef :
    bounded[1]&&res[1]>1? undef :
    res[0];


// Function: polygon_line_intersection()
// Usage:
//   pt = polygon_line_intersection(poly, line, [bounded], [eps]);
// Description:
//   Takes a possibly bounded line, and a 3D planar polygon, and finds their intersection point.
//   If the line is on the plane as the polygon, and intersects, then a list of 3D line
//   segments is returned, one for each section of the line that is inside the polygon.
//   If the line is not on the plane of the polygon, but intersects, then the 3D intersection
//   point is returned.  If the line does not intersect the polygon, then `undef` is returned.
// Arguments:
//   poly = The 3D planar polygon to find the intersection with.
//   line = A list of two 3D points that are on the line.
//   bounded = If false, the line is considered unbounded.  If true, it is treated as a bounded line segment.  If given as `[true, false]` or `[false, true]`, the boundedness of the points are specified individually, allowing the line to be treated as a half-bounded ray.  Default: false (unbounded)
//   eps = The epsilon error value to determine whether the line is too close to parallel to the plane.  Default: `EPSILON` (1e-9)
function polygon_line_intersection(poly, line, bounded=false, eps=EPSILON) =
    assert(is_path(poly))
    assert(is_path(line)&&len(line)==2)
    let(
        bounded = is_list(bounded)? bounded : [bounded, bounded],
        poly = deduplicate(poly),
        indices = sort(find_noncollinear_points(poly)),
        p1 = poly[indices[0]],
        p2 = poly[indices[1]],
        p3 = poly[indices[2]],
        plane = plane3pt(p1,p2,p3),
        res = _general_plane_line_intersection(plane, line, eps=eps)
    )
    is_undef(res)? undef :
    is_undef(res[1])? (
        let(
            // Line is on polygon plane.
            linevec = unit(line[1] - line[0]),
            lp1 = line[0] + (bounded[0]? 0 : -1000000) * linevec,
            lp2 = line[1] + (bounded[1]? 0 :  1000000) * linevec,
            poly2d = clockwise_polygon(project_plane(poly, p1, p2, p3)),
            line2d = project_plane([lp1,lp2], p1, p2, p3),
            parts = split_path_at_region_crossings(line2d, [poly2d], closed=false),
            inside = [
                for (part = parts)
                if (point_in_polygon(mean(part), poly2d)>0) part
            ]
        ) !inside? undef :
        let(
            isegs = [
                for (seg = inside)
                lift_plane(seg, p1, p2, p3)
            ]
        ) isegs
    ) :
    bounded[0]&&res[1]<0? undef :
    bounded[1]&&res[1]>1? undef :
    let(
        proj = clockwise_polygon(project_plane(poly, p1, p2, p3)),
        pt = project_plane(res[0], p1, p2, p3)
    ) point_in_polygon(pt, proj) < 0? undef :
    res[0];


// Function: plane_intersection()
// Usage:
//   plane_intersection(plane1, plane2, [plane3])
// Description:
//   Compute the point which is the intersection of the three planes, or the line intersection of two planes.
//   If you give three planes the intersection is returned as a point.  If you give two planes the intersection
//   is returned as a list of two points on the line of intersection.  If any of the input planes are parallel
//   then returns undef.  
function plane_intersection(plane1,plane2,plane3) =
    is_def(plane3)? let(
        matrix = [for(p=[plane1,plane2,plane3]) select(p,0,2)],
        rhs = [for(p=[plane1,plane2,plane3]) p[3]]
    ) linear_solve(matrix,rhs) :
    let(
        normal = cross(plane_normal(plane1), plane_normal(plane2))
    ) approx(norm(normal),0) ? undef :
    let(
        matrix = [for(p=[plane1,plane2]) select(p,0,2)],
        rhs = [for(p=[plane1,plane2]) p[3]],
        point = linear_solve(matrix,rhs)
    ) is_undef(point)? undef :
    [point, point+normal];


// Function: coplanar()
// Usage:
//   coplanar(plane, point);
// Description:
//   Given a plane as [A,B,C,D] where the cartesian equation for that plane
//   is Ax+By+Cz=D, determines if the given point is on that plane.
//   Returns true if the point is on that plane.
// Arguments:
//   plane = The [A,B,C,D] values for the equation of the plane.
//   point = The point to test.
//   eps = How much variance is allowed in testing that each point is on the same plane.  Default: `EPSILON` (1e-9)
function coplanar(plane, point, eps=EPSILON) =
    abs(distance_from_plane(plane, point)) <= eps;


// Function: points_are_coplanar()
// Usage:
//   points_are_coplanar(points, [eps]);
// Description:
//   Given a list of points, returns true if all points in the list are coplanar.
// Arguments:
//   points = The list of points to test.
//   eps = How much variance is allowed in testing that each point is on the same plane.  Default: `EPSILON` (1e-9)
function points_are_coplanar(points, eps=EPSILON) =
    points_are_collinear(points, eps=eps)? true :
    let(
        plane = plane_from_points(points, fast=true, eps=eps)
    ) all([for (pt = points) coplanar(plane, pt, eps=eps)]);



// Function: in_front_of_plane()
// Usage:
//   in_front_of_plane(plane, point);
// Description:
//   Given a plane as [A,B,C,D] where the cartesian equation for that plane
//   is Ax+By+Cz=D, determines if the given point is on the side of that
//   plane that the normal points towards.  The normal of the plane is the
//   same as [A,B,C].
// Arguments:
//   plane = The [A,B,C,D] values for the equation of the plane.
//   point = The point to test.
function in_front_of_plane(plane, point) =
    distance_from_plane(plane, point) > EPSILON;



// Section: Circle Calculations

// Function: find_circle_2tangents()
// Usage:
//   find_circle_2tangents(pt1, pt2, pt3, r|d, [tangents]);
// Description:
//   Given a pair of rays with a common origin, and a known circle radius/diameter, finds
//   the centerpoint for the circle of that size that touches both rays tangentally.
//   Both rays start at `pt2`, one passing through `pt1`, and the other through `pt3`.
//   If the rays given are collinear, `undef` is returned.  Otherwise, if `tangents` is
//   true, then `[CP,NORMAL]` is returned.  If `tangents` is false, the more extended
//   `[CP,NORMAL,TANPT1,TANPT2,ANG1,ANG2]` is returned
//   - CP is the centerpoint of the circle.
//   - NORMAL is the normal vector of the plane that the circle is on (UP or DOWN if the points are 2D).
//   - TANPT1 is the point where the circle is tangent to the ray `[pt2,pt1]`.
//   - TANPT2 is the point where the circle is tangent to the ray `[pt2,pt3]`.
//   - ANG1 is the angle from the ray `[CP,pt2]` to the ray `[CP,TANPT1]`
//   - ANG2 is the angle from the ray `[CP,pt2]` to the ray `[CP,TANPT2]`
// Arguments:
//   pt1 = A point that the first ray passes though.
//   pt2 = The starting point of both rays.
//   pt3 = A point that the second ray passes though.
//   r = The radius of the circle to find.
//   d = The diameter of the circle to find.
//   tangents = If true, extended information about the tangent points is calculated and returned.  Default: false
// Example(2D):
//   pts = [[60,40], [10,10], [65,5]];
//   rad = 10;
//   stroke([pts[1],pts[0]], endcap2="arrow2");
//   stroke([pts[1],pts[2]], endcap2="arrow2");
//   circ = find_circle_2tangents(pt1=pts[0], pt2=pts[1], pt3=pts[2], r=rad);
//   translate(circ[0]) {
//       color("green") {
//           stroke(circle(r=rad),closed=true);
//           stroke([[0,0],rad*[cos(315),sin(315)]]);
//       }
//   }
//   move_copies(pts) color("blue") circle(d=2, $fn=12);
//   translate(circ[0]) color("red") circle(d=2, $fn=12);
//   labels = [[pts[0], "pt1"], [pts[1],"pt2"], [pts[2],"pt3"], [circ[0], "CP"], [circ[0]+[cos(315),sin(315)]*rad*0.7, "r"]];
//   for(l=labels) translate(l[0]+[0,2]) color("black") text(text=l[1], size=2.5, halign="center");
function find_circle_2tangents(pt1, pt2, pt3, r, d, tangents=false) =
    let(r = get_radius(r=r, d=d, dflt=undef))
    assert(r!=undef, "Must specify either r or d.")
    (is_undef(pt2) && is_undef(pt3) && is_list(pt1))? find_circle_2tangents(pt1[0], pt1[1], pt1[2], r=r) :
    collinear(pt1, pt2, pt3)? undef :
    let(
        v1 = unit(pt1 - pt2),
        v2 = unit(pt3 - pt2),
        vmid = unit(mean([v1, v2])),
        n = vector_axis(v1, v2),
        a = vector_angle(v1, v2),
        hyp = r / sin(a/2),
        cp = pt2 + hyp * vmid
    ) !tangents? [cp, n] :
    let(
        x = hyp * cos(a/2),
        tp1 = pt2 + x * v1,
        tp2 = pt2 + x * v2,
        fff=echo(tp1=tp1,cp=cp,pt2=pt2),
        dang1 = vector_angle(tp1-cp,pt2-cp),
        dang2 = vector_angle(tp2-cp,pt2-cp)
    ) [cp, n, tp1, tp2, dang1, dang2];


// Function: find_circle_3points()
// Usage:
//   find_circle_3points(pt1, pt2, pt3);
// Description:
//   Returns the [CENTERPOINT, RADIUS, NORMAL] of the circle that passes through three non-collinear
//   points.  The centerpoint will be a 2D or 3D vector, depending on the points input.  If all three
//   points are 2D, then the resulting centerpoint will be 2D, and the normal will be UP ([0,0,1]).
//   If any of the points are 3D, then the resulting centerpoint will be 3D.  If the three points are
//   collinear, then `[undef,undef,undef]` will be returned.  The normal will be a normalized 3D
//   vector with a non-negative Z axis.
// Arguments:
//   pt1 = The first point.
//   pt2 = The second point.
//   pt3 = The third point.
// Example(2D):
//   pts = [[60,40], [10,10], [65,5]];
//   circ = find_circle_3points(pts[0], pts[1], pts[2]);
//   translate(circ[0]) color("green") stroke(circle(r=circ[1]),closed=true,$fn=72);
//   translate(circ[0]) color("red") circle(d=3, $fn=12);
//   move_copies(pts) color("blue") circle(d=3, $fn=12);
function find_circle_3points(pt1, pt2, pt3) =
    (is_undef(pt2) && is_undef(pt3) && is_list(pt1))? find_circle_3points(pt1[0], pt1[1], pt1[2]) :
    collinear(pt1,pt2,pt3)? [undef,undef,undef] :
    let(
        v1 = pt1-pt2,
        v2 = pt3-pt2,
        n = vector_axis(v1,v2),
        n2 = n.z<0? -n : n
    ) len(pt1)+len(pt2)+len(pt3)>6? (
        let(
            a = project_plane(pt1, pt1, pt2, pt3),
            b = project_plane(pt2, pt1, pt2, pt3),
            c = project_plane(pt3, pt1, pt2, pt3),
            res = find_circle_3points(a, b, c)
        ) res[0]==undef? [undef,undef,undef] : let(
            cp = lift_plane(res[0], pt1, pt2, pt3),
            r = norm(pt2-cp)
        ) [cp, r, n2]
    ) : let(
        mp1 = pt2 + v1/2,
        mp2 = pt2 + v2/2,
        mpv1 = rot(90, v=n, p=v1),
        mpv2 = rot(90, v=n, p=v2),
        l1 = [mp1, mp1+mpv1],
        l2 = [mp2, mp2+mpv2],
        isect = line_intersection(l1,l2)
    ) is_undef(isect)? [undef,undef,undef] : let(
        r = norm(pt2-isect)
    ) [isect, r, n2];



// Function: circle_point_tangents()
// Usage:
//   tangents = circle_point_tangents(r|d, cp, pt);
// Description:
//   Given a circle and a point outside that circle, finds the tangent point(s) on the circle for a
//   line passing through the point.  Returns list of zero or more sublists of [ANG, TANGPT]
// Arguments:
//   r = Radius of the circle.
//   d = Diameter of the circle.
//   cp = The coordinates of the circle centerpoint.
//   pt = The coordinates of the external point.
// Example(2D):
//   cp = [-10,-10];  r = 30;  pt = [30,10];
//   tanpts = subindex(circle_point_tangents(r=r, cp=cp, pt=pt),1);
//   color("yellow") translate(cp) circle(r=r);
//   color("cyan") for(tp=tanpts) {stroke([tp,pt]); stroke([tp,cp]);}
//   color("red") move_copies(tanpts) circle(d=3,$fn=12);
//   color("blue") move_copies([cp,pt]) circle(d=3,$fn=12);
function circle_point_tangents(r, d, cp, pt) =
    assert(is_num(r) || is_num(d))
    assert(is_vector(cp))
    assert(is_vector(pt))
    let(
        r = get_radius(r=r, d=d, dflt=1),
        delta = pt - cp,
        dist = norm(delta),
        baseang = atan2(delta.y,delta.x)
    ) dist < r? [] :
    approx(dist,r)? [[baseang, pt]] :
    let(
        relang = acos(r/dist),
        angs = [baseang + relang, baseang - relang]
    ) [for (ang=angs) [ang, cp + r*[cos(ang),sin(ang)]]];



// Function: circle_circle_tangents()
// Usage: circle_circle_tangents(c1, r1|d1, c2, r2|d2)
// Description:
//   Computes lines tangents to a pair of circles.  Returns a list of line endpoints [p1,p2] where
//   p2 is the tangent point on circle 1 and p2 is the tangent point on circle 2.
//   If four tangents exist then the first one the left hand exterior tangent as regarded looking from
//   circle 1 toward circle 2.  The second value is the right hand exterior tangent.  The third entry
//   gives the interior tangent that starts on the left of circle 1 and crosses to the right side of
//   circle 2.  And the fourth entry is the last interior tangent that starts on the right side of
//   circle 1.  If the circles intersect then the interior tangents don't exist and the function
//   returns only two entries.  If one circle is inside the other one then no tangents exist
//   so the function returns the empty set.  When the circles are tangent a degenerate tangent line
//   passes through the point of tangency of the two circles:  this degenerate line is NOT returned.  
// Example(2D): Four tangents, first in green, second in black, third in blue, last in red.  
//   $fn=32;
//   c1 = [3,4];  r1 = 2;
//   c2 = [7,10]; r2 = 3;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=.1, closed=true);
//   move(c2) stroke(circle(r=r2), width=.1, closed=true);
//   colors = ["green","black","blue","red"];
//   for(i=[0:len(pts)-1]) color(colors[i]) stroke(pts[i],width=.1);
// Example(2D): Circles overlap so only exterior tangents exist.
//   $fn=32;
//   c1 = [4,4];  r1 = 3;
//   c2 = [7,7]; r2 = 2;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=.1, closed=true);
//   move(c2) stroke(circle(r=r2), width=.1, closed=true);
//   colors = ["green","black","blue","red"];
//   for(i=[0:len(pts)-1]) color(colors[i]) stroke(pts[i],width=.1);
// Example(2D): Circles are tangent.  Only exterior tangents are returned.  The degenerate internal tangent is not returned.  
//   $fn=32;
//   c1 = [4,4];  r1 = 4;
//   c2 = [4,10]; r2 = 2;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=.1, closed=true);
//   move(c2) stroke(circle(r=r2), width=.1, closed=true);
//   colors = ["green","black","blue","red"];
//   for(i=[0:1:len(pts)-1]) color(colors[i]) stroke(pts[i],width=.1);
// Example(2D): One circle is inside the other: no tangents exist.  If the interior circle is tangent the single degenerate tangent will not be returned.  
//   $fn=32;
//   c1 = [4,4];  r1 = 4;
//   c2 = [5,5];  r2 = 2;
//   pts = circle_circle_tangents(c1,r1,c2,r2);
//   move(c1) stroke(circle(r=r1), width=.1, closed=true);
//   move(c2) stroke(circle(r=r2), width=.1, closed=true);
//   echo(pts);   // Returns []
function circle_circle_tangents(c1,r1,c2,r2,d1,d2) =
    let(
        r1 = get_radius(r1=r1,d1=d1),
        r2 = get_radius(r1=r2,d1=d2),
        Rvals = [r2-r1, r2-r1, -r2-r1, -r2-r1]/norm(c1-c2),
        kvals = [-1,1,-1,1],
        ext = [1,1,-1,-1],
        N = 1-sqr(Rvals[2])>=0 ? 4 :
            1-sqr(Rvals[0])>=0 ? 2 : 0,
        coef= [
            for(i=[0:1:N-1]) [
                [Rvals[i], -kvals[i]*sqrt(1-sqr(Rvals[i]))],
                [kvals[i]*sqrt(1-sqr(Rvals[i])), Rvals[i]]
            ] * unit(c2-c1)
        ]
    ) [
        for(i=[0:1:N-1]) let(
            pt = [
                c1-r1*coef[i],
                c2-ext[i]*r2*coef[i]
            ]
        ) if (pt[0]!=pt[1]) pt
    ];



// Section: Pointlists

// Function: first_noncollinear()
// Usage:
//   first_noncollinear(i1, i2, points);
// Description:
//   Returns index of the first point in `points` that is not collinear with the points indexed by `i1` and `i2`.
// Arguments:
//   i1 = The first point.
//   i2 = The second point.
//   points = The list of points to find a non-collinear point from.
function first_noncollinear(i1, i2, points) =
    [for (j = idx(points)) if (j!=i1 && j!=i2 && !collinear_indexed(points,i1,i2,j)) j][0];


// Function: find_noncollinear_points()
// Usage:
//   find_noncollinear_points(points);
// Description:
//   Finds the indices of three good non-collinear points from the points list `points`.
function find_noncollinear_points(points) =
    let(
        a = 0,
        b = furthest_point(points[a], points),
        pa = points[a],
        pb = points[b],
        c = max_index([
            for (p=points)
                (approx(p,pa) || approx(p,pb))? 0 :
                sin(vector_angle(points[a]-p,points[b]-p)) *
                    norm(p-points[a]) * norm(p-points[b])
        ])
    )
    assert(c!=a && c!=b, "Cannot find three noncollinear points in pointlist.")
    [a, b, c];


// Function: pointlist_bounds()
// Usage:
//   pointlist_bounds(pts);
// Description:
//   Finds the bounds containing all the 2D or 3D points in `pts`.
//   Returns `[[MINX, MINY, MINZ], [MAXX, MAXY, MAXZ]]`
// Arguments:
//   pts = List of points.
function pointlist_bounds(pts) = [
    [for (a=[0:2]) min([ for (x=pts) point3d(x)[a] ]) ],
    [for (a=[0:2]) max([ for (x=pts) point3d(x)[a] ]) ]
];


// Function: closest_point()
// Usage:
//   closest_point(pt, points);
// Description:
//   Given a list of `points`, finds the index of the closest point to `pt`.
// Arguments:
//   pt = The point to find the closest point to.
//   points = The list of points to search.
function closest_point(pt, points) =
    min_index([for (p=points) norm(p-pt)]);


// Function: furthest_point()
// Usage:
//   furthest_point(pt, points);
// Description:
//   Given a list of `points`, finds the index of the furthest point from `pt`.
// Arguments:
//   pt = The point to find the farthest point from.
//   points = The list of points to search.
function furthest_point(pt, points) =
    max_index([for (p=points) norm(p-pt)]);



// Section: Polygons

// Function: polygon_area()
// Usage:
//   area = polygon_area(poly);
// Description:
//   Given a 2D or 3D planar polygon, returns the area of that polygon.  If the polygon is self-crossing, the results are undefined.
function polygon_area(poly) =
    len(poly)<3? 0 :
    len(poly[0])==2? 0.5*sum([for(i=[0:1:len(poly)-1]) det2(select(poly,i,i+1))]) :
    let(
        plane = plane_from_points(poly)
    ) plane==undef? undef :
    let(
        n = unit(plane_normal(plane)),
        total = sum([for (i=[0:1:len(poly)-1]) cross(poly[i], select(poly,i+1))]),
        res = abs(total * n) / 2
    ) res;


// Function: polygon_is_convex()
// Usage:
//   polygon_is_convex(poly);
// Description:
//   Returns true if the given polygon is convex.  Result is undefined if the polygon is self-intersecting.
// Example:
//   polygon_is_convex(circle(d=50));  // Returns: true
// Example:
//   spiral = [for (i=[0:36]) let(a=-i*10) (10+i)*[cos(a),sin(a)]];
//   polygon_is_convex(spiral);  // Returns: false
function polygon_is_convex(poly) =
    let(
        l = len(poly),
        c = [for (i=idx(poly)) cross(poly[(i+1)%l]-poly[i],poly[(i+2)%l]-poly[(i+1)%l])]
    )
    len([for (x=c) if(x>0) 1])==0 ||
    len([for (x=c) if(x<0) 1])==0;


// Function: polygon_shift()
// Usage:
//   polygon_shift(poly, i);
// Description:
//   Given a polygon `poly`, rotates the point ordering so that the first point in the polygon path is the one at index `i`.
// Arguments:
//   poly = The list of points in the polygon path.
//   i = The index of the point to shift to the front of the path.
// Example:
//   polygon_shift([[3,4], [8,2], [0,2], [-4,0]], 2);   // Returns [[0,2], [-4,0], [3,4], [8,2]]
function polygon_shift(poly, i) =
    list_rotate(cleanup_path(poly), i);


// Function: polygon_shift_to_closest_point()
// Usage:
//   polygon_shift_to_closest_point(path, pt);
// Description:
//   Given a polygon `path`, rotates the point ordering so that the first point in the path is the one closest to the given point `pt`.
function polygon_shift_to_closest_point(path, pt) =
    let(
        path = cleanup_path(path),
        dists = [for (p=path) norm(p-pt)],
        closest = min_index(dists)
    ) select(path,closest,closest+len(path)-1);


// Function: reindex_polygon()
// Usage:
//   newpoly = reindex_polygon(reference, poly);
// Description:
//   Rotates and possibly reverses the point order of a 2d or 3d polygon path to optimize its pairwise point
//   association with a reference polygon.  The two polygons must have the same number of vertices and be the same dimension. 
//   The optimization is done by computing the distance, norm(reference[i]-poly[i]), between
//   corresponding pairs of vertices of the two polygons and choosing the polygon point order that
//   makes the total sum over all pairs as small as possible.  Returns the reindexed polygon.  Note
//   that the geometry of the polygon is not changed by this operation, just the labeling of its
//   vertices.  If the input polygon is 2d and is oriented opposite the reference then its point order is
//   flipped.
// Arguments:
//   reference = reference polygon path
//   poly = input polygon to reindex
// Example(2D):  The red dots show the 0th entry in the two input path lists.  Note that the red dots are not near each other.  The blue dot shows the 0th entry in the output polygon
//   pent = subdivide_path([for(i=[0:4])[sin(72*i),cos(72*i)]],30);
//   circ = circle($fn=30,r=2.2);
//   reindexed = reindex_polygon(circ,pent);
//   move_copies(concat(circ,pent)) circle(r=.1,$fn=32);
//   color("red") move_copies([pent[0],circ[0]]) circle(r=.1,$fn=32);
//   color("blue") translate(reindexed[0])circle(r=.1,$fn=32);
// Example(2D): The indexing that minimizes the total distance will not necessarily associate the nearest point of `poly` with the reference, as in this example where again the blue dot indicates the 0th entry in the reindexed result.
//   pent = move([3.5,-1],p=subdivide_path([for(i=[0:4])[sin(72*i),cos(72*i)]],30));
//   circ = circle($fn=30,r=2.2);
//   reindexed = reindex_polygon(circ,pent);
//   move_copies(concat(circ,pent)) circle(r=.1,$fn=32);
//   color("red") move_copies([pent[0],circ[0]]) circle(r=.1,$fn=32);
//   color("blue") translate(reindexed[0])circle(r=.1,$fn=32);
function reindex_polygon(reference, poly, return_error=false) = 
    assert(is_path(reference) && is_path(poly))
    assert(len(reference)==len(poly), "Polygons must be the same length in reindex_polygon")
    let(
        dim = len(reference[0]),
        N = len(reference),
        fixpoly = dim != 2? poly :
            polygon_is_clockwise(reference)? clockwise_polygon(poly) :
            ccw_polygon(poly),
        dist = [
            // Matrix of all pairwise distances
            for (p1=reference) [
                for (p2=fixpoly) norm(p1-p2)
            ]
        ],
        // Compute the sum of all distance pairs for a each shift
        sums = [
            for(shift=[0:1:N-1]) sum([
                for(i=[0:1:N-1]) dist[i][(i+shift)%N]
            ])
        ],
        optimal_poly = polygon_shift(fixpoly,min_index(sums))
    )
    return_error? [optimal_poly, min(sums)] :
    optimal_poly;


// Function: align_polygon()
// Usage:
//   newpoly = align_polygon(reference, poly, angles, [cp]);
// Description:
//   Tries the list or range of angles to find a rotation of the specified polygon that best aligns
//   with the reference polygon.  For each angle, the polygon is reindexed, which is a costly operation
//   so if run time is a problem, use a smaller sampling of angles.  Returns the rotated and reindexed
//   polygon.
// Arguments:
//   reference = reference polygon 
//   poly = polygon to rotate into alignment with the reference
//   angles = list or range of angles to test
//   cp = centerpoint for rotations
// Example(2D): The original hexagon in yellow is not well aligned with the pentagon.  Turning it so the faces line up gives an optimal alignment, shown in red.  
//   $fn=32;
//   pentagon = subdivide_path(pentagon(side=2),60);
//   hexagon = subdivide_path(hexagon(side=2.7),60);
//   color("red") move_copies(scale(1.4,p=align_polygon(pentagon,hexagon,[0:10:359]))) circle(r=.1);
//   move_copies(concat(pentagon,hexagon))circle(r=.1);
function align_polygon(reference, poly, angles, cp) =
    assert(is_path(reference) && is_path(poly))
    assert(len(reference)==len(poly), "Polygons must be the same length to be aligned in align_polygon")
    assert(is_num(angles[0]), "The `angle` parameter to align_polygon must be a range or vector")
    let(     // alignments is a vector of entries of the form: [polygon, error]
        alignments = [
            for(angle=angles) reindex_polygon(
                reference,
                zrot(angle,p=poly,cp=cp),
                return_error=true
            )
        ],
        best = min_index(subindex(alignments,1))
    ) alignments[best][0];


// Function: centroid()
// Usage:
//   cp = centroid(poly);
// Description:
//   Given a simple 2D polygon, returns the 2D coordinates of the polygon's centroid.
//   Given a simple 3D planar polygon, returns the 3D coordinates of the polygon's centroid.
//   If the polygon is self-intersecting, the results are undefined.
function centroid(poly) =
    len(poly[0])==2? (
        sum([
            for(i=[0:len(poly)-1])
            let(segment=select(poly,i,i+1))
            det2(segment)*sum(segment)
        ]) / 6 / polygon_area(poly)
    ) : (
        let(
            n = plane_normal(plane_from_points(poly)),
            p1 = vector_angle(n,UP)>15? vector_axis(n,UP) : vector_axis(n,RIGHT),
            p2 = vector_axis(n,p1),
            cp = mean(poly),
            proj = project_plane(poly,cp,cp+p1,cp+p2),
            cxy = centroid(proj)
        ) lift_plane(cxy,cp,cp+p1,cp+p2)
    );


// Function: point_in_polygon()
// Usage:
//   point_in_polygon(point, path, [eps])
// Description:
//   This function tests whether the given 2D point is inside, outside or on the boundary of
//   the specified 2D polygon using the Winding Number method.
//   The polygon is given as a list of 2D points, not including the repeated end point.
//   Returns -1 if the point is outside the polyon.
//   Returns 0 if the point is on the boundary.
//   Returns 1 if the point lies in the interior.
//   The polygon does not need to be simple: it can have self-intersections.
//   But the polygon cannot have holes (it must be simply connected).
//   Rounding error may give mixed results for points on or near the boundary.
// Arguments:
//   point = The 2D point to check position of.
//   path = The list of 2D path points forming the perimeter of the polygon.
//   eps = Acceptable variance.  Default: `EPSILON` (1e-9)
function point_in_polygon(point, path, eps=EPSILON) =
    // Original algorithm from http://geomalgorithms.com/a03-_inclusion.html
    // Does the point lie on any edges?  If so return 0.
    sum([for(i=[0:1:len(path)-1]) let(seg=select(path,i,i+1)) if(!approx(seg[0],seg[1],eps=eps)) point_on_segment2d(point, seg, eps=eps)?1:0]) > 0? 0 :
    // Otherwise compute winding number and return 1 for interior, -1 for exterior
    sum([for(i=[0:1:len(path)-1]) let(seg=select(path,i,i+1)) if(!approx(seg[0],seg[1],eps=eps)) _point_above_below_segment(point, seg)]) != 0? 1 : -1;


// Function: polygon_is_clockwise()
// Usage:
//   polygon_is_clockwise(path);
// Description:
//   Return true if the given 2D simple polygon is in clockwise order, false otherwise.
//   Results for complex (self-intersecting) polygon are indeterminate.
// Arguments:
//   path = The list of 2D path points for the perimeter of the polygon.
function polygon_is_clockwise(path) =
    assert(is_path(path) && len(path[0])==2, "Input must be a 2d path")
    let(
        minx = min(subindex(path,0)),
        lowind = search(minx, path, 0, 0),
        lowpts = select(path, lowind),
        miny = min(subindex(lowpts, 1)),
        extreme_sub = search(miny, lowpts, 1, 1)[0],
        extreme = select(lowind,extreme_sub)
    ) det2([select(path,extreme+1)-path[extreme], select(path, extreme-1)-path[extreme]])<0;


// Function: clockwise_polygon()
// Usage:
//   clockwise_polygon(path);
// Description:
//   Given a 2D polygon path, returns the clockwise winding version of that path.
function clockwise_polygon(path) =
    polygon_is_clockwise(path)? path : reverse_polygon(path);


// Function: ccw_polygon()
// Usage:
//   ccw_polygon(path);
// Description:
//   Given a 2D polygon path, returns the counter-clockwise winding version of that path.
function ccw_polygon(path) =
    polygon_is_clockwise(path)? reverse_polygon(path) : path;


// Function: reverse_polygon()
// Usage:
//   reverse_polygon(poly)
// Description:
//   Reverses a polygon's winding direction, while still using the same start point.
function reverse_polygon(poly) =
    let(lp=len(poly)) [for (i=idx(poly)) poly[(lp-i)%lp]];


// Function: polygon_normal()
// Usage:
//   n = polygon_normal(poly);
// Description:
//   Given a 3D planar polygon, returns a unit-length normal vector for the
//   clockwise orientation of the polygon. 
function polygon_normal(poly) =
    let(
        poly = path3d(cleanup_path(poly)),
        p0 = poly[0],
        n = sum([
            for (i=[1:1:len(poly)-2])
            cross(poly[i+1]-p0, poly[i]-p0)
        ])
    ) unit(n);


function _split_polygon_at_x(poly, x) =
    let(
        xs = subindex(poly,0)
    ) (min(xs) >= x || max(xs) <= x)? [poly] :
    let(
        poly2 = [
            for (p = pair_wrap(poly)) each [
                p[0],
                if(
                    (p[0].x < x && p[1].x > x) ||
                    (p[1].x < x && p[0].x > x)
                ) let(
                    u = (x - p[0].x) / (p[1].x - p[0].x)
                ) [
                    x,  // Important for later exact match tests
                    u*(p[1].y-p[0].y)+p[0].y,
                    u*(p[1].z-p[0].z)+p[0].z,
                ]
            ]
        ],
        out1 = [for (p = poly2) if(p.x <= x) p],
        out2 = [for (p = poly2) if(p.x >= x) p],
        out = [
            if (len(out1)>=3) out1,
            if (len(out2)>=3) out2,
        ]
    ) out;


function _split_polygon_at_y(poly, y) =
    let(
        ys = subindex(poly,1)
    ) (min(ys) >= y || max(ys) <= y)? [poly] :
    let(
        poly2 = [
            for (p = pair_wrap(poly)) each [
                p[0],
                if(
                    (p[0].y < y && p[1].y > y) ||
                    (p[1].y < y && p[0].y > y)
                ) let(
                    u = (y - p[0].y) / (p[1].y - p[0].y)
                ) [
                    u*(p[1].x-p[0].x)+p[0].x,
                    y,  // Important for later exact match tests
                    u*(p[1].z-p[0].z)+p[0].z,
                ]
            ]
        ],
        out1 = [for (p = poly2) if(p.y <= y) p],
        out2 = [for (p = poly2) if(p.y >= y) p],
        out = [
            if (len(out1)>=3) out1,
            if (len(out2)>=3) out2,
        ]
    ) out;


function _split_polygon_at_z(poly, z) =
    let(
        zs = subindex(poly,2)
    ) (min(zs) >= z || max(zs) <= z)? [poly] :
    let(
        poly2 = [
            for (p = pair_wrap(poly)) each [
                p[0],
                if(
                    (p[0].z < z && p[1].z > z) ||
                    (p[1].z < z && p[0].z > z)
                ) let(
                    u = (z - p[0].z) / (p[1].z - p[0].z)
                ) [
                    u*(p[1].x-p[0].x)+p[0].x,
                    u*(p[1].y-p[0].y)+p[0].y,
                    z,  // Important for later exact match tests
                ]
            ]
        ],
        out1 = [for (p = poly2) if(p.z <= z) p],
        out2 = [for (p = poly2) if(p.z >= z) p],
        out = [
            if (len(out1)>=3) out1,
            if (len(out2)>=3) out2,
        ]
    ) out;


// Function: split_polygons_at_each_x()
// Usage:
//   splitpolys = split_polygons_at_each_x(polys, xs);
// Description:
//   Given a list of 3D polygons, splits all of them wherever they cross any X value given in `xs`.
// Arguments:
//   polys = A list of 3D polygons to split.
//   xs = A list of scalar X values to split at.
function split_polygons_at_each_x(polys, xs, _i=0) =
    _i>=len(xs)? polys :
    split_polygons_at_each_x(
        [
            for (poly = polys)
            each _split_polygon_at_x(poly, xs[_i])
        ], xs, _i=_i+1
    );


// Function: split_polygons_at_each_y()
// Usage:
//   splitpolys = split_polygons_at_each_y(polys, ys);
// Description:
//   Given a list of 3D polygons, splits all of them wherever they cross any Y value given in `ys`.
// Arguments:
//   polys = A list of 3D polygons to split.
//   ys = A list of scalar Y values to split at.
function split_polygons_at_each_y(polys, ys, _i=0) =
    _i>=len(ys)? polys :
    split_polygons_at_each_y(
        [
            for (poly = polys)
            each _split_polygon_at_y(poly, ys[_i])
        ], ys, _i=_i+1
    );


// Function: split_polygons_at_each_z()
// Usage:
//   splitpolys = split_polygons_at_each_z(polys, zs);
// Description:
//   Given a list of 3D polygons, splits all of them wherever they cross any Z value given in `zs`.
// Arguments:
//   polys = A list of 3D polygons to split.
//   zs = A list of scalar Z values to split at.
function split_polygons_at_each_z(polys, zs, _i=0) =
    _i>=len(zs)? polys :
    split_polygons_at_each_z(
        [
            for (poly = polys)
            each _split_polygon_at_z(poly, zs[_i])
        ], zs, _i=_i+1
    );



// vim: expandtab tabstop=4 shiftwidth=4 softtabstop=4 nowrap
