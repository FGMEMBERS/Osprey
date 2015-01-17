# Maik Justus < fg # mjustus : de >, partly based on bo105.nas by Melchior FRANZ, < mfranz # aon : at >
# updates for vmx22 version by Oliver Thurau

var optarg = aircraft.optarg;
var makeNode = aircraft.makeNode;

var sin = func(a) { math.sin(a * math.pi / 180.0) }
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var clamp = func(v, min=0, max=1) { v < min ? min : v > max ? max : v }
var max = func(a, b) { a > b ? a : b }
var min = func(a, b) { a < b ? a : b }
var normatan = func(x) { math.atan2(x, 1) * 2 / math.pi }

var interpol = func(x, x0, y0, x1, y1) { x < x0 ? y0 : x > x1 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0) }

# controls 
var control_rotor_incidence_wing_fold = props.globals.getNode("sim/model/v22/wingfoldincidence");

var control_throttle = props.globals.getNode("/controls/engines/engine[0]/throttle");
var control_rotor_brake = props.globals.getNode("/controls/rotor/brake",1);

var out_wing_flap = props.globals.getNode("/v22/pfcs/output/flaps");

var rotor_pos = props.globals.getNode("rotors/main/blade[0]/position-deg",1);

# Because YASim does not support folding the blades, it is necessary to
# use a separate property for the 3D model. Otherwise, the blades will
# break when you try to stow the wing. When the wing is being stowed,
# the tilt property stays at 0 degrees to keep YASim happy, while
# animation_tilt gradually changes to 90 degrees to tilt the nacelles
# of the 3D model when the wing is rotating.
var animation_tilt = props.globals.getNode("sim/model/v22/animation_tilt",1);

# 0 = vertical, 90 = horizontal, range -7.5 ... 90
var actual_tilt = props.globals.getNode("sim/model/v22/tilt",1);
actual_tilt.setValue(0);

var target_rpm_helicopter = 397;

var apln_col_500ft   = 60;
var apln_col_15000ft = 66;

var update_apln_mode_collective = func {
    # Misuse the collective to limit the KTAS to about 275 at sea level
    # and 305 at 15000 ft.
    #
    # Beause YASim computes the torque when given a certain collective
    # and RPM instead of computing the collective, we need to manually add
    # some extra collective when the pilot has reduced the RPM to 84 % in
    # order to keep the maximum speed unchanged.

    # TODO Set apln_max_col to a fixed value and fix the problem in the FDM instead

    # Extra collective when rotors are spinning at 84 % RPM: 0.83 -> +9.5; 1.00 -> +0.0
    var rpm_fraction = getprop("/rotors/main/rpm") / target_rpm_helicopter;
    var extra_col_84 = interpol(rpm_fraction, 0.84, 9.5, 0.99, 0.0);

    var altitude = max(500, min(15000, getprop("/position/altitude-ft")));
    var apln_max_col = (apln_col_15000ft - apln_col_500ft) * altitude / 15000 + apln_col_500ft + extra_col_84;

    var collective = interpol(getprop("/velocities/airspeed-kt"), 0, 20, 200, apln_max_col);
    setprop("/v22/pfcs/internal/apln-collective", collective);
};

var set_tilt = func (value = 0) {
    if (props.globals.getNode("sim/crashed",1).getBoolValue()) {return; }
    setprop("/v22/pfcs/target/tilt", clamp(value, -10, 90));
}

var set_tilt_rate = func (v) {
    var tilt_rate = getprop("/v22/pfcs/target/tilt-rate");

    if (v != 0) {
        # Increase or decrease tilt rate
        tilt_rate += v;
    }
    else {
        # Reset tilt rate to zero
        tilt_rate = 0.0;
    }

    # Keep tilt rate within -8 .. 8 deg/s
    setprop("/v22/pfcs/target/tilt-rate", clamp(tilt_rate, -8, 8));
}

# Set the target tilt depending on the desired tilt rate
# so that the nacelles move in the correct direction.
setlistener("/v22/pfcs/target/tilt-rate", func(n) {
    var tilt_rate = n.getValue();

    if (tilt_rate != 0) {
        set_tilt(tilt_rate > 0 ? 90 : -10);
    }
}, runtime=0);

# engines/rotor/wing =====================================================
var state = props.globals.getNode("sim/model/v22/state", 1);
var wing_state = props.globals.getNode("sim/model/v22/wing_state", 1);
var wing_rotation = props.globals.getNode("sim/model/v22/wing_rotation", 1);
var engine1 = props.globals.getNode("sim/model/v22/engine_right", 1);
var engine2 = props.globals.getNode("sim/model/v22/engine_left", 1);
var rotor = props.globals.getNode("controls/engines/engine/magnetos", 1);
var rotor_rpm = props.globals.getNode("rotors/main/rpm", 1);

var torque = props.globals.getNode("rotors/gear/total-torque", 1);
var stall_right = props.globals.getNode("rotors/main/stall", 1);
var stall_filtered = props.globals.getNode("rotors/main/stall-filtered", 1);
var stall_left = props.globals.getNode("rotors/tail/stall", 1);
#var stall_left_filtered = props.globals.getNode("rotors/tail/stall-filtered", 1);
var torque_sound_filtered = props.globals.getNode("rotors/gear/torque-sound-filtered", 1);
var target_rel_rpm = props.globals.getNode("controls/rotor/reltarget", 1);
var max_rel_torque = props.globals.getNode("controls/rotor/maxreltorque", 1);

# Blades Fold/Wing Stow state:

#  0 Fly-position
#  1 Tilting nacelles up
#  2 Folding blades
#  3 Tilting nacelles down
#  4 Stowing wing and tilting nacelles down
# 10 Wing fully stowed
# 11 Unstowing wing and tilting nacelles up
# 12 Wing unstowed, tilting nacelles up
# 13 Unfolding blades
# 14 Resetting blades collective
# 15 -> 0
var blade_folding = props.globals.getNode("sim/model/v22/blade_folding",1);

# Duration in seconds for various parts of the Blades Fold/Wing Stow sequence
var bfws_duration = {
    flaps:       4.0,
    blades:     20.0,
    tilt:        6.0,
    tilt_stow:  18.0,
    stow:       34.0,
};

var update_wing_state = func (new_state) {
    var ws = wing_state.getValue();
    if (new_state == (ws+1)) {
        wing_state.setValue(new_state);
        if (new_state == 1) {
            # Tilting nacelles up
            var delta = abs(animation_tilt.getValue() - 0);
            settimer(func { update_wing_state(2) }, max(1.2 , delta/9+0.5));
            interpolate(animation_tilt, 0, delta/9);
            interpolate(out_wing_flap, 0, bfws_duration.flaps);
            interpolate(control_rotor_incidence_wing_fold, 1 , 1);
        }
        if (new_state == 2) {
            # Folding blades
            settimer(func { update_wing_state(3) }, bfws_duration.blades);
            interpolate(blade_folding, 1, bfws_duration.blades);
        }
        if (new_state == 3) {
            # Tilting nacelles to 75 degrees from horizontal (15 degrees for YASim)
            settimer(func { update_wing_state(4) }, bfws_duration.tilt);
            interpolate(animation_tilt, 15, bfws_duration.tilt);
        }
        if (new_state == 4) {
            # Stowing wing and tilting nacelles to 0 degrees
            # from horizontal (90 degrees for YASim)
            settimer(func { update_wing_state(5) }, std.max(bfws_duration.tilt_stow, bfws_duration.stow));
            interpolate(animation_tilt, 90, bfws_duration.tilt_stow);
            interpolate(wing_rotation, 90, bfws_duration.stow);
        }
        if (new_state == 5) {
            wing_state.setValue(10);
        }
        if (new_state == 11) {
            # Unstowing wing and tilting nacelles to 75 degrees from
            # horizontal (15 degrees for YASim)
            assert(bfws_duration.stow >= bfws_duration.tilt_stow);
            settimer(func { update_wing_state(12) }, bfws_duration.stow);
            interpolate(wing_rotation, 0, bfws_duration.stow);
            settimer(func { interpolate(animation_tilt, 15, bfws_duration.tilt_stow); }, bfws_duration.stow - bfws_duration.tilt_stow);
        }
        if (new_state == 12) {
            # Tilting nacelles up
            settimer(func { update_wing_state(13) }, bfws_duration.tilt);
            interpolate(animation_tilt, 0, bfws_duration.tilt);
        }
        if (new_state == 13) {
            # Unfold blades
            settimer(func { update_wing_state(14) }, std.max(bfws_duration.blades, bfws_duration.flaps));
            interpolate(blade_folding, 0, bfws_duration.blades);
            interpolate(out_wing_flap, 1, bfws_duration.flaps);
        }
        if (new_state == 14) {
            settimer(func { update_wing_state(15) }, 1);
            set_tilt(0);
            interpolate(control_rotor_incidence_wing_fold, 0 , 1);
        }
        if (new_state == 15) {
            wing_state.setValue(0);
        }
    }
}

# state: (engine)
# 0 off
# 1 engine 1 startup
# 2 engine 2 startup 
# 3 engine idle
# 4 engine accel
# 5 engine sound loop

var update_state = func {
    var s = state.getValue();
    var new_state = arg[0];

    if (new_state != s+1) {
        return;
    }

    state.setValue(new_state);
    if (new_state == 1) {
        max_rel_torque.setValue(0);
        target_rel_rpm.setValue(0);
        settimer(func { update_state(2) }, 7.5);
        interpolate(engine1, 0.30, 7.5);
    }
    elsif (new_state == 2) {
        settimer(func { update_state(3) }, 7.5);
        rotor.setValue(1);
        # max_rel_torque.setValue(0.01);
        # target_rel_rpm.setValue(0.002);
        interpolate(engine1, 0.25, 2);
        interpolate(engine2, 0.30, 7.5);
        if (rotor_rpm.getValue() > 100) {
            # Rotor is running at high rpm, so accel. engine faster
            max_rel_torque.setValue(0.6);
            target_rel_rpm.setValue(1.0);
            interpolate(engine1, 1.0, 10);
        }
     }
     elsif (new_state == 3) {
        if (rotor_rpm.getValue() > 100) {
            # Rotor is running at high rpm, so accel. engine faster
            max_rel_torque.setValue(1);
            target_rel_rpm.setValue(1.0);
            state.setValue(5);
            interpolate(engine1, 1.0, 5);
            interpolate(engine2, 1.0, 10);
        }
        else {
            settimer(func { update_state(4) }, 2);
            interpolate(engine2, 0.25, 2);
        }
    }
    elsif (new_state == 4) {
        if (wing_state.getValue() != 0) {
            state.setValue(new_state-1); # keep old state
            settimer(func { update_state(4) }, 1); # check again later
        }
        else {
            settimer(func { update_state(5) }, 30);
            max_rel_torque.setValue(0.35);
            target_rel_rpm.setValue(1.0);
        }
    }
    elsif (new_state == 5) {
        max_rel_torque.setValue(1);
        target_rel_rpm.setValue(1.0);
    }
}

var engines = func {
    if (props.globals.getNode("sim/crashed",1).getBoolValue()) {return; }
    var s = state.getValue();
    if (arg[0] == 1) {
        if (s == 0) {
            var ws = wing_state.getValue();
            if (ws == 10) {
                update_wing_state(11);
            }
            if ((ws == 0) or (ws>=10)) {
                update_state(1);
            }
        }
    } else {
        rotor.setValue(0);              # engines stopped
        state.setValue(0);
        interpolate(engine1, 0, 4);
        interpolate(engine2, 0, 4);
    }
}

var wing_fold = func {
    if (props.globals.getNode("sim/crashed",1).getBoolValue()) {return; }
    var s = state.getValue();
    var ws = wing_state.getValue();
    if (s) {return;}
    if (rotor_rpm.getValue() >0.001) {return;}
    if (arg[0] == 1) {
        if (ws == 10) {
            update_wing_state(11);
        }
    } else {
        if (ws == 0) {
            update_wing_state(1);
        }
    }
}

var update_engine = func {
    if (state.getValue() > 3 ) {
        interpolate(engine1,
            clamp(rotor_rpm.getValue() / target_rpm_helicopter, 0.25, target_rel_rpm.getValue()),
            0.25);
        interpolate(engine2,
            clamp(rotor_rpm.getValue() / target_rpm_helicopter, 0.25, target_rel_rpm.getValue()),
            0.20);
    }
}

# torquemeter
torque.setDoubleValue(0);

var update_rotor_brake = func {
    var rpm=rotor_rpm.getValue();
    var brake=0;
    if (state.getValue() == 0 and rpm < 250) {
        var target = 95;
        var low = 25;
        var lrange = 5;
        var srange = 5;
        var pos = rotor_pos.getValue();
        if (rpm > low) {
            brake = (rpm-low + lrange * 0.25) / lrange;
            brake = clamp(brake, 0, 0.3);
        }
        else {
            var delta = target - pos;
            if (delta > 180) {
                delta = delta - 360;
            }
            if (delta < -180) {
                delta = delta + 360;
            }
            if (delta > 0 and rpm - 2 > delta * 0.1) {
                brake = rpm - 2 - delta * 0.1;
            }
            else {
                if (rpm * 3.5 < low) {
                    brake = (srange - abs(delta)) / srange;
                }
            }
            brake = clamp(brake, 0, 1);
        }
    }
    control_rotor_brake.setValue(brake);
}

controls.adjMixture = func(v) set_tilt_rate(v > 0 ? 1.0 : -1.0);
controls.adjPropeller = func(v) wing_fold(v > 0);


# sound =============================================================

# some sounds sound
var last_wing_rotation = 0;
var wing_rotation_speed = props.globals.getNode("sim/model/v22/wing_rotation_speed", 1);

var last_blade_folding = 0;
var blade_folding_speed = props.globals.getNode("sim/model/v22/blade_folding_speed", 1);

var last_flap = 0;
var flap_speed = props.globals.getNode("sim/model/v22/flap_speed", 1);
var flap_pos = props.globals.getNode("surface-positions/flap-pos-norm", 1);

var last_animation_tilt = 0;
var animation_tilt_speed = props.globals.getNode("sim/model/v22/animation_tilt_speed", 1);

var update_sound = func(dt) {
    var wr = wing_rotation.getValue();
    var wrs = abs (wr - last_wing_rotation);
    if (dt > 0.00001){
        wrs=wrs/dt;
    }
    else {
        wrs=wrs*120;
    }
    var f = dt / (0.05 + dt);
    var wrsf = wrs * f + wing_rotation_speed.getValue() * (1 - f);
    wing_rotation_speed.setValue(wrsf);
    last_wing_rotation = wr;
    
    var bf = blade_folding.getValue();
    var bfs = abs (bf - last_blade_folding);
    if (dt > 0.00001){
        bfs=bfs/dt;
    }
    else {
        bfs=bfs*120;
    }
    f = dt / (0.05 + dt);
    var bfsf = bfs * f + blade_folding_speed.getValue() * (1 - f);
    blade_folding_speed.setValue(bfsf);
    last_blade_folding = bf;
    
    var fp = flap_pos.getValue();
    var fps = abs (fp - last_flap);
    if (dt > 0.00001){
        fps=fps/dt;
    }
    else {
        fps=fps*120;
    }
    f = dt / (0.05 + dt);
    var fpsf = fps * f + flap_speed.getValue() * (1 - f);
    flap_speed.setValue(fpsf);
    last_flap = fp;

    var at = animation_tilt.getValue();
    var ats = abs(at - last_animation_tilt);
    if (dt > 0.00001) {
        ats = ats / dt;
    }
    else {
        ats = ats * 120;
    }
    f = dt / (0.05 + dt);
    var atsf = ats * f + animation_tilt_speed.getValue() * (1 - f);
    animation_tilt_speed.setValue(atsf);
    last_animation_tilt = at;
}


# stall sound
var stall_val = 0;
#var stall_leftt_val = 0;
stall_left.setDoubleValue(0);
stall_right.setDoubleValue(0);

var update_stall = func(dt) {
    var s = 0.5 * (stall_right.getValue()+stall_left.getValue());
    if (s < stall_val) {
        var f = dt / (0.3 + dt);
        stall_val = s * f + stall_val * (1 - f);
    } else {
        stall_val = s;
    }
    var c = getprop("/v22/pfcs/output/tcl") or 0.0;
    var r = clamp(rotor_rpm.getValue()*0.004-0.2,0,1);
    stall_filtered.setDoubleValue(r*min(1,0.5+5*stall_val + 0.006 * (1 - c)));
    
    #s = stall_left.getValue();
    #if (s < stall_left_val) {
    #   var f = dt / (0.3 + dt);
#       stall_left_val = s * f + stall_left_val * (1 - f);
#   } else {
#       stall_left_val = s;
#   }
#   c = getprop("/v22/pfcs/output/tcl");
#   stall_left_filtered.setDoubleValue(stall_left_val + 0.006 * (1 - c));
}


# modify sound by torque
var update_torque_sound_filtered = func(dt) {
    var t = torque.getValue();
    t = clamp(t * 0.000000025);
    t = t*0.5 + 0.5;
    var r = clamp(rotor_rpm.getValue()*0.02-1);
    torque_sound_filtered.setDoubleValue(t*r);
}


# skid slide sound
var Skid = {
    new : func(n) {
        var m = { parents : [Skid] };
        var soundN = props.globals.getNode("sim/sound", 1).getChild("slide", n, 1);
        var gearN = props.globals.getNode("gear", 1).getChild("gear", n, 1);

        m.compressionN = gearN.getNode("compression-norm", 1);
        m.rollspeedN = gearN.getNode("rollspeed-ms", 1);
        m.frictionN = gearN.getNode("ground-friction-factor", 1);
        m.wowN = gearN.getNode("wow", 1);
        m.volumeN = soundN.getNode("volume", 1);
        m.pitchN = soundN.getNode("pitch", 1);

        m.compressionN.setDoubleValue(0);
        m.rollspeedN.setDoubleValue(0);
        m.frictionN.setDoubleValue(0);
        m.volumeN.setDoubleValue(0);
        m.pitchN.setDoubleValue(0);
        m.wowN.setBoolValue(1);
        m.self = n;
        return m;
    },
    update : func {
        me.wowN.getBoolValue() or return;
        var rollspeed = abs(me.rollspeedN.getValue());
        me.pitchN.setDoubleValue(rollspeed * 0.6);

        var s = normatan(20 * rollspeed);
        var f = clamp((me.frictionN.getValue() - 0.5) * 2);
        var c = clamp(me.compressionN.getValue() * 2);
        me.volumeN.setDoubleValue(s * f * c * 2);
    },
};

var skid = [];
for (var i = 0; i < 3; i += 1) {
    append(skid, Skid.new(i));
}

var update_slide = func {
    forindex (var i; skid) {
        skid[i].update();
    }
}

# crash handler =====================================================
#var load = nil;
var crash = func {
    if (arg[0]) {
        # crash
        setprop("rotors/main/rpm", 0);
        setprop("rotors/main/blade[0]/flap-deg", -60);
        setprop("rotors/main/blade[1]/flap-deg", -50);
        setprop("rotors/main/blade[2]/flap-deg", -40);
        setprop("rotors/main/blade[0]/incidence-deg", -30);
        setprop("rotors/main/blade[1]/incidence-deg", -20);
        setprop("rotors/main/blade[2]/incidence-deg", -50);
        setprop("rotors/tail/rpm", 0);
        lighting.beacon_switch.setValue(0);
        lighting.navigation_switch.setValue(0);
        rotor.setValue(0);
        stall_filtered.setValue(stall_val = 0);
        state.setValue(0);

    } else {
        # uncrash (for replay)
        setprop("rotors/tail/rpm", target_rpm_helicopter);
        setprop("rotors/main/rpm", target_rpm_helicopter);
        for (i = 0; i < 4; i += 1) {
            setprop("rotors/main/blade[" ~ i ~ "]/flap-deg", 0);
            setprop("rotors/main/blade[" ~ i ~ "]/incidence-deg", 0);
        }
        lighting.beacon_switch.setValue(1);
        lighting.navigation_switch.setValue(1);
        rotor.setValue(1);
        state.setValue(5);
    }
}

# view management ===================================================

var elapsedN = props.globals.getNode("/sim/time/elapsed-sec", 1);
var flap_mode = 0;
var down_time = 0;
controls.flapsDown = func(v) {
    if (!flap_mode) {
        if (v < 0) {
            down_time = elapsedN.getValue();
            flap_mode = 1;
            dynamic_view.lookat(
                    5,     # heading left
                    -20,   # pitch up
                    0,     # roll right
                    0.2,   # right
                    0.6,   # up
                    0.85,  # back
                    0.2,   # time
                    55,    # field of view
            );
        } elsif (v > 0) {
            flap_mode = 2;
            var p = "/sim/view/dynamic/enabled";
            setprop(p, !getprop(p));
        }

    } else {
        if (flap_mode == 1) {
            if (elapsedN.getValue() < down_time + 0.2) {
                return;
            }
            dynamic_view.resume();
        }
        flap_mode = 0;
    }
}


# register function that may set me.heading_offset, me.pitch_offset, me.roll_offset,
# me.x_offset, me.y_offset, me.z_offset, and me.fov_offset
#
dynamic_view.register(func {
    var lowspeed = 1 - normatan(me.speedN.getValue() / 50);
    var r = sin(me.roll) * cos(me.pitch);

    me.heading_offset =                     # heading change due to
        (me.roll < 0 ? -50 : -30) * r * abs(r);         #    roll left/right

    me.pitch_offset =                       # pitch change due to
        (me.pitch < 0 ? -50 : -50) * sin(me.pitch) * lowspeed   #    pitch down/up
        + 15 * sin(me.roll) * sin(me.roll);         #    roll

    me.roll_offset =                        # roll change due to
        -15 * r * lowspeed;                 #    roll
});

# main() ============================================================
var delta_time = props.globals.getNode("/sim/time/delta-realtime-sec", 1);

var main_loop = func {
    var dt = delta_time.getValue();
    update_stall(dt);
    update_torque_sound_filtered(dt);
    #update_slide();
    update_engine();
    update_sound(dt);
    update_apln_mode_collective();
    # update_rotor_brake();
}

var crashed = 0;

var make_weights_persistent = func {
    # Make weights persistent across sessions
    foreach (var weight; props.globals.getNode("/sim").getChildren("weight")) {
        aircraft.data.add(weight.getNode("weight-lb").getPath());
    }
    aircraft.data.load();
};

# Initialization
setlistener("/sim/signals/fdm-initialized", func {
    control_throttle.setDoubleValue(0);

    setlistener("/sim/signals/reinit", func(n) {
        n.getBoolValue() and return;
        control_throttle.setDoubleValue(0);
        crashed = 0;
    });

    setlistener("sim/crashed", func(n) {
        if (n.getBoolValue()) {
            crash(crashed = 1);
        }
    });

    setlistener("/sim/freeze/replay-state", func(n) {
        if (crashed) {
            crash(!n.getBoolValue())
        }
    });

    setlistener("/rotors/main/blade/position-deg", func {
        update_rotor_brake();
    });

    # Tyre smoke
    aircraft.tyresmoke_system.new(0, 1, 2);

    # Rain
    aircraft.rain.init();
    var rain_timer = maketimer(0.0, func aircraft.rain.update());
    rain_timer.start();

    # Livery
    aircraft.livery.init("Aircraft/VMX22-Osprey/Models/Liveries");

    make_weights_persistent();

    var afcs_loop_timer = maketimer(0.5, afcs.main_loop);
    afcs_loop_timer.start();

    var main_loop_timer = maketimer(0.0, main_loop);
    main_loop_timer.start();
});
