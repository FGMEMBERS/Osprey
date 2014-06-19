# Maik Justus < fg # mjustus : de >, partly based on bo105.nas by Melchior FRANZ, < mfranz # aon : at >
# updates for vmx22 version by Oliver Thurau

# Sources:
#     [1] http://www.bellhelicopter.com/MungoBlobs/126/268/V-22%20Guidebook%202013_update_PREVIEW_LR2.pdf
#     (conversion corridor, page 57 on slide 29)

var optarg = aircraft.optarg;
var makeNode = aircraft.makeNode;

var sin = func(a) { math.sin(a * math.pi / 180.0) }
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var clamp = func(v, min=0, max=1) { v < min ? min : v > max ? max : v }
var max = func(a, b) { a > b ? a : b }
var min = func(a, b) { a < b ? a : b }
var normatan = func(x) { math.atan2(x, 1) * 2 / math.pi }

var interpol = func(x, x0, y0, x1, y1) { x < x0 ? y0 : x > x1 ? y1 : y0 + (y1 - y0) * (x - x0) / (x1 - x0) }
var interpolation = func (x, x0, y0, x1, y1, x2=nil, y2=nil, x3=nil, y3=nil, x4=nil, y4=nil, x5=nil, y5=nil) {
    if (x < x1 or x2 == nil) {
        interpol (x, x0, y0, x1, y1);
    }
    elsif (x < x2 or x3 == nil) {
        interpol (x, x1, y1, x2, y2);
    }
    elsif (x < x3 or x4 == nil) {
        interpol (x, x2, y2, x3, y3);
    }
    elsif (x < x4 or x5 == nil) {
        interpol (x, x3, y3, x4, y4);
    }
    else {
        interpol (x, x4, y4, x5, y5);
    }
}

# controls 
var control_rotor_incidence_wing_fold = props.globals.getNode("sim/model/v22/wingfoldincidence");

var input_flaps = props.globals.getNode("controls/flight/flaps",1);
var control_flaps = props.globals.getNode("sim/model/v22/inputflaps",1);

var control_throttle = props.globals.getNode("/controls/engines/engine[0]/throttle");
var control_tilt = props.globals.getNode("sim/model/v22/inputtilt",1);
var control_rotor_brake = props.globals.getNode("/controls/rotor/brake",1);

var out_wing_flap = props.globals.getNode("sim/model/v22/wing/flap");
var out_rotor_l_col = props.globals.getNode("sim/model/v22/rotor/left/collective");
var out_rotor_r_col = props.globals.getNode("sim/model/v22/rotor/right/collective");

var airspeed_kt = props.globals.getNode("/velocities/airspeed-kt");
var rotor_pos = props.globals.getNode("rotors/main/blade[0]/position-deg",1);
var actual_tilt_left = props.globals.getNode("sim/model/v22/rotor/left/tilt",1); #0 up, 90 forward, range -10 ... 90
var actual_tilt_right = props.globals.getNode("sim/model/v22/rotor/right/tilt",1); #0 up, 90 forward, range -10 ... 90
actual_tilt_left.setValue(0);
actual_tilt_right.setValue(0);

var target_rpm_airplane = 333;
var target_rpm_helicopter = 397;
var target_rpm = target_rpm_helicopter;

# [1] actually describes the lower bound as "40 to 80 knots" (KTAS) and the
# upper bound as "100 to 120 knots" (KTAS)
var min_conv_mode_kias = 40;
var max_conv_mode_kias = 120;

# Lower the speed at which the flaps are fully extended by 10 knots
var flap_speed_offset = -10;

# Increase the range in which the flaps are (partially) extended by 40 knots
var flap_speed_range = 40;

var update_controls_and_tilt_loop = func(dt) {
    if (props.globals.getNode("sim/crashed",1).getBoolValue()) {
        return;
    }

    var ail = clamp(getprop("/controls/flight/aileron") + getprop("/controls/flight/aileron-trim"), -1, 1);
    var ele = clamp(getprop("/controls/flight/elevator") + getprop("/controls/flight/elevator-trim"), -1, 1);
    var rud = clamp(getprop("/controls/flight/rudder") + getprop("/controls/flight/rudder-trim"), -1, 1);

    setprop("/controls/flight/fbw/target/pitch", ele);
    setprop("/controls/flight/fbw/target/roll", ail);
    setprop("/controls/flight/fbw/target/yaw", rud);

    var thr = 1 - control_throttle.getValue();
    var act_tilt_avg = (actual_tilt_left.getValue() + actual_tilt_right.getValue()) / 2.0;
    var speed = airspeed_kt.getValue();

    target_rpm = clamp(target_rpm_helicopter + (target_rpm_airplane - target_rpm_helicopter) * (act_tilt_avg - 30) / 60,
        target_rpm_airplane,target_rpm_helicopter);
    if (state.getValue() == 5) {
        target_rel_rpm.setValue(target_rpm / target_rpm_helicopter);
    }

    ################################################################################
    # Conversion mode control factors
    ################################################################################

    # Below min_conv_mode_kias the conversion factor is 0, above max_conv_mode_kias it is 1
    var conv_factor = clamp((speed - min_conv_mode_kias) / (max_conv_mode_kias - min_conv_mode_kias), 0, 1);

    var airplane_control_factor = conv_factor;
    var helicopter_control_factor = 1 - conv_factor;

    ################################################################################

    var flap_control_factor = clamp((speed - min_conv_mode_kias - flap_speed_offset) / (max_conv_mode_kias - min_conv_mode_kias + flap_speed_range), 0, 1);

    var flap = control_flaps.getValue();
    var iflap = input_flaps.getValue();
    var maxflap_delta = dt * 0.125;
    flap = max(min(iflap, flap + maxflap_delta), flap - maxflap_delta);
    control_flaps.setValue(flap);

    if (wing_state.getValue() == 0) {
        out_wing_flap.setValue(flap_control_factor * flap * 0.3 + (1 - flap_control_factor) * min(1, 1 - act_tilt_avg / 90));
    }

    ################################################################################

    var col_wing = thr * interpolation(speed, 0, 20, 300, 75); 

    # Calculate the rotor controls
    var ail2col = 5 * getprop("/controls/flight/fbw/output/vtol/dcp-tilt") * getprop("/controls/flight/fbw/output/vtol/dcp-airspeed");
    var min_col = 2;
    var max_col = 23;

    var col_tilt_correction = 1 / cos(clamp(act_tilt_avg, -10, 30));
    var col_rotor = min_col + thr * (max_col - min_col) * col_tilt_correction;

    # Set blades vertical if folded
    var h = control_rotor_incidence_wing_fold.getValue();
    col_rotor = 100 * h + col_rotor * (1-h);
    ail = getprop("/controls/flight/fbw/output/vtol/aileron") * (1-h);
    ele = ele * (1-h);
    rud = rud * (1-h);

    # Rotor collective
    out_rotor_r_col.setValue(airplane_control_factor * col_wing + helicopter_control_factor * (col_rotor - ail * ail2col));
    out_rotor_l_col.setValue(airplane_control_factor * col_wing + helicopter_control_factor * (col_rotor + ail * ail2col));

    ################################################################################

    setprop("sim/model/v22/helicopter_control_factor", helicopter_control_factor);
    setprop("sim/model/v22/airplane_control_factor", airplane_control_factor);
    setprop("sim/model/v22/flap_control_factor", flap_control_factor);
}

var set_tilt = func (delta = 0, target = nil) {
    if (props.globals.getNode("sim/crashed",1).getBoolValue()) {return; }
    var value = delta + (target == nil ? control_tilt.getValue() : target);
    value = clamp(value ,-10 ,90);
    control_tilt.setValue(value);
}

# timers ============================================================
aircraft.timer.new("/sim/time/hobbs/helicopter", nil).start();

# strobes ===========================================================
var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/v22/lighting/strobe-top", [0.05, 1.00], strobe_switch);
aircraft.light.new("sim/model/v22/lighting/strobe-bottom", [0.05, 1.03], strobe_switch);

# engines/rotor/wing =====================================================
var state = props.globals.getNode("sim/model/v22/state", 1);
var wing_state = props.globals.getNode("sim/model/v22/wing_state", 1);
var wing_rotation = props.globals.getNode("sim/model/v22/wing_rotation", 1);
var engine1 = props.globals.getNode("sim/model/v22/engine_right", 1);
var engine2 = props.globals.getNode("sim/model/v22/engine_left", 1);
var rotor = props.globals.getNode("controls/engines/engine/magnetos", 1);
var rotor_rpm = props.globals.getNode("rotors/main/rpm", 1);


# MP door/airrefuel ======================================================
# door cargodown - cargodoormix
var door_cargodown = props.globals.getNode("instrumentation/doors/cargodoor/position-norm", 1);
# door cargodoorup
var door_cargoup = props.globals.getNode("instrumentation/doors/cargodoorup/position-norm", 1);
# door airrefuel probe
var door_fuelpr = props.globals.getNode("instrumentation/doors/airrefuel/position-norm", 1);
# door cockpit
var door_cockpit = props.globals.getNode("instrumentation/doors/cockpitdoor/position-norm", 1);
# door crew
var door_crew = props.globals.getNode("instrumentation/doors/crew/position-norm", 1);
# door crewup
var door_crewup = props.globals.getNode("instrumentation/doors/crewup/position-norm", 1);

# MP gear-agl-meter for rotor particle ====================================
var gear_magl = props.globals.getNode("position/gear-agl-m", 1);

# MP gear-caster for gear rotation ====================================
var gear_cast = props.globals.getNode("gear/gear[0]/caster-angle-deg", 1);

# MP Front gear-spin ====================================
var gear0_spin = props.globals.getNode("gear/gear[0]/rollspeed-ms", 1);
# MP Left gear-spin ====================================
var gear1_spin = props.globals.getNode("gear/gear[1]/rollspeed-ms", 1);
# MP Right gear-spin ====================================
var gear2_spin = props.globals.getNode("gear/gear[2]/rollspeed-ms", 1);


# MP sim/model/v22/rotor/left/collective for rotor particle
var collective_left = props.globals.getNode("sim/model/v22/rotor/left/collective", 1);

# MP sim/model/v22/rotor/right/collective for rotor particle
var collective_right = props.globals.getNode("sim/model/v22/rotor/right/collective", 1);

# landing lights movement ====================================
var light_position = props.globals.getNode("instrumentation/doors/landinglightpos/position-norm", 1);

# landing lights state ====================================
var l_light_state = props.globals.getNode("sim/model/lights/landing-lights/state", 1);

# pushback state ====================================
var pback_state = props.globals.getNode("sim/model/pushback/enabled", 1);

# paratrooper jump state ====================================
#var ptroup_jump_state = props.globals.getNode("controls/jump-signal", 1);

# pushback positon ====================================
var pback_pos = props.globals.getNode("sim/model/pushback/position-norm", 1);


var torque = props.globals.getNode("rotors/gear/total-torque", 1);
var collective = props.globals.getNode("controls/engines/engine[0]/throttle", 1);
var turbine = props.globals.getNode("sim/model/v22/turbine-rpm-pct", 1);
var stall_right = props.globals.getNode("rotors/main/stall", 1);
var stall_filtered = props.globals.getNode("rotors/main/stall-filtered", 1);
var stall_left = props.globals.getNode("rotors/tail/stall", 1);
#var stall_left_filtered = props.globals.getNode("rotors/tail/stall-filtered", 1);
var torque_sound_filtered = props.globals.getNode("rotors/gear/torque-sound-filtered", 1);
var target_rel_rpm = props.globals.getNode("controls/rotor/reltarget", 1);
var max_rel_torque = props.globals.getNode("controls/rotor/maxreltorque", 1);

#wing_state
# 0 fly-position
# 1 moving engines up
# 2 folding blades
# 3 rotating wing and moving engines down
# 10 fully folded
# 11 rotating wing and moving engines up
# 12 unfolding blades
# 13 -> 0
var blade_folding = props.globals.getNode("sim/model/v22/blade_folding",1);
var blade_incidence = props.globals.getNode("rotors/main/blade/incidence-deg",1);

var animation_tilt_left = props.globals.getNode("sim/model/v22/rotor/left/animation_tilt",1);
var animation_tilt_right = props.globals.getNode("sim/model/v22/rotor/right/animation_tilt",1);

var update_wing_state = func {
    var ws = wing_state.getValue();
    var new_state = arg[0];
    if (new_state == (ws+1)) {
        wing_state.setValue(new_state);
        if (new_state == 1) {
            var animation_tilt_avg = (animation_tilt_left.getValue() + animation_tilt_right.getValue()) / 2;
            var delta = abs(animation_tilt_avg-0);
            settimer(func { update_wing_state(2) }, max(1.2 , delta/9+0.5));
            interpolate(animation_tilt_left, 0, delta/9);
            interpolate(animation_tilt_right, 0, delta/9);
            interpolate(out_wing_flap, 0, 5.5);
            interpolate(control_rotor_incidence_wing_fold, 1 , 1);
        }
        if (new_state == 2) {
            settimer(func { update_wing_state(3) }, 4);
            interpolate(blade_folding, 1, 3.5);
        }
        if (new_state == 3) {
            settimer(func { update_wing_state(4) }, 12);
            interpolate(animation_tilt_left, 90, 9);
            interpolate(animation_tilt_right, 90, 9);
            interpolate(wing_rotation, 90, 11.5);
        }
        if (new_state == 4) {
            wing_state.setValue(10);
        }
        if (new_state == 11) {
            settimer(func { update_wing_state(12) }, 12);
            # interpolate(animation_tilt, 90, 2.5, 0, 11);
            interpolate(wing_rotation, 0, 11.5);
            # interpolate(out_wing_flap, 0, 7, 1, 12.5);
            settimer(func { interpolate(animation_tilt_left, 0, 8.5); }, 2.5);
            settimer(func { interpolate(animation_tilt_right, 0, 8.5); }, 2.5);
            settimer(func { interpolate(out_wing_flap, 1, 5.5);}, 7);
        }
        if (new_state == 12) {
            settimer(func { update_wing_state(13) }, 4);
            interpolate(blade_folding, 0, 3.5);
        }
        if (new_state == 13) {
            set_tilt(0,0);
            interpolate(control_rotor_incidence_wing_fold, 0 , 1);
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
            target_rel_rpm.setValue(target_rpm / target_rpm_helicopter);
            interpolate(engine1, 1.0, 10);
        }
     }
     elsif (new_state == 3) {
        if (rotor_rpm.getValue() > 100) {
            # Rotor is running at high rpm, so accel. engine faster
            max_rel_torque.setValue(1);
            target_rel_rpm.setValue(target_rpm / target_rpm_helicopter);
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
            target_rel_rpm.setValue(target_rpm / target_rpm_helicopter);
        }
    }
    elsif (new_state == 5) {
        max_rel_torque.setValue(1);
        target_rel_rpm.setValue(target_rpm / target_rpm_helicopter);
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
        interpolate (engine1,  clamp( rotor_rpm.getValue() / 412 ,
                                0.25, target_rel_rpm.getValue() ), 0.25 );
        interpolate (engine2,  clamp( rotor_rpm.getValue() / 412 ,
                                0.25, target_rel_rpm.getValue() ), 0.20 );
    }
}

# torquemeter
torque.setDoubleValue(0);

var update_rotor_brake = func {
    var rpm=rotor_rpm.getValue();
    var brake=0;
    if ((state.getValue()==0) and (rpm < 250)) {
        var target = 95;
        var low = 25;
        var lrange = 5;
        var srange = 5;
        var pos = rotor_pos.getValue();
        if (rpm > low )
        {
            brake = (rpm-low + lrange * 0.25) / lrange;
            brake = clamp(brake, 0, 0.3);
        } else
        {
            var delta = target - pos;
            if (delta> 180) {delta = delta-360;}
            if (delta<-180) {delta = delta+360;}
            if ((delta > 0) and ((rpm-2) > delta*0.1 )) {
                brake = rpm-2-delta*0.1;
            }
            else {
                if (rpm * 3.5 < low) {
                    brake = (srange-abs(delta))/srange;
                }
            }
            brake = clamp (brake, 0,1);
        }
    }
    control_rotor_brake.setValue(brake);
}

controls.adjMixture = func(v) set_tilt(v > 0 ? 10 : -10);
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

    var animation_tilt_avg = (animation_tilt_left.getValue() + animation_tilt_right.getValue()) / 2;
    var at = animation_tilt_avg;
    var ats = abs (at - last_animation_tilt);
    if (dt > 0.00001){
        ats=ats/dt;
    }
    else {
        ats=ats*120;
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
    var c = collective.getValue();
    var r = clamp(rotor_rpm.getValue()*0.004-0.2,0,1);
    stall_filtered.setDoubleValue(r*min(1,0.5+5*stall_val + 0.006 * (1 - c)));
    
    #s = stall_left.getValue();
    #if (s < stall_left_val) {
    #   var f = dt / (0.3 + dt);
#       stall_left_val = s * f + stall_left_val * (1 - f);
#   } else {
#       stall_left_val = s;
#   }
#   c = collective.getValue();
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
        strobe_switch.setValue(0);
        lighting.beacon_switch.setValue(0);
        lighting.navigation_switch.setValue(0);
        rotor.setValue(0);
        stall_filtered.setValue(stall_val = 0);
        state.setValue(0);

    } else {
        # uncrash (for replay)
        setprop("rotors/tail/rpm", 412);
        setprop("rotors/main/rpm", 412);
        for (i = 0; i < 4; i += 1) {
            setprop("rotors/main/blade[" ~ i ~ "]/flap-deg", 0);
            setprop("rotors/main/blade[" ~ i ~ "]/incidence-deg", 0);
        }
        strobe_switch.setValue(1);
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


var update_mp_generics = func {
    setprop("sim/multiplay/generic/float[0]", blade_folding.getValue());
    setprop("sim/multiplay/generic/float[1]", animation_tilt_left.getValue());
    setprop("sim/multiplay/generic/float[2]", animation_tilt_right.getValue());
    setprop("sim/multiplay/generic/float[3]", wing_rotation.getValue());
    setprop("sim/multiplay/generic/float[4]", blade_incidence.getValue());

    # door cargodown
    setprop("sim/multiplay/generic/float[5]", door_cargodown.getValue());
    # door cargoup
    setprop("sim/multiplay/generic/float[6]", door_cargoup.getValue());
    # door airrefuel
    setprop("sim/multiplay/generic/float[7]", door_fuelpr.getValue());
    # door cockpit
    setprop("sim/multiplay/generic/float[8]", door_cockpit.getValue());
    # door crew
    setprop("sim/multiplay/generic/float[9]", door_crew.getValue());
    # door crewup
    setprop("sim/multiplay/generic/float[10]", door_crewup.getValue());

    # gear meter agl
    var gearagl_mp = gear_magl.getValue();
    if (gearagl_mp != nil) {
        setprop("sim/multiplay/generic/float[11]", gear_magl.getValue());
    }
    else {
        setprop("sim/multiplay/generic/float[11]", 0.0);
    }

    # gear caster-angle-deg for mp front gear caster rotation
    var gearcast_mp = gear_cast.getValue();
    if (gearcast_mp != nil) {
        setprop("sim/multiplay/generic/float[12]", gear_cast.getValue());
    }
    else {
        setprop("sim/multiplay/generic/float[12]", 0.0);
    }

    # Front gear spin A for mp
    setprop("sim/multiplay/generic/float[18]", gear0_spin.getValue());
    # Left gear spin G for mp
    setprop("sim/multiplay/generic/float[19]", gear1_spin.getValue());
    # Right gear spin D for mp
    setprop("sim/multiplay/generic/float[20]", gear2_spin.getValue());  

    # collective_left for particle effect 
    setprop("sim/multiplay/generic/float[14]", collective_left.getValue());

    # collective_right for particle effect 
    setprop("sim/multiplay/generic/float[15]", collective_right.getValue());

    # landing lights animation
    setprop("sim/multiplay/generic/float[16]", light_position.getValue());

    # landing lights state
    setprop("sim/multiplay/generic/int[10]", l_light_state.getValue());

    # pushback state
    var pbacks_mp = pback_state.getValue();
    if (pbacks_mp != nil) {
        setprop("sim/multiplay/generic/int[11]", pback_state.getValue());
    }
    else {
        setprop("sim/multiplay/generic/int[11]", 0);
    }

    # paratrooper jump signal state
    #var ptroup_mp = ptroup_jump_state.getValue();
    #if (ptroup_mp != nil) {
    #setprop("sim/multiplay/generic/int[12]", ptroup_jump_state.getValue());
    #} else {
    #setprop("sim/multiplay/generic/int[12]", 0);
    #}

    # pushback position animation
    var pbackpos_mp = pback_pos.getValue();
    if (pbackpos_mp != nil) {
        setprop("sim/multiplay/generic/float[17]", pback_pos.getValue());
    }
    else {
        setprop("sim/multiplay/generic/float[17]", 0);
    }
}

# main() ============================================================
var delta_time = props.globals.getNode("/sim/time/delta-realtime-sec", 1);

var main_loop = func {
    var dt = delta_time.getValue();
    update_stall(dt);
    update_torque_sound_filtered(dt);
    #update_slide();
    update_engine();
    update_sound(dt);
    update_controls_and_tilt_loop(dt);
    # update_rotor_brake();
    update_mp_generics();
}

var crashed = 0;

# Initialization
setlistener("/sim/signals/fdm-initialized", func {
    collective.setDoubleValue(1);
    #settimer(update_controls_and_tilt_loop, 0);

    setlistener("/sim/signals/reinit", func(n) {
        n.getBoolValue() and return;
        #turbine_timer.stop();
        collective.setDoubleValue(1);
        crashed = 0;
    });

    setlistener("sim/crashed", func(n) {
        #turbine_timer.stop();
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

    # the attitude indicator needs pressure
    # settimer(func { setprop("engines/engine/rpm", 3000) }, 8);

    var main_loop_timer = maketimer(0.0, main_loop);
    main_loop_timer.start();
});
