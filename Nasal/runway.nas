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

var announce_config = { parents: [runway.TakeoffRunwayAnnounceConfig] };

var runway_announcer = runway.TakeoffRunwayAnnounceClass.new(announce_config);
runway_announcer.connect("on-runway", on_runway);
runway_announcer.connect("approaching-runway", approaching_runway);

setlistener("/controls/lighting/taxi-light", func (n) {
    if (n.getBoolValue()) {
        runway_announcer.set_mode("taxi-and-takeoff");
    }
    else {
        runway_announcer.set_mode("");
    }
}, startup=1, runtime=0);

setlistener("/controls/lighting/nav-lights", func (n) {
    if (n.getBoolValue()) {
        runway_announcer.set_mode("takeoff");
    }
    else {
        runway_announcer.set_mode("");
    }
}, startup=1, runtime=0);

setlistener("/gear/gear[0]/wow", func (n) {
    if (n.getBoolValue()) {
        runway_announcer.start();
        logger.warn("Starting runway announce");
    }
    else {
        runway_announcer.stop();
        logger.warn("Stopping runway announce");
    }
}, startup=1, runtime=0);
