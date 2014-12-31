aircraft.tyresmoke_system.new(0, 1, 2);

aircraft.rain.init();
var rain_timer = maketimer(0.0, func aircraft.rain.update());
rain_timer.start();
