/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library
.import "materialshapes.js" as Shapes

var loopSeconds = 50;

var FLOOR = 0.88;
var AXIS = 0.70;
var ROCK = 0.32;
var REBUILD = 0.62;
var HOP_GAP = 1.1;
var GRAVITY = 3.0;
var SCALE = 0.86;

var pieces = [
    { shape: "slab",    w: 0.36,  h: 0.062, dx: 0.000,  family: "ink",   tone: 30 },
    { shape: "square",  w: 0.15,  h: 0.15,  dx: -0.050, family: "ember", tone: 58 },
    { shape: "cookie4", w: 0.13,  h: 0.13,  dx: -0.035, family: "amber", tone: 80 },
    { shape: "slab",    w: 0.25,  h: 0.046, dx: 0.010,  family: "teal",  tone: 52 },
    { shape: "arch",    w: 0.125, h: 0.125, dx: 0.040,  family: "rose",  tone: 64 },
    { shape: "circle",  w: 0.085, h: 0.085, dx: 0.040,  family: "plum",  tone: 40 },
    { shape: "slab",    w: 0.16,  h: 0.036, dx: 0.030,  family: "ember", tone: 72 },
    { shape: "clover4", w: 0.095, h: 0.095, dx: 0.010,  family: "teal",  tone: 74 },
    { shape: "sunny",   w: 0.085, h: 0.085, dx: 0.015,  family: "amber", tone: 88 },
];

var DEG = 180 / Math.PI;

function hash(seed) {
    var v = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
    return v - Math.floor(v);
}

function outline(piece, height) {
    var w = piece.w * SCALE * height, h = piece.h * SCALE * height;
    var points = [];
    if (piece.shape === "slab") {
        var r = h / 2;
        for (var i = 0; i <= 8; ++i) {
            var a = -Math.PI / 2 + Math.PI * i / 8;
            points.push([w / 2 - r + r * Math.cos(a), r * Math.sin(a)]);
            points.push([-(w / 2 - r) - r * Math.cos(a), -r * Math.sin(a)]);
        }
        return points;
    }
    var hull = Shapes.shapes[piece.shape].hull;
    for (var k = 0; k < hull.length; ++k) {
        points.push([hull[k][0] * w, hull[k][1] * h]);
    }
    return points;
}

function reach(points, angle) {
    var c = Math.cos(angle / DEG), s = Math.sin(angle / DEG);
    var r = { down: -1e9, up: -1e9, left: -1e9, right: -1e9 };
    for (var i = 0; i < points.length; ++i) {
        var x = points[i][0] * c - points[i][1] * s;
        var y = points[i][0] * s + points[i][1] * c;
        if (y > r.down) r.down = y;
        if (-y > r.up) r.up = -y;
        if (-x > r.left) r.left = -x;
        if (x > r.right) r.right = x;
    }
    return r;
}

function reachTables(points) {
    var tables = { down: [], left: [], right: [] };
    for (var a = 0; a < 360; ++a) {
        var r = reach(points, a);
        tables.down.push(r.down);
        tables.left.push(r.left);
        tables.right.push(r.right);
    }
    return tables;
}

function downTable(points) {
    return reachTables(points).down;
}

function restingAngles(table, size) {
    var low = Math.min.apply(null, table), high = Math.max.apply(null, table);
    var margin = 0.012 * size;
    if (high - low < margin) return [];
    var angles = [];
    for (var a = 0; a < 360; ++a) {
        var lowest = true, before = 0, after = 0;
        for (var d = 1; d <= 30; ++d) {
            var b = table[(a + 360 - d) % 360], f = table[(a + d) % 360];
            if (d <= 6 && (b < table[a] || f <= table[a])) lowest = false;
            before = Math.max(before, b);
            after = Math.max(after, f);
        }
        if (lowest && Math.min(before, after) - table[a] > margin) angles.push(a);
    }
    return angles;
}

function nearestRest(angles, angle) {
    var best = angle, distance = 1e9;
    for (var i = 0; i < angles.length; ++i) {
        var d = ((angles[i] - angle) % 360 + 540) % 360 - 180;
        if (Math.abs(d) < distance) {
            distance = Math.abs(d);
            best = angle + d;
        }
    }
    return best;
}

function lookup(table, angle) {
    var a = ((angle % 360) + 360) % 360;
    var i = Math.floor(a), f = a - i;
    return table[i] * (1 - f) + table[(i + 1) % 360] * f;
}

function centroid(points) {
    var area = 0, cx = 0, cy = 0;
    for (var i = 0; i < points.length; ++i) {
        var p = points[i], q = points[(i + 1) % points.length];
        var cross = p[0] * q[1] - q[0] * p[1];
        area += cross;
        cx += (p[0] + q[0]) * cross;
        cy += (p[1] + q[1]) * cross;
    }
    return area === 0 ? [0, 0] : [cx / (3 * area), cy / (3 * area)];
}

function rotateAbout(px, py, x, y, angle) {
    var c = Math.cos(angle / DEG), s = Math.sin(angle / DEG);
    var dx = x - px, dy = y - py;
    return [px + dx * c - dy * s, py + dx * s + dy * c];
}

function unitOf(width, height) {
    return Math.min(height, width * 0.625);
}

function plan(width, height) {
    var unit = unitOf(width, height);
    var floor = FLOOR * height;
    var g = GRAVITY * unit;
    var n = pieces.length;

    var bodies = [];
    var top = floor;
    for (var i = 0; i < n; ++i) {
        var piece = pieces[i];
        var drawn = outline(piece, unit);
        var mass = centroid(drawn);
        var points = drawn.map(function (p) { return [p[0] - mass[0], p[1] - mass[1]]; });
        var upright = reach(points, 0);
        var x = AXIS * width + piece.dx * SCALE * unit + mass[0];
        var y = top - upright.down;
        top = y - upright.up;
        var tables = reachTables(points);
        var down = tables.down;
        bodies.push({
            points: points,
            down: down,
            left: tables.left,
            right: tables.right,
            resting: restingAngles(down, Math.min(piece.w, piece.h) * SCALE * unit),
            offset: mass,
            w: piece.w * SCALE * unit,
            h: piece.h * SCALE * unit,
            mass: piece.w * piece.h,
            slot: [x, y],
        });
    }
    var base = bodies[0];
    var pivot = [base.slot[0] - base.w / 2 + base.h / 2, floor];

    function drawnAt(k, x, y, angle) {
        var c = Math.cos(angle / DEG), s = Math.sin(angle / DEG);
        var o = bodies[k].offset;
        return [x - (o[0] * c - o[1] * s), y - (o[0] * s + o[1] * c), angle];
    }

    function lever(only) {
        var sx = 0, sy = 0, inertia = 0;
        for (var k = 0; k < n; ++k) {
            if (only !== undefined && k !== only) continue;
            var rx = bodies[k].slot[0] - pivot[0], ry = bodies[k].slot[1] - pivot[1];
            sx += bodies[k].mass * rx;
            sy += bodies[k].mass * ry;
            inertia += bodies[k].mass * (rx * rx + ry * ry + (bodies[k].w * bodies[k].w + bodies[k].h * bodies[k].h) / 12);
        }
        return { x: g * sx / inertia, y: g * sy / inertia };
    }
    var whole = lever(), baseAlone = lever(0);
    function tipping(theta, only) {
        var l = only === 0 ? baseAlone : whole;
        return l.x * Math.cos(theta / DEG) - l.y * Math.sin(theta / DEG);
    }

    var dt = 1 / 120;
    function goesOver(spin) {
        var theta = 0, omega = -spin;
        for (var t = 0; t < 6; t += dt) {
            omega += tipping(theta) * dt;
            theta += omega * DEG * dt;
            if (theta >= 0) return false;
            if (theta < -60) return true;
        }
        return false;
    }
    var tipsAt = 0;
    while (tipsAt > -89 && tipping(tipsAt) > 0) tipsAt -= 0.25;

    var low = 0, high = 20;
    for (var b = 0; b < 18; ++b) {
        var mid = (low + high) / 2;
        if (goesOver(mid)) high = mid; else low = mid;
    }
    var critical = high;
    var pushes = [critical * 0.62, critical * 0.86, critical * 1.025];
    var pause = 0.45;

    var samples = [];
    for (i = 0; i < n; ++i) samples.push([]);
    var sampleEvery = 1 / 60;
    var nextSample = 0;
    var t = 0;

    var theta = 0, omega = 0, push = 0, waiting = 0.25;
    var free = [];
    for (i = 0; i < n; ++i) free.push(null);
    function release(index) {
        return tipsAt - 2 - (n - 1 - index) * 1.8;
    }
    var anchored = false, baseTheta = 0, baseOmega = 0;
    var fallen = false;

    function record() {
        for (var k = 0; k < n; ++k) {
            if (k === 0 && anchored) {
                var b = rotateAbout(pivot[0], pivot[1], bodies[0].slot[0], bodies[0].slot[1], baseTheta);
                samples[0].push(drawnAt(0, b[0], b[1], baseTheta));
            } else if (free[k]) {
                samples[k].push(drawnAt(k, free[k].x, free[k].y, free[k].a));
            } else {
                var p = rotateAbout(pivot[0], pivot[1], bodies[k].slot[0], bodies[k].slot[1], theta);
                samples[k].push(drawnAt(k, p[0], p[1], theta));
            }
        }
    }

    function freePiece(k) {
        var p = rotateAbout(pivot[0], pivot[1], bodies[k].slot[0], bodies[k].slot[1], theta);
        var rx = p[0] - pivot[0], ry = p[1] - pivot[1];
        var fling = (k + 1) / n;
        free[k] = {
            x: p[0], y: p[1],
            vx: -omega * ry - (0.04 + 0.22 * hash(k * 3 + 1)) * unit * fling,
            vy: omega * rx - (0.05 + 0.25 * hash(k * 3 + 2)) * unit * fling,
            a: theta,
            w: omega * DEG + (hash(k * 3 + 3) - 0.5) * 420,
            grounded: false,
        };
    }
    function letGo() {
        for (var k = 1; k < n; ++k) {
            if (!free[k]) freePiece(k);
        }
        anchored = true;
        baseTheta = theta;
        baseOmega = omega;
        fallen = true;
    }

    var left = width * 0.015, right = width * 0.985;
    var duration = 13;
    var k;
    while (t < duration) {
        if (t >= nextSample - 1e-9) {
            record();
            nextSample += sampleEvery;
        }
        if (!fallen) {
            if (waiting > 0) {
                waiting -= dt;
                if (waiting <= 0) {
                    omega = -pushes[push];
                    push += 1;
                }
            } else {
                omega += tipping(theta) * dt;
                theta += omega * DEG * dt;
                if (theta >= 0) {
                    theta = 0;
                    omega = 0;
                    waiting = pause;
                    if (push >= pushes.length) letGo();
                }
                for (k = n - 1; k >= 1; --k) {
                    if (!free[k] && theta < release(k)) {
                        freePiece(k);
                    }
                }
                if (free[1] && !anchored) letGo();
            }
        }
        if (anchored) {
            baseOmega += tipping(baseTheta, 0) * dt;
            baseTheta += baseOmega * DEG * dt;
            if (baseTheta >= 0) {
                baseTheta = 0;
                baseOmega = baseOmega > 0.4 ? -0.3 * baseOmega : 0;
            }
        }
        for (k = 0; k < n; ++k) {
            var f = free[k];
            if (!f) continue;
            var body = bodies[k];
            var settle = t > 7 ? 1 + (t - 7) * 2 : 1;
            if (!f.grounded) {
                f.vy += g * dt;
                f.x += f.vx * dt;
                f.y += f.vy * dt;
                f.a += f.w * dt;
                var reachDown = lookup(body.down, f.a);
                if (f.y + reachDown >= floor) {
                    f.y = floor - reachDown;
                    if (f.vy > 0.22 * unit) {
                        f.vy = -0.3 * f.vy;
                        f.vx *= 0.7;
                        f.w = 0.5 * f.w + 0.5 * (f.vx / Math.max(reachDown, 1)) * DEG;
                    } else {
                        f.grounded = true;
                        f.w = 0.5 * f.w + 0.5 * (f.vx / Math.max(reachDown, 1)) * DEG;
                        f.vx = 0;
                        f.vy = 0;
                    }
                }
            } else {
                var e = lookup(body.down, f.a);
                var target = nearestRest(body.resting, f.a);
                if (t > 6 && Math.abs(target - f.a) > 1.5 && Math.abs(f.w) < 60) {
                    f.w += (40 * (target - f.a) - 9 * f.w) * dt;
                } else {
                    var slope = (lookup(body.down, f.a + 1) - lookup(body.down, f.a - 1)) / 2 * DEG;
                    var inertia = (body.w * body.w + body.h * body.h) / 12 + e * e;
                    var alpha = -g * slope / inertia - 1.4 * settle * (f.w / DEG);
                    var drag = 1.2 * Math.max(1, settle) * dt;
                    f.w = Math.abs(f.w) <= drag * DEG ? 0 : f.w - Math.sign(f.w) * drag * DEG;
                    f.w += alpha * DEG * dt;
                }
                f.a += f.w * dt;
                f.x += (f.w / DEG) * e * dt;
                f.y = floor - lookup(body.down, f.a);
            }
            var r = { left: lookup(body.left, f.a), right: lookup(body.right, f.a) };
            if (f.x - r.left < left) {
                f.x = left + r.left;
                f.vx = Math.abs(f.vx) * 0.4;
                f.w = -f.w * 0.4;
            } else if (f.x + r.right > right) {
                f.x = right - r.right;
                f.vx = -Math.abs(f.vx) * 0.4;
                f.w = -f.w * 0.4;
            }
        }
        var baseFlat = anchored && baseTheta === 0
            ? { x: bodies[0].slot[0], grounded: true, a: 0, fixed: true } : null;
        for (k = 0; k < n; ++k) {
            for (var j = k + 1; j < n; ++j) {
                var a = k === 0 ? baseFlat : free[k], c = free[j];
                if (!a || !c || !a.grounded || !c.grounded) continue;
                var ra = { left: lookup(bodies[k].left, a.a), right: lookup(bodies[k].right, a.a) };
                var rc = { left: lookup(bodies[j].left, c.a), right: lookup(bodies[j].right, c.a) };
                var overlap = (a.x < c.x ? (a.x + ra.right) - (c.x - rc.left) : (c.x + rc.right) - (a.x - ra.left))
                    - 0.3 * Math.min(ra.left + ra.right, rc.left + rc.right);
                if (overlap > 0) {
                    var share = a.fixed ? 1 : bodies[k].mass / (bodies[k].mass + bodies[j].mass);
                    var shift = overlap * Math.min(1, 40 * dt) * (a.x < c.x ? 1 : -1);
                    if (!a.fixed) a.x -= shift * (1 - share);
                    c.x += shift * share;
                }
            }
        }
        t += dt;
    }
    record();

    var rests = [];
    var hopping = 0;
    for (i = 0; i < n; ++i) {
        var last = samples[i][samples[i].length - 1];
        var home = drawnAt(i, bodies[i].slot[0], bodies[i].slot[1], 0);
        var dist = Math.hypot(home[0] - last[0], home[1] - last[1]) / unit;
        var turns = Math.round(last[2] / 360);
        if (dist > 0.25) turns += home[0] > last[0] ? 1 : -1;
        var hops = dist > 0.01 || Math.abs(last[2]) > 1;
        rests.push({
            x: last[0], y: last[1], a: last[2],
            home: turns * 360,
            start: REBUILD * loopSeconds + hopping * HOP_GAP,
            hops: hops,
            flight: 0.55 + 0.5 * Math.sqrt(dist),
            lift: unit * (0.1 + 0.12 * Math.min(1, dist)),
        });
        if (hops) hopping += 1;
    }

    return {
        width: width,
        height: height,
        slots: bodies.map(function (body, k) { return drawnAt(k, body.slot[0], body.slot[1], 0); }),
        samples: samples,
        sampleEvery: sampleEvery,
        rests: rests,
    };
}

function ease(t) {
    t = Math.max(0, Math.min(1, t));
    return t * t * (3 - 2 * t);
}

var SQUAT = 0.18;
var LANDING = 0.28;

function poses(plan, phase) {
    var result = [];
    var now = phase * loopSeconds;
    var fallAt = ROCK * loopSeconds;
    var homeAt = REBUILD * loopSeconds;
    var simulated = (plan.samples[0].length - 1) * plan.sampleEvery;
    for (var i = 0; i < pieces.length; ++i) {
        var slot = plan.slots[i];
        var pose = { x: slot[0], y: slot[1], a: 0, sx: 1, sy: 1 };
        if (now >= fallAt && now < homeAt) {
            var s = Math.min(now - fallAt, simulated) / plan.sampleEvery;
            var k = Math.floor(s), f = s - k;
            var table = plan.samples[i];
            var p = table[Math.min(k, table.length - 1)], q = table[Math.min(k + 1, table.length - 1)];
            pose.x = p[0] + (q[0] - p[0]) * f;
            pose.y = p[1] + (q[1] - p[1]) * f;
            pose.a = p[2] + (q[2] - p[2]) * f;
        } else if (now >= homeAt) {
            var rest = plan.rests[i];
            var t = now - rest.start;
            if (!rest.hops) {
            } else if (t < 0) {
                pose.x = rest.x;
                pose.y = rest.y;
                pose.a = rest.a;
            } else if (t < SQUAT) {
                var squat = Math.sin(Math.PI * t / SQUAT);
                pose.x = rest.x;
                pose.y = rest.y;
                pose.a = rest.a;
                pose.sy = 1 - 0.16 * squat;
                pose.sx = 1 + 0.08 * squat;
            } else if (t < SQUAT + rest.flight) {
                var u = (t - SQUAT) / rest.flight;
                var along = u;
                pose.x = rest.x + (slot[0] - rest.x) * along;
                pose.y = rest.y + (slot[1] - rest.y) * u - 4 * rest.lift * u * (1 - u);
                pose.a = rest.a + (rest.home - rest.a) * ease(u * 1.15);
                pose.sy = 1 + 0.1 * (1 - u) * Math.sin(Math.PI * Math.min(1, u * 3));
                pose.sx = 1 / pose.sy;
            } else if (t < SQUAT + rest.flight + LANDING) {
                var l = (t - SQUAT - rest.flight) / LANDING;
                var squash = Math.sin(Math.PI * l) * (1 - l) * 1.6 - 0.25 * Math.sin(2 * Math.PI * l) * l;
                pose.sy = 1 - 0.18 * squash;
                pose.sx = 1 + 0.1 * squash;
            }
        }
        result.push(pose);
    }
    return result;
}
