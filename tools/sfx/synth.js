// عناصر مركّبة رقمياً (WAV 44.1k mono 16-bit) — اللي ما بتعطيه العيّنات:
// أصوات هواء (whoosh)، بزرات، صعود توتّر (riser)، تكّات، وفرقعات.
// كلها من هون أصلية ١٠٠٪ — ما فيها أي مقطع مسجّل.
'use strict';
const fs = require('fs');
const path = require('path');

const SR = 44100;

function wav(samples) {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8);
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
  let peak = 0;
  for (const s of samples) peak = Math.max(peak, Math.abs(s));
  const g = peak > 0 ? 0.9 / peak : 1;
  for (let i = 0; i < n; i++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i] * g)) * 32767), 44 + i * 2);
  return buf;
}

const sec = (s) => Math.round(s * SR);
const buffer = (seconds) => new Float64Array(sec(seconds));

/// بيضيف [gen](t, p) على [dst] من [at] لمدة [dur]. t بالثواني، p من ٠ لـ١.
function add(dst, at, dur, gen) {
  const start = sec(at), n = sec(dur);
  for (let i = 0; i < n && start + i < dst.length; i++) dst[start + i] += gen(i / SR, i / n);
}

// أغلفة
const expDecay = (t, rate) => Math.exp(-t * rate);
const attack = (t, a) => Math.min(1, t / a);
const lerp = (a, b, p) => a + (b - a) * p;

// مذبذبات
const sine = (f, t) => Math.sin(2 * Math.PI * f * t);
const square = (f, t) => Math.sign(Math.sin(2 * Math.PI * f * t));
const saw = (f, t) => 2 * ((f * t) % 1) - 1;
const tri = (f, t) => 2 * Math.abs(2 * ((f * t) % 1) - 1) - 1;

/// ضجيج وردي تقريبي (Paul Kellet) — للهواء والفرقعات.
function pinkNoise() {
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  return () => {
    const w = Math.random() * 2 - 1;
    b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759;
    b2 = 0.96900 * b2 + w * 0.1538520; b3 = 0.86650 * b3 + w * 0.3104856;
    b4 = 0.55000 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.0168980;
    const out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362;
    b6 = w * 0.115926;
    return out * 0.11;
  };
}

/// مرشّح تمرير منخفض بسيط (one-pole) — قاطع متغيّر بالزمن.
function onePoleLP() {
  let y = 0;
  return (x, cutoff) => {
    const a = 1 - Math.exp(-2 * Math.PI * cutoff / SR);
    y += a * (x - y);
    return y;
  };
}

/// مرشّح تمرير مرتفع بسيط.
function onePoleHP() {
  let yl = 0;
  return (x, cutoff) => {
    const a = 1 - Math.exp(-2 * Math.PI * cutoff / SR);
    yl += a * (x - yl);
    return x - yl;
  };
}

// ============================================================== الوصفات

/// هواء (whoosh): ضجيج وردي بمرشّح بيكنس من تحت لفوق ولتحت — طول dur.
function whoosh(dur, { from = 300, peak = 6000, to = 500, gain = 1 } = {}) {
  const s = buffer(dur + 0.1);
  const noise = pinkNoise(), lp = onePoleLP(), hp = onePoleHP();
  add(s, 0, dur, (t, p) => {
    const cut = p < 0.5 ? lerp(from, peak, p * 2) : lerp(peak, to, (p - 0.5) * 2);
    const env = Math.sin(Math.PI * p) ** 1.5;
    return hp(lp(noise() * 4, cut), 120) * env * gain;
  });
  return s;
}

/// بزّر (buzzer) خشن — مربّع + منشار بلمسة اهتزاز، [bursts] دفعة.
function buzzer(bursts, len, { base = 118, dropPer = 7, gap = 0.07 } = {}) {
  const total = bursts * len + (bursts - 1) * gap + 0.25;
  const s = buffer(total);
  for (let b = 0; b < bursts; b++) {
    add(s, b * (len + gap), len, (t, p) => {
      const f = base - b * dropPer + sine(19, t) * 3;
      const body = square(f, t) * 0.55 + saw(f * 1.5, t) * 0.22 + square(f * 2.01, t) * 0.12;
      const gate = p < 0.9 ? 1 : (1 - p) / 0.1;
      return attack(t, 0.004) * gate * body;
    });
  }
  return s;
}

/// صعود توتّر (riser): موجة جيبية بتصعد أوكتافين + ضجيج بيكبر.
function riser(dur, { from = 180, to = 900, gain = 1 } = {}) {
  const s = buffer(dur + 0.05);
  const noise = pinkNoise(), lp = onePoleLP();
  let phase = 0;
  add(s, 0, dur, (t, p) => {
    const f = from * Math.pow(to / from, p);
    phase += 2 * Math.PI * f / SR;
    const tone = Math.sin(phase) * 0.6 + Math.sin(phase * 2) * 0.2;
    const air = lp(noise() * 3, lerp(400, 8000, p));
    const env = Math.pow(p, 1.6);
    return (tone * 0.7 + air * 0.8) * env * gain;
  });
  return s;
}

/// دينغ زجاجي: عدة توافقيات بلا عزف بتخبو بسرعة مختلفة — جرس صغير لامع.
function chime(freq, dur, { bright = 1 } = {}) {
  const s = buffer(dur + 0.1);
  add(s, 0, dur, (t) =>
    expDecay(t, 3.2) * sine(freq, t) * 0.6 +
    expDecay(t, 5.5) * sine(freq * 2.01, t) * 0.25 * bright +
    expDecay(t, 9) * sine(freq * 3.98, t) * 0.12 * bright +
    expDecay(t, 14) * sine(freq * 5.1, t) * 0.05 * bright,
  );
  return s;
}

/// تكّة ساعة قصيرة — نقرة خشبية بترنّ لحظة.
function tick(freq, dur = 0.06) {
  const s = buffer(dur + 0.02);
  add(s, 0, dur, (t) => expDecay(t, 70) * (sine(freq, t) * 0.7 + (Math.random() * 2 - 1) * 0.3));
  return s;
}

/// نبضة تحت (sub) — ثقل للضربات.
function thump(dur = 0.35, { from = 140, to = 45 } = {}) {
  const s = buffer(dur + 0.05);
  let phase = 0;
  add(s, 0, dur, (t, p) => {
    phase += 2 * Math.PI * lerp(from, to, Math.min(1, p * 3)) / SR;
    return Math.sin(phase) * expDecay(t, 9) * attack(t, 0.003);
  });
  return s;
}

/// فرقعات ألعاب نارية: نبضات ضجيج عشوائية بتخبو بسرعة، على مدى [dur].
function crackle(dur, { pops = 40, seed = 1 } = {}) {
  const s = buffer(dur + 0.3);
  let r = seed;
  const rnd = () => { r = (r * 1103515245 + 12345) & 0x7fffffff; return r / 0x7fffffff; };
  const noise = pinkNoise(), hp = onePoleHP();
  for (let i = 0; i < pops; i++) {
    const at = rnd() * dur;
    const size = 0.02 + rnd() * 0.08;
    const g = 0.4 + rnd() * 0.6;
    add(s, at, size, (t, p) => hp(noise() * 6, 900) * expDecay(t, 40) * g);
  }
  return s;
}

/// نغمة نازلة (wah-wah) للغلط — منشار + مثلث بيهبطوا نص أوكتاف.
function wahDown(dur = 0.7, { from = 330 } = {}) {
  const s = buffer(dur + 0.1);
  let phase = 0;
  add(s, 0, dur, (t, p) => {
    const f = from * Math.pow(0.5, p * 1.3);
    phase += f / SR;
    const sw = 2 * (phase % 1) - 1;
    const tr = 2 * Math.abs(2 * ((phase * 0.5) % 1) - 1) - 1;
    return attack(t, 0.02) * expDecay(t, 2.4) * (sw * 0.45 + tr * 0.4);
  });
  return s;
}

/// نغمتان صاعدتان — للانضمام.
function twoNotesUp(f1 = 523.25, f2 = 783.99) {
  const s = buffer(0.5);
  add(s, 0, 0.25, (t) => expDecay(t, 8) * (sine(f1, t) * 0.7 + sine(f1 * 2, t) * 0.15));
  add(s, 0.12, 0.35, (t) => expDecay(t, 7) * (sine(f2, t) * 0.7 + sine(f2 * 2, t) * 0.15));
  return s;
}

/// نغمتان نازلتان — للمغادرة.
function twoNotesDown(f1 = 659.25, f2 = 440) {
  const s = buffer(0.5);
  add(s, 0, 0.25, (t) => expDecay(t, 8) * (sine(f1, t) * 0.7 + sine(f1 * 2, t) * 0.12));
  add(s, 0.14, 0.35, (t) => expDecay(t, 6) * (sine(f2, t) * 0.7 + sine(f2 * 2, t) * 0.12));
  return s;
}

/// نفخة فوز (fanfare): أربع نغمات صاعدة سريعة (دو-مي-صول-دو) بصوت
/// نحاسي (منشار بمرشّح) وبعدها كورد بيرنّ — أصلية بالكامل. [long] بتزيد
/// نغمة خامسة وذيل أطول (لنهاية اللعبة).
function fanfare({ long = false } = {}) {
  const notes = long ? [523.25, 659.25, 783.99, 1046.5, 1318.5] : [523.25, 659.25, 783.99, 1046.5];
  const step = 0.11;
  const hold = long ? 2.2 : 1.4;
  const s = buffer(notes.length * step + hold + 0.3);
  const brass = (f, t, p) => {
    const lp = 0.55 + 0.45 * Math.exp(-t * 6);
    const raw = saw(f, t) * 0.5 + saw(f * 1.005, t) * 0.3 + saw(f * 0.5, t) * 0.25;
    return raw * lp;
  };
  notes.forEach((f, i) => {
    const last = i === notes.length - 1;
    add(s, i * step, last ? hold : step * 1.15, (t, p) =>
      attack(t, 0.01) * (last ? expDecay(t, 1.4) : 1) * brass(f, t, p) * 0.5);
  });
  // الكورد الأخير: توافقيات النغمة الأخيرة بثلث ونصف فوق.
  const top = notes[notes.length - 1];
  add(s, (notes.length - 1) * step, hold, (t) =>
    attack(t, 0.02) * expDecay(t, 1.3) * (brass(top * 1.25, t, 0) * 0.28 + brass(top * 1.5, t, 0) * 0.22));
  // لمعة جرس فوق الكورد.
  const ch = chime(top * 2, hold * 0.8, { bright: 0.8 });
  add(s, (notes.length - 1) * step, hold * 0.8, (t) => ch[Math.min(ch.length - 1, sec(t))] * 0.35);
  return s;
}

/// كل الأصوات المركّبة — تنكتب كملفات WAV بمجلد [outDir].
function writeAll(outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  const out = (name, samples) => fs.writeFileSync(path.join(outDir, name + '.wav'), wav(samples));

  out('whoosh_short', whoosh(0.35, { from: 500, peak: 7000, to: 800 }));
  out('whoosh_long', whoosh(0.7, { from: 250, peak: 6000, to: 400 }));
  out('buzz1', buzzer(1, 0.42));
  out('buzz2', buzzer(2, 0.36));
  out('buzz3', buzzer(3, 0.34));
  out('riser_short', riser(0.9, { from: 200, to: 1000 }));
  out('riser_long', riser(1.6, { from: 150, to: 1200 }));
  out('chime_hi', chime(1567.98, 1.1));      // G6
  out('chime_mid', chime(1046.5, 1.2));      // C6
  out('chime_low', chime(783.99, 1.4));      // G5
  out('thump', thump());
  out('thump_big', thump(0.5, { from: 110, to: 38 }));
  out('crackle', crackle(2.4, { pops: 55 }));
  out('wah_down', wahDown());
  out('notes_up', twoNotesUp());
  out('notes_down', twoNotesDown());
  out('fanfare', fanfare());
  out('fanfare_long', fanfare({ long: true }));

  // تكّات الساعة: ١١ تكّة على ٥٫٤ ثانية، بتعلى شوي مع الوقت (توتّر).
  const clock = buffer(5.5);
  for (let i = 0; i < 11; i++) {
    const f = (i % 2 === 0 ? 2000 : 1500) * (1 + i * 0.02);
    const tk = tick(f);
    add(clock, i * 0.5, 0.08, (t) => tk[Math.min(tk.length - 1, sec(t))]);
  }
  out('clock_ticks', clock);

  // عدّ النقاط: تكّات سريعة بتتسارع — ٠٫٩ ثانية.
  const count = buffer(1.0);
  let at = 0, gap = 0.075;
  while (at < 0.9) {
    const tk = tick(1800 + at * 900, 0.03);
    const a = at;
    add(count, a, 0.04, (t) => tk[Math.min(tk.length - 1, sec(t))] * 0.7);
    at += gap; gap = Math.max(0.028, gap * 0.9);
  }
  out('count_ticks', count);
}

module.exports = { writeAll };
if (require.main === module) writeAll(process.argv[2] || path.join(__dirname, 'synth-out'));
