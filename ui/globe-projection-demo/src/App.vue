<template>
  <div id="app">
    <div ref="globeViz" id="globeViz"></div>
    <div id="hoverTooltip" v-if="hoveredName">{{ hoveredName }}</div>

    <el-dialog v-model="showProjectionSelect" title="选择地图投影方式" width="400px" center>
      <el-select v-model="selectedProjection" placeholder="请选择投影方式" style="width: 100%">
        <el-option-group label="方位投影（Azimuthal Projections）">
          <el-option label="等角方位投影 (Azimuthal Conformal)" value="azimuthal_conformal" />
          <el-option label="等面积方位投影 (Azimuthal Equal-Area)" value="azimuthal_equal_area" />
          <el-option label="等距离方位投影 (Azimuthal Equidistant)" value="azimuthal_equidistant" />
          <el-option label="透视方位投影 (Perspective Azimuthal)" value="azimuthal_perspective" />
        </el-option-group>

        <el-option-group label="圆锥投影（Conic Projections）">
          <el-option label="等角圆锥投影 (Conic Conformal)" value="conic_conformal" />
          <el-option label="等面积圆锥投影 (Conic Equal-Area)" value="conic_equal_area" />
          <el-option label="等距离圆锥投影 (Conic Equidistant)" value="conic_equidistant" />
          <el-option label="斜轴/横轴圆锥投影 (Oblique/Transverse Conic)" value="conic_oblique" />
        </el-option-group>

        <el-option-group label="圆柱投影（Cylindrical Projections）">
          <el-option label="等角圆柱投影 (Cylindrical Conformal)" value="cylindrical_conformal" />
          <el-option label="等面积圆柱投影 (Cylindrical Equal-Area)" value="cylindrical_equal_area" />
          <el-option label="等距离圆柱投影 (Cylindrical Equidistant)" value="cylindrical_equidistant" />
          <el-option label="斜轴/横轴圆柱投影 (Oblique/Transverse Cylindrical)" value="cylindrical_oblique" />
          <el-option label="透视圆柱投影 (Perspective Cylindrical)" value="cylindrical_perspective" />
        </el-option-group>

        <el-option-group label="其他投影类型">
          <el-option label="高斯-克吕格投影 (Gauss-Krüger)" value="gauss_kruger" />
          <el-option label="伪方位投影 (Pseudo-Azimuthal)" value="pseudo_azimuthal" />
          <el-option label="伪圆柱投影 (Pseudo-Cylindrical)" value="pseudo_cylindrical" />
          <el-option label="伪圆锥投影 (Pseudo-Conic)" value="pseudo_conic" />
        </el-option-group>
      </el-select>
      <template #footer>
        <el-button @click="showProjectionSelect = false">取消</el-button>
        <el-button type="primary" @click="confirmProjection">下一步</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showConfirm" title="确认加载" width="350px" center>
      <span>是否加载变形图并进行面积对比？</span>
      <template #footer>
        <el-button @click="showConfirm = false">取消</el-button>
        <el-button type="primary" @click="loadProjection">确定</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="showDialog"
      title="地图投影效果对比"
      width="700px"
      @opened="drawAfterDialogOpen"
    >
      <canvas ref="projectionCanvas" width="600" height="400" style="border-radius: 6px"></canvas>
      <div style="text-align: right; margin-top: 10px">
        <p>
          原始面积：<strong>{{ areaOriginal }} km²</strong> | 投影后面积：<strong>{{ areaProjected }} km²</strong> |
          面积变化：<strong>{{ areaScale }} 倍</strong>
        </p>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import Globe from 'globe.gl'

const globeViz = ref(null)
const projectionCanvas = ref(null)
const hoveredName = ref('')
const showProjectionSelect = ref(false)
const showConfirm = ref(false)
const showDialog = ref(false)

const selectedProjection = ref('')
const selectedCountry = ref('')
const selectedGeoJson = ref(null)
const lastProjection = ref(null)

const areaOriginal = ref('?')
const areaProjected = ref('?')
const areaScale = ref('?')

let countries = []
let hoveredPolygon = null
let selectedPolygons = []

onMounted(async () => {
  const res = await fetch('https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json')
  const geojson = await res.json()
  geojson.features = geojson.features.filter(f => !['Bermuda', 'Malta', 'Vatican', 'San Marino'].includes(f.properties.name))
  geojson.features.forEach(f => {
    if (f.properties.name === 'Taiwan') f.properties.name = 'China'
  })
  countries = geojson.features

  const globe = Globe()
    .globeImageUrl('//unpkg.com/three-globe/example/img/earth-dark.jpg')
    .polygonsData(countries)
    .polygonAltitude(0.005)
    .polygonCapColor((f) => selectedPolygons.includes(f)
      ? 'rgba(184,134,11,0.8)'
      : f === hoveredPolygon ? 'rgba(255,255,255,0.4)' : 'rgba(70,130,180,0.5)')
    .polygonLabel(f => f.properties.name)
    .onPolygonHover(f => {
      hoveredPolygon = f
      hoveredName.value = f ? f.properties.name : ''
      globe.polygonCapColor(f => selectedPolygons.includes(f)
        ? 'rgba(184,134,11,0.8)'
        : f === hoveredPolygon ? 'rgba(255,255,255,0.4)' : 'rgba(70,130,180,0.5)')
    })
    .onPolygonClick(handleClick)

  globe(globeViz.value)
})

function handleClick(polygon) {
  if (!polygon || !polygon.geometry) return
  selectedCountry.value = polygon.properties.name
  selectedPolygons = countries.filter(f => f.properties.name === selectedCountry.value)
  selectedGeoJson.value = { type: 'FeatureCollection', features: selectedPolygons }
  showProjectionSelect.value = true
}

function confirmProjection() {
  if (!selectedProjection.value) return
  showProjectionSelect.value = false
  showConfirm.value = true
}

function loadProjection() {
  showConfirm.value = false
  fetch('http://localhost:5000/api/project', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...selectedGeoJson.value, projection: selectedProjection.value })
  })
    .then(res => res.json())
    .then(data => {
      lastProjection.value = {
        x_raw: data.x_base,
        y_raw: data.y_base,
        x_proj: data.x,
        y_proj: data.y,
        area_original: data.area_original,
        area_projected: data.area_projected
      }
      showDialog.value = true
    })
}

function deepFlatten(arr) {
  if (!Array.isArray(arr)) return []
  return arr.flat(Infinity)
}

function drawAfterDialogOpen() {
  const canvas = projectionCanvas.value
  const ctx = canvas.getContext('2d')
  ctx.clearRect(0, 0, canvas.width, canvas.height)

  if (!lastProjection.value || !lastProjection.value.x_proj || !lastProjection.value.x_raw) return

  const xBase = deepFlatten(lastProjection.value.x_proj)
  const yBase = deepFlatten(lastProjection.value.y_proj)
  const xProj = deepFlatten(lastProjection.value.x_raw)
  const yProj = deepFlatten(lastProjection.value.y_raw)

  const baseCenterX = (Math.min(...xBase) + Math.max(...xBase)) / 2
  const baseCenterY = (Math.min(...yBase) + Math.max(...yBase)) / 2

  const projCenterX = (Math.min(...xProj) + Math.max(...xProj)) / 2
  const projCenterY = (Math.min(...yProj) + Math.max(...yProj)) / 2

  const scaleRatio = Math.sqrt(lastProjection.value.area_projected / lastProjection.value.area_original)
  const xProjAligned = xProj.map(x => (x - projCenterX) * scaleRatio + baseCenterX)
  const yProjAligned = yProj.map(y => (y - projCenterY) * scaleRatio + baseCenterY)

  const allX = [...xBase, ...xProjAligned]
  const allY = [...yBase, ...yProjAligned]
  const padding = 30
  const scaleX = (canvas.width - 2 * padding) / (Math.max(...allX) - Math.min(...allX))
  const scaleY = (canvas.height - 2 * padding) / (Math.max(...allY) - Math.min(...allY))
  const scale = Math.min(scaleX, scaleY)

  const offsetX = canvas.width / 2 - baseCenterX * scale
  const offsetY = canvas.height / 2 + baseCenterY * scale

  const draw = (x, y, stroke, fill, color) => {
    if (x.length < 3) return
    ctx.beginPath()
    ctx.moveTo(x[0] * scale + offsetX, -y[0] * scale + offsetY)
    for (let i = 1; i < x.length; i++) {
      ctx.lineTo(x[i] * scale + offsetX, -y[i] * scale + offsetY)
    }
    ctx.closePath()
    ctx.fillStyle = fill
    ctx.strokeStyle = color
    ctx.lineWidth = 1.5
    if (fill !== 'transparent') ctx.fill()
    if (stroke) ctx.stroke()
  }

  draw(xBase, yBase, true, 'transparent', 'red')
  draw(xProjAligned, yProjAligned, true, 'rgba(184,134,11,0.5)', '#444')

  areaOriginal.value = Math.round(lastProjection.value.area_original)
  areaProjected.value = Math.round(lastProjection.value.area_projected)
  areaScale.value = (lastProjection.value.area_projected / lastProjection.value.area_original).toFixed(2)
}
</script>

<style>
#globeViz {
  width: 100vw;
  height: 100vh;
  background-color: #111;
}

#hoverTooltip {
  position: absolute;
  top: 10px;
  right: 10px;
  color: #ffd700;
  background: rgba(0, 0, 0, 0.7);
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 14px;
  z-index: 100;
  font-family: 'Segoe UI', sans-serif;
}
</style>
