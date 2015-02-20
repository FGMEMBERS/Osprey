# Beacon lights low frequency (enable for 50 ms with interval of 3 seconds => |..|)
var beacon_switch_low = props.globals.initNode("controls/lighting/beacon-low", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/beacon", [0.05, 2.95], beacon_switch_low);

# Beacon lights medium frequency (enable for 50 ms with interval of 1 second, 3 seconds => ||..||)
var beacon_switch_medium = props.globals.initNode("controls/lighting/beacon-medium", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/beacon", [0.05, 0.95, 0.05, 2.95], beacon_switch_medium);

# Beacon lights high frequency (enable for 50 ms with interval of 1 second, 1 second, 2 seconds => |||.|||)
var beacon_switch_high = props.globals.initNode("controls/lighting/beacon-high", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/beacon", [0.05, 0.95, 0.05, 0.95, 0.05, 1.95], beacon_switch_high);

# Beacon lights full frequency (enable for 50 ms with interval of 1 second => ||)
var beacon_switch_full = props.globals.initNode("controls/lighting/beacon-full", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/beacon", [0.05, 0.95], beacon_switch_full);

# Navigation lights
var navigation_switch = props.globals.initNode("controls/lighting/nav-lights", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/position", [1.0], navigation_switch);

# Navigation lights ground operations
var taxi_switch = props.globals.initNode("controls/lighting/taxi-light", 0, "BOOL");
aircraft.light.new("sim/model/v22/lighting/position", [0.60, 0.10], taxi_switch);
