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
    logger.info(sprintf("Announcing '%s'", message));
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
    logger.warn("Stopping landing announcer");

    takeoff_announcer.set_mode("taxi-and-takeoff");
    logger.warn(sprintf("Takeoff mode: %s", takeoff_announcer.mode));
};

var switch_to_takeoff = func {
    if (takeoff_announcer.mode == "taxi-and-takeoff") {
        takeoff_announcer.set_mode("takeoff");
        logger.warn(sprintf("Takeoff mode: %s", takeoff_announcer.mode));

        landing_announcer.set_mode("takeoff");
        landing_announcer.start();
        logger.warn(sprintf("Starting landing (%s) announcer", landing_announcer.mode));
    }
};

var takeoff_config = { parents: [runway.TakeoffRunwayAnnounceConfig] };
takeoff_config.distances_unit = "feet";
takeoff_config.groundspeed_max_kt = 25;

var takeoff_announcer = runway.TakeoffRunwayAnnounceClass.new(takeoff_config);
takeoff_announcer.connect("on-runway", runway.make_betty_cb(copilot_say, "On runway %s", switch_to_takeoff));
takeoff_announcer.connect("on-short-runway", runway.make_betty_cb(copilot_say, on_short_runway_format, switch_to_takeoff));
takeoff_announcer.connect("approaching-runway", runway.make_betty_cb(copilot_say, "Approaching runway %s"));

var landing_config = { parents: [runway.LandingRunwayAnnounceConfig] };
landing_config.distances_unit = "feet";
landing_config.distance_center_nose_m = 8;
landing_config.groundspeed_min_kt = 15;

var landing_announcer = runway.LandingRunwayAnnounceClass.new(landing_config);
landing_announcer.connect("remaining-distance", runway.make_betty_cb(copilot_say, remaining_distance_format));
landing_announcer.connect("vacated-runway", runway.make_betty_cb(copilot_say, "Vacated runway %s", stop_announcer));
landing_announcer.connect("landed-runway", runway.make_betty_cb(copilot_say, "Touchdown on runway %s"));
landing_announcer.connect("landed-outside-runway", runway.make_betty_cb(copilot_say, nil, stop_announcer));

var have_been_in_air = 0;

var init_announcers = func {
    setlistener("/gear/gear[0]/wow-avg", func (n) {
        var on_ground = n.getBoolValue();

        if (on_ground) {
            if (have_been_in_air == 1) {
                have_been_in_air = 0;

                takeoff_announcer.set_mode("");

                landing_announcer.set_mode("landing");
                landing_announcer.start();
                logger.warn(sprintf("Starting landing (%s) announcer", landing_announcer.mode));
            }
            else {
                takeoff_announcer.set_mode("taxi-and-takeoff");
            }
            takeoff_announcer.start();
            logger.warn(sprintf("Starting takeoff (%s) announcer", takeoff_announcer.mode));
        }
        else {
            takeoff_announcer.stop();
            logger.warn("Stopping takeoff announcer");

            landing_announcer.stop();
            logger.warn("Stopping landing announcer");

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
