import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

const MAPS = JSON.parse(document.getElementById("maps").textContent);

const MAT = {
  Grass: { c: [96, 140, 64], r: 1 }, LeafyGrass: { c: null, r: 1 }, Mud: { c: [92, 74, 56], r: 1 },
  Sand: { c: [206, 186, 140], r: 1 }, Ground: { c: [120, 96, 70], r: 1 }, Rock: { c: [118, 116, 112], r: 1 },
  Slate: { c: null, r: 0.95 }, Water: { c: [40, 110, 150], r: 0.15, t: 0.25 }, Asphalt: { c: null, r: 0.95 },
  Concrete: { c: null, r: 0.9 }, Metal: { c: null, r: 0.45, m: 0.6 }, DiamondPlate: { c: null, r: 0.5, m: 0.6 },
  CorrodedMetal: { c: null, r: 0.75, m: 0.4 }, Glass: { c: null, r: 0.05, m: 0.3, t: 0.45 }, Neon: { c: null, neon: true },
  Wood: { c: null, r: 0.85 }, WoodPlanks: { c: null, r: 0.85 }, Brick: { c: null, r: 0.9 }, Marble: { c: null, r: 0.3 },
  Fabric: { c: null, r: 1 }, Pavement: { c: null, r: 0.95 }, SmoothPlastic: { c: null, r: 0.55 }, Plastic: { c: null, r: 0.6 },
};

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMappingExposure = 1.35;
document.getElementById("view").appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.5, 4000);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI * 0.495;

const hemi = new THREE.HemisphereLight(0xe8efff, 0x6a5a48, 1.7);
scene.add(hemi);
const sun = new THREE.DirectionalLight(0xffffff, 2.2);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
sun.shadow.bias = -0.0004;
scene.add(sun);
scene.add(sun.target);

const geoCache = {};
function wedgeGeometry() {
  // Roblox wedge: full height at +Z, slope falls to the front (-Z)
  const shape = new THREE.Shape();
  shape.moveTo(-0.5, -0.5); shape.lineTo(0.5, -0.5); shape.lineTo(0.5, 0.5); shape.closePath();
  const g = new THREE.ExtrudeGeometry(shape, { depth: 1, bevelEnabled: false });
  // shape is in (x=z, y=y), extruded along z -> rotate so extrusion runs along X
  g.translate(0, 0, -0.5);
  g.rotateY(-Math.PI / 2);
  return g;
}
function geometry(s) {
  if (geoCache[s]) return geoCache[s];
  let g;
  if (s === "Wedge") g = wedgeGeometry();
  else if (s === "Cylinder") { g = new THREE.CylinderGeometry(0.5, 0.5, 1, 20); g.rotateZ(Math.PI / 2); }
  else if (s === "Ball") g = new THREE.SphereGeometry(0.5, 18, 12);
  else g = new THREE.BoxGeometry(1, 1, 1);
  return (geoCache[s] = g);
}
const matCache = {};
function material(m, c, t) {
  const key = m + c.join(",") + t;
  if (matCache[key]) return matCache[key];
  const spec = MAT[m] || { r: 0.7 };
  const color = new THREE.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, THREE.SRGBColorSpace);
  let mat;
  if (spec.neon) {
    mat = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.6) });
  } else {
    mat = new THREE.MeshStandardMaterial({ color, roughness: spec.r ?? 0.7, metalness: spec.m ?? 0 });
  }
  const tr = Math.max(t, spec.t ?? 0);
  if (tr > 0.01) { mat.transparent = true; mat.opacity = 1 - tr; mat.depthWrite = tr < 0.4; }
  return (matCache[key] = mat);
}


// Voxelize terrain fills like Roblox does (4 stud cells, later fills overwrite earlier ones)
const TCOL = { Grass: [92, 138, 62], Mud: [96, 76, 58], Sand: [212, 192, 146], Ground: [128, 102, 74], Rock: [120, 118, 114], Water: [44, 120, 160], Slate: [110, 110, 110], LeafyGrass: [80, 130, 60], Asphalt: [60, 60, 64], Concrete: [150, 150, 146] };
function buildTerrain(ops, parent) {
  if (!ops.length) return;
  const R = 4, N = 150, YMIN = -24, NY = 26; // x/z: -300..300, y: -24..80
  const names = ["Air"]; const idx = { Air: 0 };
  const grid = new Uint8Array(N * N * NY);
  const id = (m) => (idx[m] ?? (idx[m] = names.push(m) - 1));
  const at = (x, y, z) => (y * N + z) * N + x;
  for (const t of ops) {
    const mid = id(t.m);
    let minx, maxx, miny, maxy, minz, maxz, test;
    if (t.k === "ball") {
      const [cx, cy, cz] = t.p; const r = t.rad;
      minx = cx - r; maxx = cx + r; miny = cy - r; maxy = cy + r; minz = cz - r; maxz = cz + r;
      test = (x, y, z) => (x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2 <= r * r;
    } else {
      const [cx, cy, cz] = t.p; const [sx, sy, sz] = t.z; const r = t.r;
      const ext = Math.hypot(sx, sy, sz) / 2;
      minx = cx - ext; maxx = cx + ext; miny = cy - ext; maxy = cy + ext; minz = cz - ext; maxz = cz + ext;
      test = (x, y, z) => {
        const dx = x - cx, dy = y - cy, dz = z - cz;
        const lx = r[0] * dx + r[3] * dy + r[6] * dz, ly = r[1] * dx + r[4] * dy + r[7] * dz, lz = r[2] * dx + r[5] * dy + r[8] * dz;
        return Math.abs(lx) <= sx / 2 && Math.abs(ly) <= sy / 2 && Math.abs(lz) <= sz / 2;
      };
    }
    const i0 = Math.max(0, Math.floor((minx + 300) / R)), i1 = Math.min(N - 1, Math.floor((maxx + 300) / R));
    const k0 = Math.max(0, Math.floor((minz + 300) / R)), k1 = Math.min(N - 1, Math.floor((maxz + 300) / R));
    const j0 = Math.max(0, Math.floor((miny - YMIN) / R)), j1 = Math.min(NY - 1, Math.floor((maxy - YMIN) / R));
    for (let j = j0; j <= j1; j++) for (let k = k0; k <= k1; k++) for (let i = i0; i <= i1; i++) {
      if (test(i * R - 300 + R / 2, j * R + YMIN + R / 2, k * R - 300 + R / 2)) grid[at(i, j, k)] = mid;
    }
  }
  const lists = {};
  const solid = (i, j, k) => i < 0 || k < 0 || i >= N || k >= N || j < 0 ? true : j >= NY ? false : grid[at(i, j, k)] !== 0 && names[grid[at(i, j, k)]] !== "Water";
  for (let j = 0; j < NY; j++) for (let k = 0; k < N; k++) for (let i = 0; i < N; i++) {
    const v = grid[at(i, j, k)]; if (!v) continue;
    const m = names[v];
    if (m === "Water") { if (j + 1 < NY && grid[at(i, j + 1, k)] === v) continue; }
    else if (solid(i + 1, j, k) && solid(i - 1, j, k) && solid(i, j + 1, k) && solid(i, j - 1, k) && solid(i, j, k + 1) && solid(i, j, k - 1)) continue;
    (lists[m] ||= []).push([i * R - 300 + R / 2, j * R + YMIN + R / 2, k * R - 300 + R / 2]);
  }
  const dummy = new THREE.Object3D();
  for (const [m, cells] of Object.entries(lists)) {
    const c = TCOL[m] || [120, 120, 120];
    const water = m === "Water";
    const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, THREE.SRGBColorSpace), roughness: water ? 0.1 : 1, metalness: water ? 0.2 : 0, transparent: water, opacity: water ? 0.78 : 1 });
    const inst = new THREE.InstancedMesh(new THREE.BoxGeometry(R, water ? R * 0.8 : R, R), mat, cells.length);
    const col = new THREE.Color();
    cells.forEach((p, n) => {
      dummy.position.set(p[0], water ? p[1] - R * 0.1 : p[1], p[2]); dummy.updateMatrix();
      inst.setMatrixAt(n, dummy.matrix);
      const f = water ? 1 : 0.9 + ((Math.sin(p[0] * 12.9898 + p[2] * 78.233) * 43758.5453) % 1 + 1) % 1 * 0.2;
      inst.setColorAt(n, col.setRGB(f, f, f));
    });
    inst.receiveShadow = !water; inst.castShadow = !water;
    parent.add(inst);
  }
}

let group = null;
let current = null;
function load(idx) {
  if (group) scene.remove(group);
  group = new THREE.Group();
  const map = MAPS[idx];
  current = map;
  const m4 = new THREE.Matrix4();
  const box = new THREE.Box3();
  for (const p of map.parts) {
    let s = p.s;
    const size = p.z.slice();
    if (s === "Cylinder") { const d = Math.min(size[1], size[2]); size[1] = d; size[2] = d; }
    if (s === "Ball") { const d = Math.min(...size); size[0] = size[1] = size[2] = d; }
    const mesh = new THREE.Mesh(geometry(s === "Truss" ? "Block" : s), material(s === "Truss" ? "Metal" : p.m, p.c, p.t));
    const r = p.r;
    m4.set(r[0] * size[0], r[1] * size[1], r[2] * size[2], p.p[0],
           r[3] * size[0], r[4] * size[1], r[5] * size[2], p.p[1],
           r[6] * size[0], r[7] * size[1], r[8] * size[2], p.p[2], 0, 0, 0, 1);
    mesh.matrixAutoUpdate = false;
    mesh.matrix.copy(m4);
    const big = size[0] * size[1] * size[2] > 6000;
    mesh.castShadow = p.m !== "Neon" && p.m !== "Glass" && !(big && size[1] < 3);
    mesh.receiveShadow = true;
    group.add(mesh);
    if (p.l && p.m === "Neon") {
      const light = new THREE.PointLight(new THREE.Color().setRGB(p.c[0] / 255, p.c[1] / 255, p.c[2] / 255), 0.0, 30);
      light.position.set(p.p[0], p.p[1], p.p[2]);
    }
  }
  buildTerrain(map.terrain, group);
  scene.add(group);
  box.setFromObject(group);

  // lighting from the map's clock time
  const clock = map.lighting.clock;
  const dayT = Math.max(0.05, Math.sin(((clock - 6) / 12) * Math.PI));
  const warm = clock > 16.5 || clock < 8;
  const skyTop = warm ? new THREE.Color(0x6b86c9) : new THREE.Color(0x7fb2ff);
  const skyLow = warm ? new THREE.Color(0xffb27a) : new THREE.Color(0xd6e8ff);
  scene.background = skyLow.clone().lerp(skyTop, 0.35);
  scene.fog = new THREE.Fog(skyLow, 350, 1400);
  sun.color = warm ? new THREE.Color(0xffc48a) : new THREE.Color(0xfff6e8);
  sun.intensity = 1.2 + dayT * 1.6;
  const ang = ((clock - 6) / 12) * Math.PI;
  sun.position.set(Math.cos(ang) * 400, Math.max(80, Math.sin(ang) * 500), 220);
  sun.target.position.set(0, 0, 0);
  const sc = sun.shadow.camera;
  sc.left = -260; sc.right = 260; sc.top = 260; sc.bottom = -260; sc.far = 1600; sc.updateProjectionMatrix();
  setView(0);
  document.querySelectorAll("#maps-bar button").forEach((b, i) => b.classList.toggle("on", i === idx));
  document.getElementById("title").textContent = map.name;
  document.getElementById("stats").textContent = `${map.parts.length.toLocaleString()} parts · ${map.spawns.length} spawns`;
}

function setView(i) {
  const map = current;
  if (i === 0 && map.name === "SHOWROOM") {
    camera.position.set(-6, 30, 62);
    controls.target.set(-4, 2, -2);
  } else if (map.name === "SHOWROOM") {
    const x = i === 2 ? -28 : 12;
    camera.position.set(x, 12, 4);
    controls.target.set(x, 4, -14);
  } else if (i === 0) {
    camera.position.set(200, 260, 230);
    controls.target.set(0, 0, 0);
  } else if (i === 1) {
    camera.position.set(0, 520, 1);
    controls.target.set(0, 0, 0);
  } else {
    // eye-level shot from a spawn point looking toward the middle
    const sp = map.spawns[(i * 5) % map.spawns.length];
    camera.position.set(sp[0], sp[1] + 3, sp[2]);
    controls.target.set(sp[0] * 0.55, sp[1] + 2, sp[2] * 0.55);
  }
  controls.update();
}

const bar = document.getElementById("maps-bar");
MAPS.forEach((m, i) => {
  const b = document.createElement("button");
  b.textContent = m.name;
  b.onclick = () => load(i);
  bar.appendChild(b);
});
document.querySelectorAll("[data-view]").forEach((b) => (b.onclick = () => setView(+b.dataset.view)));

window.addEventListener("resize", () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});
function frame() {
  controls.update();
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}
window.preview = { load, setView, count: MAPS.length };
load(0);
frame();
window.__ready = true;
