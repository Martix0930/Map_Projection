<template>
  <div id="app">
    <div ref="globeViz" id="globeViz"></div>
    <!-- 选择信息：显示当前选中国家的 GeoJSON 数据 -->
    <div id="selectionInfo">{{ selectedGeoJson }}</div>
    <!-- 自定义 tooltip：鼠标悬停时显示当前国家名称 -->
    <div id="hoverTooltip" v-if="hoveredName">{{ hoveredName }}</div>
    <canvas ref="projectionCanvas" id="projectionCanvas"></canvas>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import Globe from 'globe.gl'

const globeViz = ref(null)
const projectionCanvas = ref(null)
const selectedGeoJson = ref('')
const hoveredName = ref('')

let selectedPolygons = []
let hoveredPolygon = null
let worldGlobe = null
let countries = []

const blacklistedCountries = [
  'Bermuda', 'Malta', 'Vatican', 'San Marino', 'Liechtenstein', 'Monaco', 'Andorra',
  'Tuvalu', 'Nauru', 'Palau', 'Marshall Islands', 'Micronesia', 'Saint Kitts and Nevis',
  'Grenada', 'Seychelles', 'Maldives', 'Barbados', 'Antigua and Barbuda'
]

onMounted(async () => {
  const res = await fetch('https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json')
  const geojson = await res.json()

  geojson.features = geojson.features.filter(
    f => !blacklistedCountries.includes(f.properties.name)
  )

  geojson.features.forEach(f => {
    if (f.properties.name === 'Taiwan') {
      f.properties.name = 'China'
    }
  })

  countries = geojson.features

  worldGlobe = Globe()
    .globeImageUrl('//unpkg.com/three-globe/example/img/earth-dark.jpg')
    .polygonsData(countries)
    .polygonAltitude(0.005)
    .polygonCapColor(feat =>
      selectedPolygons.includes(feat)
        ? 'rgba(184, 134, 11, 0.8)'
        : feat === hoveredPolygon
          ? 'rgba(255, 255, 255, 0.4)'
          : 'rgba(70, 130, 180, 0.5)'
    )
    .polygonSideColor(() => 'rgba(255, 255, 255, 0.1)')
    .polygonStrokeColor(feat =>
      feat.properties.name === 'China' ? '#b8860b' : '#ddd'
    )
    .polygonLabel(() => '')
    .onPolygonClick(handlePolygonClick)
    .onPolygonHover(feat => {
      hoveredPolygon = feat
      hoveredName.value = feat && feat.properties && feat.properties.name ? feat.properties.name : ''
      worldGlobe.polygonCapColor(feat =>
        selectedPolygons.includes(feat)
          ? 'rgba(184, 134, 11, 0.8)'
          : feat === hoveredPolygon
            ? 'rgba(255, 255, 255, 0.4)'
            : 'rgba(70, 130, 180, 0.5)'
      )
    })

  worldGlobe(globeViz.value)
})

function handlePolygonClick(clickedPolygon) {
  if (!clickedPolygon || !clickedPolygon.geometry) return

  const countryName = clickedPolygon.properties.name
  selectedPolygons = countries.filter(f => f.properties.name === countryName)

  const selectedGeoJsonData = {
    type: "FeatureCollection",
    features: selectedPolygons
  }
  selectedGeoJson.value = JSON.stringify(selectedGeoJsonData, null, 2)

  worldGlobe.polygonCapColor(feat =>
    selectedPolygons.includes(feat)
      ? 'rgba(184, 134, 11, 0.8)'
      : feat === hoveredPolygon
        ? 'rgba(255, 255, 255, 0.4)'
        : 'rgba(70, 130, 180, 0.5)'
  )

  fetch('http://localhost:5000/api/project', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(selectedGeoJsonData)
  })
    .then(res => res.json())
    .then(data => {
      console.log('投影结果:', data)
      renderProjection(data)
    })
}

function renderProjection(data) {
  const canvas = projectionCanvas.value
  const ctx = canvas.getContext('2d')
  ctx.clearRect(0, 0, canvas.width, canvas.height)

  ctx.fillStyle = 'rgba(184, 134, 11, 0.5)'
  ctx.beginPath()

  const x = data.x
  const y = data.y

  if (x.length > 0) {
    ctx.moveTo(x[0] * 3, y[0] * 3)
    for (let i = 1; i < x.length; i++) {
      ctx.lineTo(x[i] * 3, y[i] * 3)
    }
    ctx.closePath()
    ctx.fill()
  }
}
</script>

<style>
#globeViz {
  width: 100vw;
  height: 100vh;
  background-color: #121212;
}

#selectionInfo {
  position: absolute;
  top: 20px;
  left: 20px;
  background: rgba(0, 0, 0, 0.7);
  color: #ffd700;
  padding: 10px 15px;
  border-radius: 6px;
  font-family: 'Segoe UI', sans-serif;
  font-size: 14px;
  z-index: 100;
  box-shadow: 0 0 5px rgba(184, 134, 11, 0.5);
  transition: opacity 0.3s ease;
  max-width: 1200px;
  white-space: pre-wrap;
  word-wrap: break-word;
}

#hoverTooltip {
  position: absolute;
  top: 20px;
  right: 20px;
  background: rgba(0, 0, 0, 0.7);
  color: #ffd700;
  padding: 8px 12px;
  border-radius: 6px;
  font-family: 'Segoe UI', sans-serif;
  font-size: 14px;
  z-index: 110;
  box-shadow: 0 0 5px rgba(184, 134, 11, 0.5);
  transition: opacity 0.3s ease;
}

#projectionCanvas {
  position: absolute;
  bottom: 20px;
  right: 20px;
  width: 300px;
  height: 200px;
  border: 1px solid #b8860b;
  background-color: #1e1e1e;
  border-radius: 8px;
  box-shadow: 0 0 8px rgba(0, 0, 0, 0.6);
}
</style>


<!--<template>-->
<!--  <div id="app">-->
<!--    <div ref="globeViz" id="globeViz"></div>-->
<!--    &lt;!&ndash; 选择信息：显示当前选中国家的 GeoJSON 数据 &ndash;&gt;-->
<!--    <div id="selectionInfo">{{ selectedGeoJson }}</div>-->
<!--    &lt;!&ndash; 自定义 tooltip：鼠标悬停时显示当前国家名称 &ndash;&gt;-->
<!--    <div id="hoverTooltip" v-if="hoveredName">{{ hoveredName }}</div>-->
<!--    <canvas ref="projectionCanvas" id="projectionCanvas"></canvas>-->
<!--  </div>-->
<!--</template>-->

<!--<script setup>-->
<!--import { onMounted, ref } from 'vue'-->
<!--import Globe from 'globe.gl'-->

<!--const globeViz = ref(null)-->
<!--const projectionCanvas = ref(null)-->
<!--const selectedGeoJson = ref('') // 这里用于保存当前选中国家的 GeoJSON 数据-->
<!--const hoveredName = ref('')-->

<!--let selectedPolygons = []-->
<!--let hoveredPolygon = null-->
<!--let worldGlobe = null-->
<!--let countries = []-->

<!--// 黑名单国家，过滤掉那些尺寸过小容易误触的国家-->
<!--const blacklistedCountries = [-->
<!--  'Bermuda', 'Malta', 'Vatican', 'San Marino', 'Liechtenstein', 'Monaco', 'Andorra',-->
<!--  'Tuvalu', 'Nauru', 'Palau', 'Marshall Islands', 'Micronesia', 'Saint Kitts and Nevis',-->
<!--  'Grenada', 'Seychelles', 'Maldives', 'Barbados', 'Antigua and Barbuda'-->
<!--]-->

<!--onMounted(async () => {-->
<!--  // 获取 GeoJSON 数据-->
<!--  const res = await fetch('https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json')-->
<!--  const geojson = await res.json()-->

<!--  // 过滤掉黑名单中的国家-->
<!--  geojson.features = geojson.features.filter(-->
<!--    f => !blacklistedCountries.includes(f.properties.name)-->
<!--  )-->

<!--  // 将所有 "Taiwan" 改名为 "China"，但不合并 geometry，保留各自边界-->
<!--  geojson.features.forEach(f => {-->
<!--    if (f.properties.name === 'Taiwan') {-->
<!--      f.properties.name = 'China'-->
<!--    }-->
<!--  })-->

<!--  countries = geojson.features-->

<!--  worldGlobe = Globe()-->
<!--    .globeImageUrl('//unpkg.com/three-globe/example/img/earth-dark.jpg')-->
<!--    .polygonsData(countries)-->
<!--    .polygonAltitude(0.005)-->
<!--    .polygonCapColor(feat =>-->
<!--      selectedPolygons.includes(feat)-->
<!--        ? 'rgba(184, 134, 11, 0.8)'   // 选中区域暗金色-->
<!--        : feat === hoveredPolygon-->
<!--          ? 'rgba(255, 255, 255, 0.4)'-->
<!--          : 'rgba(70, 130, 180, 0.5)'-->
<!--    )-->
<!--    .polygonSideColor(() => 'rgba(255, 255, 255, 0.1)')-->
<!--    .polygonStrokeColor(feat =>-->
<!--      feat.properties.name === 'China' ? '#b8860b' : '#ddd'-->
<!--    )-->
<!--    .polygonLabel(() => '')-->
<!--    .onPolygonClick(handlePolygonClick)-->
<!--    .onPolygonHover(feat => {-->
<!--      hoveredPolygon = feat-->
<!--      hoveredName.value = feat && feat.properties && feat.properties.name ? feat.properties.name : ''-->
<!--      worldGlobe.polygonCapColor(feat =>-->
<!--        selectedPolygons.includes(feat)-->
<!--          ? 'rgba(184, 134, 11, 0.8)'-->
<!--          : feat === hoveredPolygon-->
<!--            ? 'rgba(255, 255, 255, 0.4)'-->
<!--            : 'rgba(70, 130, 180, 0.5)'-->
<!--      )-->
<!--    })-->

<!--  worldGlobe(globeViz.value)-->
<!--})-->

<!--function handlePolygonClick(clickedPolygon) {-->
<!--  if (!clickedPolygon || !clickedPolygon.geometry) return-->

<!--  const countryName = clickedPolygon.properties.name-->
<!--  // 根据名称筛选所有同名区域（即“中国大陆”与“台湾”均会被选中）-->
<!--  selectedPolygons = countries.filter(f => f.properties.name === countryName)-->

<!--  // 更新左侧的选中国家信息（GeoJSON）-->
<!--  const selectedGeoJsonData = {-->
<!--    type: "FeatureCollection",-->
<!--    features: selectedPolygons-->
<!--  }-->
<!--  selectedGeoJson.value = JSON.stringify(selectedGeoJsonData, null, 2)-->

<!--  worldGlobe.polygonCapColor(feat =>-->
<!--    selectedPolygons.includes(feat)-->
<!--      ? 'rgba(184, 134, 11, 0.8)' // 选中区域暗金色-->
<!--      : feat === hoveredPolygon-->
<!--        ? 'rgba(255, 255, 255, 0.4)'-->
<!--        : 'rgba(70, 130, 180, 0.5)'-->
<!--  )-->

<!--  // 收集所有选中区域的坐标数据-->
<!--  const combinedCoords = selectedPolygons.flatMap(f => f.geometry.coordinates)-->

<!--  // 请求后端投影数据-->
<!--  fetch('/api/project', {-->
<!--    method: 'POST',-->
<!--    headers: { 'Content-Type': 'application/json' },-->
<!--    body: JSON.stringify({-->
<!--      region_name: countryName,-->
<!--      coordinates: combinedCoords,-->
<!--      projection: 'mercator'-->
<!--    })-->
<!--  })-->
<!--    .then(res => res.json())-->
<!--    .then(data => {-->
<!--      console.log('投影结果:', data)-->
<!--      renderProjection(data)-->
<!--    })-->
<!--}-->

<!--function renderProjection(data) {-->
<!--  const canvas = projectionCanvas.value-->
<!--  const ctx = canvas.getContext('2d')-->
<!--  ctx.clearRect(0, 0, canvas.width, canvas.height)-->

<!--  ctx.fillStyle = 'rgba(184, 134, 11, 0.5)'  // 暗金色半透明-->
<!--  ctx.beginPath()-->
<!--  // 在这里根据 data 的坐标进行绘制（示例）-->
<!--  ctx.fill()-->
<!--}-->
<!--</script>-->

<!--<style>-->
<!--/* Globe 显示 */-->
<!--#globeViz {-->
<!--  width: 100vw;-->
<!--  height: 100vh;-->
<!--  background-color: #121212;-->
<!--}-->

<!--/* 选择信息：显示当前选中国家的 GeoJSON 数据 */-->
<!--#selectionInfo {-->
<!--  position: absolute;-->
<!--  top: 20px;-->
<!--  left: 20px;-->
<!--  background: rgba(0, 0, 0, 0.7);-->
<!--  color: #ffd700;-->
<!--  padding: 10px 15px;-->
<!--  border-radius: 6px;-->
<!--  font-family: 'Segoe UI', sans-serif;-->
<!--  font-size: 14px;-->
<!--  z-index: 100;-->
<!--  box-shadow: 0 0 5px rgba(184, 134, 11, 0.5);-->
<!--  transition: opacity 0.3s ease;-->
<!--  max-width: 1200px; /* 修改为原来的三倍宽度 */-->
<!--  white-space: pre-wrap; /* 保持格式化 */-->
<!--  word-wrap: break-word; /* 自动换行 */-->
<!--}-->

<!--/* 自定义悬停 tooltip：显示当前鼠标悬停的国家名称 */-->
<!--#hoverTooltip {-->
<!--  position: absolute;-->
<!--  top: 20px;-->
<!--  right: 20px;-->
<!--  background: rgba(0, 0, 0, 0.7);-->
<!--  color: #ffd700;-->
<!--  padding: 8px 12px;-->
<!--  border-radius: 6px;-->
<!--  font-family: 'Segoe UI', sans-serif;-->
<!--  font-size: 14px;-->
<!--  z-index: 110;-->
<!--  box-shadow: 0 0 5px rgba(184, 134, 11, 0.5);-->
<!--  transition: opacity 0.3s ease;-->
<!--}-->

<!--/* 投影 Canvas 优化 */-->
<!--#projectionCanvas {-->
<!--  position: absolute;-->
<!--  bottom: 20px;-->
<!--  right: 20px;-->
<!--  width: 300px;-->
<!--  height: 200px;-->
<!--  border: 1px solid #b8860b;-->
<!--  background-color: #1e1e1e;-->
<!--  border-radius: 8px;-->
<!--  box-shadow: 0 0 8px rgba(0, 0, 0, 0.6);-->
<!--}-->
<!--</style>-->
