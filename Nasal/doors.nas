# cargo, crew, and cockpit doors

var cargo_upper = aircraft.door.new("instrumentation/doors/cargodoorup", 3.0, 0);
var cargo_lower = aircraft.door.new("instrumentation/doors/cargodoor", 3.0, 0);

var (cargo_upper_state, cargo_lower_state) = (0, 0);

var cargo_upper_toggle = func {
    if (cargo_upper_state) {
        if (!cargo_lower_state) {
            cargo_upper.close();
            cargo_upper_state = 0;
        }
        else {
            gui.popupTip("Cabin crew: Close loading ramp first", 3);
        }
    }
    else {
        cargo_upper.open();
        cargo_upper_state = 1;
    }
}

# Position of the loading ramp when it is horizontal.
# 0 is fully closed, 1 is fully open.
var loading_ramp_horizontal_pos = 0.44;

# Position when the loading ramp is fully opened. Keep it a bit lower
# than 1.0 because otherwise it will touch or go through the ground.
var loading_ramp_max_pos = 0.9;

var loading_ramp_open = func {
    if (cargo_upper_state) {
        if (cargo_lower_state == 0) {
            cargo_lower.move(loading_ramp_horizontal_pos);
            cargo_lower_state = 1;
        }
        elsif (cargo_lower_state == 1) {
            cargo_lower.move(loading_ramp_max_pos);
            cargo_lower_state = 2;
        }
    }
    else {
        gui.popupTip("Cabin crew: Open cargo door first", 3);
    }
}

var loading_ramp_close = func {
    if (cargo_lower_state == 2) {
        cargo_lower.move(loading_ramp_horizontal_pos);
        cargo_lower_state = 1;
    }
    elsif (cargo_lower_state == 1) {
        cargo_lower.close();
        cargo_lower_state = 0;
    }
}

################################################################################

var crew_upper = aircraft.door.new("instrumentation/doors/crewup", 3.0, 0);
var crew_lower = aircraft.door.new("instrumentation/doors/crew", 3.0, 0);

var (crew_upper_state, crew_lower_state) = (0, 0);

var crew_upper_toggle = func {
    if (crew_upper_state) {
        if (!crew_lower_state) {
            crew_upper.close();
            crew_upper_state = 0;
        }
        else {
            gui.popupTip("Cabin crew: Close lower starboard door first", 3);
        }
    }
    else {
        crew_upper.open();
        crew_upper_state = 1;
    }
}

var crew_lower_toggle = func {
    if (crew_lower_state) {
        crew_lower.close();
        crew_lower_state = 0;
    }
    else {
        if (crew_upper_state) {
            crew_lower.open();
            crew_lower_state = 1;
        }
        else {
            gui.popupTip("Cabin crew: Open upper starboard door first");
        }
    }
}

################################################################################

var gear_up = func {
    if (getprop("/gear/gear[0]/wow") or getprop("/gear/gear[1]/wow") or getprop("/gear/gear[2]/wow")) {
        gui.popupTip("Co-pilot: Cannot move gear up while aircraft is on the ground");
    }
    else {
        controls.gearDown(-1);
    }
}

################################################################################

var cockpit = aircraft.door.new("instrumentation/doors/cockpitdoor", 1.0, 0);
var air_refuel = aircraft.door.new("instrumentation/doors/airrefuel", 4.0, 0);
var landinglightpos = aircraft.door.new("instrumentation/doors/landinglightpos", 4.0, 0);
