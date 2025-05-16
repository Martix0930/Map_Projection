% Map_Projection\backend\project_with_baseline.m

function [x_proj_all, y_proj_all, x_raw_all, y_raw_all, area_original, area_projected] = project_with_baseline(lon_cell, lat_cell, projection_type)
    % 对比真实面积图形（等积投影）与投影变形图形（任意投影）

    R = 6371; % 地球半径，单位：km
    x_proj_all = {};
    y_proj_all = {};
    x_raw_all = {};
    y_raw_all = {};
    area_original = 0;
    area_projected = 0;

    for i = 1:length(lon_cell)
        lon = lon_cell{i};
        lat = lat_cell{i};

        % 球面真实面积（近似）
        area_original = area_original + spherical_polygon_area(lon, lat, R);

        % 改为原始经纬度直接传给前端（无投影！）
        x_raw_all{end+1} = lon;
        y_raw_all{end+1} = lat;

        % === 用户选择的变形投影（黄图）
        [x_proj, y_proj] = project_coordinates(lon, lat, projection_type, R);
        x_proj_all{end+1} = x_proj;
        y_proj_all{end+1} = y_proj;

        % 平面面积近似计算
        area_projected = area_projected + polyarea(x_proj, y_proj);
    end
end

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