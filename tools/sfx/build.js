// بيبني كل أصوات اللعبة من وصفات: طبقات من تسجيلات محترفة مجانية (Mixkit)
// وعيّنات CC0 (Kenney) بتتقصّ وتتخلط وتتعالج بـffmpeg، وبعدين بتتعاير لنفس
// الحجم المسموع (-10 LUFS للأحداث الكبيرة، أهدى للنقرات) بمحدّد -1 dBFS،
// وبتتصدّر MP3. ما في أي صوت مولّد من مذبذبات — كله تسجيلات حقيقية.
//
// الاستعمال:
//   node tools/sfx/build.js <mixkit-dir> <kenney-dir> <out-dir> [ffmpeg-path]
// <mixkit-dir> فيه <id>.wav لكل صوت (من https://assets.mixkit.co/active_storage/sfx/<id>/<id>.wav)
// <kenney-dir> فيه الحزم مفكوكة: casino-audio/Audio/… إلخ.
//
// الرخص: Mixkit Sound Effects Free License (استعمال تجاري، بدون نسب، بدون
// إعادة توزيع الملفات الخام — لهيك المصادر مش بالمستودع، والناتج مخلوط
// ومعالج). Kenney: CC0.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

const [, , mixkitDir, kenneyDir, outDir, ffmpegArg] = process.argv;
if (!mixkitDir || !kenneyDir || !outDir) {
  console.error('usage: node build.js <mixkit-dir> <kenney-dir> <out-dir> [ffmpeg]');
  process.exit(2);
}
const FFMPEG = ffmpegArg || process.env.FFMPEG || 'ffmpeg';
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'sfx-'));
fs.mkdirSync(outDir, { recursive: true });

/// عيّنة Mixkit برقمها.
const M = (id) => path.join(mixkitDir, `${id}.wav`);
/// عيّنة Kenney.
const K = (pack, file) => path.join(kenneyDir, pack, 'Audio', file);

// ------------------------------------------------------------- الوصفات
// طبقة: {src, at (ث)، gain، pitch (١ = كما هي)، trim: [من, إلى] بالثواني،
//        fadeIn/fadeOut (ث)}.
// fx: hp/lp (هرتز)، reverb (0..1).
// target: LUFS للحجم المسموع؛ الافتراضي -10.
//
// مصادر Mixkit المستعملة (الاسم عندهم):
//   952 Correct answer reward · 2870 Correct answer tone · 600 Achievement bell
//   2015 Winning chimes · 2352 Magic glitter · 2350 Magic sparkle whoosh
//   950 Game show wrong answer buzz · 948 Wrong answer bass buzzer
//   954 Wrong long buzzer · 3219 Wrong answer game show · 946 Wrong answer fail
//   2042 Player losing · 3090 Game show buzz in · 722 Successful horns fanfare
//   518 Small group cheer and applause · 631 Grand brass fanfare
//   462 Huge crowd cheering victory · 2918 Epic movie trailer whoosh impact
//   2902 Movie impact intro presentation · 2633 Sweeping sparkle intro
//   1492 Cinematic whoosh fast · 2908 Movie trailer epic impact
//   2344 Magic notification ring · 790 Cinematic trailer riser
//   577 Tension and suspense drum roll · 786 Cinematic suspense swell
//   937 Happy bells notification · 2867 Confirmation tone · 1053 Ticking counter
//   1490 Fast whoosh transition · 1045 Tick tock clock timer · 1109 Select click
//   2357 Bubble pop up alert · 2575 Software interface back
//   2569 Negative tone interface tap · 2585 Light switch tap · 1110 Click error
//   524 Fireworks whooshes and bangs · 2993 Firework rockets exploding
const recipes = {
  // -------------------------------------------------- اللعبة الأساسية
  reveal: {
    layers: [
      { src: M(952), gain: 1.0 },
      { src: M(2352), gain: 0.3, trim: [0, 1.6], fadeOut: 0.6 },
    ],
    fx: { hp: 90, reverb: 0.15 },
  },
  strike1: {
    layers: [{ src: M(950), gain: 1.0 }],
  },
  strike2: {
    layers: [
      { src: M(950), gain: 1.0 },
      { src: M(950), at: 0.55, gain: 1.0, pitch: 0.94 },
    ],
  },
  strike3: {
    layers: [
      { src: M(950), gain: 1.0 },
      { src: M(950), at: 0.5, gain: 1.0, pitch: 0.94 },
      { src: M(950), at: 1.0, gain: 1.0, pitch: 0.88 },
      { src: M(948), at: 1.0, gain: 0.8 },
      { src: M(2908), at: 1.05, gain: 0.45, trim: [0, 2.0], fadeOut: 0.7 },
    ],
    fx: { reverb: 0.15 },
  },
  wrong: {
    layers: [{ src: M(3219), gain: 1.0, trim: [0, 2.2], fadeOut: 0.4 }],
  },
  timeUp: {
    layers: [
      { src: M(954), gain: 1.0 },
      { src: M(2042), at: 0.25, gain: 0.6, trim: [0, 2.0], fadeOut: 0.4 },
    ],
  },
  buzz: {
    layers: [{ src: M(3090), gain: 1.0, trim: [0, 1.0], fadeOut: 0.3 }],
    target: -11,
  },
  clock: {
    layers: [{ src: M(1045), gain: 1.0, trim: [0, 5.4], fadeOut: 0.25 }],
    fx: { hp: 200 },
    target: -14,
  },
  faceOffOpen: {
    layers: [{ src: M(2344), gain: 1.0 }],
    target: -12,
  },
  stealOpen: {
    layers: [
      { src: M(577), gain: 0.9, trim: [0, 1.35], fadeIn: 0.05 },
      { src: M(786), gain: 0.45, trim: [0, 1.45], fadeIn: 0.2, fadeOut: 0.1 },
      { src: M(2908), at: 1.3, gain: 1.0, trim: [0, 1.8], fadeOut: 0.6 },
    ],
    fx: { hp: 50, reverb: 0.15 },
  },
  stealWin: {
    layers: [
      { src: M(2350), gain: 0.5 },
      { src: M(2015), at: 0.05, gain: 1.0 },
      { src: M(518), at: 0.25, gain: 0.5, trim: [0, 2.6], fadeIn: 0.05, fadeOut: 0.9 },
    ],
    fx: { hp: 90, reverb: 0.15 },
  },
  choicePrompt: {
    layers: [{ src: M(937), gain: 1.0 }],
    target: -12,
  },
  choiceMade: {
    layers: [{ src: M(2867), gain: 1.0 }],
    target: -12,
  },
  win: {
    layers: [
      { src: M(722), gain: 1.0 },
      { src: M(2015), at: 0.1, gain: 0.45 },
      { src: M(518), at: 0.35, gain: 0.55, trim: [0, 3.0], fadeIn: 0.05, fadeOut: 1.0 },
    ],
    fx: { hp: 70, reverb: 0.2 },
  },
  // ---------------------------------------------- الحركات والشاشات
  intro: {
    layers: [
      { src: M(2633), gain: 0.6 },
      { src: M(2902), gain: 1.0, trim: [0, 3.2], fadeOut: 0.7 },
    ],
    fx: { hp: 50, reverb: 0.2 },
  },
  roundStart: {
    // الكرت بيطير ٠٫٠٦–٠٫٥ ث، هزّة ٠٫٤٤، الشارة ٠٫٥ (round_opening.dart).
    layers: [
      { src: M(1492), gain: 1.0 },
      { src: M(2908), at: 0.38, gain: 1.0, trim: [0, 1.6], fadeOut: 0.6 },
      { src: M(2344), at: 0.5, gain: 0.45 },
    ],
    fx: { hp: 60, reverb: 0.15 },
  },
  versus: {
    // شاشة «استعدوا» ٢ ث: صعود ١٫٥ ث وبعدها ضربة.
    layers: [
      { src: M(790), gain: 0.9, trim: [1.07, 2.57] },
      { src: M(577), gain: 0.5, trim: [0, 1.5], fadeIn: 0.2 },
      { src: M(2908), at: 1.5, gain: 1.0, trim: [0, 2.2], fadeOut: 0.8 },
    ],
    fx: { hp: 40, reverb: 0.2 },
  },
  scoreCount: {
    // الأرقام بتعدّ ٠٫٥–١٫٤ ث بشاشة النتيجة.
    layers: [{ src: M(1053), gain: 1.0, trim: [0, 1.0], fadeOut: 0.15 }],
    fx: { hp: 300 },
    target: -8,
  },
  crown: {
    layers: [
      { src: M(600), gain: 1.0 },
      { src: M(2352), gain: 0.4, trim: [0, 1.6], fadeOut: 0.6 },
    ],
    fx: { hp: 90, reverb: 0.25 },
  },
  banner: {
    layers: [{ src: M(1490), gain: 1.0 }],
    target: -13,
  },
  gameOver: {
    layers: [
      { src: M(2918), gain: 0.8, trim: [0, 2.5], fadeOut: 0.6 },
      { src: M(631), at: 0.7, gain: 1.0 },
      { src: M(462), at: 1.0, gain: 0.55, trim: [0, 5.0], fadeIn: 0.1, fadeOut: 1.6 },
    ],
    fx: { hp: 50, reverb: 0.2 },
  },
  fireworks: {
    // دورة الألعاب النارية ٢٫٦ ث (fireworks.dart).
    layers: [
      { src: M(524), gain: 1.0, trim: [0, 2.7], fadeOut: 0.4 },
      { src: M(2993), at: 0.4, gain: 0.55, trim: [0, 2.2], fadeOut: 0.4 },
    ],
    fx: { hp: 60 },
    target: -14,
  },
  // ---------------------------------------------- اللوبي والواجهة
  tap: {
    layers: [{ src: M(1109), gain: 1.0, trim: [0, 0.35], fadeOut: 0.1 }],
    target: -13,
  },
  join: {
    layers: [
      { src: M(2357), gain: 1.0 },
      { src: M(2867), at: 0.08, gain: 0.5 },
    ],
    target: -13,
  },
  leave: {
    layers: [{ src: M(2575), gain: 1.0 }],
    target: -14,
  },
  connected: {
    layers: [
      { src: M(2867), gain: 1.0 },
      { src: M(2344), at: 0.1, gain: 0.35 },
    ],
    target: -12,
  },
  kicked: {
    layers: [
      { src: M(2569), gain: 1.0 },
      { src: M(946), at: 0.15, gain: 0.6 },
    ],
    target: -13,
  },
  teamSwitch: {
    layers: [{ src: M(2585), gain: 1.0 }],
    target: -10,
  },
  error: {
    layers: [{ src: M(1110), gain: 1.0 }],
    target: -14,
  },
};

// ------------------------------------------------------------ التنفيذ
function run(args) {
  return execFileSync(FFMPEG, ['-hide_banner', '-nostdin', '-y', ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
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
    if (l.trim) parts.push(`atrim=start=${l.trim[0]}:end=${l.trim[1]}`, 'asetpts=PTS-STARTPTS');
    if (l.pitch && l.pitch !== 1) parts.push(`asetrate=${Math.round(44100 * l.pitch)}`, 'aresample=44100');
    if (l.fadeIn) parts.push(`afade=t=in:st=0:d=${l.fadeIn}`);
    if (l.fadeOut) {
      // الخفوت من آخر المقطع: لازم نعرف طوله — منستعمل atrim إذا موجود
      // وإلا طول الملف.
      const len = l.trim ? l.trim[1] - l.trim[0] : duration(l.src);
      const effective = l.pitch && l.pitch !== 1 ? len / l.pitch : len;
      parts.push(`afade=t=out:st=${Math.max(0, effective - l.fadeOut).toFixed(3)}:d=${l.fadeOut}`);
    }
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
    // صدى قصير متعدّد — لمسة غرفة، خفيفة (المصادر إلها ذيولها أصلاً).
    const r = fx.reverb;
    post.push(
      `aecho=0.85:0.55:23|41|67|97:${(0.32 * r).toFixed(3)}|${(0.22 * r).toFixed(3)}|${(0.14 * r).toFixed(3)}|${(0.08 * r).toFixed(3)}`,
    );
  }
  post.push('apad=pad_dur=0.25', 'silenceremove=stop_periods=-1:stop_threshold=-70dB:stop_duration=0.25');
  const labels = recipe.layers.map((_, i) => `[l${i}]`).join('');
  const graph = `${chains.join(';')};${labels}amix=inputs=${recipe.layers.length}:normalize=0:dropout_transition=0,${post.join(',')}[out]`;
  const wavPath = path.join(work, `${name}.mix.wav`);
  run([...inputs, '-filter_complex', graph, '-map', '[out]', '-ar', '44100', '-ac', '1', wavPath]);
  return wavPath;
}

const durations = new Map();
function duration(file) {
  if (durations.has(file)) return durations.get(file);
  const out = runCapture(['-i', file, '-f', 'null', '-']);
  const dur = /Duration:\s*(\d+):(\d+):([\d.]+)/.exec(out);
  const seconds = dur ? (+dur[1]) * 3600 + (+dur[2]) * 60 + (+dur[3]) : 0;
  durations.set(file, seconds);
  return seconds;
}

/// الحجم المسموع الحالي: LUFS إذا الملف طويل كفاية، وإلا RMS (dBFS).
function measure(file) {
  const out = runCapture([
    '-i', file,
    '-af', 'ebur128=peak=true,astats=measure_overall=RMS_level:measure_perchannel=none',
    '-f', 'null', '-',
  ]);
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
  return {
    name,
    seconds: after.seconds.toFixed(2),
    before: `${m.value.toFixed(1)} ${m.kind}`,
    after: `${after.value.toFixed(1)} ${after.kind}`,
  };
}

const report = [];
for (const [name, recipe] of Object.entries(recipes)) {
  const wavPath = mix(name, recipe);
  report.push(master(name, wavPath, recipe.target ?? -10));
}
console.table(report);
fs.rmSync(work, { recursive: true, force: true });
