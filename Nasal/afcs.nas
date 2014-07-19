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

var tacan_bearing_listener = nil;
var tacan_in_range_listener = nil;

var tacan_init = func (node) {
    if (node.getValue() == "tacan-hold") {
        # Construct the current TACAN channel ID
        var get_channel = func (i) {
            return getprop("/instrumentation/tacan/frequencies/selected-channel[" ~ i ~ "]");
        }
        var tacan_channel = get_channel(1) ~ get_channel(2) ~ get_channel(3) ~ get_channel(4);

        var tankers = props.globals.getNode("/ai/models", 1).getChildren("tanker");
        foreach (var tanker; tankers) {
            if (tanker.getNode("valid", 1).getValue()
              and tanker.getNode("refuel/type").getValue() == "probe"
              and tanker.getNode("navaids/tacan/channel-ID", 1).getValue() == tacan_channel) {
                var copilot_message = sprintf("Found tanker %s on TACAN %s for aerial refueling", tanker.getNode("callsign").getValue(), tacan_channel);
                setprop("/sim/messages/copilot", copilot_message);

                var true_hdg_deg = tanker.getNode("orientation/true-heading-deg");
                var range_nm = tanker.getNode("radar/range-nm");

                tacan_bearing_listener = setlistener(tanker.getNode("radar/bearing-deg"), func (node) {
                    if (range_nm.getValue() > 0.2) {
                        setprop("/v22/afcs/target/tacan-bearing-deg", node.getValue());
                    }
                    else {
                        setprop("/v22/afcs/target/tacan-bearing-deg", true_hdg_deg.getValue());
                    }
                }, startup=1);
                tacan_in_range_listener = setlistener(tanker.getNode("radar/in-range"), func (node) {
                    setprop("/v22/afcs/internal/tacan-in-range", node.getValue());
                }, startup=1);
            }
        }
    }
    else {
        if (tacan_bearing_listener != nil) {
            removelistener(tacan_bearing_listener);
        }
        if (tacan_in_range_listener != nil) {
            removelistener(tacan_in_range_listener);
        }
    }
}

setlistener("/v22/afcs/locks/heading", tacan_init, runtime=0);

# Disable standard magnetic heading hold if NAV1 localizer or TACAN
# signal has been captured.
var disable_heading = func (node) {
    if (node.getValue()) {
        setprop("/autopilot/locks/heading", "");
    }
}

setlistener("/v22/afcs/active/loc-hold", disable_heading);
setlistener("/v22/afcs/active/tacan-hold", disable_heading);
