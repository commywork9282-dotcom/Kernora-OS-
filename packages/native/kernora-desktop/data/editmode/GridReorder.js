/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

var LEFT = 1;
var TOP = 2;
var RIGHT = 4;
var BOTTOM = 8;

function makeGrid(columns, rows) {
    var cells = [];
    for (var x = 0; x < columns; ++x) {
        var column = [];
        for (var y = 0; y < rows; ++y) {
            column.push(false);
        }
        cells.push(column);
    }
    return cells;
}

function mark(grid, rect, value) {
    for (var x = rect.x; x < rect.x + rect.w; ++x) {
        if (x < 0 || x >= grid.length) {
            continue;
        }
        for (var y = rect.y; y < rect.y + rect.h; ++y) {
            if (y >= 0 && y < grid[x].length) {
                grid[x][y] = value;
            }
        }
    }
}

function intersects(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function clone(state) {
    var copy = {};
    for (var id in state) {
        var c = state[id];
        copy[id] = { x: c.x, y: c.y, w: c.w, h: c.h };
    }
    return copy;
}

function occupancy(ctx, state) {
    var grid = makeGrid(ctx.columns, ctx.rows);
    for (var id in state) {
        mark(grid, state[id], true);
    }
    return grid;
}

function sortedIds(state) {
    return Object.keys(state).sort(function (a, b) {
        return state[a].x - state[b].x || state[a].y - state[b].y;
    });
}

function fits(grid, x, y, w, h, block) {
    for (var i = 0; i < w; ++i) {
        for (var j = 0; j < h; ++j) {
            if (grid[x + i][y + j] && (!block || block[i][j])) {
                return false;
            }
        }
    }
    return true;
}

function nearestArea(ctx, pixelX, pixelY, spanX, spanY, grid) {
    var px = pixelX - ctx.cellWidth * (spanX - 1) / 2;
    var py = pixelY - ctx.cellHeight * (spanY - 1) / 2;
    var best = { x: -1, y: -1 };
    var bestDistance = Infinity;
    for (var y = 0; y + spanY <= ctx.rows; ++y) {
        for (var x = 0; x + spanX <= ctx.columns; ++x) {
            if (grid && !fits(grid, x, y, spanX, spanY, null)) {
                continue;
            }
            var distance = Math.hypot((x + 0.5) * ctx.cellWidth - px, (y + 0.5) * ctx.cellHeight - py);
            if (distance <= bestDistance) {
                bestDistance = distance;
                best = { x: x, y: y };
            }
        }
    }
    return best;
}

function directionVector(deltaX, deltaY) {
    var angle = Math.atan(deltaY / deltaX);
    var result = [0, 0];
    if (Math.abs(Math.cos(angle)) > 0.5) {
        result[0] = Math.sign(deltaX);
    }
    if (Math.abs(Math.sin(angle)) > 0.5) {
        result[1] = Math.sign(deltaY);
    }
    return result;
}

function nearestCells(ctx, cellX, cellY, spanX, spanY, direction, grid, block) {
    var best = { x: -1, y: -1 };
    var bestDistance = Infinity;
    var bestScore = -Infinity;
    for (var y = 0; y < ctx.rows - (spanY - 1); ++y) {
        for (var x = 0; x < ctx.columns - (spanX - 1); ++x) {
            if (!fits(grid, x, y, spanX, spanY, block)) {
                continue;
            }
            var distance = Math.hypot(x - cellX, y - cellY);
            var current = directionVector(x - cellX, y - cellY);
            var score = direction[0] * current[0] + direction[1] * current[1];
            if (distance < bestDistance || (distance === bestDistance && score > bestScore)) {
                bestDistance = distance;
                bestScore = score;
                best = { x: x, y: y };
            }
        }
    }
    return best;
}

function bounds(state, ids) {
    var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
    for (var i = 0; i < ids.length; ++i) {
        var c = state[ids[i]];
        left = Math.min(left, c.x);
        top = Math.min(top, c.y);
        right = Math.max(right, c.x + c.w);
        bottom = Math.max(bottom, c.y + c.h);
    }
    return { x: left, y: top, w: right - left, h: bottom - top };
}

function Cluster(ctx, ids, state) {
    this.ctx = ctx;
    this.ids = ids.slice();
    this.state = state;
}

Cluster.prototype.edge = function (which) {
    var size = which === LEFT || which === RIGHT ? this.ctx.rows : this.ctx.columns;
    var edge = [];
    for (var i = 0; i < size; ++i) {
        edge.push(-1);
    }
    for (var k = 0; k < this.ids.length; ++k) {
        var c = this.state[this.ids[k]];
        var j;
        if (which === LEFT) {
            for (j = c.y; j < c.y + c.h; ++j) {
                if (j >= 0 && j < size && (c.x < edge[j] || edge[j] < 0)) {
                    edge[j] = c.x;
                }
            }
        } else if (which === RIGHT) {
            for (j = c.y; j < c.y + c.h; ++j) {
                if (j >= 0 && j < size && c.x + c.w > edge[j]) {
                    edge[j] = c.x + c.w;
                }
            }
        } else if (which === TOP) {
            for (j = c.x; j < c.x + c.w; ++j) {
                if (j >= 0 && j < size && (c.y < edge[j] || edge[j] < 0)) {
                    edge[j] = c.y;
                }
            }
        } else {
            for (j = c.x; j < c.x + c.w; ++j) {
                if (j >= 0 && j < size && c.y + c.h > edge[j]) {
                    edge[j] = c.y + c.h;
                }
            }
        }
    }
    return edge;
};

Cluster.prototype.touching = function (id, which) {
    var c = this.state[id];
    var edge = this.edge(which);
    var start, end, value;
    if (which === LEFT) {
        start = c.y; end = c.y + c.h; value = c.x + c.w;
    } else if (which === RIGHT) {
        start = c.y; end = c.y + c.h; value = c.x;
    } else if (which === TOP) {
        start = c.x; end = c.x + c.w; value = c.y + c.h;
    } else {
        start = c.x; end = c.x + c.w; value = c.y;
    }
    for (var i = start; i < end; ++i) {
        if (i >= 0 && i < edge.length && edge[i] === value) {
            return true;
        }
    }
    return false;
};

Cluster.prototype.shift = function (which, delta) {
    for (var k = 0; k < this.ids.length; ++k) {
        var c = this.state[this.ids[k]];
        if (which === LEFT) {
            c.x -= delta;
        } else if (which === RIGHT) {
            c.x += delta;
        } else if (which === TOP) {
            c.y -= delta;
        } else {
            c.y += delta;
        }
    }
};

function restore(state, saved) {
    for (var id in saved) {
        state[id].x = saved[id].x;
        state[id].y = saved[id].y;
    }
}

function pushViews(ctx, ids, occupied, direction, state, grid) {
    var cluster = new Cluster(ctx, ids, state);
    var rect = bounds(state, cluster.ids);
    var which, distance;
    if (direction[0] < 0) {
        which = LEFT;
        distance = rect.x + rect.w - occupied.x;
    } else if (direction[0] > 0) {
        which = RIGHT;
        distance = occupied.x + occupied.w - rect.x;
    } else if (direction[1] < 0) {
        which = TOP;
        distance = rect.y + rect.h - occupied.y;
    } else {
        which = BOTTOM;
        distance = occupied.y + occupied.h - rect.y;
    }
    if (distance <= 0) {
        return false;
    }
    var k;
    for (k = 0; k < ids.length; ++k) {
        mark(grid, state[ids[k]], false);
    }
    var saved = clone(state);
    var order = Object.keys(state).sort(function (a, b) {
        var l = state[a], r = state[b];
        if (which === LEFT) {
            return r.x + r.w - (l.x + l.w);
        } else if (which === RIGHT) {
            return l.x - r.x;
        } else if (which === TOP) {
            return r.y + r.h - (l.y + l.h);
        }
        return l.y - r.y;
    });
    while (distance > 0) {
        for (k = 0; k < order.length; ++k) {
            var id = order[k];
            if (cluster.ids.indexOf(id) < 0 && cluster.touching(id, which)) {
                cluster.ids.push(id);
                mark(grid, state[id], false);
            }
        }
        distance--;
        cluster.shift(which, 1);
    }
    rect = bounds(state, cluster.ids);
    var found = rect.x >= 0 && rect.x + rect.w <= ctx.columns && rect.y >= 0 && rect.y + rect.h <= ctx.rows;
    if (!found) {
        restore(state, saved);
    }
    for (k = 0; k < cluster.ids.length; ++k) {
        mark(grid, state[cluster.ids[k]], true);
    }
    return found;
}

function attemptPush(ctx, ids, occupied, direction, state, grid) {
    var i, j, temp;
    if (Math.abs(direction[0]) + Math.abs(direction[1]) > 1) {
        for (j = 0; j < 2; ++j) {
            for (i = 1; i >= 0; --i) {
                temp = direction[i];
                direction[i] = 0;
                if (pushViews(ctx, ids, occupied, direction, state, grid)) {
                    return true;
                }
                direction[i] = temp;
            }
            direction[0] = -direction[0];
            direction[1] = -direction[1];
        }
    } else {
        for (j = 0; j < 2; ++j) {
            for (i = 0; i < 2; ++i) {
                if (pushViews(ctx, ids, occupied, direction, state, grid)) {
                    return true;
                }
                direction[0] = -direction[0];
                direction[1] = -direction[1];
            }
            temp = direction[1];
            direction[1] = direction[0];
            direction[0] = temp;
        }
    }
    return false;
}

function addViews(ctx, ids, occupied, direction, state, grid) {
    if (ids.length === 0) {
        return true;
    }
    var rect = bounds(state, ids);
    var k;
    for (k = 0; k < ids.length; ++k) {
        mark(grid, state[ids[k]], false);
    }
    var block = makeGrid(rect.w, rect.h);
    for (k = 0; k < ids.length; ++k) {
        var c = state[ids[k]];
        mark(block, { x: c.x - rect.x, y: c.y - rect.y, w: c.w, h: c.h }, true);
    }
    mark(grid, occupied, true);
    var spot = nearestCells(ctx, rect.x, rect.y, rect.w, rect.h, direction, grid, block);
    var success = false;
    if (spot.x >= 0 && spot.y >= 0) {
        for (k = 0; k < ids.length; ++k) {
            state[ids[k]].x += spot.x - rect.x;
            state[ids[k]].y += spot.y - rect.y;
        }
        success = true;
    }
    for (k = 0; k < ids.length; ++k) {
        mark(grid, state[ids[k]], true);
    }
    return success;
}

function addView(ctx, id, occupied, direction, state, grid) {
    var c = state[id];
    mark(grid, c, false);
    mark(grid, occupied, true);
    var spot = nearestCells(ctx, c.x, c.y, c.w, c.h, direction, grid, null);
    var success = false;
    if (spot.x >= 0 && spot.y >= 0) {
        c.x = spot.x;
        c.y = spot.y;
        success = true;
    }
    mark(grid, c, true);
    return success;
}

function rearrangement(ctx, target, direction, state, grid, result) {
    if (target.x < 0 || target.y < 0) {
        return false;
    }
    var ids = sortedIds(state).filter(function (id) {
        return intersects(target, state[id]);
    });
    result.intersecting = ids;
    if (attemptPush(ctx, ids, target, direction, state, grid)) {
        return true;
    }
    if (addViews(ctx, ids, target, direction, state, grid)) {
        return true;
    }
    for (var k = 0; k < ids.length; ++k) {
        if (!addView(ctx, ids[k], target, direction, state, grid)) {
            return false;
        }
    }
    return true;
}

function dropDirection(ctx, pixelX, pixelY, spanX, spanY) {
    var target = nearestArea(ctx, pixelX, pixelY, spanX, spanY, null);
    var region = { x: target.x, y: target.y, w: spanX, h: spanY };
    var left = region.x, top = region.y, right = region.x + region.w, bottom = region.y + region.h;
    for (var id in ctx.state) {
        var c = ctx.state[id];
        if (intersects(region, c)) {
            left = Math.min(left, c.x);
            top = Math.min(top, c.y);
            right = Math.max(right, c.x + c.w);
            bottom = Math.max(bottom, c.y + c.h);
        }
    }
    var centerX = (left + right) / 2 * ctx.cellWidth;
    var centerY = (top + bottom) / 2 * ctx.cellHeight;
    var deltaX = Math.trunc((centerX - pixelX) / spanX);
    var deltaY = Math.trunc((centerY - pixelY) / spanY);
    if (right - left === ctx.columns || spanX === ctx.columns) {
        deltaX = 0;
    }
    if (bottom - top === ctx.rows || spanY === ctx.rows) {
        deltaY = 0;
    }
    if (deltaX === 0 && deltaY === 0) {
        return [1, 0];
    }
    return directionVector(deltaX, deltaY);
}

function occupied(ctx, rect) {
    for (var id in ctx.state) {
        if (intersects(rect, ctx.state[id])) {
            return true;
        }
    }
    return false;
}

function calculate(ctx, pixelX, pixelY, spanX, spanY) {
    var direction = dropDirection(ctx, pixelX, pixelY, spanX, spanY);
    var target = nearestArea(ctx, pixelX, pixelY, spanX, spanY, null);
    var state = clone(ctx.state);
    var grid = occupancy(ctx, state);
    var result = { intersecting: [] };
    if (rearrangement(ctx, { x: target.x, y: target.y, w: spanX, h: spanY }, direction, state, grid, result)) {
        return { x: target.x, y: target.y, w: spanX, h: spanY, state: state, intersecting: result.intersecting };
    }
    var vacant = nearestArea(ctx, pixelX, pixelY, spanX, spanY, occupancy(ctx, ctx.state));
    if (vacant.x >= 0) {
        return { x: vacant.x, y: vacant.y, w: spanX, h: spanY, state: clone(ctx.state), intersecting: [] };
    }
    return null;
}

function makeRoom(ctx, rect, direction) {
    var state = clone(ctx.state);
    var grid = occupancy(ctx, state);
    var result = { intersecting: [] };
    if (rearrangement(ctx, rect, direction.slice(), state, grid, result)) {
        return { x: rect.x, y: rect.y, w: rect.w, h: rect.h, state: state, intersecting: result.intersecting };
    }
    return null;
}

function spanIncrement(fraction) {
    return Math.abs(fraction) > 0.66 ? Math.round(fraction) : 0;
}

function bound(start, end, moveStart, moveEnd, delta, minSize, maxSize, maxEnd) {
    var outStart = moveStart ? start + delta : start;
    var outEnd = moveEnd ? end + delta : end;
    if (outStart < 0) {
        outStart = 0;
    }
    if (outEnd > maxEnd) {
        outEnd = maxEnd;
    }
    if (outEnd - outStart < minSize) {
        if (moveStart) {
            outStart = outEnd - minSize;
        } else if (moveEnd) {
            outEnd = outStart + minSize;
        }
    }
    if (outEnd - outStart > maxSize) {
        if (moveStart) {
            outStart = outEnd - maxSize;
        } else if (moveEnd) {
            outEnd = outStart + maxSize;
        }
    }
    var change = moveEnd ? (outEnd - outStart) - (end - start) : (end - start) - (outEnd - outStart);
    return { start: outStart, end: outEnd, delta: change };
}
