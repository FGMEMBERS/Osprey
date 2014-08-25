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

var ATCChat = {

    name: "mp-atc-chat",

    new: func (name) {
        var m = {
            parents: [ATCChat]
        };
        m.dialog = nil;
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
        me.dialog.set("pref-width", 200);

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

        var content = me.dialog.addChild("group");
        content.set("layout", "table");
        content.set("default-padding", 0);

        me.dialog.set("x", 2);
        var menubar_height = getprop("/sim/menubar/visibility") ? 28 : 0;
        me.dialog.set("y", getprop("/sim/startup/ysize") - 2 - menubar_height - 25);

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

    redraw: func {
        if (me.dialog != nil) {
            var was_visible = me.visible;

            me.del();
            me.create();

            if (was_visible) {
                me.show();
            }
        }
    },

    set_runway_takeoff_announcer: func (announcer) {
        announcer.connect("on-runway", me.on_runway);
        announcer.connect("approaching-runway", me.approaching_runway);
    },

    set_runway_landing_announcer: func (announcer) {
        announcer.connect("vacated-runway", me.vacated_runway);
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

    on_runway: func (node) {
        debug.dump(sprintf("(ATC) On runway %s", node.getValue()));
    },

    approaching_runway: func (node) {
        debug.dump(sprintf("(ATC) Approaching runway %s", node.getValue()));
    },

    vacated_runway: func (node) {
        debug.dump(sprintf("(ATC) Vacated runway %s", node.getValue()));
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
