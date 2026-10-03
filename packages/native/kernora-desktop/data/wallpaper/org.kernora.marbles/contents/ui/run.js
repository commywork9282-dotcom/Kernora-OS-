/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library
.import "materialshapes.js" as Shapes

var loopSeconds = 60;
var MARBLES = 5;
var GRAVITY = 3.0;

var DEG = 180 / Math.PI;

var marbles = [
    { shape: "cookie9",  symmetry: 40,  family: "ember",  tone: 64 },
    { shape: "sunny",    symmetry: 45,  family: "amber",  tone: 82 },
    { shape: "clover4",  symmetry: 90,  family: "rose",   tone: 72 },
    { shape: "cookie6",  symmetry: 60,  family: "sky",    tone: 76 },
    { shape: "cookie4",  symmetry: 90,  family: "violet", tone: 74 },
];

function unitOf(width, height) {
    return Math.min(height, width * 0.625);
}

function downTable(shape, size) {
    var hull = Shapes.shapes[shape].hull;
    var table = [];
    for (var a = 0; a < 360; ++a) {
        var c = Math.cos(a / DEG), s = Math.sin(a / DEG), down = 0;
        for (var i = 0; i < hull.length; ++i) {
            down = Math.max(down, (hull[i][0] * s + hull[i][1] * c) * size);
        }
        table.push(down);
    }
    return table;
}

function lookup(table, angle) {
    var a = ((angle % 360) + 360) % 360;
    var i = Math.floor(a), f = a - i;
    return table[i] * (1 - f) + table[(i + 1) % 360] * f;
}

function plan(width, height) {
    var H = unitOf(width, height);
    var oy = (height - H) / 2;
    var g = GRAVITY * H;
    var r = 0.042 * H;

    var lift = { x: width - 0.14 * H, top: oy + 0.1 * H, bottom: oy + 0.92 * H, width: 0.13 * H };
    var reach = 0.22 * H;
    var length = Math.max(0.35 * H, Math.min(0.8 * H, lift.x - 0.2 * width - reach));
    var far = lift.x - length;
    var drop = 0.06 * H;
    var ramps = [
        { a: [lift.x, oy + 0.25 * H],             b: [far, oy + 0.25 * H + drop],                          post: false },
        { a: [far - reach, oy + 0.42 * H],        b: [lift.x - reach - 0.08 * H, oy + 0.42 * H + drop],    post: true },
        { a: [lift.x - 0.07 * H, oy + 0.59 * H],  b: [far, oy + 0.59 * H + drop],                          post: true },
        { a: [far - reach, oy + 0.76 * H],        b: [lift.x, oy + 0.76 * H + drop],                       post: true },
    ];
    for (var i = 0; i < ramps.length; ++i) {
        var ramp = ramps[i];
        var dx = ramp.b[0] - ramp.a[0], dy = ramp.b[1] - ramp.a[1];
        ramp.length = Math.hypot(dx, dy);
        ramp.dir = [dx / ramp.length, dy / ramp.length];
        ramp.normal = dx > 0 ? [ramp.dir[1], -ramp.dir[0]] : [-ramp.dir[1], ramp.dir[0]];
        ramp.angle = Math.atan2(dy, dx) * DEG;
        ramp.post = ramp.post ? { x: ramp.a[0] + (dx > 0 ? 1 : -1) * 0.02 * H, top: ramp.a[1] - 0.11 * H } : null;
    }

    function centreOn(ramp, s) {
        return [ramp.a[0] + ramp.dir[0] * s + ramp.normal[0] * r, ramp.a[1] + ramp.dir[1] * s + ramp.normal[1] * r];
    }
    function surface(ramp, x) {
        var t = (x - ramp.a[0]) / (ramp.b[0] - ramp.a[0]);
        return t < 0 || t > 1 ? null : ramp.a[1] + (ramp.b[1] - ramp.a[1]) * t;
    }

    var dt = 1 / 240;
    var sampleEvery = 1 / 60;
    var samples = [];
    var hits = [];
    var t = 0, nextSample = 0;
    var mode = "roll", on = 0;
    var s = 0, v = 0.12 * H;
    var x = 0, y = 0, vx = 0, vy = 0;
    var angle = 0;
    var start = centreOn(ramps[0], 0);
    var postRadius = 0.017 * H;
    while (t < 40) {
        if (mode === "roll") {
            var rp = ramps[on];
            v += g * rp.dir[1] * 5 / 7 * dt;
            s += v * dt;
            var c = centreOn(rp, s);
            angle += (v * rp.dir[0]) / r * DEG * dt;
            x = c[0];
            y = c[1];
            var stop = rp.post ? Math.abs(rp.post.x - rp.a[0]) + postRadius + r : 0;
            if (rp.post && s < stop) {
                s = stop;
                if (v < 0) {
                    hits.push({ post: on, time: t, strength: Math.min(1, -v / (0.4 * H)) });
                    v = -0.45 * v;
                }
            }
            if (on === ramps.length - 1 && x >= lift.x) {
                break;
            }
            if (s > rp.length) {
                mode = "air";
                vx = rp.dir[0] * v;
                vy = rp.dir[1] * v;
            }
        } else {
            vy += g * dt;
            x += vx * dt;
            y += vy * dt;
            angle += vx / r * DEG * dt * 0.6;
            var next = ramps[on + 1];
            var post = next.post;
            if (post && Math.abs(x - post.x) < r + postRadius && y > post.top) {
                hits.push({ post: on + 1, time: t, strength: Math.min(1, Math.abs(vx) / (0.4 * H)) });
                vx = -0.45 * vx;
                x = post.x + Math.sign(x - post.x) * (r + postRadius);
            }
            var top = surface(next, x);
            if (top !== null && y + r >= top) {
                var along = vx * next.dir[0] + vy * next.dir[1];
                var across = vx * next.normal[0] + vy * next.normal[1];
                if (across < -0.08 * H) {
                    vx = next.dir[0] * along - next.normal[0] * across * 0.35;
                    vy = next.dir[1] * along - next.normal[1] * across * 0.35;
                    y = top - r;
                } else {
                    on += 1;
                    mode = "roll";
                    s = (x - next.a[0]) / next.dir[0];
                    v = along;
                }
            }
        }
        if (t >= nextSample - 1e-9) {
            samples.push([x, y, angle]);
            nextSample += sampleEvery;
        }
        t += dt;
    }
    samples.push([x, y, angle]);
    var runTime = t;

    var trips = Math.max(1, Math.floor(loopSeconds / (runTime + 4)));
    var period = loopSeconds / trips;
    var ride = period - runTime;
    var rideFrom = [lift.x, y];
    var rideTo = start;
    return {
        width: width,
        height: height,
        radius: r,
        lift: lift,
        ramps: ramps,
        postRadius: postRadius,
        samples: samples,
        sampleEvery: sampleEvery,
        hits: hits,
        runTime: runTime,
        period: period,
        ride: ride,
        rideFrom: rideFrom,
        rideTo: rideTo,
        endAngle: angle,
        downs: marbles.map(function (marble) {
            return downTable(marble.shape, r / Shapes.shapes[marble.shape].radius);
        }),
        speed: (rideFrom[1] - rideTo[1]) / ride,
    };
}

function ease(t) {
    t = Math.max(0, Math.min(1, t));
    return t * t * (3 - 2 * t);
}

function poses(plan, phase) {
    var result = [];
    var now = phase * loopSeconds;
    var cupLead = 0.6;
    for (var m = 0; m < MARBLES; ++m) {
        var local = ((now + m * plan.period / MARBLES) % plan.period + plan.period) % plan.period;
        var pose = { x: 0, y: 0, a: 0, cup: null };
        if (local < plan.runTime) {
            var k = local / plan.sampleEvery;
            var i = Math.floor(k), f = k - i;
            var p = plan.samples[Math.min(i, plan.samples.length - 1)];
            var q = plan.samples[Math.min(i + 1, plan.samples.length - 1)];
            pose.x = p[0] + (q[0] - p[0]) * f;
            pose.y = p[1] + (q[1] - p[1]) * f;
            pose.a = p[2] + (q[2] - p[2]) * f;
        } else {
            var u = (local - plan.runTime) / plan.ride;
            pose.x = plan.rideFrom[0];
            pose.y = plan.rideFrom[1] + (plan.rideTo[1] - plan.rideFrom[1]) * u;
            var sym = marbles[m].symmetry;
            var back = ((0 - plan.endAngle) % sym + sym * 1.5) % sym - sym / 2;
            pose.a = plan.endAngle + back * ease(u * 1.2);
        }
        pose.y += plan.radius - lookup(plan.downs[m], pose.a);
        var sinceCatch = local - plan.runTime;
        if (sinceCatch > -cupLead || local < cupLead) {
            var lifted = sinceCatch > -cupLead ? sinceCatch : local + plan.ride;
            pose.cup = plan.rideFrom[1] + plan.radius - plan.speed * lifted;
        }
        result.push(pose);
    }
    return result;
}

function nods(plan, phase) {
    var result = [];
    for (var i = 0; i < plan.ramps.length; ++i) result.push(0);
    var now = phase * loopSeconds;
    for (var m = 0; m < MARBLES; ++m) {
        var local = ((now + m * plan.period / MARBLES) % plan.period + plan.period) % plan.period;
        for (var h = 0; h < plan.hits.length; ++h) {
            var hit = plan.hits[h];
            var since = local - hit.time;
            if (since >= 0 && since < 2.5) {
                result[hit.post] += 26 * hit.strength * Math.exp(-since * 2.2) * Math.sin(since * 16);
            }
        }
    }
    return result;
}
