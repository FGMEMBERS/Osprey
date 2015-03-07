Version 1.0
===========

- Fix some parts of the FDM (dihedral, wing sweep, max speed to 305 KTAS
  up to FL150)
- Added FBW with g load and bank angle limits
- Added autopilot with custom panel (including auto nacelle function,
  VOR/ILS, TACAN, route manager)
- Emit warning sound when uncoupling the autopilot
- Using FlightGear's new-navradio code for more realistic ILS
- Fixed throttle behavior (you have to increase throttle to lift off or
  increase speed)
- Added fuel tanks, fuel system, and fuel truck:
    - One cut-off valve between each feeder tank and engine
    - Ground refueling and AAR via left sponson tank with refuel rate of
      420 gal/min
    - Ability to jettison fuel with 800 lbs/min
    - Added fuel truck that stays at a fixed position, not affected by
      roll/pitch of aircraft
    - Added Fuel System Configuration panel which you can use to tune the
      fuel consumption
    - Fuel in tanks is persistent across sessions
- Custom Fuel and Payload Settings window:
    - Make Cabin Crew and Flight Engineer installable
    - Require Cabin Crew or Flight Engineer to open/close specific doors
    - Only allow changing MATS tanks and crew on ground
    - Fuel tank sliders are read only, only way to add fuel is via fuel
      truck (which only works on the ground) or AAR
- Support for aerial refueling and fuel jettison
- Added better HUD:
    - Attitude indicator requires the engines to be running
- Added flight recorder
- Fix tilting behavior of nacelles:
    - Use tilt rate instead of fixed angles (You can control the tilt rate
      with keyboard/joystick (m, shift-m, or Alt-m (mixture keys) or mouse
      wheel)
    - Allow nacelles to be tilted to 45 degrees when on ground and forbid
      opening upper starboard door when nacelles tilt < 45 degrees
    - Added ability to use nacelles thumb wheel (keyboard/joystick or
      mouse wheel) to reduce RPM to 84 %
- Fixed multiplayer properties
- Support FlightGear 3.2's ATIS text-to-speech system
- Call out "sink rate" when you descend to fast (to avoid vortex ring state)
- Added MV-22 and CV-22 variants
- Added extra fuel tanks, TCAS, and flight engineer seat and view to CV-22
  variant
- Replaced Tail Camera view with FLIR Camera view (it does not give you
  a grey image though)
- Improved duration of Blades Fold/Wing Stow sequence
- New splash screens for MV-22 and CV-22 variants
- Disabled the viewing direction mode when pressing TAB key
- Variable anti-collision light frequency depending on TCL and tilt
- Show splash effect of raindrops on fuselage
- Lots of code clean up and many fixes
