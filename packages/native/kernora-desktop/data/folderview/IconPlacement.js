function cell(index, columns, rows, horizontal, rtl) {
    const stripe = horizontal ? columns : rows;
    const column = horizontal ? index % stripe : Math.floor(index / stripe);
    return {
        column: rtl ? columns - 1 - column : column,
        row: horizontal ? Math.floor(index / stripe) : index % stripe
    };
}

function arrange(items, rectangles, width, height, cellWidth, cellHeight, horizontal, rtl, sorted) {
    const columns = Math.floor(width / cellWidth);
    const rows = Math.floor(height / cellHeight);
    if (columns < 1 || rows < 1) {
        return [];
    }
    const capacity = columns * rows;
    const blocked = new Set();
    const occupied = new Set();
    const result = new Map();
    const cover = [];
    const insetX = cellWidth * 0.15;
    const insetY = cellHeight * 0.15;
    for (let i = 0; i < capacity; ++i) {
        const point = cell(i, columns, rows, horizontal, rtl);
        const x = point.column * cellWidth + insetX;
        const y = point.row * cellHeight + insetY;
        const w = cellWidth - 2 * insetX;
        const h = cellHeight - 2 * insetY;
        let area = 0;
        for (const rect of rectangles) {
            const overlapX = Math.min(x + w, rect.x + rect.width) - Math.max(x, rect.x);
            const overlapY = Math.min(y + h, rect.y + rect.height) - Math.max(y, rect.y);
            if (overlapX > 0 && overlapY > 0) {
                area += overlapX * overlapY;
            }
        }
        cover.push(area);
        if (area > 0) {
            blocked.add(i);
        }
    }
    const ordered = items.slice().sort((a, b) => sorted ? a.source - b.source : a.index - b.index);
    let overflow = capacity;
    if (sorted) {
        const clean = [];
        const covered = [];
        for (let i = 0; i < capacity; ++i) {
            (blocked.has(i) ? covered : clean).push(i);
        }
        let slots = clean.slice(0, ordered.length);
        if (slots.length < ordered.length) {
            covered.sort((a, b) => cover[a] - cover[b] || a - b);
            slots = slots.concat(covered.slice(0, ordered.length - slots.length)).sort((a, b) => a - b);
        }
        ordered.forEach((item, k) => result.set(item.index, k < slots.length ? slots[k] : overflow++));
        return ordered.map(item => ({from: item.index, to: result.get(item.index), source: item.source}));
    }
    for (const item of ordered) {
        if (item.index < capacity && !blocked.has(item.index)) {
            result.set(item.index, item.index);
            occupied.add(item.index);
        }
    }
    for (const item of ordered) {
        if (result.has(item.index)) {
            continue;
        }
        const origin = cell(item.index, columns, rows, horizontal, rtl);
        let chosen = -1;
        let distance = Infinity;
        for (let i = 0; i < capacity; ++i) {
            if (blocked.has(i) || occupied.has(i)) {
                continue;
            }
            const point = cell(i, columns, rows, horizontal, rtl);
            const candidate = Math.abs(point.column - origin.column) + Math.abs(point.row - origin.row);
            if (candidate < distance) {
                chosen = i;
                distance = candidate;
            }
        }
        if (chosen < 0 && item.index < capacity && !occupied.has(item.index)) {
            chosen = item.index;
        } else if (chosen < 0) {
            let least = Infinity;
            for (let i = 0; i < capacity; ++i) {
                if (occupied.has(i)) {
                    continue;
                }
                const point = cell(i, columns, rows, horizontal, rtl);
                const candidate = cover[i] * 1000 + Math.abs(point.column - origin.column) + Math.abs(point.row - origin.row);
                if (candidate < least) {
                    chosen = i;
                    least = candidate;
                }
            }
        }
        if (chosen < 0) {
            while (occupied.has(overflow)) {
                ++overflow;
            }
            chosen = overflow++;
        }
        result.set(item.index, chosen);
        occupied.add(chosen);
    }
    return ordered.map(item => ({from: item.index, to: result.get(item.index), source: item.source}));
}
