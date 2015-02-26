io.include("Aircraft/ExpansionPack/Nasal/init.nas");

with("fuel_truck_dialog");

var control_panel = gui.Dialog.new("sim/gui/dialogs/control-panel/dialog", "Aircraft/V-22/Dialogs/control-panel.xml");
var control_panel_fbw = gui.Dialog.new("sim/gui/dialogs/control-panel-fbw/dialog", "Aircraft/V-22/Dialogs/control-panel-fbw.xml");

var config_panel_fuel = gui.Dialog.new("sim/gui/dialogs/configuration-panel-fuel/dialog", "Aircraft/V-22/Dialogs/configuration-panel-fuel.xml");

# Replace Fuel and Payload Settings window
var fuel_payload_settings = gui.Dialog.new("sim/gui/dialogs/fuel-payload-settings/dialog", "Aircraft/V-22/Dialogs/fuel-payload-settings.xml");
gui.menuBind("fuel-and-payload", "dialogs.fuel_payload_settings.open()");

# Replace Autopilot Settings window
var autopilot = gui.Dialog.new("sim/gui/dialogs/autopilot-panel/dialog", "Aircraft/V-22/Dialogs/autopilot-panel.xml");
gui.menuBind("autopilot-settings", "dialogs.autopilot.open()");
