# Beacon lights (enable for 50 ms every 2 seconds)
var beacon_switch = props.globals.initNode("controls/lighting/beacon", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/beacon", [0.05, 1.95], beacon_switch);

# Navigation lights
var navigation_switch = props.globals.initNode("controls/lighting/nav-lights", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/position", [1.0], navigation_switch);

# Navigation lights ground operations
var taxi_switch = props.globals.initNode("controls/lighting/taxi-light", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/position", [0.60, 0.10], taxi_switch);
