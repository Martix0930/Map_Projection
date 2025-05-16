% Map_Projection\backend\spherical_polygon_area.m

function area = spherical_polygon_area(lon, lat, R)
    if length(lon) < 3
        area = 0;
        return;
    end
    lat_rad = deg2rad(lat);
    lon_rad = deg2rad(lon);
    area = 0;
    for i = 1:length(lat)
        j = mod(i, length(lat)) + 1;
        area = area + (lon_rad(j) - lon_rad(i)) * ...
               (2 + sin(lat_rad(i)) + sin(lat_rad(j)));
    end
    area = abs(area * R^2 / 2);
end