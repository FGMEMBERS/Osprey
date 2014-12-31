# Automatic Flight Control System

var interpol = func(x, x0, y0, x1, y1) { x < x0 ? y0 : x > x1 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0) };

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
};

var TacanClass = {

    new: func {
        return {
            parents: [TacanClass],
            listeners: [],
            mp_timer: nil,
            mp_listener: nil
        };
    },

    _find_mp_aircraft: func (callsign) {
        # Find and return an MP aircraft that has the given callsign

        if (contains(multiplayer.model.callsign, callsign)) {
            return multiplayer.model.callsign[callsign].node;
        };
        return nil;
    },

    _follow_mp_target: func(target) {
        # Set-up listeners to follow the given MP target

        var valid = target.getNode("valid");
        var distance = target.getNode("radar/range-nm");

        append(me.listeners, setlistener(target.getNode("radar/bearing-deg"), func (node) {
            setprop("/instrumentation/tacan/indicated-bearing-true-deg", node.getValue());
            setprop("/instrumentation/tacan/indicated-distance-nm", distance.getValue());
            globals.props.getNode("/instrumentation/tacan/in-range").setBoolValue(valid.getValue());
        }, startup=1));
    },

    find_and_follow_mp_target: func (callsign) {
        # Try to find the MP aircraft that uses the given callsign
        # and then make sure that it gets followed. Additionally, if
        # necessary, it creates a listener to handle the multiplayer updates
        # This listener is created once and gets only cleaned up when TACAN
        # is disabled again

        var target = me._find_mp_aircraft(callsign);

        if (target != nil) {
            var callsign = target.getNode("callsign").getValue();

            var copilot_message = sprintf("Found target %s", callsign);
            setprop("/sim/messages/copilot", copilot_message);

            # Start a timer to continuously update various properties
            # needed to keep tracking the MP target
            me.mp_timer = maketimer(0.0, func me._update_pos_mp_target(target)); 
            me.mp_timer.start();
            # TODO ideally this timer should have a fixed frequency, irrespective of the fps of the GUI

            # Make sure the A/P starts following the target
            me._follow_mp_target(target);
        }
        else {
            var copilot_message = sprintf("Target %s not found", callsign);
            setprop("/sim/messages/copilot", copilot_message);
        }

        if (me.mp_listener == nil) {
            # If this signal gets emitted, it will clean up the old
            # listeners (but not this listener itself!) and then tries
            # to find and follow the targeted MP aircraft again
            me.mp_listener = setlistener("/sim/signals/multiplayer-updated", func me._update_mp_target(callsign));
        }
    },

    remove_listeners: func {
        # Remove all listeners, including the listener that handles
        # multiplayer updates

        me._remove_listeners();

        if (me.mp_listener != nil) {
            removelistener(me.mp_listener);
            me.mp_listener = nil;
        }
    },

    _remove_listeners: func {
        # Remove listeners and the timer that updates the radar 
        # properties of the aircraft that is being tracked

        foreach (var l; me.listeners) {
            removelistener(l);
        }
        me.listeners = [];

        if (me.mp_timer != nil) {
            me.mp_timer.stop();
            me.mp_timer = nil;
        }

        # Make sure TACAN gets disabled
        globals.props.getNode("/instrumentation/tacan/in-range").setBoolValue(0);
        setprop("/instrumentation/tacan/indicated-bearing-true-deg", 0.0);
        setprop("/instrumentation/tacan/indicated-distance-nm", 0.0);
    },

    _update_mp_target: func (callsign) {
        me._remove_listeners();

        me.find_and_follow_mp_target(callsign);
    },

    _update_pos_mp_target: func (target) {
        # Following code is from Nasal/multiplayer.nas
        var x = target.getNode("position/global-x").getValue();
        var y = target.getNode("position/global-y").getValue();
        var z = target.getNode("position/global-z").getValue();
        var ac = geo.Coord.new().set_xyz(x, y, z);

        # Following code is from Nasal/multiplayer.nas
        var distance = nil;
        var self = geo.aircraft_position();
        call(func distance = self.distance_to(ac), nil, var err = []);

        if (size(err) == 0 and distance != nil) {
            target.setValues({
                "radar/bearing-deg": self.course_to(ac),
                "radar/range-nm": distance * M2NM,
                "radar/in-range": target.getNode("valid").getBoolValue()
            });
        }
    }
};

var tacan = TacanClass.new();

var tacan_init = func (node) {
    var callsign = getprop("/v22/afcs/target/mp-callsign-tacan");
    if (node.getValue() == "tacan-hold" and callsign != "") {
        tacan.find_and_follow_mp_target(callsign);
    }
    else {
        tacan.remove_listeners();
    }
};

setlistener("/v22/afcs/locks/heading", tacan_init, runtime=0);

# Disable standard magnetic heading hold if NAV1 localizer or TACAN
# signal has been captured.
var disable_heading = func {
    setprop("/autopilot/locks/heading", "");
};

# Disable standard magnetic heading hold and VOR/ILS if TACAN signal
# has been captured.
var disable_vor_heading = func (node) {
    if (node.getValue()) {
        setprop("/v22/afcs/locks/vor-ils", 0);
        disable_heading();
    }
};

# Disable standard magnetic heading hold and TACAN if NAV1 localizer or
# VOR signal has been captured.
var disable_tacan_heading = func (node) {
    if (node.getValue()) {
        setprop("/v22/afcs/locks/heading", "");
        disable_heading();
    }
};

setlistener("/v22/afcs/active/loc-hold", disable_tacan_heading);
setlistener("/v22/afcs/active/tacan-hold", disable_vor_heading);


# Disable standard altitude hold if NAV1 glideslope signal has been
# captured.
var disable_altitude = func (node) {
    if (node.getValue()) {
        setprop("/autopilot/locks/altitude", "");
    }
};

setlistener("/v22/afcs/active/gs-hold", disable_altitude);

var disable_auto_nac = func (node) {
    if (!node.getValue()) {
        setprop("/v22/afcs/locks/auto-nac", 0);
    }
};

setlistener("/v22/afcs/active/spd-hold", disable_auto_nac, 0, 0);
