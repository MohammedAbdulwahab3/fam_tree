const pptxgen = require('pptxgenjs');
const fs = require('fs');

const tree = JSON.parse(fs.readFileSync('tree.json', 'utf8'));

// ---------------------------------------------------------------- palette
// Evergreen: the family tree's own identity, and the same green the app uses.
const C = {
  deep: '0A5B43',
  green: '0F7A5A',
  light: '3FBF92',
  gold: 'C9A227',
  ground: 'FFFFFF',
  tint: 'F1F6F3',
  tintWarm: 'FBF7EC',
  ink: '14201B',
  inkSoft: '3E4F47',
  muted: '6E7F76',
  hair: 'DDE6E1',
  night: '0B1512',
};

// Generation colours — one family of greens deepening to gold, so a dot tells
// you which generation a name belongs to on any slide.
const GEN = ['0A5B43', '0F7A5A', '2E9B76', '3FBF92', '8FB43F', 'C9A227'];

const HEAD = 'Cambria';
const BODY = 'Calibri';

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.3 x 7.5
pres.author = 'Mammaduu Family Tree';
pres.title = 'The Mammaduu Family';

const W = 13.3, H = 7.5, M = 0.62;

// ---------------------------------------------------------------- helpers
// The recorded data is inconsistently cased — "Eliyas seid", "zikera
// Abduljebar", "batool feysel". Names are title-cased for display only; the
// record itself is untouched.
const tc = (w) =>
  w.replace(/[A-Za-z\u00C0-\u024F]+/g, (part) =>
    /[a-z][A-Z]/.test(part) ? part : part.charAt(0).toUpperCase() + part.slice(1)
  );
const full = (p) => `${tc(p.first)} ${tc(p.last)}`;
const firstOf = (p) => tc(p.first);
const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;

function descendants(node) {
  return node.children.reduce((n, c) => n + 1 + descendants(c), 0);
}
function byGeneration() {
  const out = {};
  (function walk(ns, d) {
    ns.forEach((x) => {
      (out[d] = out[d] || []).push(x);
      walk(x.children, d + 1);
    });
  })(tree, 1);
  return out;
}
const gens = byGeneration();
const TOTAL = Object.values(gens).reduce((a, b) => a + b.length, 0);

const root = tree[0];
const sons = root.children;
const osman = sons.find((s) => s.first === 'Osman');
const muzeyen = osman.children.find((c) => c.first === 'Muzeyen');
const kid = (parent, first) => parent.children.find((c) => c.first === first);

// Dark slide ground.
function darkSlide() {
  const s = pres.addSlide();
  s.background = { color: C.night };
  return s;
}

// Light slide with a title and an optional standfirst.
function contentSlide(title, kicker, standfirst) {
  const s = pres.addSlide();
  s.background = { color: C.ground };

  if (kicker) {
    s.addText(kicker.toUpperCase(), {
      x: M, y: 0.42, w: 9, h: 0.26,
      fontFace: BODY, fontSize: 11, bold: true, color: C.gold,
      charSpacing: 2.2, margin: 0,
    });
  }
  s.addText(title, {
    x: M, y: kicker ? 0.72 : 0.52, w: W - M * 2, h: 0.62,
    fontFace: HEAD, fontSize: 30, bold: true, color: C.deep, margin: 0,
  });
  if (standfirst) {
    s.addText(standfirst, {
      x: M, y: kicker ? 1.34 : 1.14, w: W - M * 2 - 0.4, h: 0.42,
      fontFace: BODY, fontSize: 13.5, color: C.muted, margin: 0,
    });
  }
  return s;
}

// The repeated motif: a name on a soft card with a generation dot.
function nameCard(s, o) {
  const { x, y, w, h, name, sub, gen, emphasis } = o;
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h,
    rectRadius: 0.09,
    fill: { color: emphasis ? C.tintWarm : C.tint },
    line: { color: emphasis ? C.gold : C.hair, width: emphasis ? 1.1 : 0.75 },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: x + 0.15, y: y + h / 2 - 0.055, w: 0.11, h: 0.11,
    fill: { color: GEN[(gen - 1) % GEN.length] },
    line: { color: GEN[(gen - 1) % GEN.length], width: 0.4 },
  });
  // Name in the upper band, sub in the lower one, with a hard gap between —
  // they used to be given overlapping boxes and collided whenever a name ran
  // to two lines.
  const nameH = sub ? h * 0.56 : h;
  s.addText(name, {
    x: x + 0.34, y: y + (sub ? 0.03 : 0), w: w - 0.46, h: nameH,
    fontFace: BODY, fontSize: o.size || 11.5, bold: true, color: C.ink,
    margin: 0, valign: 'middle', shrinkText: true,
  });
  if (sub) {
    s.addText(sub, {
      x: x + 0.34, y: y + nameH + 0.02, w: w - 0.46, h: h - nameH - 0.05,
      fontFace: BODY, fontSize: 8.6, color: C.muted, margin: 0, valign: 'top',
    });
  }
}

// A grid of name cards that fits `people` into the given box.
function cardGrid(s, people, o) {
  const { x, y, w, cols, ch, gap, subFn, emphasisFn, sizeFn } = o;
  const cw = (w - gap * (cols - 1)) / cols;
  people.forEach((p, i) => {
    const c = i % cols, r = Math.floor(i / cols);
    nameCard(s, {
      x: x + c * (cw + gap),
      y: y + r * (ch + gap),
      w: cw, h: ch,
      name: typeof p === 'string' ? p : full(p),
      sub: subFn ? subFn(p) : null,
      gen: o.gen,
      emphasis: emphasisFn ? emphasisFn(p) : false,
      size: sizeFn ? sizeFn(p) : o.size,
    });
  });
  const rows = Math.ceil(people.length / cols);
  return y + rows * (ch + gap) - gap;
}

// A household: one parent heading with their children listed beneath it.
// Rows a household's child list needs at the given column count.
function householdHeight(parent, cols, fs) {
  const rows = Math.ceil(parent.children.length / cols);
  return 0.52 + rows * (fs === 'sm' ? 0.175 : 0.2) + 0.12;
}

function household(s, o) {
  const { x, y, w, parent, gen, childCols } = o;
  const cols = childCols || 2;
  const fs = o.small ? 8.8 : 10;
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h: o.h,
    rectRadius: 0.1,
    fill: { color: 'FFFFFF' },
    line: { color: C.hair, width: 0.9 },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: x + 0.18, y: y + 0.245, w: 0.12, h: 0.12,
    fill: { color: GEN[(gen - 1) % GEN.length] },
    line: { color: GEN[(gen - 1) % GEN.length], width: 0.4 },
  });
  // The count sits in its own reserved column so a long parent name cannot
  // run underneath it.
  const showCount = w >= 2.7;
  const countW = showCount ? 0.95 : 0;
  s.addText(full(parent), {
    x: x + 0.38, y: y + 0.1, w: w - 0.5 - countW, h: 0.34,
    fontFace: BODY, fontSize: o.small ? 11 : 12, bold: true, color: C.deep,
    margin: 0, valign: 'middle', shrinkText: true,
  });
  if (showCount) {
    s.addText(
      parent.children.length ? plural(parent.children.length, 'child', 'children') : '—',
      {
        x: x + w - countW - 0.18, y: y + 0.1, w: countW, h: 0.34,
        fontFace: BODY, fontSize: 8.6, color: C.muted,
        align: 'right', margin: 0, valign: 'middle',
      }
    );
  }

  const names = parent.children.map(full);
  const per = Math.ceil(names.length / cols);
  for (let c = 0; c < cols; c++) {
    const slice = names.slice(c * per, (c + 1) * per);
    if (!slice.length) continue;
    s.addText(
      slice.map((n, i) => ({
        text: n,
        options: { breakLine: i < slice.length - 1 },
      })),
      {
        x: x + 0.38 + c * ((w - 0.56) / cols),
        y: y + 0.48,
        w: (w - 0.56) / cols - 0.08,
        h: o.h - 0.56,
        fontFace: BODY, fontSize: fs, color: C.inkSoft,
        lineSpacingMultiple: 1.14, margin: 0, valign: 'top',
      }
    );
  }
}

function statTile(s, o) {
  s.addText(o.value, {
    x: o.x, y: o.y, w: o.w, h: 0.72,
    fontFace: HEAD, fontSize: 44, bold: true, color: o.color || C.light,
    margin: 0, align: 'left',
  });
  s.addText(o.label, {
    x: o.x, y: o.y + 0.68, w: o.w, h: 0.5,
    fontFace: BODY, fontSize: 11, color: o.labelColor || 'A9BDB3',
    margin: 0, align: 'left',
  });
}

// A closing note, for slides whose content ends high up the page.
function noteStrip(s, y, heading, text, warm) {
  s.addShape(pres.ShapeType.roundRect, {
    x: M, y, w: W - M * 2, h: 1.02,
    rectRadius: 0.1,
    fill: { color: warm ? C.tintWarm : C.tint },
    line: { color: warm ? C.gold : C.hair, width: warm ? 1 : 0.8 },
  });
  s.addText(heading, {
    x: M + 0.3, y: y + 0.14, w: W - M * 2 - 0.6, h: 0.28,
    fontFace: BODY, fontSize: 11.5, bold: true, color: C.deep, margin: 0,
  });
  s.addText(text, {
    x: M + 0.3, y: y + 0.45, w: W - M * 2 - 0.6, h: 0.46,
    fontFace: BODY, fontSize: 10.8, color: C.inkSoft,
    lineSpacingMultiple: 1.2, margin: 0,
  });
}

function footer(s, text) {
  s.addText(text, {
    x: M, y: H - 0.46, w: W - M * 2, h: 0.26,
    fontFace: BODY, fontSize: 8.6, color: C.muted, margin: 0,
  });
}

// ================================================================ 1. Title
{
  const s = darkSlide();
  s.addShape(pres.ShapeType.ellipse, {
    x: 9.5, y: -1.7, w: 5.6, h: 5.6,
    fill: { color: C.deep, transparency: 45 }, line: { color: C.deep, width: 0 },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: 10.9, y: 3.6, w: 3.4, h: 3.4,
    fill: { color: C.green, transparency: 62 }, line: { color: C.green, width: 0 },
  });

  s.addText('A FAMILY RECORD', {
    x: M + 0.1, y: 1.62, w: 6, h: 0.3,
    fontFace: BODY, fontSize: 12, bold: true, color: C.gold,
    charSpacing: 3, margin: 0,
  });
  s.addText('The Mammaduu Family', {
    x: M + 0.1, y: 2.02, w: 10.4, h: 1.1,
    fontFace: HEAD, fontSize: 50, bold: true, color: 'FFFFFF',
    margin: 0, valign: 'middle',
  });
  s.addText(
    'Every name in the tree, and exactly where it sits — from Mammaduu ' +
      'to the youngest generation recorded.',
    {
      x: M + 0.1, y: 3.26, w: 7.4, h: 0.9,
      fontFace: BODY, fontSize: 15, color: 'B9CCC2',
      lineSpacingMultiple: 1.25, margin: 0,
    }
  );

  statTile(s, { x: M + 0.1, y: 4.72, w: 2.2, value: String(TOTAL), label: 'people recorded' });
  statTile(s, { x: 3.1, y: 4.72, w: 2.2, value: '6', label: 'generations' });
  statTile(s, { x: 5.5, y: 4.72, w: 2.4, value: String(sons.length), label: 'sons of Mammaduu' });

  s.addNotes(
    `The whole tree as it stands: ${TOTAL} people across six generations, ` +
      `descending from Mammaduu through his ${sons.length} sons.`
  );
}

// ================================================================ 2. At a glance
{
  const s = contentSlide(
    'How the family grew',
    'At a glance',
    'Each generation is larger than the one before it. The fifth is the widest recorded.'
  );

  const rows = [1, 2, 3, 4, 5, 6].map((g) => ({ g, n: gens[g].length }));
  const max = Math.max(...rows.map((r) => r.n));
  const romans = ['I', 'II', 'III', 'IV', 'V', 'VI'];

  const bx = M, by = 2.06, bw = 7.3, rh = 0.56;
  rows.forEach((r, i) => {
    const y = by + i * rh;
    s.addText(romans[i], {
      x: bx, y, w: 0.5, h: 0.4,
      fontFace: HEAD, fontSize: 14, bold: true, color: C.muted,
      align: 'right', margin: 0, valign: 'middle',
    });
    const barW = Math.max(0.16, (r.n / max) * (bw - 1.5));
    s.addShape(pres.ShapeType.roundRect, {
      x: bx + 0.68, y: y + 0.07, w: barW, h: 0.27,
      rectRadius: 0.06,
      fill: { color: GEN[i] }, line: { color: GEN[i], width: 0 },
    });
    s.addText(String(r.n), {
      x: bx + 0.68 + barW + 0.12, y, w: 0.7, h: 0.4,
      fontFace: BODY, fontSize: 11.5, bold: true, color: C.inkSoft,
      margin: 0, valign: 'middle',
    });
  });

  s.addText('Generation', {
    x: bx, y: by - 0.32, w: 2, h: 0.26,
    fontFace: BODY, fontSize: 9, bold: true, color: C.muted,
    charSpacing: 1.4, margin: 0,
  });

  // The three households that carry most of the family.
  const bigs = [
    { p: muzeyen, note: 'the largest single household in the tree' },
    { p: kid(muzeyen, 'Almaz'), note: 'thirteen children, two with families of their own' },
    { p: kid(muzeyen, 'Seid'), note: 'ten children and thirty-two grandchildren' },
  ];
  s.addText('WHERE THE FAMILY IS WIDEST', {
    x: 8.35, y: 1.74, w: 4.4, h: 0.28,
    fontFace: BODY, fontSize: 10, bold: true, color: C.gold,
    charSpacing: 1.8, margin: 0,
  });
  bigs.forEach((b, i) => {
    const y = 2.14 + i * 1.34;
    s.addShape(pres.ShapeType.roundRect, {
      x: 8.35, y, w: 4.33, h: 1.16,
      rectRadius: 0.1,
      fill: { color: C.tint }, line: { color: C.hair, width: 0.8 },
    });
    s.addText(full(b.p), {
      x: 8.6, y: y + 0.13, w: 2.7, h: 0.32,
      fontFace: BODY, fontSize: 12.5, bold: true, color: C.deep, margin: 0,
    });
    s.addText(`${b.p.children.length}`, {
      x: 11.3, y: y + 0.1, w: 1.15, h: 0.42,
      fontFace: HEAD, fontSize: 22, bold: true, color: C.light,
      align: 'right', margin: 0,
    });
    s.addText(b.note, {
      x: 8.6, y: y + 0.5, w: 3.85, h: 0.56,
      fontFace: BODY, fontSize: 9.8, color: C.muted,
      lineSpacingMultiple: 1.15, margin: 0,
    });
  });

  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 5.5, w: 7.3, h: 1.32,
    rectRadius: 0.1,
    fill: { color: C.tint }, line: { color: C.hair, width: 0.8 },
  });
  s.addText('Reading the shape', {
    x: M + 0.3, y: 5.66, w: 6.7, h: 0.3,
    fontFace: BODY, fontSize: 11.5, bold: true, color: C.deep, margin: 0,
  });
  s.addText(
    'Generation VI is smaller than V not because the family shrank, but ' +
      'because it is the edge of what has been written down. Its children are ' +
      'simply not in the record yet.',
    {
      x: M + 0.3, y: 5.99, w: 6.7, h: 0.72,
      fontFace: BODY, fontSize: 10.8, color: C.inkSoft,
      lineSpacingMultiple: 1.2, margin: 0,
    }
  );

  footer(s, `${TOTAL} people · ${gens[6].length} in the youngest generation recorded`);
  s.addNotes(
    'Generation V is the widest at 82 people. The three households listed on the ' +
      'right account for a large share of the whole tree.'
  );
}

// ================================================================ 3. The seven sons
{
  const s = contentSlide(
    'Mammaduu and his seven sons',
    'Generation I and II',
    'Everyone in this deck descends from one of these seven. Three of them have no recorded children.'
  );

  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 2.0, w: 3.5, h: 1.0,
    rectRadius: 0.1,
    fill: { color: C.deep }, line: { color: C.deep, width: 0 },
  });
  s.addText('Mammaduu', {
    x: M + 0.28, y: 2.14, w: 3, h: 0.38,
    fontFace: HEAD, fontSize: 20, bold: true, color: 'FFFFFF', margin: 0,
  });
  s.addText(`${TOTAL - 1} descendants recorded`, {
    x: M + 0.28, y: 2.55, w: 3, h: 0.3,
    fontFace: BODY, fontSize: 10, color: '9FC0B2', margin: 0,
  });

  const withKids = sons.filter((x) => x.children.length);
  const without = sons.filter((x) => !x.children.length);

  withKids.forEach((son, i) => {
    const y = 2.0 + i * 0.86;
    s.addShape(pres.ShapeType.roundRect, {
      x: 4.55, y, w: 8.15, h: 0.72,
      rectRadius: 0.1,
      fill: { color: son.first === 'Osman' ? C.tintWarm : C.tint },
      line: { color: son.first === 'Osman' ? C.gold : C.hair, width: son.first === 'Osman' ? 1.1 : 0.8 },
    });
    s.addText(full(son), {
      x: 4.82, y: y + 0.055, w: 3.3, h: 0.32,
      fontFace: BODY, fontSize: 13, bold: true, color: C.ink, margin: 0,
    });
    // First names only in this preview: the card header already names the
    // father, and the full names would run past the card on Osman's row.
    s.addText(son.children.map(firstOf).join(' · '), {
      x: 4.82, y: y + 0.37, w: 6.4, h: 0.28,
      fontFace: BODY, fontSize: 9.2, color: C.muted,
      margin: 0, valign: 'middle', shrinkText: true,
    });
    s.addText(`${descendants(son)}`, {
      x: 11.45, y: y + 0.08, w: 1.0, h: 0.5,
      fontFace: HEAD, fontSize: 21, bold: true, color: C.green,
      align: 'right', margin: 0, valign: 'middle',
    });
  });

  s.addText(
    `No children recorded: ${without.map(full).join(', ')}.`,
    {
      x: 4.55, y: 5.68, w: 8.15, h: 0.34,
      fontFace: BODY, fontSize: 10.5, italic: true, color: C.muted, margin: 0,
    }
  );
  s.addText('descendants', {
    x: 11.05, y: 1.72, w: 1.6, h: 0.26,
    fontFace: BODY, fontSize: 8.5, color: C.muted, align: 'right', margin: 0,
  });

  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 3.14, w: 3.5, h: 1.62,
    rectRadius: 0.1,
    fill: { color: C.tint }, line: { color: C.hair, width: 0.8 },
  });
  s.addText(
    'Four of the seven have descendants in the record. Osman\'s line alone ' +
      'accounts for ' +
      Math.round((descendants(osman) / (TOTAL - 1)) * 100) +
      '% of everyone below Mammaduu.',
    {
      x: M + 0.28, y: 3.34, w: 2.98, h: 1.24,
      fontFace: BODY, fontSize: 11, color: C.inkSoft,
      lineSpacingMultiple: 1.22, margin: 0,
    }
  );
  footer(s, 'Children shown by first name; every full name is in the index at the end.');
  s.addNotes(
    'Osman is the branch that grew. Of the 204 descendants, the overwhelming ' +
      'majority sit under him — chiefly through his son Muzeyen.'
  );
}

// ================================================================ 4. Issa's line
{
  const issa = sons.find((x) => x.first === 'Issa');
  const s = contentSlide(
    `Issa's household`,
    'Branch one of seven · Generation III',
    'The eldest branch: five children, none with recorded families of their own.'
  );
  cardGrid(s, issa.children, {
    x: M, y: 2.25, w: W - M * 2, cols: 5, ch: 0.86, gap: 0.2, gen: 3, size: 12.5,
    subFn: () => 'child of Issa',
  });

  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 3.66, w: W - M * 2, h: 1.05,
    rectRadius: 0.1,
    fill: { color: C.tintWarm }, line: { color: C.hair, width: 0.8 },
  });
  s.addText(
    'These five are where this branch of the record currently ends. If any of ' +
      'them have children or grandchildren, that is the first gap worth filling.',
    {
      x: M + 0.3, y: 3.86, w: W - M * 2 - 0.6, h: 0.66,
      fontFace: BODY, fontSize: 12, color: C.inkSoft,
      lineSpacingMultiple: 1.22, margin: 0,
    }
  );
  footer(s, 'Issa Mammaduu · son of Mammaduu · 5 recorded descendants');
}

// ================================================================ 5. Osman's line
{
  const s = contentSlide(
    `Osman's seven children`,
    'The main branch · Generation III',
    'Osman carries most of the family. Three of his children have descendants of their own.'
  );

  cardGrid(s, osman.children, {
    x: M, y: 2.2, w: W - M * 2, cols: 4, ch: 1.0, gap: 0.22, gen: 3, size: 13,
    subFn: (p) =>
      p.children.length
        ? `${p.children.length} children · ${descendants(p)} descendants`
        : 'no children recorded',
    emphasisFn: (p) => p.children.length > 0,
  });

  noteStrip(
    s, 4.9,
    'What follows',
    'Muzeyen, Mohammed and Mustefa each get a slide of their own. Muzeyen ' +
      'alone accounts for more of the tree than every other branch combined — ' +
      'his twenty-three children are the next slide.'
  );
  footer(s, 'Osman Mammaduu · son of Mammaduu');
}

// ================================================================ 6. Muzeyen's 23
{
  const s = contentSlide(
    `Muzeyen's twenty-three children`,
    'Generation IV · the largest household',
    'The widest single family in the record. Twelve of the twenty-three have children of their own.'
  );

  cardGrid(s, muzeyen.children, {
    x: M, y: 2.0, w: W - M * 2, cols: 6, ch: 0.86, gap: 0.15, gen: 5, size: 10.4,
    subFn: (p) => (p.children.length ? plural(p.children.length, 'child', 'children') : '—'),
    emphasisFn: (p) => p.children.length >= 5,
  });

  const openable = muzeyen.children.filter((c) => c.children.length >= 5);
  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 6.0, w: W - M * 2, h: 0.82,
    rectRadius: 0.1,
    fill: { color: C.tintWarm }, line: { color: C.gold, width: 1 },
  });
  s.addText(
    `Opened on the slides that follow: ${openable.map(firstOf).join(', ')} — ` +
      `the five households of five children or more.`,
    {
      x: M + 0.3, y: 6.16, w: W - M * 2 - 0.6, h: 0.5,
      fontFace: BODY, fontSize: 11.5, color: C.inkSoft, margin: 0, valign: 'middle',
    }
  );

  footer(
    s,
    `Muzeyen Osman · ${descendants(muzeyen)} descendants · highlighted households have five or more children`
  );
  s.addNotes(
    'Twenty-three children. The highlighted ones — Oumer, Seid, Almaz, Nuru, ' +
      'Mohammed — are the households opened on the following slides.'
  );
}

// ================================================================ 7. Oumer's eight
{
  const oumer = kid(muzeyen, 'Oumer');
  const s = contentSlide(
    `Oumer's eight`,
    'Generation V · son of Muzeyen',
    'Eight children, recorded as the youngest generation in this part of the tree.'
  );
  cardGrid(s, oumer.children, {
    x: M, y: 2.3, w: W - M * 2, cols: 4, ch: 1.05, gap: 0.24, gen: 5, size: 13.5,
    subFn: () => 'child of Oumer Muzeyen',
  });
  noteStrip(
    s, 4.9,
    'Where this sits',
    'Oumer is the eldest of Muzeyen\'s twenty-three. His eight are recorded ' +
      'with no children of their own yet — which makes this branch four ' +
      'generations deep, against six elsewhere in the family.'
  );
  footer(s, 'Oumer Muzeyen · son of Muzeyen Osman · son of Osman Mammaduu');
}

// ================================================================ 8. Seid's ten
{
  const seid = kid(muzeyen, 'Seid');
  const s = contentSlide(
    `Seid's ten children`,
    'Generation V · son of Muzeyen',
    'Nine of the ten have families of their own — thirty-two grandchildren in all.'
  );
  cardGrid(s, seid.children, {
    x: M, y: 2.15, w: W - M * 2, cols: 5, ch: 0.98, gap: 0.2, gen: 5, size: 12.5,
    subFn: (p) => (p.children.length ? `${p.children.length} children` : 'no children recorded'),
    emphasisFn: (p) => p.children.length >= 4,
  });
  noteStrip(
    s, 4.5,
    'The generation below',
    'The next two slides open each of these households in turn. Only Yusuf ' +
      'Seid is recorded without children of his own — with 42 people under ' +
      'him, Seid\'s is the deepest branch in the family.'
  );
  footer(s, `Seid Muzeyen · ${descendants(seid)} descendants`);
}

// ================================================================ 9/10. Seid's grandchildren
{
  const seid = kid(muzeyen, 'Seid');
  const withKids = seid.children.filter((c) => c.children.length);
  const halves = [withKids.slice(0, 5), withKids.slice(5)];

  halves.forEach((group, gi) => {
    const s = contentSlide(
      gi === 0 ? `Seid's grandchildren` : `Seid's grandchildren, continued`,
      'Generation VI · children of Seid\'s children',
      gi === 0
        ? 'Each card is one household: the parent, then their children.'
        : 'The remaining households in Seid\'s line.'
    );
    const cols = 3;
    const gw = (W - M * 2 - 0.24 * (cols - 1)) / cols;
    const rowH = [0, 0];
    group.forEach((p, i) => {
      const c = i % cols, r = Math.floor(i / cols);
      const cc = p.children.length > 4 ? 2 : 1;
      rowH[r] = Math.max(rowH[r], householdHeight(p, cc));
    });
    group.forEach((p, i) => {
      const c = i % cols, r = Math.floor(i / cols);
      const cc = p.children.length > 4 ? 2 : 1;
      household(s, {
        x: M + c * (gw + 0.24),
        y: 2.16 + (r === 1 ? rowH[0] + 0.3 : 0),
        w: gw, h: rowH[r],
        parent: p, gen: 5, childCols: cc,
      });
    });
    if (gi === 0) {
      noteStrip(
        s, 5.72,
        'A note on the surnames',
        'A child takes their father\'s first name as their surname — so ' +
          'Eliyas Seid\'s children are Elias, and Yunus Seid\'s are Yunus. ' +
          'Where a mother is the one recorded, the surname is her husband\'s.'
      );
    } else {
      const gk = seid.children.reduce((n, c) => n + c.children.length, 0);
      noteStrip(
        s, 5.72,
        'Seid\'s line in full',
        `Ten children and ${gk} grandchildren — ${descendants(seid)} people in ` +
          `all, which is more than any other household in the tree. Only ` +
          `Yusuf Seid is recorded without children of his own.`,
        true
      );
    }
    footer(s, 'Seid Muzeyen · son of Muzeyen Osman');
  });
}

// ================================================================ 11. Almaz
{
  const almaz = kid(muzeyen, 'Almaz');
  const s = contentSlide(
    `Almaz's thirteen`,
    'Generation V · daughter of Muzeyen',
    'The largest family among Muzeyen\'s daughters. Two of the thirteen have children of their own.'
  );

  cardGrid(s, almaz.children, {
    x: M, y: 2.02, w: W - M * 2, cols: 5, ch: 0.8, gap: 0.16, gen: 6, size: 11,
    subFn: (p) => (p.children.length ? plural(p.children.length, 'child', 'children') : '—'),
    emphasisFn: (p) => p.children.length > 0,
  });

  const carriers = almaz.children.filter((c) => c.children.length);
  const gw = (W - M * 2 - 0.3) / 2;
  const ch = Math.max(...carriers.map((p) => householdHeight(p, 1)));
  s.addText('Their own children', {
    x: M, y: 4.94, w: 6, h: 0.3,
    fontFace: BODY, fontSize: 11, bold: true, color: C.gold,
    charSpacing: 1.2, margin: 0,
  });
  carriers.forEach((p, i) => {
    household(s, {
      x: M + i * (gw + 0.3), y: 5.3, w: gw, h: ch,
      parent: p, gen: 6, childCols: 1,
    });
  });
  footer(s, `Almaz Muzeyen · ${descendants(almaz)} descendants`);
}

// ================================================================ 12. Smaller households
{
  const skip = new Set(['Oumer', 'Seid', 'Almaz']);
  const rest = muzeyen.children.filter((c) => c.children.length && !skip.has(c.first));
  const s = contentSlide(
    'The rest of Muzeyen\'s households',
    'Generation V and VI',
    'Every remaining child of Muzeyen who has a family of their own.'
  );
  const cols = 4;
  const gw = (W - M * 2 - 0.2 * (cols - 1)) / cols;
  const rowH = [];
  rest.forEach((p, i) => {
    const r = Math.floor(i / cols);
    rowH[r] = Math.max(rowH[r] || 0, householdHeight(p, 1, 'sm'));
  });
  rest.forEach((p, i) => {
    const c = i % cols, r = Math.floor(i / cols);
    const yOff = rowH.slice(0, r).reduce((a, b) => a + b + 0.22, 0);
    household(s, {
      x: M + c * (gw + 0.2),
      y: 2.0 + yOff,
      w: gw, h: rowH[r],
      parent: p, gen: 6, childCols: 1, small: true,
    });
  });
  footer(s, 'Children of Muzeyen Osman · the households not opened on their own slide');
}

// ================================================================ 13. Mohammed Osman
{
  const mo = osman.children.find((c) => c.first === 'Mohammed');
  const khedir = kid(mo, 'Khedir');
  const khedija = kid(mo, 'Khedija');
  const s = contentSlide(
    `Mohammed's line`,
    'Generation IV to VI · son of Osman',
    'Two children — Khedir, whose five sons carry the line on, and Khedija.'
  );

  s.addText(
    [
      { text: 'Khedir Mohammed', options: { fontSize: 14, bold: true, color: C.deep } },
      { text: `   five sons · ${descendants(khedir)} descendants`, options: { fontSize: 11, color: C.muted } },
    ],
    { x: M, y: 1.94, w: 9, h: 0.32, fontFace: BODY, margin: 0, valign: 'middle' }
  );

  // Khedir's five sons, laid out in two rows so the eight-child household has
  // the width its list needs — at five across it overflowed its card.
  const rowA = khedir.children.slice(0, 3);
  const rowB = khedir.children.slice(3);

  const layRow = (row, y, gapCount) => {
    const gw = (W - M * 2 - 0.2 * (gapCount - 1)) / gapCount;
    const h = Math.max(...row.map((p) => householdHeight(p, p.children.length > 4 ? 2 : 1)));
    row.forEach((p, i) => {
      household(s, {
        x: M + i * (gw + 0.2), y, w: gw, h,
        parent: p, gen: 6, childCols: p.children.length > 4 ? 2 : 1,
      });
    });
    return y + h;
  };

  let yy = layRow(rowA, 2.34, 3);
  yy = layRow(rowB, yy + 0.22, 3);

  s.addText('Khedir\'s sister, and her eight', {
    x: M, y: yy + 0.2, w: 9, h: 0.3,
    fontFace: BODY, fontSize: 11, bold: true, color: C.gold,
    charSpacing: 1.2, margin: 0, valign: 'middle',
  });
  household(s, {
    x: M, y: yy + 0.54, w: W - M * 2,
    h: householdHeight(khedija, 4),
    parent: khedija, gen: 5, childCols: 4,
  });

  footer(s, 'Mohammed Osman · son of Osman Mammaduu');
}

// ================================================================ 14. Mustefa Osman
{
  const mu = osman.children.find((c) => c.first === 'Mustefa');
  const s = contentSlide(
    `Mustefa's household`,
    'Generation IV to VI · son of Osman',
    'Six children; Temima and Jibrel have families of their own.'
  );
  cardGrid(s, mu.children, {
    x: M, y: 2.16, w: W - M * 2, cols: 6, ch: 0.96, gap: 0.18, gen: 5, size: 11.2,
    subFn: (p) => (p.children.length ? plural(p.children.length, 'child', 'children') : '—'),
    emphasisFn: (p) => p.children.length > 0,
  });

  const carriers = mu.children.filter((c) => c.children.length);
  const gw = (W - M * 2 - 0.3) / 2;
  const ch = Math.max(...carriers.map((p) => householdHeight(p, 1)));
  s.addText('Their own children', {
    x: M, y: 3.42, w: 6, h: 0.3,
    fontFace: BODY, fontSize: 11, bold: true, color: C.gold,
    charSpacing: 1.2, margin: 0,
  });
  carriers.forEach((p, i) => {
    household(s, {
      x: M + i * (gw + 0.3), y: 3.78, w: gw, h: ch,
      parent: p, gen: 6, childCols: 1,
    });
  });
  noteStrip(
    s, 5.66,
    'Where this sits',
    `Mustefa is the fifth of Osman's seven. Of his six children, four are ` +
      `recorded without families of their own — the ${
        descendants(mu) - mu.children.length
      } people below him all descend from Temima and Jibrel.`
  );
  footer(s, `Mustefa Osman · ${descendants(mu)} descendants`);
}

// ================================================================ 15. Mussa & Abdu
{
  const mussa = sons.find((x) => x.first === 'Sheikh Mussa');
  const abdu = sons.find((x) => x.first === 'Sheikh Abdu');
  const without = sons.filter((x) => !x.children.length);

  const s = contentSlide(
    'The remaining branches',
    'Generation III',
    'Sheikh Mussa and Sheikh Abdu each have five children. Three of Mammaduu\'s sons have none recorded.'
  );

  [mussa, abdu].forEach((p, i) => {
    const x = M + i * ((W - M * 2) / 2 + 0.16);
    const w = (W - M * 2) / 2 - 0.16;
    s.addText(full(p), {
      x, y: 2.02, w, h: 0.36,
      fontFace: HEAD, fontSize: 17, bold: true, color: C.deep, margin: 0,
    });
    cardGrid(s, p.children, {
      x, y: 2.48, w, cols: 1, ch: 0.58, gap: 0.12, gen: 4, size: 12,
    });
  });

  noteStrip(
    s, 5.94,
    'The three without descendants',
    `No children are recorded for ${without.map(full).join(', ')} — Mammaduu's ` +
      'three youngest sons. Any family they have belongs in the tree next.',
    true
  );
}

// ================================================================ 16-18. Index
{
  const romans = { 1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI' };
  const parentOf = new Map();
  (function walk(ns, p) {
    ns.forEach((x) => { parentOf.set(x, p); walk(x.children, x); });
  })(tree, null);

  // Every person, in tree order, with the parent that places them.
  const all = [];
  (function walk(ns, d) {
    ns.forEach((x) => { all.push({ p: x, d }); walk(x.children, d + 1); });
  })(tree, 1);

  const PAGES = 3;
  const PER_SLIDE = Math.ceil(all.length / PAGES);
  const chunks = [];
  for (let i = 0; i < all.length; i += PER_SLIDE) chunks.push(all.slice(i, i + PER_SLIDE));

  chunks.forEach((chunk, ci) => {
    const s = contentSlide(
      ci === 0 ? 'Every name, and where it sits' : 'Every name, continued',
      `Complete index · ${ci + 1} of ${chunks.length}`,
      ci === 0
        ? 'In tree order. The second line of each entry is the parent that places them.'
        : null
    );

    const cols = 3;
    const cw = (W - M * 2 - 0.34 * (cols - 1)) / cols;
    const per = Math.ceil(chunk.length / cols);
    for (let c = 0; c < cols; c++) {
      const slice = chunk.slice(c * per, (c + 1) * per);
      if (!slice.length) continue;
      const runs = [];
      slice.forEach((item, i) => {
        const par = parentOf.get(item.p);
        runs.push({
          text: `${romans[item.d]}  `,
          options: { fontSize: 7.6, bold: true, color: GEN[(item.d - 1) % 6] },
        });
        runs.push({
          text: full(item.p),
          options: { fontSize: 9.4, bold: true, color: C.ink },
        });
        runs.push({
          text: par ? `  · ${full(par)}` : '  · the head of the family',
          options: {
            fontSize: 8.2, color: C.muted,
            breakLine: i < slice.length - 1,
          },
        });
      });
      s.addText(runs, {
        x: M + c * (cw + 0.34),
        y: ci === 0 ? 2.02 : 1.68,
        w: cw,
        h: ci === 0 ? 4.86 : 5.2,
        fontFace: BODY, lineSpacingMultiple: 1.16, margin: 0, valign: 'top',
      });
    }
    footer(s, `${TOTAL} people · generation numeral, then the name, then the parent`);
  });
}

// ================================================================ 19. Closing
{
  const s = darkSlide();
  s.addShape(pres.ShapeType.ellipse, {
    x: 10.2, y: -2.3, w: 5.2, h: 5.2,
    fill: { color: C.deep, transparency: 52 }, line: { color: C.deep, width: 0 },
  });

  s.addText('WHAT IS MISSING', {
    x: M + 0.1, y: 1.5, w: 6, h: 0.3,
    fontFace: BODY, fontSize: 12, bold: true, color: C.gold, charSpacing: 3, margin: 0,
  });
  s.addText('The record is not finished', {
    x: M + 0.1, y: 1.9, w: 9, h: 0.9,
    fontFace: HEAD, fontSize: 40, bold: true, color: 'FFFFFF', margin: 0,
  });
  s.addText(
    'A tree with names in it is a diagram. A tree with dates, places and the ' +
      'things people did is a family history — and that part is still to be written.',
    {
      x: M + 0.1, y: 2.92, w: 8.2, h: 0.9,
      fontFace: BODY, fontSize: 14.5, color: 'B9CCC2',
      lineSpacingMultiple: 1.25, margin: 0,
    }
  );

  const gaps = [
    ['3', 'sons of Mammaduu with no descendants recorded', 'Ibrahim, Hassen and Hussen'],
    ['5', 'of Issa\'s children with no families recorded', 'the whole eldest branch'],
    [`${gens[6].length}`, 'people in the youngest generation', 'their children come next'],
  ];
  gaps.forEach((g, i) => {
    const x = M + 0.1 + i * 4.05;
    s.addText(g[0], {
      x, y: 4.32, w: 3.7, h: 0.72,
      fontFace: HEAD, fontSize: 40, bold: true, color: C.light, margin: 0,
    });
    s.addText(g[1], {
      x, y: 5.04, w: 3.7, h: 0.56,
      fontFace: BODY, fontSize: 11.5, bold: true, color: 'DCE9E3',
      lineSpacingMultiple: 1.15, margin: 0,
    });
    s.addText(g[2], {
      x, y: 5.62, w: 3.7, h: 0.36,
      fontFace: BODY, fontSize: 10, italic: true, color: '8AA79A', margin: 0,
    });
  });

  s.addText('The Mammaduu Family Tree', {
    x: M + 0.1, y: 6.5, w: 8, h: 0.3,
    fontFace: BODY, fontSize: 10, color: '6E8579', margin: 0,
  });
  s.addNotes(
    'Close on the gaps, because the point of showing the tree is to get people ' +
      'to fill them in.'
  );
}

pres.writeFile({ fileName: 'Mammaduu-Family-Tree.pptx' }).then(() =>
  console.log('wrote Mammaduu-Family-Tree.pptx')
);
