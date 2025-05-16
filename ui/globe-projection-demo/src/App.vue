<template>
  <div id="app">
    <div ref="globeViz" id="globeViz"></div>

    <!-- 悬浮国名 -->
    <div id="hoverTooltip" v-if="hoveredName">{{ hoveredName }}</div>

  <el-dialog v-model="showDialog" fullscreen @opened="drawAfterDialogOpen">

  <div class="dialog-container">
    <!-- 左侧 -->
    <div class="left-panel">
      <div class="dual-canvas-wrapper">
        <canvas ref="baseCanvas" class="layer-canvas" />
        <canvas ref="projectedCanvas" class="layer-canvas" />
      </div>

      <div style="text-align: right; margin-top: 10px">
        <p>
          原始面积：<strong>{{ areaOriginal }} km²</strong> |
          投影后面积：<strong>{{ areaProjected }} km²</strong> |
          面积变化：<strong>{{ areaScale }} 倍</strong>
        </p>
      </div>
      <div class="fixed-explanation">
        {{ staticExplanation }}
      </div>
    </div>

    <!-- 右侧 -->
    <div class="right-panel">
      <div class="chat-container">
        <div
          v-for="(msg, idx) in chatHistory"
          :key="idx"
          :class="['chat-bubble', msg.role === 'user' ? 'user-msg' : 'ai-msg']"
        >
          {{ msg.content }}
        </div>
      </div>
      <div class="chat-input">
        <el-input
          v-model="userInput"
          placeholder="输入您对该国变形的提问..."
          class="input-box"
          @keyup.enter="sendToAI"
        />
        <el-button type="primary" @click="sendToAI">发送</el-button>
      </div>
    </div>
  </div>
</el-dialog>

    <!-- 投影方式选择弹窗 -->
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

    <!-- 加载确认弹窗 -->
    <el-dialog v-model="showConfirm" title="确认加载" width="350px" center>
      <span>是否加载变形图并进行面积对比？</span>
      <template #footer>
        <el-button @click="showConfirm = false">取消</el-button>
        <el-button type="primary" @click="loadProjection">确定</el-button>
      </template>
    </el-dialog>

  </div>
</template>

<script setup>
import Globe from 'globe.gl'
import * as topojson from 'topojson-client'
import {ref, onMounted, nextTick } from 'vue'

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
const baseCanvas = ref(null);
const projectedCanvas = ref(null);

const areaScaleFactor = ref(1);  // 默认 1 倍缩放

let countries = []
let hoveredPolygon = null
let selectedPolygons = []
let globe = null

function getPolygonColor(f) {
  if (selectedPolygons.includes(f)) return 'rgba(218,165,32,0.9)'
  if (f === hoveredPolygon) return 'rgba(255,255,255,0.6)'
  return 'rgba(25,60,160,0.65)'
}

onMounted(async () => {
  const res = await fetch('/data/countries_zh.topojson')
  const topoData = await res.json()
  const geojson = topojson.feature(topoData, topoData.objects[Object.keys(topoData.objects)[0]])
  countries = geojson.features

  globe = Globe()
    .globeImageUrl('/assets/earth-dark.jpg')
    .polygonsData(countries)
    .polygonAltitude(0.005)
    .polygonCapColor(getPolygonColor)
    .polygonStrokeColor(() => '#ccc')
    .polygonLabel(f => f.properties.name)
    .onPolygonHover(f => {
      hoveredPolygon = f
      hoveredName.value = f ? f.properties.name : ''
      globe.polygonCapColor(getPolygonColor)
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
  globe.polygonCapColor(getPolygonColor)
}

function confirmProjection() {
  if (!selectedProjection.value) return
  showProjectionSelect.value = false
  showConfirm.value = true
}

const staticExplanation = ref('这是关于该国家使用所选地图投影方式后的几何变形与地理意义的解说文本。该段落将固定显示，不随对话滚动。')

const chatHistory = ref([
  { role: 'ai', content: '您好，我是地图投影解释助手，请问您想了解哪方面的信息？' }
])
const userInput = ref('')

function sendToAI() {
  if (!userInput.value.trim()) return
  chatHistory.value.push({ role: 'user', content: userInput.value.trim() })
  // 模拟 AI 回复（未来接 LangChain 或 OpenAI）
  setTimeout(() => {
    chatHistory.value.push({ role: 'ai', content: '这是关于该国地图投影变形的分析结果。' })
  }, 1000)
  userInput.value = ''}

function loadProjection() {
  showConfirm.value = false
  fetch('http://localhost:5000/api/project', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...selectedGeoJson.value, projection: selectedProjection.value })
  })
    .then(res => res.json())
    .then(async data => {
      lastProjection.value = {
        x_raw: data.x_base,
        y_raw: data.y_base,
        x_proj: data.x,
        y_proj: data.y,
        area_original: data.area_original,
        area_projected: data.area_projected
      }
      showDialog.value = true
      nextTick(() => {
        drawAfterDialogOpen()
      })
    })
}

function drawCenteredPolygon(canvas, x, y, color, fill = "transparent", areaScale = 1) {
  const ctx = canvas.getContext("2d");

  const dpr = window.devicePixelRatio || 1;
  const cssWidth = canvas.clientWidth;
  const cssHeight = canvas.clientHeight;
  canvas.width = cssWidth * dpr;
  canvas.height = cssHeight * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, cssWidth, cssHeight);

  const flatten = arr => arr.flat(2);
  const xFlat = flatten(x);
  const yFlat = flatten(y);
  const xMin = Math.min(...xFlat), xMax = Math.max(...xFlat);
  const yMin = Math.min(...yFlat), yMax = Math.max(...yFlat);

  const centerX = (xMin + xMax) / 2;
  const centerY = (yMin + yMax) / 2;
  const padding = 30;
  const scaleX = (cssWidth - 2 * padding) / (xMax - xMin);
  const scaleY = (cssHeight - 2 * padding) / (yMax - yMin);
  const scale = Math.min(scaleX, scaleY) * areaScale;

  const offsetX = cssWidth / 2 - centerX * scale;
  const offsetY = cssHeight / 2 + centerY * scale;

  for (let p = 0; p < x.length; p++) {
    const xRings = x[p];
    const yRings = y[p];
    for (let r = 0; r < xRings.length; r++) {
      const xPts = xRings[r];
      const yPts = yRings[r];
      if (!xPts || !yPts || xPts.length < 3) continue;

      ctx.beginPath();
      ctx.moveTo(xPts[0] * scale + offsetX, -yPts[0] * scale + offsetY);
      for (let i = 1; i < xPts.length; i++) {
        ctx.lineTo(xPts[i] * scale + offsetX, -yPts[i] * scale + offsetY);
      }
      ctx.closePath();
      ctx.fillStyle = fill;
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      if (fill !== "transparent") ctx.fill();
      ctx.stroke();
    }
  }
}


function drawAfterDialogOpen() {
  if (!lastProjection.value) return;
  const { x_proj, y_proj, x_raw, y_raw, area_original, area_projected } = lastProjection.value;

  areaOriginal.value = Math.round(area_original);
  areaProjected.value = Math.round(area_projected);
  areaScale.value = (area_projected / area_original).toFixed(2);

  // 计算面积修正因子（只作用于面积大的图形，使其变小以还原视觉）
  if (area_projected > area_original) {
    areaScaleFactor.value = 1 / Math.sqrt(area_projected / area_original);
  } else {
    areaScaleFactor.value = 1;
  }

  // 红色绘制 projected（面积大的）
  drawCenteredPolygon(baseCanvas.value, x_proj, y_proj, "red", "transparent", areaScaleFactor.value);

  // 黄色绘制原始（面积小的）
  drawCenteredPolygon(projectedCanvas.value, x_raw, y_raw, "gold", "rgba(255,255,0,0.3)", 1);
}






</script>

<style>
html, body, #app {
  margin: 0;
  padding: 0;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  font-family: 'Segoe UI', sans-serif;
  background-color: #1e1e1e;
  color: #eee;
}

#globeViz {
  width: 100%;
  height: 100%;
  background-color: #111;
  position: absolute;
  top: 0;
  left: 0;
  z-index: 1;
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
  z-index: 10;
}

.dual-canvas-wrapper {
  position: relative;
  width: 100%;
  height: 400px;
  border-radius: 6px;
}

.layer-canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.compass {
  position: absolute;
  bottom: 20px;
  left: 20px;
  width: 60px;
  height: 60px;
  cursor: pointer;
  opacity: 0.8;
  transition: transform 0.5s ease, opacity 0.3s ease;
}
.compass:hover {
  transform: rotate(20deg) scale(1.1);
  opacity: 1;
}

.dialog-container {
  display: flex;
  width: 100vw;
  height: 90vh;
  background-color: #1e1e1e;
  color: #eee;
  font-family: 'Segoe UI', sans-serif;
}

.left-panel {
  flex: 2;
  padding: 20px;
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  border-right: 1px solid #555; /* 灰色分隔线 */
}

.right-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 20px;
  box-sizing: border-box;
}

.fixed-explanation {
  padding: 12px;
  background-color: #2c2c2c;
  border-radius: 8px;
  color: #ccc;
  line-height: 1.5;
  font-size: 14px;
}
.chat-container {
  flex: 1;
  overflow-y: auto;
  padding-right: 6px;
  margin-bottom: 10px;

}

.chat-container .chat-bubble:first-child {
  margin-top: 0px;
}

.chat-bubble {
  max-width: 55%;
  padding: 12px 14px;
  border-radius: 28px;
  margin: 40px 0;
  line-height: 2;
  word-break: break-word;
}

.user-msg {
  background-color: #409eff;
  color: #fff;
  align-self: flex-end;
  margin-left: auto;
}

.ai-msg {
  background-color: #2e2e2e;
  color: #ccc;
  align-self: flex-start;
  margin-right: auto;
}

.chat-input {
  display: flex;
  gap: 10px;
  padding-bottom: 0px;
}

.input-box .el-input__inner {
  background-color: #2c2c2c !important;
  border: none !important;
  border-radius: 20px !important;
  color: #eee !important;
  padding: 10px 14px !important;
  font-size: 14px;
}

.el-button {
  background-color: #444;
  border: none;
  color: #eee;
  height: 40px;
  line-height: 40px;
}

.el-dialog__wrapper.is-fullscreen {
  padding: 0 !important;
}

.el-dialog.is-fullscreen {
  margin: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  background-color: #1e1e1e !important;
  height: 100vh;
  overflow: hidden;
  color: #eee;
}

.el-dialog,
.el-select,
.el-select-dropdown,
.el-option,
.el-option-group {
  background-color: #2c2c2c !important;
  color: #eee !important;
  border-color: #444 !important;
}

.el-select-dropdown__item:hover {
  background-color: #444 !important;
  color: #fff !important;
}

.el-dialog__footer .el-button {
  background-color: #444 !important;
  color: #eee !important;
}

.el-select .el-input__inner {
  background-color: #2c2c2c !important;
  color: #eee !important;
  border-color: #444 !important;
}

.el-dialog__title {
  color: #f5f5f5 !important;  /* 更亮的白色文字 */
  font-weight: bold;
  font-size: 16px;
}

.el-dialog__wrapper.is-fullscreen {
  padding: 0 !important;
  margin: 0 !important;
  overflow: hidden !important;
}

.el-dialog.is-fullscreen {
  width: 100vw !important;
  height: 100vh !important;
  margin: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  background-color: #1e1e1e !important; /* 统一背景 */
  overflow: hidden !important;
}

.el-input__wrapper {
  border: none !important;
  box-shadow: none !important;
  background-color: #2b2b2b !important; /* 保持一致的深色背景 */
  border-radius: 20px !important;
  padding: 4px 12px !important;
}

/* 发送按钮美化为圆角、深色风格、右侧留白 */
.chat-input .el-button {
  border-radius: 20px !important;
  background-color: #409eff !important;
  color: white !important;
  padding: 6px 20px !important;
  margin-right: 20px; /* 离右边远一些 */
  border: none !important;
  box-shadow: none !important;
}
</style>
