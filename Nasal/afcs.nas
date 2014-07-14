# Automatic Flight Control System

var interpol = func(x, x0, y0, x1, y1) { x < x0 ? y0 : x > x1 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0) }

var main_loop = func {
    if (getprop("/autopilot/settings/gps-driving-true-heading") and getprop("/autopilot/route-manager/active")) {
        # If current waypoint is not the last waypoint
        if (getprop("/autopilot/route-manager/current-wp") + 1 < getprop("/autopilot/route-manager/route/num")) {
            # Let distance threshold depend on ground speed
            gnd_speed = getprop("/velocities/groundspeed-kt");
            dist_nm = interpol(gnd_speed, 40, 0.3, 300, 1.0);

            # Proceed to next waypoint if remaining distance is less than or equal to the threshold
            if (getprop("/autopilot/route-manager/wp/dist") <= dist_nm) {
                setprop("/autopilot/route-manager/input", "@next");
            }
        }
    }
}
