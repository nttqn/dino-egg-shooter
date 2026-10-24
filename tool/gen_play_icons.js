// Builds the 512x512 Play Games leaderboard and achievement icons from the
// game's own art (menu backdrop, egg sprites, dinosaur portraits).
//   node tool/gen_play_icons.js <path-to-sharp-module> <out-dir>
// Everything important sits inside the central circle, since Play Games may
// crop icons round.
const path = require('path');
const fs = require('fs');
const sharp = require(process.argv[2] || 'sharp');
const OUT = process.argv[3] || path.join(__dirname, '..', 'build', 'play_icons');
const IMG = path.join(__dirname, '..', 'assets', 'images');
const S = 512;
fs.mkdirSync(OUT, { recursive: true });

const img = (name) => path.join(IMG, name);

async function art(name, size) {
  return sharp(img(name)).resize({ width: size, height: size, fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }).toBuffer();
}

function medallionSvg(color, glow) {
  return Buffer.from(`<svg width="${S}" height="${S}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="g" cx="50%" cy="42%" r="60%">
      <stop offset="0%" stop-color="${glow}"/>
      <stop offset="100%" stop-color="${color}"/>
    </radialGradient>
  </defs>
  ${Array.from({ length: 16 }, (_, i) => {
    const a = (i / 16) * Math.PI * 2;
    const x = 256 + Math.cos(a) * 250, y = 256 + Math.sin(a) * 250;
    const x2 = 256 + Math.cos(a + 0.09) * 250, y2 = 256 + Math.sin(a + 0.09) * 250;
    return `<polygon points="256,256 ${x},${y} ${x2},${y2}" fill="#FFE082" opacity="0.18"/>`;
  }).join('')}
  <circle cx="256" cy="256" r="212" fill="#3E2723"/>
  <circle cx="256" cy="256" r="200" fill="url(#g)"/>
  <circle cx="256" cy="256" r="200" fill="none" stroke="#FFD54F" stroke-width="10"/>
  <circle cx="256" cy="256" r="186" fill="none" stroke="#FFF8E1" stroke-width="2" opacity="0.5"/>
</svg>`);
}

function labelSvg(text, { y = 420, size = 76 } = {}) {
  return Buffer.from(`<svg width="${S}" height="${S}" xmlns="http://www.w3.org/2000/svg">
  <text x="256" y="${y}" text-anchor="middle" font-family="Arial Black, Arial, sans-serif" font-weight="900"
        font-size="${size}" fill="#FFFFFF" stroke="#3E2723" stroke-width="12" paint-order="stroke"
        stroke-linejoin="round">${text}</text>
</svg>`);
}

function stopwatchSvg(cx, cy, r) {
  return Buffer.from(`<svg width="${S}" height="${S}" xmlns="http://www.w3.org/2000/svg">
  <rect x="${cx - r * 0.18}" y="${cy - r * 1.32}" width="${r * 0.36}" height="${r * 0.28}" rx="6" fill="#ECEFF1" stroke="#3E2723" stroke-width="8"/>
  <circle cx="${cx}" cy="${cy}" r="${r}" fill="#FAFAFA" stroke="#3E2723" stroke-width="12"/>
  <circle cx="${cx}" cy="${cy}" r="${r * 0.82}" fill="none" stroke="#B0BEC5" stroke-width="4"/>
  <path d="M ${cx} ${cy} L ${cx} ${cy - r * 0.82} A ${r * 0.82} ${r * 0.82} 0 0 1 ${cx + r * 0.82} ${cy} Z" fill="#EF5350" opacity="0.85"/>
  <line x1="${cx}" y1="${cy}" x2="${cx + r * 0.5}" y2="${cy - r * 0.45}" stroke="#3E2723" stroke-width="12" stroke-linecap="round"/>
  <circle cx="${cx}" cy="${cy}" r="12" fill="#3E2723"/>
</svg>`);
}

function infinitySvg() {
  return Buffer.from(`<svg width="${S}" height="${S}" xmlns="http://www.w3.org/2000/svg">
  <path d="M 256 300 C 210 250, 140 250, 140 300 C 140 350, 210 350, 256 300 C 302 250, 372 250, 372 300 C 372 350, 302 350, 256 300 Z"
        fill="none" stroke="#3E2723" stroke-width="34" stroke-linecap="round"/>
  <path d="M 256 300 C 210 250, 140 250, 140 300 C 140 350, 210 350, 256 300 C 302 250, 372 250, 372 300 C 372 350, 302 350, 256 300 Z"
        fill="none" stroke="#FFD54F" stroke-width="18" stroke-linecap="round"/>
</svg>`);
}

function sparklesSvg() {
  const star = (x, y, s) => `<path d="M ${x} ${y - s} L ${x + s * 0.3} ${y - s * 0.3} L ${x + s} ${y} L ${x + s * 0.3} ${y + s * 0.3} L ${x} ${y + s} L ${x - s * 0.3} ${y + s * 0.3} L ${x - s} ${y} L ${x - s * 0.3} ${y - s * 0.3} Z" fill="#FFFDE7"/>`;
  return Buffer.from(`<svg width="${S}" height="${S}" xmlns="http://www.w3.org/2000/svg">${star(150, 150, 26)}${star(372, 170, 20)}${star(380, 330, 16)}${star(130, 330, 14)}</svg>`);
}

let backdrop;
async function base(color, glow) {
  backdrop ??= await sharp(img('menu_bg.png')).resize(S, S, { fit: 'cover', position: 'centre' }).modulate({ brightness: 0.55 }).png().toBuffer();
  return [{ input: backdrop }, { input: medallionSvg(color, glow) }];
}

async function make(name, color, glow, layers) {
  const comps = [...(await base(color, glow)), ...layers];
  await sharp({ create: { width: S, height: S, channels: 3, background: '#1B3A24' } })
    .composite(comps)
    .flatten({ background: '#1B3A24' })
    .removeAlpha()
    .png({ compressionLevel: 9 })
    .toFile(path.join(OUT, `${name}.png`));
  console.log(name);
}

const at = async (file, size, left, top) => ({ input: await art(file, size), left, top });

(async () => {
  // Leaderboards
  await make('lb-1-diem-cao-normal', '#1565C0', '#64B5F6', [
    await at('egg_red.png', 150, 105, 150), await at('egg_yellow.png', 150, 257, 150), await at('egg_blue.png', 150, 181, 70),
    { input: labelSvg('NORMAL', { y: 405, size: 64 }) },
  ]);
  await make('lb-2-diem-cao-endless', '#6A1B9A', '#BA68C8', [
    await at('egg_purple.png', 170, 171, 85),
    { input: infinitySvg() },
    { input: labelSvg('ENDLESS', { y: 425, size: 58 }) },
  ]);
  await make('lb-3-diem-cao-time-trial', '#C62828', '#EF9A9A', [
    { input: stopwatchSvg(256, 230, 110) },
    { input: labelSvg('3:00', { y: 425, size: 72 }) },
  ]);
  await make('lb-4-khung-long-da-ap', '#2E7D32', '#81C784', [
    await at('dino_triceratops.png', 190, 70, 120), await at('dino_stegosaurus.png', 190, 252, 120), await at('dino_trex.png', 210, 151, 70),
  ]);

  // Achievements
  await make('ach-01-qua-trung-dau-tien', '#F9A825', '#FFF59D', [
    { input: sparklesSvg() }, await at('egg_yellow.png', 120, 196, 300), await at('dino_trex.png', 250, 131, 70),
  ]);
  await make('ach-02-vuon-khung-long-day-du', '#2E7D32', '#A5D6A7', [
    await at('dino_brachiosaurus.png', 150, 80, 90), await at('dino_pteranodon.png', 150, 282, 90),
    await at('dino_triceratops.png', 150, 90, 250), await at('dino_stegosaurus.png', 150, 272, 250),
    await at('dino_trex.png', 170, 171, 165),
  ]);
  await make('ach-03-nguoi-ap-trung', '#EF6C00', '#FFCC80', [
    { input: sparklesSvg() }, await at('egg_green.png', 230, 141, 90), { input: labelSvg('25') },
  ]);
  await make('ach-04-dong-doi-an-y', '#00838F', '#80DEEA', [
    { input: sparklesSvg() }, await at('dino_stegosaurus.png', 280, 116, 100),
  ]);
  await make('ach-05-bac-thay-ky-nang', '#283593', '#9FA8DA', [
    { input: sparklesSvg() }, await at('dino_triceratops.png', 250, 131, 80), { input: labelSvg('50') },
  ]);
  await make('ach-06-nghin-qua-trung', '#AD1457', '#F48FB1', [
    await at('egg_red.png', 120, 110, 110), await at('egg_blue.png', 120, 282, 110), await at('egg_yellow.png', 150, 181, 175),
    { input: labelSvg('1000', { size: 80 }) },
  ]);
  await make('ach-07-cu-ban-de-doi', '#D84315', '#FFAB91', [
    { input: sparklesSvg() },
    await at('egg_green.png', 100, 140, 120), await at('egg_green.png', 100, 206, 100), await at('egg_green.png', 100, 272, 120),
    await at('egg_green.png', 100, 173, 195), await at('egg_green.png', 100, 239, 195),
    { input: labelSvg('x15') },
  ]);
  await make('ach-08-vuot-man-5', '#558B2F', '#C5E1A5', [
    await at('dino_brachiosaurus.png', 250, 131, 70), { input: labelSvg('MÀN 5', { size: 66 }) },
  ]);
  await make('ach-09-vuot-man-10', '#4527A0', '#B39DDB', [
    await at('dino_pteranodon.png', 260, 126, 75), { input: labelSvg('MÀN 10', { size: 62 }) },
  ]);
  await make('ach-10-tay-sung-than-toc', '#B71C1C', '#FFCDD2', [
    { input: stopwatchSvg(205, 225, 95) }, await at('dino_pteranodon.png', 170, 250, 160), { input: labelSvg('3000', { size: 80 }) },
  ]);
})();
