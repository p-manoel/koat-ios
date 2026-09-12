import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, copyFileSync, readFileSync } from 'node:fs';
import path from 'node:path';
import cfg from './goldie.config.ts';

// Preserve the authenticated WKWebView session. Goldie's reinstall step clears it.
const udid = process.argv[2];
if (!udid) throw new Error('Informe o UDID do simulador autenticado.');
const argent = process.env.GOLDIE_ARGENT_BIN || '/Users/pedromanoel/.asdf/installs/nodejs/22.14.0/lib/node_modules/goldie/node_modules/@swmansion/argent/dist/cli.js';
const env = { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' };
function call(args) {
  const r = spawnSync(process.execPath, [argent, ...args], { cwd: cfg.appRoot, env, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(r.stderr || r.stdout);
  return r.stdout;
}
function parse(output) {
  for (let i = output.indexOf('{'); i >= 0; i = output.indexOf('{', i + 1)) {
    try { return JSON.parse(output.slice(i)); } catch {}
  }
  throw new Error('Resposta JSON inválida: ' + output.slice(-1000));
}
function tool(name, args = {}) {
  const result = parse(call(['run', name, '--json', '--udid', udid, ...Object.entries(args).flatMap(([k,v]) => ['--'+k, String(v)])]));
  return result.data || result;
}
function flow(name) {
  console.log('Fluxo: ' + name);
  const output = call(['flow', 'run', name, '--device', udid, '--json']);
  writeFileSync(path.join(raw, name + '.report.json'), output);
  return parse(output);
}
const raw = path.join(cfg.appRoot, 'goldie/out/raw/iphone-6.9');
mkdirSync(raw, { recursive: true });
const manifest = { device: 'iphone-6.9', udid, capturedAt: new Date().toISOString(), screenshots: [], preview: null };
const pin = () => spawnSync('xcrun', ['simctl', 'status_bar', udid, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--cellularMode', 'active', '--cellularBars', '4', '--batteryState', 'charged', '--batteryLevel', '100'], { env });
if (process.argv.includes('--preview-only')) manifest.screenshots = JSON.parse(readFileSync(path.join(raw, 'manifest.json'))).screenshots;
for (const scene of cfg.scenes.filter(s => s.kind === 'screenshot' && !process.argv.includes('--preview-only'))) {
  flow(scene.flow);
  pin();
  const file = path.join(raw, scene.id + '.png');
  call(['run', 'screenshot', '--udid', udid, '--scale', '1', '--includeImageInContext', 'false', '--out', file]);
  manifest.screenshots.push({ sceneId: scene.id, file });
}
// Set up the plan before recording: authentication and searching are not the story.
flow('store-mariana');
const scene = cfg.scenes.find(s => s.kind === 'preview');
const clips = [];
for (const segment of scene.segments) {
  // Start/stop INSIDE the outer flow: Argent pins its clock for the whole
  // run and clears it on return. This keeps that reset out of the recording.
  const recordingFlow = 'store-recording-' + segment.id;
  const steps = [
    { tool: 'screen-recording-start', args: { timeLimitSeconds: 120, trimStatic: false, showTouches: false } },
    { run: segment.flow + '.yaml' },
    ...(segment.holdSeconds ? [{ wait: segment.holdSeconds * 1000 }] : []),
    { tool: 'screen-recording-stop' },
  ];
  writeFileSync(path.join(cfg.appRoot, '.argent/flows', recordingFlow + '.yaml'), JSON.stringify({ executionPrerequisite: 'Sessão do treinador no ponto inicial deste segmento; executar com capture-session.mjs.', steps }, null, 2));
  let report;
  try { report = flow(recordingFlow); }
  catch (error) { try { tool('screen-recording-stop'); } catch {} throw error; }
  const stopped = report.steps.find(step => step.tool === 'screen-recording-stop')?.result;
  if (!stopped?.video) throw new Error('Gravação sem arquivo de vídeo: ' + JSON.stringify(stopped));
  const file = path.join(raw, scene.id + '-' + segment.id + '.mp4');
  copyFileSync(stopped.video.hostPath || stopped.video, file);
  clips.push({ segmentId: segment.id, file, durationSeconds: stopped.durationMs / 1000 });
}
manifest.preview = { sceneId: scene.id, clips };
writeFileSync(path.join(raw, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log('Capturas concluídas.');
