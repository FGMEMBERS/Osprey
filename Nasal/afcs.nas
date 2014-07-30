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

var TacanClass = {

    new: func {
        return {
            parents: [TacanClass],
            listeners: []
        };
    },

    get_channel_id: func {
        # Return the current TACAN channel ID. This ID can be set in the Radio Settings panel.

        var get_channel = func (i) {
            return getprop("/instrumentation/tacan/frequencies/selected-channel[" ~ i ~ "]");
        }
        return get_channel(1) ~ get_channel(2) ~ get_channel(3) ~ get_channel(4);
    },

    find_tanker: func (channel_id) {
        # Find and return a tanker that has the given TACAN channel ID
        # and a fuel drogue. Return nil if no appropriate tanker can be found.

        var tankers = props.globals.getNode("/ai/models", 1).getChildren("tanker");

        foreach (var tanker; tankers) {
            if (tanker.getNode("valid", 1).getValue()
              and tanker.getNode("refuel/type").getValue() == "probe"
              and tanker.getNode("navaids/tacan/channel-ID", 1).getValue() == channel_id) {
                return tanker; 
            }
        }
        return nil;
    },

    follow_ai_target: func(target) {
        var true_hdg_deg = target.getNode("orientation/true-heading-deg");
        var range_nm = target.getNode("radar/range-nm");

        append(me.listeners, setlistener(target.getNode("radar/bearing-deg"), func (node) {
            if (range_nm.getValue() > 0.2) {
                setprop("/v22/afcs/target/tacan-bearing-deg", node.getValue());
            }
            else {
                setprop("/v22/afcs/target/tacan-bearing-deg", true_hdg_deg.getValue());
            }
        }, startup=1));

        append(me.listeners, setlistener(target.getNode("radar/in-range"), func (node) {
            setprop("/v22/afcs/internal/tacan-in-range", node.getValue());
        }, startup=1));
    },

    find_mp_aircraft: func (callsign) {
        if (contains(multiplayer.model.callsign, callsign)) {
            return multiplayer.model.callsign[callsign].node;
        };
        return nil;
    },

    follow_mp_target: func(target) {
        var valid = target.getNode("valid");

        append(me.listeners, setlistener(target.getNode("bearing-to"), func (node) {
            setprop("/v22/afcs/target/tacan-bearing-deg", node.getValue());
            setprop("/v22/afcs/internal/tacan-in-range", valid.getValue());
        }, startup=1));

        var callsign = target.getNode("callsign").getValue();

        var copilot_message = sprintf("Found target %s", callsign);
        setprop("/sim/messages/copilot", copilot_message);

        append(me.listeners, setlistener("/sim/signals/multiplayer-updated", func me._update_mp_target(callsign)));
    },

    find_and_follow_mp_target: func (callsign) {
        var mp_aircraft = me.find_mp_aircraft(callsign);

        if (mp_aircraft != nil) {
            me.follow_mp_target(mp_aircraft);
        }
        else {
            var copilot_message = sprintf("Target %s not found", callsign);
            setprop("/sim/messages/copilot", copilot_message);
        }
    },

    remove_listeners: func {
        foreach (var l; me.listeners) {
            removelistener(l);
        }
        me.listeners = [];

        # Make sure TACAN gets disabled
        setprop("/v22/afcs/internal/tacan-in-range", 0);
    },

    _update_mp_target: func (callsign) {
        me.remove_listeners();

        me.find_and_follow_mp_target(callsign);
    }
};

var tacan = TacanClass.new();

var tacan_init = func (node) {
    if (node.getValue() == "tacan-hold") {
        var tacan_channel = tacan.get_channel_id();
        var tanker = tacan.find_tanker(tacan_channel);

        if (tanker != nil) {
            var copilot_message = sprintf("Found tanker %s on TACAN %s for aerial refueling", tanker.getNode("callsign").getValue(), tacan_channel);
            setprop("/sim/messages/copilot", copilot_message);

            tacan.follow_ai_target(tanker);
        }
        else {
            tacan.find_and_follow_mp_target(getprop("/v22/afcs/target/mp-callsign-tacan"));
        }
    }
    else {
        tacan.remove_listeners();
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

# Disable standard altitude hold if NAV1 glideslope signal has been
# captured.
var disable_altitude = func (node) {
    if (node.getValue()) {
        setprop("/autopilot/locks/altitude", "");
    }
}

setlistener("/v22/afcs/active/gs-hold", disable_altitude);
