# =====
# terrain_under
# =====

terrain_under = func {

var lat = getprop("/position/latitude-deg");
var lon = getprop("/position/longitude-deg");
var info = geodinfo(lat, lon);

    if (info != nil) {
    if (info[1] != nil){
   if (info[1].solid !=nil)
      setprop("/environment/terrain",info[1].solid);
   if (info[1].load_resistance !=nil)
      setprop("/environment/terrain-load-resistance",info[1].load_resistance);
   if (info[1].friction_factor!=nil)
      setprop("/environment/terrain-friction-factor",info[1].friction_factor);
   if (info[1].bumpiness)
      setprop("/environment/terrain-bumpiness",info[1].bumpiness);
   if (info[1].rolling_friction)
      setprop("/environment/terrain-rolling-friction",info[1].rolling_friction);
         #debug.dump(geodinfo(lat, lon));
   }
    }else {
    setprop("/environment/terrain",1);
    }
#print ("lat  ", lat , "lon  " , lon);
settimer (terrain_under, 0.1);
}


terrain_under();
