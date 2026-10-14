const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.resolve(__dirname, '../../packages/native/kernora-desktop/data/folderview/IconPlacement.js'), 'utf8'), context);
let seed = 32191;
const random = n => {
    seed = (1664525 * seed + 1013904223) >>> 0;
    return seed % n;
};
for (let test = 0; test < 2000; ++test) {
    const columns = 1 + random(12);
    const rows = 1 + random(9);
    const horizontal = random(2) === 0;
    const rtl = random(2) === 0;
    const sorted = random(2) === 0;
    const width = columns * 100;
    const height = rows * 100;
    const slots = new Set();
    const count = random(columns * rows + 12);
    while (slots.size < count) {
        slots.add(random(columns * rows + 24));
    }
    const items = Array.from(slots, (index, source) => ({index, source}));
    const rectangles = Array.from({length: random(7)}, () => ({
        x: random(width + 100) - 50, y: random(height + 100) - 50,
        width: 1 + random(400), height: 1 + random(350)
    }));
    const placed = context.arrange(items, rectangles, width, height, 100, 100, horizontal, rtl, sorted);
    assert.equal(placed.length, items.length);
    assert.equal(new Set(placed.map(item => item.to)).size, items.length);
    assert.deepEqual(Array.from(placed, item => item.source).sort((a, b) => a - b), items.map(item => item.source));
    for (const item of placed) {
        const stripe = horizontal ? columns : rows;
        const column = horizontal ? item.to % stripe : Math.floor(item.to / stripe);
        const x = (rtl ? columns - 1 - column : column) * 100;
        const y = (horizontal ? Math.floor(item.to / stripe) : item.to % stripe) * 100;
        if (item.to < columns * rows) {
            assert(!rectangles.some(rect => x < rect.x + rect.width && x + 100 > rect.x
                                        && y < rect.y + rect.height && y + 100 > rect.y));
        }
    }
    if (sorted) {
        assert(Array.from(placed).every((item, i) => i === 0 || item.to > placed[i - 1].to));
    }
    const again = context.arrange(Array.from(placed, item => ({index: item.to, source: item.source})),
                                 rectangles, width, height, 100, 100, horizontal, rtl, sorted);
    assert(Array.from(again).every(item => item.from === item.to));
}
const stable = context.arrange([{index: 6, source: 0}, {index: 3, source: 1}], [], 400, 300, 100, 100, true, false, false);
assert(Array.from(stable).every(item => item.from === item.to));
console.log('PASS: 2000 layouts, both grid flows/directions, sorting, overflow, conservation and stability');
module.exports = {status: 'PASS', layouts: 2000};
