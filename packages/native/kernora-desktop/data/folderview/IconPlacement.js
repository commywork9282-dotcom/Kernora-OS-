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
    for (let i = 0; i < capacity; ++i) {
        const point = cell(i, columns, rows, horizontal, rtl);
        const x = point.column * cellWidth;
        const y = point.row * cellHeight;
        if (rectangles.some(rect => x < rect.x + rect.width && x + cellWidth > rect.x
                            && y < rect.y + rect.height && y + cellHeight > rect.y)) {
            blocked.add(i);
        }
    }
    const ordered = items.slice().sort((a, b) => sorted ? a.source - b.source : a.index - b.index);
    if (!sorted) {
        for (const item of ordered) {
            if (!blocked.has(item.index)) {
                result.set(item.index, item.index);
                occupied.add(item.index);
            }
        }
    }
    let overflow = capacity;
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
            if (sorted) {
                chosen = i;
                break;
            }
            const point = cell(i, columns, rows, horizontal, rtl);
            const candidate = Math.abs(point.column - origin.column) + Math.abs(point.row - origin.row);
            if (candidate < distance) {
                chosen = i;
                distance = candidate;
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
