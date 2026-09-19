// بيبني كل أصوات اللعبة من وصفات: طبقات (عيّنات CC0 من Kenney + عناصر
// مركّبة من synth.js) بتتخلط وتتعالج بـffmpeg، وبعدين بتتعاير لنفس الحجم
// المسموع (-10 LUFS أو RMS للقصير جداً) بمحدّد -1 dBFS، وبتتصدّر MP3.
//
// الاستعمال:
//   node tools/sfx/build.js <kenney-dir> <out-dir> [ffmpeg-path]
// <kenney-dir> فيه الحزم مفكوكة: interface-sounds/Audio/…، impact-sounds/… إلخ.
// كل الحزم CC0 (https://kenney.nl) — بدون شرط نسب، وبتنستعمل تجارياً.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');
const synth = require('./synth');

const [, , kenneyDir, outDir, ffmpegArg] = process.argv;
if (!kenneyDir || !outDir) {
  console.error('usage: node build.js <kenney-dir> <out-dir> [ffmpeg]');
  process.exit(2);
}
const FFMPEG = ffmpegArg || process.env.FFMPEG || 'ffmpeg';
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'sfx-'));
const synthDir = path.join(work, 'synth');
synth.writeAll(synthDir);
fs.mkdirSync(outDir, { recursive: true });

const K = (pack, file) => path.join(kenneyDir, pack, 'Audio', file);
const S = (name) => path.join(synthDir, name + '.wav');

// ------------------------------------------------------------- الوصفات
// طبقة: {src, at (ث), gain, pitch (١ = كما هي)، fadeOut (ث)}.
// fx: hp/lp (هرتز)، reverb (0..1)، comp (bool).
// target: LUFS للحجم المسموع؛ الافتراضي -10 (قوي — سهرة).
const recipes = {
  // -------------------------------------------------- اللعبة الأساسية
  reveal: {
    layers: [
      { src: K('interface-sounds', 'confirmation_002.ogg'), gain: 1.0 },
      { src: S('chime_hi'), gain: 0.8 },
      { src: K('impact-sounds', 'impactBell_heavy_000.ogg'), gain: 0.55, pitch: 1.6 },
      { src: K('interface-sounds', 'glass_003.ogg'), at: 0.02, gain: 0.5 },
    ],
    fx: { hp: 120, reverb: 0.35 },
  },
  strike1: {
    layers: [
      { src: S('buzz1'), gain: 1.0 },
      { src: K('interface-sounds', 'error_004.ogg'), gain: 0.55 },
      { src: S('thump'), gain: 0.6 },
    ],
    fx: { lp: 9000 },
  },
  strike2: {
    layers: [
      { src: S('buzz2'), gain: 1.0 },
      { src: K('interface-sounds', 'error_004.ogg'), gain: 0.55 },
      { src: K('interface-sounds', 'error_004.ogg'), at: 0.43, gain: 0.55, pitch: 0.95 },
      { src: S('thump'), gain: 0.6 },
    ],
    fx: { lp: 9000 },
  },
  strike3: {
    layers: [
      { src: S('buzz3'), gain: 1.0 },
      { src: K('interface-sounds', 'error_004.ogg'), gain: 0.55 },
      { src: K('interface-sounds', 'error_004.ogg'), at: 0.41, gain: 0.55, pitch: 0.95 },
      { src: K('interface-sounds', 'error_004.ogg'), at: 0.82, gain: 0.55, pitch: 0.9 },
      { src: K('impact-sounds', 'impactMetal_heavy_000.ogg'), at: 0.8, gain: 0.7 },
      { src: S('thump_big'), at: 0.8, gain: 0.8 },
    ],
    fx: { lp: 9000, reverb: 0.15 },
  },
  wrong: {
    layers: [
      { src: S('wah_down'), gain: 1.0 },
      { src: K('interface-sounds', 'error_006.ogg'), at: 0.05, gain: 0.5 },
      { src: S('thump'), gain: 0.4 },
    ],
    fx: { lp: 10000 },
  },
  win: {
    layers: [
      { src: S('whoosh_short'), gain: 0.5 },
      { src: S('fanfare'), at: 0.12, gain: 1.0 },
      { src: K('impact-sounds', 'impactBell_heavy_001.ogg'), at: 0.55, gain: 0.7 },
      { src: K('casino-audio', 'chips-collide-1.ogg'), at: 0.6, gain: 0.45 },
    ],
    fx: { hp: 90, reverb: 0.3 },
  },
  buzz: {
    layers: [
      { src: K('interface-sounds', 'select_001.ogg'), gain: 1.0 },
      { src: K('digital-audio', 'zap1.ogg'), gain: 0.4, pitch: 1.3, fadeOut: 0.08 },
      { src: S('thump'), gain: 0.35, fadeOut: 0.12 },
    ],
    fx: { hp: 100 },
    target: -11,
  },
  clock: {
    layers: [
      { src: S('clock_ticks'), gain: 1.0 },
      ...Array.from({ length: 11 }, (_, i) => ({
        src: K('interface-sounds', 'tick_002.ogg'),
        at: i * 0.5,
        gain: 0.5,
        pitch: 1 + i * 0.015,
      })),
    ],
    fx: { hp: 300 },
    target: -12,
  },
  // ---------------------------------------------- الحركات والشاشات
  intro: {
    layers: [
      { src: S('riser_short'), gain: 0.7 },
      { src: S('whoosh_long'), at: 0.3, gain: 0.8 },
      { src: K('impact-sounds', 'impactBell_heavy_001.ogg'), at: 0.9, gain: 0.9 },
      { src: S('chime_low'), at: 0.9, gain: 0.8 },
      { src: K('casino-audio', 'chips-collide-1.ogg'), at: 0.95, gain: 0.45 },
      { src: S('thump_big'), at: 0.9, gain: 0.6 },
    ],
    fx: { hp: 60, reverb: 0.4 },
  },
  tap: {
    layers: [
      { src: K('ui-audio', 'click1.ogg'), gain: 0.9 },
      { src: K('interface-sounds', 'click_002.ogg'), gain: 0.4 },
    ],
    target: -14,
  },
  join: {
    layers: [
      { src: S('notes_up'), gain: 1.0 },
      { src: K('interface-sounds', 'pluck_001.ogg'), gain: 0.5 },
    ],
    fx: { reverb: 0.2 },
    target: -12,
  },
  leave: {
    layers: [
      { src: S('notes_down'), gain: 1.0 },
      { src: K('interface-sounds', 'drop_002.ogg'), gain: 0.5 },
    ],
    target: -13,
  },
  connected: {
    layers: [
      { src: K('interface-sounds', 'confirmation_001.ogg'), gain: 1.0 },
      { src: S('chime_mid'), gain: 0.5 },
    ],
    fx: { reverb: 0.2 },
    target: -12,
  },
  roundStart: {
    // الكرت بيطير ٠٫٠٦–٠٫٥ ث، هزّة ٠٫٤٤، الشارة ٠٫٥ (round_opening.dart).
    layers: [
      { src: S('whoosh_short'), gain: 1.0 },
      { src: K('impact-sounds', 'impactPlank_medium_000.ogg'), at: 0.4, gain: 1.0 },
      { src: S('thump'), at: 0.4, gain: 0.8 },
      { src: S('chime_hi'), at: 0.5, gain: 0.6 },
      { src: K('interface-sounds', 'glass_001.ogg'), at: 0.5, gain: 0.6 },
    ],
    fx: { hp: 70, reverb: 0.25 },
  },
  versus: {
    // شاشة «استعدوا» ٢ ث: صعود ١٫٥ ث وبعدها ضربة.
    layers: [
      { src: S('riser_long'), gain: 0.85 },
      { src: K('impact-sounds', 'impactPunch_heavy_000.ogg'), at: 1.5, gain: 1.0 },
      { src: S('thump_big'), at: 1.5, gain: 1.0 },
      { src: K('impact-sounds', 'impactMetal_medium_002.ogg'), at: 1.55, gain: 0.6 },
      { src: S('chime_low'), at: 1.55, gain: 0.5 },
    ],
    fx: { hp: 50, reverb: 0.35 },
  },
  faceOffOpen: {
    layers: [
      { src: K('interface-sounds', 'bong_001.ogg'), gain: 0.9 },
      { src: S('chime_mid'), gain: 0.45 },
    ],
    fx: { reverb: 0.2 },
    target: -12,
  },
  timeUp: {
    layers: [
      { src: S('buzz1'), gain: 0.85, pitch: 0.9 },
      { src: K('digital-audio', 'lowThreeTone.ogg'), gain: 0.5 },
      { src: S('thump'), gain: 0.5 },
    ],
    fx: { lp: 8000 },
  },
  stealOpen: {
    layers: [
      { src: S('riser_short'), gain: 0.75 },
      { src: K('digital-audio', 'phaserUp3.ogg'), gain: 0.35 },
      { src: K('impact-sounds', 'impactMetal_medium_000.ogg'), at: 0.85, gain: 0.85 },
      { src: S('thump'), at: 0.85, gain: 0.7 },
    ],
    fx: { hp: 60, reverb: 0.3 },
  },
  stealWin: {
    layers: [
      { src: S('whoosh_short'), gain: 0.6 },
      { src: K('interface-sounds', 'confirmation_003.ogg'), at: 0.1, gain: 1.0 },
      { src: S('chime_hi'), at: 0.1, gain: 0.8 },
      { src: K('casino-audio', 'chips-collide-2.ogg'), at: 0.15, gain: 0.6 },
      { src: K('impact-sounds', 'impactBell_heavy_002.ogg'), at: 0.1, gain: 0.5, pitch: 1.4 },
    ],
    fx: { hp: 100, reverb: 0.35 },
  },
  choicePrompt: {
    layers: [
      { src: K('interface-sounds', 'question_001.ogg'), gain: 1.0 },
      { src: S('chime_mid'), gain: 0.5 },
    ],
    fx: { reverb: 0.2 },
    target: -12,
  },
  choiceMade: {
    layers: [
      { src: K('interface-sounds', 'confirmation_004.ogg'), gain: 1.0 },
      { src: K('ui-audio', 'switch5.ogg'), gain: 0.5 },
    ],
    target: -12,
  },
  scoreCount: {
    // الأرقام بتعدّ ٠٫٥–١٫٤ ث بشاشة النتيجة.
    layers: [
      { src: S('count_ticks'), gain: 1.0 },
      { src: K('casino-audio', 'chips-handle-1.ogg'), gain: 0.35, fadeOut: 0.3 },
    ],
    fx: { hp: 400 },
    target: -13,
  },
  crown: {
    layers: [
      { src: K('impact-sounds', 'impactBell_heavy_002.ogg'), gain: 1.0 },
      { src: S('chime_hi'), gain: 0.9 },
      { src: K('interface-sounds', 'glass_002.ogg'), gain: 0.6 },
      { src: K('casino-audio', 'chips-collide-3.ogg'), at: 0.05, gain: 0.4 },
    ],
    fx: { hp: 120, reverb: 0.45 },
  },
  banner: {
    layers: [
      { src: S('whoosh_long'), gain: 1.0 },
      { src: K('ui-audio', 'rollover2.ogg'), at: 0.25, gain: 0.35 },
    ],
    target: -13,
  },
  gameOver: {
    layers: [
      { src: S('whoosh_long'), gain: 0.5 },
      { src: K('impact-sounds', 'impactBell_heavy_000.ogg'), at: 0.15, gain: 0.8 },
      { src: S('fanfare_long'), at: 0.2, gain: 1.0 },
      { src: K('casino-audio', 'chips-collide-1.ogg'), at: 0.3, gain: 0.5 },
      { src: S('crackle'), at: 0.6, gain: 0.45 },
      { src: S('chime_low'), at: 0.75, gain: 0.5 },
    ],
    fx: { hp: 70, reverb: 0.4 },
  },
  fireworks: {
    // دورة الألعاب النارية ٢٫٦ ث (fireworks.dart).
    layers: [
      { src: S('crackle'), gain: 1.0 },
      { src: K('impact-sounds', 'impactSoft_heavy_000.ogg'), at: 0.2, gain: 0.7, pitch: 0.8 },
      { src: K('impact-sounds', 'impactSoft_heavy_000.ogg'), at: 1.1, gain: 0.6, pitch: 0.75 },
      { src: K('impact-sounds', 'impactSoft_heavy_000.ogg'), at: 1.9, gain: 0.7, pitch: 0.85 },
    ],
    fx: { hp: 80, reverb: 0.3 },
    target: -14,
  },
  error: {
    layers: [
      { src: K('interface-sounds', 'error_002.ogg'), gain: 0.9 },
      { src: S('thump'), gain: 0.3, fadeOut: 0.15 },
    ],
    target: -14,
  },
  kicked: {
    layers: [
      { src: K('interface-sounds', 'back_001.ogg'), gain: 0.8 },
      { src: S('notes_down'), gain: 0.9, pitch: 0.8 },
    ],
    target: -13,
  },
  teamSwitch: {
    layers: [
      { src: K('ui-audio', 'switch3.ogg'), gain: 0.9 },
      { src: K('interface-sounds', 'toggle_001.ogg'), gain: 0.5 },
    ],
    target: -14,
  },
};

// ------------------------------------------------------------ التنفيذ
function run(args) {
  return execFileSync(FFMPEG, ['-hide_banner', '-nostdin', '-y', ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

/// ffmpeg بيكتب القياسات على stderr — منجمع الاتنين.
function runCapture(args) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-nostdin', ...args], { encoding: 'utf8' });
  return (r.stdout || '') + (r.stderr || '');
}

/// بيخلط طبقات الوصفة بملف WAV واحد (ما زال بدون معايرة).
function mix(name, recipe) {
  const inputs = [];
  const chains = [];
  recipe.layers.forEach((l, i) => {
    if (!fs.existsSync(l.src)) throw new Error(`${name}: missing ${l.src}`);
    inputs.push('-i', l.src);
    const parts = ['aformat=sample_rates=44100:channel_layouts=mono'];
    if (l.pitch && l.pitch !== 1) parts.push(`asetrate=${Math.round(44100 * l.pitch)}`, 'aresample=44100');
    if (l.fadeOut) parts.push(`afade=t=out:st=0:d=${l.fadeOut}`);
    parts.push(`volume=${l.gain ?? 1}`);
    const ms = Math.round((l.at || 0) * 1000);
    if (ms > 0) parts.push(`adelay=${ms}`);
    chains.push(`[${i}:a]${parts.join(',')}[l${i}]`);
  });
  const fx = recipe.fx || {};
  const post = [];
  if (fx.hp) post.push(`highpass=f=${fx.hp}`);
  if (fx.lp) post.push(`lowpass=f=${fx.lp}`);
  if (fx.reverb) {
    // صدى قصير متعدّد — ذيل غرفة صغيرة، بدون مكتبات خارجية.
    const r = fx.reverb;
    post.push(`aecho=0.85:0.55:23|41|67|97:${(0.32 * r).toFixed(3)}|${(0.22 * r).toFixed(3)}|${(0.14 * r).toFixed(3)}|${(0.08 * r).toFixed(3)}`);
  }
  post.push('apad=pad_dur=0.25', 'silenceremove=stop_periods=-1:stop_threshold=-70dB:stop_duration=0.25');
  const labels = recipe.layers.map((_, i) => `[l${i}]`).join('');
  const graph = `${chains.join(';')};${labels}amix=inputs=${recipe.layers.length}:normalize=0:dropout_transition=0,${post.join(',')}[out]`;
  const wavPath = path.join(work, `${name}.mix.wav`);
  run([...inputs, '-filter_complex', graph, '-map', '[out]', '-ar', '44100', '-ac', '1', wavPath]);
  return wavPath;
}

/// الحجم المسموع الحالي: LUFS إذا الملف طويل كفاية، وإلا RMS (dBFS).
function measure(file) {
  const out = runCapture(['-i', file, '-af', 'ebur128=peak=true,astats=measure_overall=RMS_level:measure_perchannel=none', '-f', 'null', '-']);
  // ebur128 بيطبع I: بكل إطار وبعدين ملخّص — آخر قيمة هي المتكاملة النهائية.
  const all = [...out.matchAll(/I:\s+(-?[\d.]+) LUFS/g)];
  const lufs = all.length ? all[all.length - 1] : null;
  const rms = /RMS level dB:\s*(-?[\d.]+)/.exec(out);
  const dur = /Duration:\s*(\d+):(\d+):([\d.]+)/.exec(out);
  const seconds = dur ? (+dur[1]) * 3600 + (+dur[2]) * 60 + (+dur[3]) : 0;
  const i = lufs ? parseFloat(lufs[1]) : NaN;
  if (seconds >= 0.6 && Number.isFinite(i) && i > -60) return { kind: 'lufs', value: i, seconds };
  return { kind: 'rms', value: rms ? parseFloat(rms[1]) : -20, seconds };
}

/// معايرة للحجم المستهدف + محدّد -1 dBFS، وتصدير MP3.
function master(name, wavPath, target) {
  const m = measure(wavPath);
  // RMS بيقرا أخفض من LUFS بـ~٣ dB لنفس الإحساس — منعدّل.
  const want = m.kind === 'lufs' ? target : target - 3;
  const gain = Math.max(-30, Math.min(30, want - m.value));
  const outPath = path.join(outDir, `sfx_${name}.mp3`);
  run([
    '-i', wavPath,
    '-af', `volume=${gain.toFixed(2)}dB,alimiter=limit=0.891:attack=3:release=60:level=false`,
    '-codec:a', 'libmp3lame', '-q:a', '2', '-ar', '44100', '-ac', '1',
    outPath,
  ]);
  const after = measure(outPath);
  return { name, seconds: after.seconds.toFixed(2), before: `${m.value.toFixed(1)} ${m.kind}`, after: `${after.value.toFixed(1)} ${after.kind}` };
}

const report = [];
for (const [name, recipe] of Object.entries(recipes)) {
  const wavPath = mix(name, recipe);
  report.push(master(name, wavPath, recipe.target ?? -10));
}
console.table(report);
fs.rmSync(work, { recursive: true, force: true });
