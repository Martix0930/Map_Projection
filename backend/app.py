from flask import Flask, request, jsonify
from flask_cors import CORS
import matlab.engine

app = Flask(__name__)
CORS(app)

print("🚀 启动 Matlab 引擎中...")
eng = matlab.engine.start_matlab()
print("✅ Matlab 已启动")


@app.route('/api/project', methods=['POST'])
def project():
    try:
        data = request.get_json()
        print("✅ 收到数据")

        geometry = data['features'][0]['geometry']
        coords_all = []

        if geometry['type'] == 'Polygon':
            coords_all = geometry['coordinates']
        elif geometry['type'] == 'MultiPolygon':
            for polygon in geometry['coordinates']:
                coords_all.extend(polygon)
        else:
            return jsonify({'error': '不支持的几何类型'}), 400

        print("✅ 坐标数量：", len(coords_all))

        # 展平坐标
        lon, lat = [], []
        for ring in coords_all:
            for pt in ring:
                lon.append(pt[0])
                lat.append(pt[1])

        print("✅ 投影点数：", len(lon), len(lat))

        # 调用 Matlab
        lon_mat = matlab.double(lon)
        lat_mat = matlab.double(lat)
        x_proj, y_proj = eng.mercator_projection(lon_mat, lat_mat, nargout=2)

        print("✅ Matlab 投影完成")

        return jsonify({
            'x': list(x_proj),
            'y': list(y_proj)
        })

    except Exception as e:
        print("❌ 发生错误:", str(e))
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(port=5000)