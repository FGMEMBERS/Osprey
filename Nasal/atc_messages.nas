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

var MessageChoiceClass = {

    new: func (label, message, receiver) {
        var m = {
            parents: [MessageChoiceClass]
        };
        m.label = label;
        m.message = message;
        m.receiver = receiver;
        return m;
    },

    get_label: func {
        return me.label;
    },

    execute: func {
        var message = sprintf("%s: %s", me.receiver, me.message);
        atc.dialog.send_message(message);
        atc.dialog.choice_list.remove_all();
    }

};

var ReplyMessageChoiceClass = {

    new: func (label, message, receiver) {
        var sender  = getprop("/sim/multiplay/callsign");
        var message = sprintf("%s, %s", message, sender);
        var m = {
            parents: [ReplyMessageChoiceClass, MessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var ReadbackMessageChoiceClass = {

    new: func (message, receiver) {
        var label = sprintf("Read back \"%s\" to %s", message, receiver);
        var m = {
            parents: [ReadbackMessageChoiceClass, ReplyMessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var RequestMessageChoiceClass = {

    new: func (label, message, receiver) {
        var sender  = getprop("/sim/multiplay/callsign");
        var message = sprintf("%s, %s", sender, message);
        var m = {
            parents: [RequestMessageChoiceClass, MessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var EnrouteRequestMessageChoiceClass = {

    new: func (receiver, destination) {
        var label   = sprintf("Request %s to give en-route clearance to %s", receiver, destination);
        var message = sprintf("requesting clearance to %s", destination);
        var m = {
            parents: [EnrouteRequestMessageChoiceClass, RequestMessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var StartupRequestMessageChoiceClass = {

    new: func (receiver) {
        var label   = sprintf("Request %s to give start-up clearance", receiver);
        var message = sprintf("Request start-up");
        var m = {
            parents: [EnrouteRequestMessageChoiceClass, ReplyMessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var PushbackRequestMessageChoiceClass = {

    new: func (receiver) {
        var label   = sprintf("Request push-back from  %s", receiver);
        var message = sprintf("request push-back");
        var m = {
            parents: [EnrouteRequestMessageChoiceClass, RequestMessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var TaxiRequestMessageChoiceClass = {

    new: func (receiver, runway=nil) {
        if (runway != nil) {
            var label   = sprintf("Request taxi to runway %s from %s", runway, receiver);
            var message = sprintf("Request taxi to runway %s", runway);
        }
        else {
            var label   = sprintf("Request taxi from %s", receiver);
            var message = sprintf("Request taxi");
        }
        var m = {
            parents: [EnrouteRequestMessageChoiceClass, ReplyMessageChoiceClass.new(label, message, receiver)]
        };
        return m;
    }

};

var ActionChoiceClass = {

    new: func (label, action) {
        var m = {
            parents: [ActionChoiceClass]
        };
        m.label = label;
        m.action = action;
        return m;
    },

    get_label: func {
        return me.label;
    },

    execute: func {
        me.action();
    }

};

var AbstractATCMessageClass = {

    new: func {
        var m = {
            parents: [AbstractATCMessageClass]
        };
        return m;
    },

    is_instance: func (message) {
        return find(me.text, message) == 0;
    },

    get_error_text: func {
        return me.error_text;
    },

    get_response_format: func {
        return me.response_format;
    }

};

var AbstractHeadingATCMessageClass = {

    new: func {
        var m = {
            parents: [AbstractHeadingATCMessageClass, AbstractATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid heading";
        return m;
    },

    get_value: func (message) {
        var heading = int(substr(message, size(me.text)));
        return (heading != nil and heading >= 0 and heading <= 359) ? heading : nil;
    }

};

var HeadingLeftATCMessageClass = {

    new: func {
        var m = {
            parents: [HeadingLeftATCMessageClass, AbstractHeadingATCMessageClass.new()]
        };
        m.text = "Turn left heading: ";
        m.response_format = "Turning left heading %03d";
        return m;
    }

};

var HeadingRightATCMessageClass = {

    new: func {
        var m = {
            parents: [HeadingRightATCMessageClass, AbstractHeadingATCMessageClass.new()]
        };
        m.text = "Turn right heading: ";
        m.response_format = "Turning right heading %03d";
        return m;
    }

};

var AbstractFlightLevelATCMessageClass = {

    new: func {
        var m = {
            parents: [AbstractFlightLevelATCMessageClass, AbstractATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid flight level";
        return m;
    },

    get_value: func (message) {
        var fl_str = substr(message, size(me.text));

        if (find(" ", fl_str) == 0) {
            var fl = int(substr(fl_str, 1));
        }
        else {
            var fl = int(fl_str);
        }

        return (fl != nil and fl >= 0 and fl <= 999) ? fl : nil;
    }

};

var ClimbFlightLevelATCMessageClass = {

    new: func {
        var m = {
            parents: [ClimbFlightLevelATCMessageClass, AbstractFlightLevelATCMessageClass.new()]
        };
        m.text = "Climb and maintain: FL";
        m.response_format = "Climbing to FL%03d";
        return m;
    }

};

var DescendFlightLevelATCMessageClass = {

    new: func {
        var m = {
            parents: [DescendFlightLevelATCMessageClass, AbstractFlightLevelATCMessageClass.new()]
        };
        m.text = "Descend and maintain: FL";
        m.response_format = "Descending to FL%03d";
        return m;
    }

};

var AbstractAltitudeATCMessageClass = {

    new: func {
        var m = {
            parents: [AbstractAltitudeATCMessageClass, AbstractATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid altitude";
        return m;
    },

    get_value: func (message) {
        var altitude_str = substr(message, size(me.text));
        
        if (find(" ft", altitude_str) == size(altitude_str) - 3) {
            var altitude = int(substr(altitude_str, 0, size(altitude_str) - 3));
        }
        elsif (find("ft", altitude_str) == size(altitude_str) - 2) {
            var altitude = int(substr(altitude_str, 0, size(altitude_str) - 2));
        }
        else {
            var altitude = int(altitude_str);
        }

        return (altitude != nil and altitude >= 0 and altitude <= 99999) ? altitude : nil;
    }

};

var ClimbAltitudeATCMessageClass = {

    new: func {
        var m = {
            parents: [ClimbAltitudeATCMessageClass, AbstractAltitudeATCMessageClass.new()]
        };
        m.text = "Climb and maintain: ";
        m.response_format = "Climbing to %d";
        return m;
    }

};

var DescendAltitudeATCMessageClass = {

    new: func {
        var m = {
            parents: [DescendAltitudeATCMessageClass, AbstractAltitudeATCMessageClass.new()]
        };
        m.text = "Descend and maintain: ";
        m.response_format = "Descending to %d";
        return m;
    }

};

var ReduceSpeedATCMessageClass = {

    new: func {
        var m = {
            parents: [ReduceSpeedATCMessageClass, AbstractATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid speed";
        m.text = "Reduce speed to: ";
        m.response_format = "Reducing speed to %d";
        return m;
    },

    get_value: func (message) {
        var speed = int(substr(message, size(me.text)));
        return (speed != nil and speed >= 0 and speed <= 999) ? speed : nil;
    }

};

var ClearedCrossRunwayATCMessageClass = {

    new: func {
        var m = {
            parents: [ClearedCrossRunwayATCMessageClass, AbstractATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid runway";
        m.text = "Cleared to cross runway: ";
        m.response_format = "Cleared to cross runway %s";
        return m;
    },

    get_value: func (message) {
        var runway = substr(message, size(me.text));
        return runway != nil and contains(airportinfo().runways, runway) ? runway : nil;
    }

};

var AbstractLandingATCMessageClass = {

    new: func {
        var m = {
            parents: [AbstractLandingATCMessageClass, AbstractATCMessageClass.new()]
        };
        return m;
    },

    is_instance: func (message) {
        var distance_mi = int(string.trim(substr(message, 0, 3), -1, func (c) { c == ` ` }));
        return distance_mi != nil and find(me.text, substr(message, 3)) == 0;
    }

};

var ILSApproachATCMessageClass = {

    new: func {
        var m = {
            parents: [ILSApproachATCMessageClass, AbstractLandingATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid runway";
        m.text = " mi out, maintain hdg until intercepting localizer, cleared for ILS appr rwy: ";
        m.response_format = "Cleared for ILS approach runway %s";
        return m;
    },

    get_value: func (message) {
        var runway = substr(message, size(me.text) + 3);
        # TODO Check that the destination airport has this runway
        return runway != nil ? runway : nil;
    }

};

var RunwayInSightATCMessageClass = {

    new: func {
        var m = {
            parents: [RunwayInSightATCMessageClass, AbstractLandingATCMessageClass.new()]
        };
        m.text = " mi out, report when runway in sight";
        m.response_format = "Runway in sight";
        return m;
    },

    get_value: func (message) {
        # Return a dummy value other than nil
        return 1;
    }

};

var ClearedToLandATCMessageClass = {

    new: func {
        var m = {
            parents: [ClearedToLandATCMessageClass, AbstractLandingATCMessageClass.new()]
        };
        m.error_text = "Unable, invalid runway";
        m.text = "cleared to land runway: ";
        m.response_format = "Cleared to land runway %s";
        return m;
    },

    is_instance: func (message) {
        var distance_mi = int(string.trim(substr(message, 0, 3), -1, func (c) { c == ` ` }));

        # We do not care about the precise text that ATC sent since
        # Nasal does not support regular expressions
        return distance_mi != nil and find(me.text, message) > 0;
    },

    get_value: func (message) {
        var index = find(me.text, message) + size(me.text);
        var runway = substr(message, index);
        # TODO Check that the destination airport has this runway
        return runway != nil ? runway : nil;
    }

};

var messages = [
    HeadingLeftATCMessageClass.new(),
    HeadingRightATCMessageClass.new(),
    ClimbFlightLevelATCMessageClass.new(),
    DescendFlightLevelATCMessageClass.new(),
    ClimbAltitudeATCMessageClass.new(),
    DescendAltitudeATCMessageClass.new(),
    ReduceSpeedATCMessageClass.new(),
    ClearedCrossRunwayATCMessageClass.new(),
    ILSApproachATCMessageClass.new(),
    RunwayInSightATCMessageClass.new(),
    ClearedToLandATCMessageClass.new()
];
