# Copyright (C) 2014  onox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

var copilot_say = func (message) {
    setprop("/sim/messages/copilot", message);
};

var make_notification_cb = func (format, action=nil) {
    return func (data=nil) {
        if (format != nil) {
            if (typeof(format) == "func") {
                var message_format = format();
            }
            else {
                var message_format = format;
            }

            if (data != nil) {
                var message = sprintf(message_format, data.getValue());
            }
            else {
                var message = message_format;
            }

            copilot_say(message);
            logger.info(sprintf("Announcing '%s'", message));
        }

        if (typeof(action) == "func") {
            action();
        }
    };
};

var on_short_runway_format = func {
    var distance = takeoff_announcer.get_short_runway_distance();
    return sprintf("On runway %%s, %d %s remaining", distance, takeoff_config.distances_unit);
};

var remaining_distance_format = func {
    return sprintf("%%d %s remaining", landing_config.distances_unit);
};

var stop_announcer = func {
    landing_announcer.stop();
    logger.warn("Stopping landing announce");

    takeoff_announcer.set_mode("taxi-and-takeoff");
    logger.warn(sprintf("Takeoff mode: %s", takeoff_announcer.mode));
};

var switch_to_takeoff = func {
    if (takeoff_announcer.mode == "taxi-and-takeoff") {
        takeoff_announcer.set_mode("takeoff");
        logger.warn(sprintf("Takeoff mode: %s", takeoff_announcer.mode));

        landing_announcer.set_mode("takeoff");
        landing_announcer.start();
        logger.warn("Starting landing announce");
    }
};

var takeoff_config = { parents: [runway.TakeoffRunwayAnnounceConfig] };
takeoff_config.distances_unit = "feet";

var takeoff_announcer = runway.TakeoffRunwayAnnounceClass.new(takeoff_config);
takeoff_announcer.connect("on-runway", make_notification_cb("On runway %s", switch_to_takeoff));
takeoff_announcer.connect("on-short-runway", make_notification_cb(on_short_runway_format, switch_to_takeoff));
takeoff_announcer.connect("approaching-runway", make_notification_cb("Approaching runway %s"));

var landing_config = { parents: [runway.LandingRunwayAnnounceConfig] };
landing_config.distances_unit = "feet";
landing_config.distance_center_nose_m = 8;

var landing_announcer = runway.LandingRunwayAnnounceClass.new(landing_config);
landing_announcer.connect("remaining-distance", make_notification_cb(remaining_distance_format));
landing_announcer.connect("vacated-runway", make_notification_cb("Vacated runway %s", stop_announcer));
landing_announcer.connect("landed-runway", make_notification_cb("Touchdown on runway %s"));
landing_announcer.connect("landed-outside-runway", make_notification_cb(nil, stop_announcer));

var make_switch_mode_cb = func (wow_mode, no_wow_mode) {
    return func (node) {
        if (node.getBoolValue()) {
            if (getprop("/gear/gear[0]/wow")) {
                takeoff_announcer.set_mode(wow_mode);
            }
            else {
                takeoff_announcer.set_mode(no_wow_mode);
            }
        }
        else {
            takeoff_announcer.set_mode("");
        }
        logger.warn(sprintf("Takeoff mode: %s", takeoff_announcer.mode));
    };
};

setlistener("/controls/lighting/taxi-light",
  make_switch_mode_cb("taxi-and-takeoff", "taxi"),
  startup=1, runtime=0);
setlistener("/controls/lighting/nav-lights",
  make_switch_mode_cb("takeoff", "taxi"),
  startup=1, runtime=0);

var have_been_in_air = 0;

var init_announcers = func {
    setlistener("/gear/gear[0]/wow-avg", func (n) {
        var on_ground = n.getBoolValue();

        if (on_ground) {
            takeoff_announcer.start();
            logger.warn("Starting takeoff announce");

            if (have_been_in_air == 1) {
                have_been_in_air = 0;

                takeoff_announcer.set_mode("");
                logger.warn(sprintf("Takeoff mode: %s", takeoff_announcer.mode));

                landing_announcer.set_mode("landing");
                landing_announcer.start();
                logger.warn("Starting landing announce");
            }
        }
        else {
            takeoff_announcer.stop();
            logger.warn("Stopping takeoff announce");

            landing_announcer.stop();
            logger.warn("Stopping landing announce");

            if (have_been_in_air == 0) {
                have_been_in_air = 1;
            }
        }

        # Tell the multiplayer ATC chat window whether the aircraft is
        # on the ground or in the air
        atc.dialog.set_on_ground(on_ground);
    }, startup=1, runtime=0);
};

setlistener("/sim/signals/fdm-initialized", func {
    logger.warn("FDM initialized");

    var timer = maketimer(5.0, func init_announcers());
    timer.singleShot = 1;
    timer.start();
});

atc.dialog.set_runway_takeoff_announcer(takeoff_announcer);
atc.dialog.set_runway_landing_announcer(landing_announcer);
