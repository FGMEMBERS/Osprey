# Copyright (C) 2015  onox
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

io.include("Aircraft/ExpansionPack/Nasal/init.nas");

with("fuel", "updateloop");
check_version("fuel", 1, 0);

# Number of iterations per second
var frequency = 2.0;

# RPM at which engines are running the most efficiently.
# By default this is 84 % Nr.
var target_rpm_eff = 334;

# At 100 % Nr about 19 % extra fuel is consumed compared to 84 % Nr
extra_fuel_100_nr_perc = (397 / target_rpm_eff - 1) * 100;

var FuelSystemUpdater = {

    new: func {
        var m = {
            parents: [FuelSystemUpdater, updateloop.Updatable]
        };
        m.loop = updateloop.UpdateLoop.new(components: [m], update_period: 1 / frequency);
        return m;
    },

    get_gain: func (rpm) {
        var full_rpm_extra_perc = getprop("/systems/fuel/settings/full-rpm-extra-perc");
        var gain_no_tcl = getprop("/systems/fuel/settings/gain-no-tcl");
        var gain_full_tcl = getprop("/systems/fuel/settings/gain-full-tcl");
        var vtol_extra_perc = getprop("/systems/fuel/settings/vtol-extra-perc");

        # Compute tilt gain
        var factor_vtol = max(0, getprop("/v22/pfcs/internal/tilt-cos"));
        var gain_vtol   = (vtol_extra_perc / 100) * factor_vtol + 1;

        # Compute the 100/84 % Nr gain
        var extra_ineff  = max(target_rpm_eff, rpm) / target_rpm_eff - 1;
        var factor_ineff = full_rpm_extra_perc / extra_fuel_100_nr_perc;
        var gain_ineff   = extra_ineff * factor_ineff + 1;

        # Compute RPM gain so that engines do not consume fuel if RPM is
        # zero, but throttle is higher than zero.
        var gain_rpm = max(0, min(rpm / target_rpm_eff, 1));

        # Compute power gain
        var gain_tcl = gain_no_tcl + getprop("/v22/pfcs/output/tcl") * (gain_full_tcl - gain_no_tcl);

        return gain_tcl * gain_ineff * gain_rpm * gain_vtol;
    },

    get_lbs_per_hour: func (rpm) {
        var default_lbs_hour = getprop("/systems/fuel/settings/default-lbs-hour");
        return me.get_gain(rpm) * default_lbs_hour / 2;
    },

    reset: func {
        me.manifolds = [];
        me.pumps = std.Vector.new();

        ###############################################################################
        # Fuel Consumption                                                            #
        ###############################################################################

        var ppg = getprop("/consumables/fuel/tank[2]/density-ppg");

        var super = me;

        var left_engine_flow = func (flow, dt) {
            var lbs_hour = super.get_lbs_per_hour(getprop("/rotors/tail/rpm"));
            setprop("/v22/fadec/internal/left-lbs-hour", lbs_hour);

            var gal_s = lbs_hour / ppg / 3600;
            var flow_needed = gal_s * dt;
            var flow_used = min(flow_needed, flow);

            if (flow_needed > 0.0) {
                var fuel_flow_norm = flow_used / flow_needed;
                if (fuel_flow_norm < 0.1) {
                    fuel_flow_norm = 0.0;
                }
                setprop("/v22/fadec/output/fuel-flow-norm", fuel_flow_norm);
            }
            else {
                setprop("/v22/fadec/output/fuel-flow-norm", 0.0);
            }

            return max(0, flow_used);
        };
        var right_engine_flow = func (flow, dt) {
            var lbs_hour = super.get_lbs_per_hour(getprop("/rotors/main/rpm"));
            setprop("/v22/fadec/internal/right-lbs-hour", lbs_hour);

            var gal_s = lbs_hour / ppg / 3600;
            var flow_needed = gal_s * dt;
            var flow_used = min(flow_needed, flow);

            return max(0, flow_used);
        };

        ###############################################################################
        # Fuel Production                                                             #
        ###############################################################################

        var probe = func (tanker, dt) {
            var tanker_lbs_min = tanker.getNode("refuel/max-fuel-transfer-lbs-min", 1).getValue() or 6000;
            var osprey_lbs_min = getprop("/systems/refuel/max-fuel-transfer-lbs-min");

            var lbs_s = std.min(tanker_lbs_min, osprey_lbs_min) / 60;
            var gal_s = lbs_s / ppg;

            return gal_s * dt;
        };

        var contact_point = func (fuel_truck, dt) {
            var truck_total_gal_us = fuel_truck.getNode("level-gal_us").getValue();

            # Compute maximum gal/s that can be transferred
            var truck_lbs_s = fuel_truck.getNode("max-fuel-transfer-lbs-min").getValue() / 60;
            var truck_gal_s = truck_lbs_s / ppg;

            # Compute actual flow (per step instead of per second), taking
            # into account the maximum amount of fuel in the truck
            var flow = truck_gal_s * dt;
            return std.min(flow, truck_total_gal_us);
        };

        ###############################################################################
        # Wing Feeder tanks and Engines                                               #
        ###############################################################################

        # Default gallons per time step
        var default_max_capacity = 0.1;

        # Left/Right Wing Feeder tanks
        var tank_left_wing_feed  = fuel.Tank.new("left-wing-feeder", 2);
        var tank_right_wing_feed = fuel.Tank.new("right-wing-feeder", 3);

        # Left/Right Engines
        var left_engine  = fuel.EngineConsumer.new("left", left_engine_flow);
        var right_engine = fuel.EngineConsumer.new("right", right_engine_flow);

        # Pumps for the two engines
        var pump_left_feed_engine  = fuel.AutoPump.new("left-feed-engine", 1.0);
        var pump_right_feed_engine = fuel.AutoPump.new("right-feed-engine", 1.0);

        pump_left_feed_engine.connect(tank_left_wing_feed, left_engine);
        pump_right_feed_engine.connect(tank_right_wing_feed, right_engine);

        ###############################################################################
        # Manifold and the sponson tanks and their boost pumps                        #
        ###############################################################################

        var manifold_feeders = fuel.Manifold.new("feeders");

        # Sinks attached to the manifold
        var tube_left_feeder  = fuel.Tube.new("left-feeder", default_max_capacity);
        var tube_right_feeder = fuel.Tube.new("right-feeder", default_max_capacity);

        # Sources attached to the manifold
        var pump_left_fwd_sponson  = fuel.BoostPump.new("left-fwd-sponson", default_max_capacity);
        var pump_right_fwd_sponson = fuel.BoostPump.new("right-fwd-sponson", default_max_capacity);
        var pump_right_aft_sponson = fuel.BoostPump.new("right-aft-sponson", default_max_capacity);

        # Add the sinks and sources to the manifold
        manifold_feeders.add_sink(tube_left_feeder);
        manifold_feeders.add_sink(tube_right_feeder);
        manifold_feeders.add_source(pump_left_fwd_sponson);
        manifold_feeders.add_source(pump_right_fwd_sponson);
        manifold_feeders.add_source(pump_right_aft_sponson);

        # Insert the tubes between the manifold and the two wing feeder tanks
        tube_left_feeder.connect(manifold_feeders, tank_left_wing_feed);
        tube_right_feeder.connect(manifold_feeders, tank_right_wing_feed);

        # The sponson tanks
        var tank_left_forward_sponson  = fuel.Tank.new("left-forward-sponson", 0);
        var tank_right_forward_sponson = fuel.Tank.new("right-forward-sponson", 1);
        var tank_right_aft_sponson     = fuel.Tank.new("right-aft-sponson", 4);

        # Insert the boost pumps between the sponson tanks and the manifold
        pump_left_fwd_sponson.connect(tank_left_forward_sponson, manifold_feeders);
        pump_right_fwd_sponson.connect(tank_right_forward_sponson, manifold_feeders);
        pump_right_aft_sponson.connect(tank_right_aft_sponson, manifold_feeders);

        ###############################################################################

        # Aerial refueling probe
        var aar_probe = fuel.AirRefuelProducer.new("probe", probe);

        # Pump for the aerial refueling probe
        var pump_aar_probe = fuel.AutoPump.new("aar-probe", 1.0);

        pump_aar_probe.connect(aar_probe, tank_left_forward_sponson);

        ###############################################################################

        # Fuel truck contact point
        var fuel_truck = fuel.GroundRefuelProducer.new("fuel-truck", contact_point);

        # Pump for the fuel truck contact point
        var pump_fuel_truck = fuel.AutoPump.new("fuel-truck", 1.0);

        pump_fuel_truck.connect(fuel_truck, tank_left_forward_sponson);

        ###############################################################################
        # MATS tanks and their boost pumps                                            #
        ###############################################################################

        # Sources attached to the manifold
        var pump_fwd_mats_one   = fuel.BoostPump.new("fwd-mats-1", default_max_capacity);
        var pump_fwd_mats_two   = fuel.BoostPump.new("fwd-mats-2", default_max_capacity);
        var pump_aft_mats_three = fuel.BoostPump.new("aft-mats-3", default_max_capacity);

        # Add the sources to the manifold
        manifold_feeders.add_source(pump_fwd_mats_one);
        manifold_feeders.add_source(pump_fwd_mats_two);
        manifold_feeders.add_source(pump_aft_mats_three);

        # The MATS tanks
        var tank_fwd_mats_one   = fuel.Tank.new("fwd-mats-1", 5);
        var tank_fwd_mats_two   = fuel.Tank.new("fwd-mats-2", 6);
        var tank_aft_mats_three = fuel.Tank.new("aft-mats-3", 7);

        # Insert the boost pumps between the MATS tanks and the manifold
        pump_fwd_mats_one.connect(tank_fwd_mats_one, manifold_feeders);
        pump_fwd_mats_two.connect(tank_fwd_mats_two, manifold_feeders);
        pump_aft_mats_three.connect(tank_aft_mats_three, manifold_feeders);

        ###############################################################################
        # Wing Auxilliary tanks and their boost pumps                                 #
        ###############################################################################

        if (getprop("/sim/aircraft") == "cv22") {
            # Sources attached to the manifold
            var pump_left_wing_aux  = fuel.BoostPump.new("left-wing-aux", default_max_capacity);
            var pump_right_wing_aux = fuel.BoostPump.new("right-wing-aux", default_max_capacity);

            # Add the sources to the manifold
            manifold_feeders.add_source(pump_left_wing_aux);
            manifold_feeders.add_source(pump_right_wing_aux);

            # The wing auxilliary tanks
            var tank_left_wing_aux  = fuel.Tank.new("left-wing-aux", 8);
            var tank_right_wing_aux = fuel.Tank.new("right-wing-aux", 9);

            # Insert the boost pumps between the auxilliary tanks and the manifold
            pump_left_wing_aux.connect(tank_left_wing_aux, manifold_feeders);
            pump_right_wing_aux.connect(tank_right_wing_aux, manifold_feeders);
        }

        ###############################################################################

        # Notes:
        # 1) Actual aircraft needs to add some higher level Nasal code that
        #    controls which pumps are enabled/disabled
        # 2) Add some valves
        # 3) Add a JettisonConsumer

        # Enable sponson tanks
        pump_left_fwd_sponson.enable();
        pump_right_fwd_sponson.enable();
        pump_right_aft_sponson.enable();

        # Enable MATS tanks
        #pump_fwd_mats_one.enable();
        #pump_fwd_mats_two.enable();
        #pump_aft_mats_three.enable();

        # Enable wing auxilliary tanks
        #pump_left_wing_aux.enable();
        #pump_right_wing_aux.enable();

        me.manifolds = [
            manifold_feeders
        ];

        me.pumps.extend([
            pump_left_feed_engine,
            pump_right_feed_engine,

            pump_right_aft_sponson,

            pump_aft_mats_three,

            pump_fwd_mats_one,
            pump_fwd_mats_two
        ]);

        # Add the two extra boost pumps of the wing auxilliary tanks for the CV-22
        if (getprop("/sim/aircraft") == "cv22") {
            me.pumps.extend([
                pump_left_wing_aux,
                pump_right_wing_aux
            ]);
        }

        me.pumps.extend([
            pump_left_fwd_sponson,
            pump_right_fwd_sponson,

            pump_aar_probe,
            pump_fuel_truck
        ]);
    },

    update: func (dt) {
        foreach (var manifold; me.manifolds) {
            manifold.prepare_distribution(dt);
        }

        foreach (var pump; me.pumps.vector) {
            pump.transfer_fuel(dt);
        }
    }

};

FuelSystemUpdater.new();
