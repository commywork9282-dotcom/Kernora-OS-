/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library
.import "materialshapes.js" as Shapes

var loopSeconds = 180;

var cast = [
    { shape: "cookie9",   size: 0.74, anchor: [0.94, 0.08], orbit: [[0.035, 1, 0.0], [0.016, 2, 1.3]], stretch: 1.0, turns: 1,  breath: [0.02, 2, 0.0], family: 0, tone: 28 },
    { shape: "flower",    size: 0.66, anchor: [0.04, 0.96], orbit: [[0.030, 1, 2.1], [0.020, 3, 0.4]], stretch: 1.0, turns: -1, breath: [0.02, 3, 1.1], family: 1, tone: 32 },
    { shape: "sunny",     size: 0.38, anchor: [0.76, 0.80], orbit: [[0.060, 1, 4.0], [0.030, 2, 0.7]], stretch: 1.2, turns: 2,  breath: [0.03, 2, 2.0], family: 2, tone: 42 },
    { shape: "clover4",   size: 0.33, anchor: [0.16, 0.22], orbit: [[0.055, 1, 1.0], [0.025, 3, 2.2]], stretch: 1.2, turns: -2, breath: [0.03, 3, 0.5], family: 3, tone: 48 },
    { shape: "pill",      size: 0.34, anchor: [0.50, 1.03], orbit: [[0.050, 1, 5.1], [0.015, 2, 3.0]], stretch: 1.6, turns: 1,  breath: [0.02, 2, 1.7], family: 4, tone: 36 },
    { shape: "cookie6",   size: 0.30, anchor: [1.01, 0.60], orbit: [[0.060, 1, 3.3], [0.020, 2, 0.0]], stretch: 1.0, turns: -3, breath: [0.03, 2, 0.9], family: 5, tone: 42 },
    { shape: "clover8",   size: 0.24, anchor: [0.40, 0.02], orbit: [[0.050, 1, 3.9], [0.020, 3, 1.2]], stretch: 1.4, turns: -2, breath: [0.03, 3, 2.4], family: 2, tone: 48 },
    { shape: "softBurst", size: 0.19, anchor: [0.60, 0.16], orbit: [[0.090, 1, 0.2], [0.030, 2, 2.0]], stretch: 1.5, turns: 3,  breath: [0.04, 3, 0.2], family: 0, tone: 56 },
    { shape: "puffy",     size: 0.17, anchor: [0.33, 0.70], orbit: [[0.200, 1, 2.6], [0.050, 2, 0.3]], stretch: 1.5, turns: -3, breath: [0.04, 4, 1.4], family: 1, tone: 72 },
    { shape: "circle",    size: 0.10, anchor: [0.58, 0.54], orbit: [[0.260, 2, 0.0], [0.060, 3, 1.0]], stretch: 1.7, turns: 0,  breath: [0.06, 4, 0.8], family: 4, tone: 80 },
    { shape: "verySunny", size: 0.13, anchor: [0.84, 0.40], orbit: [[0.160, 1, 4.4], [0.040, 3, 1.0]], stretch: 1.3, turns: 4,  breath: [0.05, 3, 2.9], family: 3, tone: 86 },
    { shape: "cookie4",   size: 0.14, anchor: [0.24, 0.50], orbit: [[0.180, 1, 1.9], [0.030, 2, 0.8]], stretch: 1.6, turns: 3,  breath: [0.04, 3, 0.6], family: 2, tone: 64 },
];

var TAU = 2 * Math.PI;

function position(spec, phase, width, height) {
    let x = spec.anchor[0] * width;
    let y = spec.anchor[1] * height;
    const angle = phase * TAU;
    for (let k = 0; k < spec.orbit.length; ++k) {
        const term = spec.orbit[k];
        x += term[0] * height * spec.stretch * Math.cos(term[1] * angle + term[2]);
        y += term[0] * height * Math.sin(term[1] * angle + term[2]);
    }
    return Qt.point(x, y);
}

function rotation(spec, phase, index) {
    return (index * 37) % 360 + 360 * spec.turns * phase;
}

function breath(spec, phase) {
    return 1 + spec.breath[0] * Math.sin(spec.breath[1] * phase * TAU + spec.breath[2]);
}

function colour(p, spec, phase, cycling) {
    if (!p) {
        return Qt.rgba(0, 0, 0, 0);
    }
    const slot = spec.family % p.families.length;
    if (!cycling) {
        return p.fixed[slot][String(spec.tone)];
    }
    const track = p.tracks[slot][String(spec.tone)];
    const position = phase * p.steps;
    const i = Math.floor(position) % p.steps;
    const f = position - Math.floor(position);
    const a = Qt.color(track[i]);
    const b = Qt.color(track[(i + 1) % p.steps]);
    return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
}

function schedule(width, height, samples) {
    const n = cast.length;
    const radius = [];
    for (let i = 0; i < n; ++i) {
        const spec = cast[i];
        radius.push(spec.size * height * (1 + spec.breath[0])
                    * Shapes.shapes[spec.shape].radius * 1.04 + 0.006 * height);
    }
    const overlap = [];
    const pairs = [];
    for (let i = 0; i < n; ++i) {
        for (let j = i + 1; j < n; ++j) {
            pairs.push([i, j]);
            overlap.push(new Uint8Array(samples));
        }
    }
    for (let s = 0; s < samples; ++s) {
        const p = [];
        for (let i = 0; i < n; ++i) {
            p.push(position(cast[i], s / samples, width, height));
        }
        for (let k = 0; k < pairs.length; ++k) {
            const a = pairs[k][0], b = pairs[k][1];
            const dx = p[a].x - p[b].x, dy = p[a].y - p[b].y;
            const reach = radius[a] + radius[b];
            overlap[k][s] = dx * dx + dy * dy < reach * reach ? 1 : 0;
        }
    }

    const episodes = [];
    for (let k = 0; k < pairs.length; ++k) {
        const o = overlap[k];
        let free = -1;
        for (let s = 0; s < samples; ++s) {
            if (!o[s]) { free = s; break; }
        }
        if (free < 0) {
            episodes.push({ pair: k, start: 0, length: samples, order: 0 });
            continue;
        }
        let count = 0;
        for (let step = 1; step <= samples; ++step) {
            const s = (free + step) % samples;
            if (o[s] && !o[(s - 1 + samples) % samples]) {
                let length = 0;
                while (o[(s + length) % samples] && length < samples) {
                    ++length;
                }
                episodes.push({ pair: k, start: s, length: length, order: count++ });
            }
        }
    }
    episodes.sort((x, y) => x.start - y.start);

    const edges = [];
    for (let s = 0; s < samples; ++s) {
        edges.push([]);
    }
    function reaches(active, from, to) {
        const seen = new Uint8Array(n);
        const stack = [from];
        while (stack.length) {
            const v = stack.pop();
            if (v === to) {
                return true;
            }
            if (seen[v]) {
                continue;
            }
            seen[v] = 1;
            for (let e = 0; e < active.length; ++e) {
                if (active[e][0] === v) {
                    stack.push(active[e][1]);
                }
            }
        }
        return false;
    }
    function fits(episode, upper, lower) {
        for (let t = 0; t < episode.length; ++t) {
            if (reaches(edges[(episode.start + t) % samples], lower, upper)) {
                return false;
            }
        }
        return true;
    }
    for (let e = 0; e < episodes.length; ++e) {
        const episode = episodes[e];
        const a = pairs[episode.pair][0], b = pairs[episode.pair][1];
        const small = cast[a].size <= cast[b].size ? a : b;
        const large = small === a ? b : a;
        let upper = episode.order % 2 === 0 ? small : large;
        let lower = upper === small ? large : small;
        if (!fits(episode, upper, lower)) {
            const swap = upper; upper = lower; lower = swap;
        }
        for (let t = 0; t < episode.length; ++t) {
            edges[(episode.start + t) % samples].push([upper, lower]);
        }
    }

    const table = [];
    let previous = [];
    for (let i = 0; i < n; ++i) {
        previous.push(i);
    }
    previous.sort((x, y) => cast[y].size - cast[x].size);
    for (let s = 0; s < samples; ++s) {
        const below = [];
        for (let i = 0; i < n; ++i) {
            below.push([]);
        }
        const active = edges[s];
        for (let e = 0; e < active.length; ++e) {
            below[active[e][0]].push(active[e][1]);
        }
        const placed = new Uint8Array(n);
        const order = [];
        while (order.length < n) {
            let pick = -1;
            for (let k = 0; k < n; ++k) {
                const v = previous[k];
                if (placed[v]) {
                    continue;
                }
                let ready = true;
                for (let d = 0; d < below[v].length; ++d) {
                    if (!placed[below[v][d]]) {
                        ready = false;
                        break;
                    }
                }
                if (ready) {
                    pick = v;
                    break;
                }
            }
            if (pick < 0) {
                for (let k = 0; k < n; ++k) {
                    if (!placed[previous[k]]) { pick = previous[k]; break; }
                }
            }
            placed[pick] = 1;
            order.push(pick);
        }
        const z = new Int8Array(n);
        for (let k = 0; k < n; ++k) {
            z[order[k]] = k;
        }
        table.push(z);
        previous = order;
    }
    return table;
}
