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
            gui.popupTip("Close loading ramp first", 3);
        }
    }
    else {
        cargo_upper.open();
        cargo_upper_state = 1;
    }
}

var cargo_lower_toggle = func {
    if (cargo_lower_state) {
        cargo_lower.close();
        cargo_lower_state = 0;
    }
    else {
        if (cargo_upper_state) {
            cargo_lower.open();
            cargo_lower_state = 1;
        }
        else {
            gui.popupTip("Open cargo door first", 3);
        }
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
            gui.popupTip("Close lower starboard door first", 3);
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
            gui.popupTip("Open upper starboard door first");
        }
    }
}

################################################################################

var cockpit = aircraft.door.new("instrumentation/doors/cockpitdoor", 1.0, 0);
var air_refuel = aircraft.door.new("instrumentation/doors/airrefuel", 4.0, 0);
var landinglightpos = aircraft.door.new("instrumentation/doors/landinglightpos", 4.0, 0);
