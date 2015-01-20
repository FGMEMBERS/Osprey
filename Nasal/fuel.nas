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

with("fuel");
with("fuel_sequencer");
with("updateloop");

check_version("fuel", 3, 1);
check_version("fuel_sequencer", 1, 2);

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
        ###############################################################################
        # Fuel consumption                                                            #
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
        # Fuel production                                                             #
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
        # Wing feeder tanks and engines                                               #
        ###############################################################################

        # Default gallons per second
        var default_max_capacity = 1.0;

        # Left/Right Wing Feeder tanks
        var tank_left_wing_feed  = fuel.Tank.new("left-wing-feeder", 2);
        var tank_right_wing_feed = fuel.Tank.new("right-wing-feeder", 3);

        # Left/Right Engines
        var left_engine  = fuel.EngineConsumer.new("left", left_engine_flow);
        var right_engine = fuel.EngineConsumer.new("right", right_engine_flow);

        # Pumps for the two engines
        var pump_left_feed_engine  = fuel.AutoPump.new("left-feed-engine", 1.0);
        var pump_right_feed_engine = fuel.AutoPump.new("right-feed-engine", 1.0);

        # Fuel cut-off valves for engines
        var valve_cutoff_left_engine = fuel.Valve.new("cut-off-left-engine", 1.0);
        var valve_cutoff_right_engine = fuel.Valve.new("cut-off-right-engine", 1.0);

        pump_left_feed_engine.connect(valve_cutoff_left_engine, left_engine);
        pump_right_feed_engine.connect(valve_cutoff_right_engine, right_engine);

        valve_cutoff_left_engine.connect(tank_left_wing_feed, pump_left_feed_engine);
        valve_cutoff_right_engine.connect(tank_right_wing_feed, pump_right_feed_engine);

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
        var pump_aar_probe = fuel.AutoPump.new("aar-probe", 7.0);

        pump_aar_probe.connect(aar_probe, tank_left_forward_sponson);

        ###############################################################################

        # Fuel truck contact point
        var fuel_truck = fuel.GroundRefuelProducer.new("fuel-truck", contact_point);

        # Pump for the fuel truck contact point
        var pump_fuel_truck = fuel.AutoPump.new("fuel-truck", 7.0);

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
        # Wing auxilliary tanks and their boost pumps                                 #
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
        # Refueling manifold, boost pump, and valves                                  #
        ###############################################################################

        # Default gallons per second for refueling lines
        # Should be larger than the flow rate of the fuel truck and AAR
        # probe, otherwise refueling would stop as soon as left forward
        # sponson tank is full.
        var refueling_max_capacity = 9.0;

        var manifold_refueling = fuel.Manifold.new("refueling");

        # Sources attached to the manifold
        var pump_refuel_left_fwd_sponson = fuel.BoostPump.new("refuel-left-fwd-sponson", refueling_max_capacity);

        # Sinks attached to the manifold
        var valve_refuel_right_fwd_sponson = fuel.Valve.new("refuel-right-fwd-sponson", refueling_max_capacity);
        var valve_refuel_right_aft_sponson = fuel.Valve.new("refuel-right-aft-sponson", refueling_max_capacity);
        var valve_refuel_fwd_mats_one   = fuel.Valve.new("refuel-fwd-mats-1", refueling_max_capacity);
        var valve_refuel_fwd_mats_two   = fuel.Valve.new("refuel-fwd-mats-2", refueling_max_capacity);
        var valve_refuel_aft_mats_three = fuel.Valve.new("refuel-aft-mats-3", refueling_max_capacity);

        # Add the sinks and sources to the manifold
        manifold_refueling.add_source(pump_refuel_left_fwd_sponson);
        manifold_refueling.add_sink(valve_refuel_right_fwd_sponson);
        manifold_refueling.add_sink(valve_refuel_right_aft_sponson);
        manifold_refueling.add_sink(valve_refuel_fwd_mats_one);
        manifold_refueling.add_sink(valve_refuel_fwd_mats_two);
        manifold_refueling.add_sink(valve_refuel_aft_mats_three);

        # Insert the valves between the tanks and the manifold
        pump_refuel_left_fwd_sponson.connect(tank_left_forward_sponson, manifold_refueling);
        valve_refuel_right_fwd_sponson.connect(manifold_refueling, tank_right_forward_sponson);
        valve_refuel_right_aft_sponson.connect(manifold_refueling, tank_right_aft_sponson);
        valve_refuel_fwd_mats_one.connect(manifold_refueling, tank_fwd_mats_one);
        valve_refuel_fwd_mats_two.connect(manifold_refueling, tank_fwd_mats_two);
        valve_refuel_aft_mats_three.connect(manifold_refueling, tank_aft_mats_three);

        if (getprop("/sim/aircraft") == "cv22") {
            # Sinks attached to the manifold
            var valve_refuel_left_wing_aux  = fuel.Valve.new("refuel-left-wing-aux", refueling_max_capacity);
            var valve_refuel_right_wing_aux = fuel.Valve.new("refuel-right-wing-aux", refueling_max_capacity);

            # Add the sinks to the manifold
            manifold_refueling.add_sink(valve_refuel_left_wing_aux);
            manifold_refueling.add_sink(valve_refuel_right_wing_aux);

            # Insert the valves between the tanks and the manifold
            valve_refuel_left_wing_aux.connect(manifold_refueling, tank_left_wing_aux);
            valve_refuel_right_wing_aux.connect(manifold_refueling, tank_right_wing_aux);
        }

        ###############################################################################

        # To do:
        # 1) Add some valves
        # 2) Add a JettisonConsumer
        # 3) Use two manifolds (one for the left side and one for the right side)

        me.manifolds = [
            manifold_feeders,
            manifold_refueling
        ];

        me.pumps = std.Vector.new();

        me.pumps.extend([
            pump_left_feed_engine,
            pump_right_feed_engine,

            # Group 1
            pump_right_aft_sponson,

            # Group 2
            pump_aft_mats_three,

            # Group 3
            pump_fwd_mats_one,
            pump_fwd_mats_two
        ]);

        # Add the two extra boost pumps of the wing auxilliary tanks for the CV-22
        if (getprop("/sim/aircraft") == "cv22") {
            me.pumps.extend([
                # Group 4
                pump_left_wing_aux,
                pump_right_wing_aux
            ]);
        }

        me.pumps.extend([
            # Group 5
            pump_left_fwd_sponson,
            pump_right_fwd_sponson,

            pump_aar_probe,
            pump_fuel_truck,
            pump_refuel_left_fwd_sponson
        ]);

        ###############################################################################
        # Pump group sequencer for engines operation                                  #
        ###############################################################################

        me.engines_sequencer = fuel_sequencer.PumpGroupSequencer.new(0.5, fuel_sequencer.EmptyTankPumpGroup);

        # Group 1: aft sponson tank
        var group1 = me.engines_sequencer.create_group();
        group1.add_tank_pump(tank_right_aft_sponson, pump_right_aft_sponson);

        # Group 2: aft MATS tank
        var group2 = me.engines_sequencer.create_group();
        group2.add_tank_pump(tank_aft_mats_three, pump_aft_mats_three);

        # Group 3: forward MATS tanks
        var group3 = me.engines_sequencer.create_group();
        group3.add_tank_pump(tank_fwd_mats_one, pump_fwd_mats_one);
        group3.add_tank_pump(tank_fwd_mats_two, pump_fwd_mats_two);

        if (getprop("/sim/aircraft") == "cv22") {
            # Group 4: wing auxilliary tanks
            var group4 = me.engines_sequencer.create_group();
            group4.add_tank_pump(tank_left_wing_aux, pump_left_wing_aux);
            group4.add_tank_pump(tank_right_wing_aux, pump_right_wing_aux);
        }

        # Group 5: forward sponson tanks
        var group5 = me.engines_sequencer.create_group();
        group5.add_tank_pump(tank_left_forward_sponson, pump_left_fwd_sponson);
        group5.add_tank_pump(tank_right_forward_sponson, pump_right_fwd_sponson);

        ###############################################################################
        # Pump group sequencer for refueling                                          #
        ###############################################################################

        me.refueling_sequencer = fuel_sequencer.PumpGroupSequencer.new(0.5, fuel_sequencer.FullTankPumpGroup);

        # Only let fuel truck or tanker fill left forward sponson tank if
        # there is at least this amount of gallons free, otherwise there is
        # a risk of filling the tank completely, which results in stopping
        # the refueling operation.
        var refuel_buffer_gal = 10.0;

        # Group 1: forward sponson tanks
        var group1 = me.refueling_sequencer.create_group();
        group1.set_condition(func (group) {
            var tank = tank_left_forward_sponson;
            return tank.get_typical_level() - tank.get_current_level() > refuel_buffer_gal;
        });
        group1.add_tank_pump(tank_right_forward_sponson, valve_refuel_right_fwd_sponson);

        if (getprop("/sim/aircraft") == "cv22") {
            # Group 2: wing auxilliary tanks
            var group2 = me.refueling_sequencer.create_group();
            group2.add_tank_pump(tank_left_wing_aux, valve_refuel_left_wing_aux);
            group2.add_tank_pump(tank_right_wing_aux, valve_refuel_right_wing_aux);
        }

        # Group 3: forward MATS tanks
        var group3 = me.refueling_sequencer.create_group();
        group3.add_tank_pump(tank_fwd_mats_one, valve_refuel_fwd_mats_one);
        group3.add_tank_pump(tank_fwd_mats_two, valve_refuel_fwd_mats_two);

        # Group 4: aft MATS tank
        var group4 = me.refueling_sequencer.create_group();
        group4.add_tank_pump(tank_aft_mats_three, valve_refuel_aft_mats_three);

        # Group 5: aft sponson tank
        var group5 = me.refueling_sequencer.create_group();
        group5.add_tank_pump(tank_right_aft_sponson, valve_refuel_right_aft_sponson);

        ###############################################################################

        # Make tank levels persistent across sessions
        fuel.make_tank_levels_persistent();
    },

    update: func (dt) {
        me.engines_sequencer.update_pumps();
        me.refueling_sequencer.update_pumps();

        foreach (var manifold; me.manifolds) {
            manifold.prepare_distribution(dt);
        }

        foreach (var pump; me.pumps.vector) {
            pump.transfer_fuel(dt);
        }
    }

};

FuelSystemUpdater.new();
