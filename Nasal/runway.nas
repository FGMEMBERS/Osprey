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

var on_runway = func (runway) {
    var message = sprintf("On runway %s", runway);
    copilot_say(message);
    logger.info(sprintf("Announcing '%s'", message));
};

var approaching_runway = func (runway) {
    var message = sprintf("Approaching runway %s", runway);
    copilot_say(message);
    logger.info(sprintf("Announcing '%s'", message));
};

var remaining_distance = func (distance) {
    var message = sprintf("%d remaining", distance);
    copilot_say(message);
    logger.info(sprintf("Announcing '%s'", message));
};

var vacated_runway = func (runway) {
    var message = sprintf("Vacated runway %s", runway);
    copilot_say(message);
    logger.info(sprintf("Announcing '%s'", message));

    landing_announcer.stop();
    logger.warn("Stopping landing announce");

    takeoff_announcer.set_mode("taxi");
};

var landed_runway = func (runway) {
    var message = sprintf("Touchdown on runway %s", runway);
    copilot_say(message);
    logger.info(sprintf("Announcing '%s'", message));
};

var landed_outside_runway = func (runway) {
    var message = sprintf("We did not land on a runway!");
    copilot_say(message);
    logger.info(sprintf("Announcing '%s'", message));

    landing_announcer.stop();
    logger.warn("Stopping landing announce");

    takeoff_announcer.set_mode("taxi");
};

var takeoff_config = { parents: [runway.TakeoffRunwayAnnounceConfig] };

var takeoff_announcer = runway.TakeoffRunwayAnnounceClass.new(takeoff_config);
takeoff_announcer.connect("on-runway", on_runway);
takeoff_announcer.connect("approaching-runway", approaching_runway);

var landing_config = { parents: [runway.LandingRunwayAnnounceConfig] };

var landing_announcer = runway.LandingRunwayAnnounceClass.new(landing_config);
landing_announcer.connect("remaining-distance", remaining_distance);
landing_announcer.connect("vacated-runway", vacated_runway);
landing_announcer.connect("landed-runway", landed_runway);
landing_announcer.connect("landed-outside-runway", landed_outside_runway);

setlistener("/controls/lighting/taxi-light", func (n) {
    if (n.getBoolValue()) {
        if (getprop("/gear/gear[0]/wow")) {
            takeoff_announcer.set_mode("taxi-and-takeoff");
        }
        else {
            takeoff_announcer.set_mode("taxi");
        }
    }
    else {
        takeoff_announcer.set_mode("");
    }
}, startup=1, runtime=0);

setlistener("/controls/lighting/nav-lights", func (n) {
    if (n.getBoolValue()) {
        if (getprop("/gear/gear[0]/wow")) {
            takeoff_announcer.set_mode("takeoff");
        }
        else {
            takeoff_announcer.set_mode("taxi");
        }
    }
    else {
        takeoff_announcer.set_mode("");
    }
}, startup=1, runtime=0);

var have_been_in_air = 0;

var init_announcers = func {
    setlistener("/gear/gear[0]/wow", func (n) {
        if (n.getBoolValue()) {
            takeoff_announcer.start();
            logger.warn("Starting takeoff announce");

            if (have_been_in_air == 1) {
                have_been_in_air = 0;

                takeoff_announcer.set_mode("");

                landing_announcer.start();
                landing_announcer.set_mode("landing");
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
    }, startup=1, runtime=0);
};

setlistener("/sim/signals/fdm-initialized", func {
    logger.warn("FDM initialized");

    settimer(func init_announcers(), 5.0);
});
