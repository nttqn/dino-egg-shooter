// Synthesises the two looping background-music tracks into assets/audio as
// 16-bit mono WAV, from pure math (no samples). Run from the project root:
//   node tool/gen_music.js
//
// Style: cheerful, bright, "mountain forest" — C major pentatonic melodies on
// a bamboo-flute voice (menu) or wooden marimba (game), over marimba/kalimba
// broken chords, a soft round bass, hand drums, a shaker, and bird calls.
//
// Every note is mixed with wrap-around (a tail ringing past the loop's end is
// added back onto the start), so the file loops with no gap or click at the
// seam.
const fs = require('fs');
const path = require('path');

const RATE = 22050;
const OUT = path.join(__dirname, '..', 'assets', 'audio');
fs.mkdirSync(OUT, { recursive: true });

let seed = 20261020;
const rand = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
};
const noise = () => rand() * 2 - 1;
const TAU = 2 * Math.PI;
const midiFreq = (n) => 440 * Math.pow(2, (n - 69) / 12);

function write(name, samples, peak) {
  let max = 0;
  for (const s of samples) max = Math.max(max, Math.abs(s));
  const gain = max > 0 ? peak / max : 1;
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => data.writeInt16LE(Math.round(s * gain * 32767), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVEfmt ', 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(OUT, name), Buffer.concat([head, data]));
  console.log(name, (samples.length / RATE).toFixed(2) + 's', Math.round((44 + data.length) / 1024) + 'KB');
}

// Mixes `synth(t)` for `durSec` seconds into `target` from `startSec`,
// wrapping past the end back to the start.
function addNote(target, startSec, durSec, synth) {
  const from = Math.round(startSec * RATE);
  const count = Math.round(durSec * RATE);
  for (let i = 0; i < count; i++) {
    target[(from + i) % target.length] += synth(i / RATE);
  }
}

// --- Voices -----------------------------------------------------------------

// Bamboo flute: soft attack, gentle delayed vibrato, a breathy noise layer.
function flute(f, dur, gain = 1) {
  let breath = 0;
  return (t) => {
    const attack = Math.min(1, t / 0.07);
    const release = Math.min(1, Math.max(0, (dur - t) / 0.12));
    const vib = 1 + 0.007 * Math.sin(TAU * 5.3 * t) * Math.min(1, Math.max(0, (t - 0.18) / 0.2));
    const ph = TAU * f * vib * t;
    breath += 0.25 * (noise() - breath);
    const tone = Math.sin(ph) + 0.18 * Math.sin(2 * ph) + 0.06 * Math.sin(3 * ph);
    return gain * attack * release * (tone + 0.09 * breath);
  };
}

// Wooden marimba bar: fast mallet attack, the bar's ~4x overtone dying away
// quickly, and a tiny click at the strike.
function marimba(f, gain = 1) {
  return (t) => {
    const strike = Math.min(1, t * 900);
    const body = Math.exp(-t * 6) * Math.sin(TAU * f * t);
    const overtone = 0.28 * Math.exp(-t * 26) * Math.sin(TAU * f * 3.93 * t);
    const click = t < 0.004 ? 0.15 * noise() : 0;
    return gain * strike * (body + overtone + click);
  };
}

// Kalimba / thumb piano: glassy, with its slightly inharmonic upper partial.
function kalimba(f, gain = 1) {
  return (t) => {
    const strike = Math.min(1, t * 700);
    return gain * strike * (Math.exp(-t * 4.2) * Math.sin(TAU * f * t)
      + 0.2 * Math.exp(-t * 11) * Math.sin(TAU * f * 5.4 * t));
  };
}

function bass(f, gain = 1) {
  return (t) => {
    const env = Math.min(1, t * 250) * Math.exp(-t * 2.8);
    return gain * env * (Math.sin(TAU * f * t) + 0.22 * Math.sin(2 * TAU * f * t));
  };
}

// Hand drum: a pitched membrane that drops in pitch as it decays.
function handDrum(high, gain = 1) {
  const f0 = high ? 330 : 150;
  const f1 = high ? 260 : 85;
  const decay = high ? 22 : 13;
  return (t) => {
    const f = f1 + (f0 - f1) * Math.exp(-t * 30);
    const env = Math.min(1, t * 1500) * Math.exp(-t * decay);
    return gain * env * Math.sin(TAU * f * t) + (t < 0.006 ? 0.3 * gain * noise() : 0);
  };
}

// Shaker: a short burst of high-passed noise.
function shaker(gain = 1) {
  let low = 0;
  return (t) => {
    const n = noise();
    low += 0.35 * (n - low);
    const env = Math.min(1, t * 400) * Math.exp(-t * 55);
    return gain * env * (n - low);
  };
}

// One bird call: a few quick rising/falling chirps.
function addBirdCall(target, startSec, gain) {
  const chirps = 2 + Math.floor(rand() * 3);
  const base = 2300 + rand() * 900;
  for (let c = 0; c < chirps; c++) {
    const rise = rand() < 0.5;
    const len = 0.06 + rand() * 0.05;
    addNote(target, startSec + c * (len + 0.035), len, (t) => {
      const p = t / len;
      const f = base * (rise ? 1 + 0.35 * p : 1.35 - 0.35 * p);
      const env = Math.sin(Math.PI * p);
      return gain * env * Math.sin(TAU * f * t + 3 * Math.sin(TAU * 38 * t));
    });
  }
}

// --- Harmony ----------------------------------------------------------------

// [bass root, triad...]; triads voiced around middle C.
const CHORDS = {
  C: [48, 60, 64, 67],
  Am: [45, 57, 60, 64],
  F: [41, 53, 57, 60],
  G: [43, 55, 59, 62],
  Em: [40, 52, 55, 59],
};

// Broken-chord accompaniment, one bar: root-5th-8ve-5th-3rd-5th-8ve-5th.
function brokenChordBar(target, barStart, secPerBeat, chord, voice, gain, perBar = 8) {
  const [, root, third, fifth] = chord;
  const pattern = [root, fifth, root + 12, fifth, third, fifth, root + 12, fifth];
  const step = (4 * secPerBeat) / perBar;
  for (let i = 0; i < perBar; i++) {
    addNote(target, barStart + i * step, 1.2, voice(midiFreq(pattern[i % pattern.length]), gain));
  }
}

function melodyBar(target, barStart, secPerBeat, notes, makeVoice) {
  for (const [beat, midi, dur] of notes) {
    const sec = dur * secPerBeat;
    addNote(target, barStart + beat * secPerBeat, sec + 0.5, makeVoice(midiFreq(midi), sec));
  }
}

// --- Tracks -----------------------------------------------------------------

function composeMenu() {
  const bpm = 100;
  const spb = 60 / bpm;
  const progression = ['C', 'Am', 'F', 'G', 'C', 'Am', 'F', 'G', 'F', 'G', 'Em', 'Am', 'F', 'G', 'C', 'C'];
  const melody = [
    [[0, 76, 1.5], [1.5, 79, 0.5], [2, 81, 1], [3, 79, 1]],
    [[0, 76, 1], [1, 74, 1], [2, 72, 2]],
    [[0, 72, 1], [1, 74, 1], [2, 76, 1], [3, 79, 1]],
    [[0, 74, 2], [2, 79, 2]],
    [[0, 76, 1.5], [1.5, 79, 0.5], [2, 84, 1], [3, 81, 1]],
    [[0, 81, 1], [1, 79, 1], [2, 76, 2]],
    [[0, 72, 1], [1, 76, 1], [2, 79, 1], [3, 76, 1]],
    [[0, 74, 2], [2, 72, 2]],
    [[0, 81, 1], [1, 84, 1], [2, 81, 1], [3, 79, 1]],
    [[0, 79, 1.5], [1.5, 81, 0.5], [2, 79, 1], [3, 74, 1]],
    [[0, 76, 1], [1, 79, 1], [2, 76, 1], [3, 74, 1]],
    [[0, 72, 1], [1, 76, 1], [2, 81, 2]],
    [[0, 84, 1], [1, 81, 1], [2, 79, 1], [3, 76, 1]],
    [[0, 79, 1], [1, 76, 1], [2, 74, 2]],
    [[0, 76, 1], [1, 74, 1], [2, 72, 2]],
    [[0, 67, 1], [1, 69, 1], [2, 72, 2]],
  ];
  const bars = progression.length;
  const x = new Float64Array(Math.round(bars * 4 * spb * RATE));

  for (let bar = 0; bar < bars; bar++) {
    const chord = CHORDS[progression[bar]];
    const start = bar * 4 * spb;
    brokenChordBar(x, start, spb, chord, marimba, 0.32);
    addNote(x, start, 2.5, bass(midiFreq(chord[0]), 0.55));
    addNote(x, start + 2 * spb, 2.5, bass(midiFreq(chord[0] + 7), 0.4));
    melodyBar(x, start, spb, melody[bar], (f, sec) => flute(f, sec, 0.7));
    addNote(x, start, 0.6, handDrum(false, 0.35));
    for (let beat = 0; beat < 4; beat++) addNote(x, start + (beat + 0.5) * spb, 0.12, shaker(0.1));
  }
  // Bird calls drifting in now and then, never in the same place twice.
  for (let bar = 0; bar < bars; bar += 2) {
    addBirdCall(x, (bar * 4 + 1 + rand() * 5) * spb, 0.11);
  }
  write('bgm_menu.wav', x, 0.8);
}

function composeGame() {
  const bpm = 132;
  const spb = 60 / bpm;
  const progression = ['C', 'G', 'Am', 'F', 'C', 'G', 'Am', 'F', 'F', 'G', 'C', 'Am', 'F', 'G', 'C', 'C'];
  const a = [
    [[0, 76, 0.5], [0.5, 79, 0.5], [1, 81, 0.5], [1.5, 79, 0.5], [2, 84, 0.5], [2.5, 81, 0.5], [3, 79, 0.5], [3.5, 76, 0.5]],
    [[0, 74, 0.5], [0.5, 79, 0.5], [1, 81, 0.5], [1.5, 79, 0.5], [2, 86, 1], [3, 79, 1]],
    [[0, 76, 0.5], [0.5, 81, 0.5], [1, 84, 0.5], [1.5, 81, 0.5], [2, 76, 0.5], [2.5, 79, 0.5], [3, 81, 1]],
    [[0, 72, 0.5], [0.5, 76, 0.5], [1, 79, 0.5], [1.5, 81, 0.5], [2, 79, 1], [3, 76, 1]],
  ];
  const melody = [
    ...a,
    a[0], a[1], a[2],
    [[0, 72, 0.5], [0.5, 74, 0.5], [1, 76, 0.5], [1.5, 79, 0.5], [2, 81, 1], [3, 79, 0.5], [3.5, 76, 0.5]],
    [[0, 84, 1], [1, 81, 0.5], [1.5, 79, 0.5], [2, 81, 1], [3, 84, 1]],
    [[0, 86, 1], [1, 84, 0.5], [1.5, 81, 0.5], [2, 79, 2]],
    [[0, 84, 0.5], [0.5, 81, 0.5], [1, 79, 0.5], [1.5, 76, 0.5], [2, 79, 1], [3, 84, 1]],
    [[0, 81, 1.5], [1.5, 79, 0.5], [2, 76, 2]],
    [[0, 72, 0.5], [0.5, 76, 0.5], [1, 79, 0.5], [1.5, 81, 0.5], [2, 84, 0.5], [2.5, 81, 0.5], [3, 79, 1]],
    [[0, 79, 0.5], [0.5, 81, 0.5], [1, 79, 0.5], [1.5, 74, 0.5], [2, 79, 1], [3, 86, 1]],
    [[0, 84, 1], [1, 79, 1], [2, 76, 1], [3, 74, 1]],
    [[0, 72, 2], [2, 79, 0.5], [2.5, 81, 0.5], [3, 79, 0.5], [3.5, 76, 0.5]],
  ];
  const bars = progression.length;
  const x = new Float64Array(Math.round(bars * 4 * spb * RATE));

  for (let bar = 0; bar < bars; bar++) {
    const chord = CHORDS[progression[bar]];
    const start = bar * 4 * spb;
    const bSection = bar >= 8;
    brokenChordBar(x, start, spb, chord, kalimba, 0.22, 16);
    addNote(x, start, 1.8, bass(midiFreq(chord[0]), 0.6));
    addNote(x, start + 1.5 * spb, 1.2, bass(midiFreq(chord[0]), 0.4));
    addNote(x, start + 2 * spb, 1.8, bass(midiFreq(chord[0] + 7), 0.5));
    melodyBar(x, start, spb, melody[bar], (f) => marimba(f, 0.85));
    // In the B section a flute doubles the tune an octave down, for lift.
    if (bSection) melodyBar(x, start, spb, melody[bar], (f, sec) => flute(f / 2, sec, 0.3));
    // Hand drums: low on 1 and 3, high on the offbeats.
    addNote(x, start, 0.5, handDrum(false, 0.5));
    addNote(x, start + 2 * spb, 0.5, handDrum(false, 0.42));
    for (const off of [0.5, 1.5, 2.5, 3.25, 3.5]) addNote(x, start + off * spb, 0.3, handDrum(true, 0.28));
    for (let s = 0; s < 8; s++) addNote(x, start + (s + 0.5) * 0.5 * spb, 0.1, shaker(s % 2 ? 0.12 : 0.07));
  }
  for (let bar = 1; bar < bars; bar += 4) addBirdCall(x, (bar * 4 + rand() * 6) * spb, 0.07);
  write('bgm_game.wav', x, 0.8);
}

composeMenu();
composeGame();
