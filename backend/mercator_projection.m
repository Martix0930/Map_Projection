function [x_proj, y_proj] = mercator_projection(lon, lat)
    lat_rad = deg2rad(lat);
    y_proj = rad2deg(log(tan(pi/4 + lat_rad/2)));
    x_proj = lon;
end