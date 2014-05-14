# =====
# Doors
# =====

Doors = {};

Doors.new = func {
   obj = { parents : [Doors],
           crewup : aircraft.door.new("instrumentation/doors/crewup", 3.0, 0),
		   crew : aircraft.door.new("instrumentation/doors/crew", 3.0, 0),
		   cargodoor : aircraft.door.new("instrumentation/doors/cargodoor", 3.0, 0),
		   cargodoorfull : aircraft.door.new("instrumentation/doors/cargodoorfull", 3.0, 0),
		   cargodoorup : aircraft.door.new("instrumentation/doors/cargodoorup", 3.0, 0),
		   cockpitdoor : aircraft.door.new("instrumentation/doors/cockpitdoor", 1.0, 0),
		   airrefule : aircraft.door.new("instrumentation/doors/airrefule", 4.0, 0),
		   landinglightpos : aircraft.door.new("instrumentation/doors/landinglightpos", 4.0, 0),
         };
   return obj;
};

Doors.crewupexport = func {
   me.crewup.toggle();
}

Doors.crewexport = func {
   me.crew.toggle();
}

Doors.cargodoorexport = func {
   me.cargodoor.toggle();
}

Doors.cargodoorfullexport = func {
   me.cargodoorfull.toggle();
}

Doors.cargodoorupexport = func {
   me.cargodoorup.toggle();
}

Doors.cockpitdoorexport = func {
   me.cockpitdoor.toggle();
}

Doors.airrefuleexport = func {
   me.airrefule.toggle();
}

Doors.landinglightposexport = func {
   me.landinglightpos.toggle();
}



# ==============
# Initialization
# ==============

# objects must be here, otherwise local to init()
doorsystem = Doors.new();




