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

var ATCMessages = {

    heading_left: "Turn left heading: ",
    heading_right: "Turn right heading: ",

};

var ATCChat = {

    name: "mp-atc-chat",

    window_width: 500,

    content_padding: 6,

    row_height: 16,

    new: func (name) {
        var m = {
            parents: [ATCChat]
        };
        m.dialog = nil;
        m.content = nil;
        m.name = name;
        m.visible = 0;
        m.online = 0;
        m.on_ground = 1;

        return m;
    },

    create: func {
        if (me.dialog != nil) {
            me.del();
        };

        me.dialog = gui.dialog[me.name] = gui.Widget.new();
        me.dialog.set("name", me.name);
        me.dialog.set("dialog-name", me.name);
        me.dialog.set("pref-width", ATCChat.window_width);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);
        me.dialog.setColor(0, 0, 0, 0.3);

        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");

        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set("label", "ATC");
        titlebar.addChild("empty").set("stretch", 1);

        var close_button = titlebar.addChild("button");
        close_button.node.setValues({ "pref-width": 16, "pref-height": 16, legend: "", default: 0 });
        close_button.set("key", "Esc");
        close_button.setBinding("nasal", "atc.dialog.hide()");

        me.dialog.addChild("hrule");

        me.content = me.dialog.addChild("group");
        me.content.set("layout", "table");
        me.content.set("halign", "left");
        me.content.set("default-padding", ATCChat.content_padding);

        fgcommand("dialog-new", me.dialog.prop());
    },

    show: func {
        if (me.online) {
            fgcommand("dialog-show", me.dialog.prop());
            me.visible = 1;
        }
    },

    hide: func {
        fgcommand("dialog-close", me.dialog.prop());
        me.visible = 0;
    },

    toggle: func {
        if (me.visible) {
            me.hide();
        }
        else {
            me.show();
        }
    },

    del: func {
        me.hide();
        delete(gui.dialog, me.name);
    },

    _reset_position: func {
        var menubar = getprop("/sim/menubar/visibility") ? 28 : 0;
        var screen = getprop("/sim/startup/ysize");

        var margin = 2;
        var titlebar = 25;

        var rows = size(me.content.node.getChildren("text"));
        var padding = rows > 0 ? 2 * ATCChat.content_padding : 0;

        me.dialog.set("x", 2);
        me.dialog.set("y", screen - menubar - margin - titlebar - rows * ATCChat.row_height - padding);
    },

    redraw: func {
        if (me.dialog != nil) {
            var was_visible = me.visible;

            me.hide();
            me._reset_position();

            if (was_visible) {
                me.show();
            }
        }
    },

    _remove_all_content: func {
        me.content.node.removeChildren("text");
    },

    _add_content_row: func (label) {
        var rows = size(me.content.node.getChildren("text"));

        var button = me.content.addChild("button");
        button.node.setValues({ "legend": "", "row": rows, "col": 0, "halign": "right", "pref-height": ATCChat.row_height - 2, "pref-width": ATCChat.row_height - 2});
        button.setBinding("nasal", "atc.dialog.send_message('" ~ label ~ "')");

        var row = me.content.addChild("text");
        row.node.setValues({ "label": label, "row": rows, "col": 1, "halign": "fill", "pref-height": ATCChat.row_height});
    },

    set_runway_takeoff_announcer: func (announcer) {
        announcer.connect("on-runway", me._on_runway);
        announcer.connect("approaching-runway", me._approaching_runway);
    },

    set_runway_landing_announcer: func (announcer) {
        announcer.connect("vacated-runway", me._vacated_runway);
    },

    set_online: func (is_online) {
        me.online = is_online;
        gui.menuEnable(me.name, is_online);

        if (!is_online) {
            me.hide();
        }
    },

    set_on_ground: func (on_ground) {
        me.on_ground = on_ground;
    },

    _on_runway: func (node) {
        var callsign = getprop("/sim/multiplay/callsign");
        me.send_message(sprintf("On runway %s, %s", node.getValue(), callsign));
    },

    _approaching_runway: func (node) {
        var callsign = getprop("/sim/multiplay/callsign");
        me.send_message(sprintf("Approaching runway %s, %s", node.getValue(), callsign));
    },

    _vacated_runway: func (node) {
        var callsign = getprop("/sim/multiplay/callsign");
        me.send_message(sprintf("Vacated runway %s, %s", node.getValue(), callsign));
    },

    send_message: func (message) {
        setprop("/sim/multiplay/chat", message);
    },

    receive_message: func (message) {
        var callsign = getprop("/sim/multiplay/callsign");
        var index = find(callsign ~ ": ", message);

        # if -1 then message was not meant for us
        # if 0 then message was sent by us
        if (index > 0) {
            foreach (var callsign_caller; keys(multiplayer.model.callsign)) {
                if (size(callsign_caller) + 2 == index and find(callsign_caller ~ ": ", message) == 0) {
                    var message_filtered = substr(message, index + size(callsign) + 2);
                    me._on_receive_message(callsign_caller, message_filtered);
                    break;
                }
            }
        }
        debug.dump(message);
    },

    _on_receive_message: func (callsign_caller, message) {
        var callsign = getprop("/sim/multiplay/callsign");

        if (find(ATCMessages.heading_left, message) == 0) {
            var heading = int(substr(message, size(ATCMessages.heading_left)));
            if (heading != nil and heading >= 0 and heading <= 359) {
                me._display_heading_left(callsign, heading);
            }
            else {
                me.send_message(sprintf("%s: Unable, invalid heading, %s", callsign_caller, callsign));
            }
        }
        elsif (find(ATCMessages.heading_right, message) == 0) {
            var heading = int(substr(message, size(ATCMessages.heading_right)));
            if (heading != nil and heading >= 0 and heading <= 359) {
                me._display_heading_right(callsign, heading);
            }
            else {
                me.send_message(sprintf("%s: Unable, invalid heading, %s", callsign_caller, callsign));
            }
        }
    },

    _display_heading_left: func (callsign, heading) {
        me._display_readback(callsign, sprintf("Turning left heading %d", heading));
    },

    _display_heading_right: func (callsign, heading) {
        me._display_readback(callsign, sprintf("Turning right heading %d", heading));
    },

    _display_readback: func (callsign, message) {
        me._remove_all_content();
        me._add_content_row(sprintf("%s, %s", message, callsign));
        me.redraw();
    }

};

var dialog = ATCChat.new(ATCChat.name);
dialog.create();

setlistener("/sim/startup/ysize", func (node) {
    dialog.redraw();
});

setlistener("/sim/signals/reinit-gui", func (node) {
    dialog.redraw();
});

setlistener("/sim/menubar/visibility", func (node) {
    dialog.redraw();
});

setlistener("/sim/multiplay/online", func (node) {
    dialog.set_online(node.getBoolValue());
}, startup=1, runtime=0);

setlistener("/sim/messages/mp-plane", func (node) {
    dialog.receive_message(node.getValue());
});
