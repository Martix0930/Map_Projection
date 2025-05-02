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

        % === 原始真实形状（红图）：统一采用等积投影
        [x_raw, y_raw] = project_coordinates(lon, lat, 'aea', R);
        x_raw_all{end+1} = x_raw;
        y_raw_all{end+1} = y_raw;

        % === 用户选择的变形投影（黄图）
        [x_proj, y_proj] = project_coordinates(lon, lat, projection_type, R);
        x_proj_all{end+1} = x_proj;
        y_proj_all{end+1} = y_proj;

        % 平面面积近似计算
        area_projected = area_projected + polyarea(x_proj, y_proj);
    end
end

function [x, y] = project_coordinates(lon, lat, type, R)
    lat_rad = deg2rad(lat);
    lon_rad = deg2rad(lon);

    switch lower(type)
        %% 方位投影
        case 'azimuthal_equidistant'
            x = R * cos(lat_rad) .* sin(lon_rad);
            y = R * lat_rad;

        case 'azimuthal_equal_area'
            k = sqrt(2 ./ (1 + cos(lat_rad) .* cos(lon_rad)));
            x = R * k .* cos(lat_rad) .* sin(lon_rad);
            y = R * k .* sin(lat_rad);

        case 'azimuthal_conformal'
            x = 2 * R * tan((pi/4) - (lat_rad / 2)) .* sin(lon_rad);
            y = -2 * R * tan((pi/4) - (lat_rad / 2)) .* cos(lon_rad);

        case 'azimuthal_perspective'
            h = 2 * R;
            cos_c = cos(lat_rad) .* cos(lon_rad);
            x = R * sin(lon_rad) ./ (1 + cos_c);
            y = R * sin(lat_rad) ./ (1 + cos_c);

        %% 圆锥投影
        case 'conic_conformal'
            stdlat = deg2rad(30);
            n = sin(stdlat);
            rho = R * cot(stdlat) - lat_rad;
            theta = n * lon_rad;
            x = rho .* sin(theta);
            y = -rho .* cos(theta);

        case 'conic_equal_area'
            stdlat = deg2rad(30);
            n = sin(stdlat);
            rho = 2 * R * sqrt(1 - n^2) ./ (1 + n * sin(lat_rad));
            theta = n * lon_rad;
            x = rho .* sin(theta);
            y = -rho .* cos(theta);

        case 'conic_equidistant'
            stdlat = deg2rad(30);
            n = sin(stdlat);
            rho = R * (1 - n * lat_rad);
            theta = n * lon_rad;
            x = rho .* sin(theta);
            y = -rho .* cos(theta);

        %% 圆柱投影
        case 'cylindrical_conformal'
            x = R * lon_rad;
            y = R * log(tan(pi/4 + lat_rad/2));

        case 'cylindrical_equal_area'
            x = R * lon_rad;
            y = R * sin(lat_rad);

        case 'cylindrical_equidistant'
            x = R * lon_rad;
            y = R * lat_rad;

        %% 特殊投影
        case 'gauss_kruger'
            k0 = 1;
            x = R * k0 * lon_rad;
            y = R * k0 * log(tan(pi/4 + lat_rad/2));

        case 'pseudo_azimuthal'
            x = R * lon_rad .* cos(lat_rad);
            y = R * lat_rad;

        case 'pseudo_cylindrical'
            x = R * lon_rad .* cos(lat_rad);
            y = R * lat_rad;

        case 'pseudo_conic'
            x = R * lon_rad .* sin(lat_rad);
            y = R * lat_rad;

        %% 默认（等积投影）
        case 'aea' % Albers Equal Area
            stdlat = deg2rad(20);
            n = sin(stdlat);
            C = cos(stdlat)^2;
            rho = 2 * R * sqrt(C - n * sin(lat_rad)) / n;
            theta = n * lon_rad;
            x = rho .* sin(theta);
            y = -rho .* cos(theta);

        otherwise
            error('Unsupported projection type: %s', type);
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