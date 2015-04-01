Bell Boeing V-22 Osprey for FlightGear
======================================

This is a model of the V-22 Osprey for FlightGear.

Dependencies
------------

* FlightGear 3.4 or later

* [ExpansionPack][url-fg-expansion-pack] aircraft

84 % RPM
========

Once you have tilted the nacelles completely horizontal, you can beep the
RPM of the engines to 84 %. The procedure is as follows:

1. Transition to APLN mode by tilting the nacelles completely horizontal

2. Make sure that the RPM is at least 99 %

3. Set the tilt rate to 0 deg/s with Alt-m or using the mouse wheel

4. Increase the tilt rate to at least 1 deg/s or by using the mouse wheel

5. Set the tilt rate back to 0 deg/s

The RPM should now decrease to 84 %. In order to be able to tilt the nacelles
aft, the RPM must be at least 99 %. To increase the RPM from 84 % to 99 % you
must follow the following procedure:

1. Make sure the nacelles are tilted completely horizontal

2. Check that the RPM is about 84 %

3. Set the tilt rate to 0 deg/s with Alt-m or using the mouse wheel

4. Increase the tilt rate to at least 1 deg/s or by using the mouse wheel

5. Set the tilt rate back to 0 deg/s

The RPM should now go back to at least 99 %. Once it has reached this RPM
you can tilt the nacelles aft to convert to VTOL mode.

Autopilot
=========

A custom 'Autopilot Panel' window has been implemented, which implements
some of the autopilot modes. In the center of the window you can buttons
to control the heading, speed, and altitude:

* **HDG** controls the magnetic heading

* **SPEED** controls the IAS in knots

* **ALT** controls the altitude based on the atmospheric pressure (AMSL)

* **HVR ALT** controls the altitude above ground level (AGL)

To the left of the basic hold modes, there are some additional modes:

* **VOR/ILS** controls the heading if the NAV1 frequency is a VOR
  beacon or heading and vertical speed if the NAV1 frequency is an
  ILS signal. The glideslope will be captured after the localizer
  has been captured first. If WYPT is active then you need to be
  quite close to the crosstrack of the VOR/ILS signal

* **APPR** controls the final altitude, speed, and glideslope when
  approaching a waypoint. These parameters are set by using the CDU

* **WYPT** controls the heading based on the current waypoint of the route
  that you have set in the 'Route Manager' window. If WYPT shows 'CAP'
  and 'VOR/ILS' shows 'ARM', then the autopilot will switch to 'VOR/ILS'
  once it is sufficiently close to the crosstrack of the ILS localizer

* **TACAN** controls the heading based on the TACAN channel ID set in the
  'Radio Frequencies' window. Currently it can be used to follow AI
  tankers or TACAN stations. If you want to follow aircraft in multiplayer,
  then you need to enter the callsign of the player in `/v22/afcs/target/mp-callsign-tacan`

Fly-By-Wire (for pilots)
========================

Various properties of the Fly-By-Wire can be tuned in the Control Panel FBW
window.

Sidestick versus displacement controller
----------------------------------------

The real Osprey uses a displacement controller, but since I found the aircraft
in FlightGear to be fairly difficult to control that way I decided to implement
a sidestick controller.

If you uncheck the 'Sidestick controller' checkbutton, your stick input will
directly control the flight surfaces and rotor swashplates. In that case you
may want to tune 'Roll Rate Gain' and 'Pitch Rate Gain' under 'Direct Mode APLN'
and 'Direct Mode VTOL'.

Currently 'Yaw Rate Gain' and 'Lateral Move Gain' are always used. No heading
hold for low airspeeds and turn coordinator for high airspeeds have been
implemented yet.

If you keep the 'Sidestick controller' checkbutton checked, then you can tune
various properties under 'FBW'. These properties are also used by the autopilot.

Fly-By-Wire (for developers)
============================

Properties are located in `/v22/pfcs/`. Boolean values can be toggled by
holding Ctrl button while click on the property. If you hold Shift while
clicking on a property, it will display the property on the screen.

Modes
-----

Modes are enabled or disabled via properties in `active/`. Some properties
like `roll-rate-bank-angle` are read-only or get automatically enabled if
certain other properties become true.

Limits
------

The minimum and maximum g force limits are read-only and depend on the
airspeed and whether the aircraft is in VTOL or APLN mode.

VTOL factors
------------

Depending on the tilt of the nacelles and the airspeed, several factors
are computed which control how effective the VTOL flight controls are.
These factors are read-only and can be found in `internal/`

* Differential Collective Pitch (DCP) controls the roll

* Lateral Swashplate Gearing (LSG) provides lateral movement

* Longitudinal Swashplate Tilting (LST) controls the pitch 

* Differential Swashplate Tilting (DST) controls the yaw

  [url-fg-expansion-pack]: https://github.com/onox/ExpansionPack
