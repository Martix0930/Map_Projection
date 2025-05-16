from flask import Flask, request, jsonify
from flask_cors import CORS
import matlab.engine

app = Flask(__name__)
CORS(app)

print("\U0001F680 启动 Matlab 引擎中...")
eng = matlab.engine.start_matlab()
eng.eval("clear functions", nargout=0)
eng.eval("rehash", nargout=0)
eng.cd(r'D:\Desktop\Code\PyCharm\Map_Projection\backend')
print("✅ Matlab 已启动")

def matlab_to_list(val):
    if isinstance(val, matlab.double):
        return [list(x) for x in val] if hasattr(val, '__len__') and isinstance(val[0], matlab.double) else list(val._data)
    elif isinstance(val, list):
        return [matlab_to_list(v) for v in val]
    return val

@app.route('/api/project', methods=['POST'])
def project():
    try:
        data = request.get_json()
        projection = data.get("projection", "mercator")
        geometry = data['features'][0]['geometry']
        coords_all = []

        if geometry['type'] == 'Polygon':
            coords_all = geometry['coordinates']
        elif geometry['type'] == 'MultiPolygon':
            for polygon in geometry['coordinates']:
                coords_all.extend(polygon)
        else:
            return jsonify({'error': '不支持的几何类型'}), 400

        print(f"✅ 区域数：{len(coords_all)} ，投影方式：{projection}")

        lon_cell, lat_cell = [], []
        for ring in coords_all:
            lons = [float(p[0]) for p in ring]
            lats = [float(p[1]) for p in ring]
            lon_cell.append(matlab.double(lons))
            lat_cell.append(matlab.double(lats))

        # 将 projection 映射为 Matlab 内部识别的值
        projection_map = {
            'azimuthal_conformal': 'azimuthal_conformal',
            'azimuthal_equal_area': 'azimuthal_equal_area',
            'azimuthal_equidistant': 'azimuthal_equidistant',
            'azimuthal_perspective': 'azimuthal_perspective',
            'conic_conformal': 'conic_conformal',
            'conic_equal_area': 'conic_equal_area',
            'conic_equidistant': 'conic_equidistant',
            'conic_oblique': 'conic_oblique',
            'cylindrical_conformal': 'cylindrical_conformal',
            'cylindrical_equal_area': 'cylindrical_equal_area',
            'cylindrical_equidistant': 'cylindrical_equidistant',
            'cylindrical_oblique': 'cylindrical_oblique',
            'cylindrical_perspective': 'cylindrical_perspective',
            'gauss_kruger': 'gauss_kruger',
            'pseudo_azimuthal': 'pseudo_azimuthal',
            'pseudo_cylindrical': 'pseudo_cylindrical',
            'pseudo_conic': 'pseudo_conic'
        }

        if projection not in projection_map:
            return jsonify({'error': f'未知的投影类型: {projection}'}), 400

        projection_key = projection_map[projection]

        x_distorted, y_distorted, x_baseline, y_baseline, area_original, area_projected = eng.project_with_baseline(
            lon_cell, lat_cell, projection_key, nargout=6
        )
        # 使用原始 lon_cell / lat_cell 作为 x_base/y_base
        return jsonify({
            'x': matlab_to_list(x_distorted),
            'y': matlab_to_list(y_distorted),
            'x_base': matlab_to_list(lon_cell),
            'y_base': matlab_to_list(lat_cell),
            'area_original': float(area_original),
            'area_projected': float(area_projected)
        })

    except Exception as e:
        print("❌ 发生错误:", str(e))
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(port=5000)


