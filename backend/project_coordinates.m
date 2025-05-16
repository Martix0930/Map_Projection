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
            h = 2 * R; % 视点高度，可自定义
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
            % 模拟高斯-克吕格投影（Transverse Mercator 近似）
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

        otherwise
            error('Unsupported projection type: %s', type)
    end
end
