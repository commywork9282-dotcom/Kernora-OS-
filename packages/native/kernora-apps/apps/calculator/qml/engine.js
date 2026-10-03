// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

.pragma library

function tokenize(text) {
    const tokens = [];
    let i = 0;
    while (i < text.length) {
        const c = text[i];
        if (c === " ") {
            ++i;
            continue;
        }
        if (/[0-9.]/.test(c)) {
            let j = i;
            while (j < text.length && /[0-9.]/.test(text[j])) {
                ++j;
            }
            if (j < text.length && text[j] === "E") {
                let k = j + 1;
                if (text[k] === "-" || text[k] === "+" || text[k] === "−") {
                    ++k;
                }
                if (/[0-9]/.test(text[k] || "")) {
                    while (k < text.length && /[0-9]/.test(text[k])) {
                        ++k;
                    }
                    tokens.push({ type: "number", value: Number(text.slice(i, k).replace("−", "-")) });
                    i = k;
                    continue;
                }
            }
            const literal = text.slice(i, j);
            if ((literal.match(/\./g) || []).length > 1) {
                throw new Error("number");
            }
            tokens.push({ type: "number", value: Number(literal === "." ? "0" : literal) });
            i = j;
            continue;
        }
        const names = ["sin⁻¹", "cos⁻¹", "tan⁻¹", "sin", "cos", "tan", "ln", "log", "√", "π", "e"];
        const name = names.find(n => text.startsWith(n, i));
        if (name) {
            tokens.push(name === "π" || name === "e" ? { type: "constant", value: name } : { type: "function", value: name });
            i += name.length;
            continue;
        }
        if ("+−-×*÷/^()%!".includes(c)) {
            const map = { "-": "−", "*": "×", "/": "÷" };
            tokens.push({ type: "op", value: map[c] || c });
            ++i;
            continue;
        }
        throw new Error("character");
    }
    return tokens;
}

function factorial(n) {
    if (n < 0 || Math.floor(n) !== n) {
        return gamma(n + 1);
    }
    if (n > 170) {
        return Infinity;
    }
    let result = 1;
    for (let k = 2; k <= n; ++k) {
        result *= k;
    }
    return result;
}

function gamma(z) {
    if (z < 0.5) {
        return Math.PI / (Math.sin(Math.PI * z) * gamma(1 - z));
    }
    const g = 7;
    const c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
               -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7];
    z -= 1;
    let x = c[0];
    for (let i = 1; i < g + 2; ++i) {
        x += c[i] / (z + i);
    }
    const t = z + g + 0.5;
    return Math.sqrt(2 * Math.PI) * Math.pow(t, z + 0.5) * Math.exp(-t) * x;
}

function evaluate(text, degrees) {
    const tokens = tokenize(text);
    let pos = 0;
    const peek = () => tokens[pos];
    const take = () => tokens[pos++];
    const isOp = (token, value) => token && token.type === "op" && token.value === value;
    const toRadians = v => degrees ? v * Math.PI / 180 : v;
    const fromRadians = v => degrees ? v * 180 / Math.PI : v;

    function expression() {
        let value = term();
        while (isOp(peek(), "+") || isOp(peek(), "−")) {
            const op = take().value;
            const right = term();
            value = op === "+" ? value + right : value - right;
        }
        return value;
    }
    function startsFactor(token) {
        return token && (token.type === "number" || token.type === "constant" || token.type === "function" || isOp(token, "("));
    }
    function term() {
        let value = unary();
        for (;;) {
            if (isOp(peek(), "×") || isOp(peek(), "÷")) {
                const op = take().value;
                const right = unary();
                value = op === "×" ? value * right : value / right;
            } else if (startsFactor(peek())) {
                value *= unary();
            } else {
                return value;
            }
        }
    }
    function unary() {
        if (isOp(peek(), "−")) {
            take();
            return -unary();
        }
        if (isOp(peek(), "+")) {
            take();
            return unary();
        }
        return power();
    }
    function power() {
        const base = postfix();
        if (isOp(peek(), "^")) {
            take();
            return Math.pow(base, unary());
        }
        return base;
    }
    function postfix() {
        let value = primary();
        for (;;) {
            if (isOp(peek(), "!")) {
                take();
                value = factorial(value);
            } else if (isOp(peek(), "%")) {
                take();
                value = value / 100;
            } else {
                return value;
            }
        }
    }
    function primary() {
        const token = take();
        if (!token) {
            throw new Error("incomplete");
        }
        if (token.type === "number") {
            return token.value;
        }
        if (token.type === "constant") {
            return token.value === "π" ? Math.PI : Math.E;
        }
        if (token.type === "function") {
            const argument = isOp(peek(), "(") ? primary() : unary();
            switch (token.value) {
            case "sin": return Math.sin(toRadians(argument));
            case "cos": return Math.cos(toRadians(argument));
            case "tan": return Math.tan(toRadians(argument));
            case "sin⁻¹": return fromRadians(Math.asin(argument));
            case "cos⁻¹": return fromRadians(Math.acos(argument));
            case "tan⁻¹": return fromRadians(Math.atan(argument));
            case "ln": return Math.log(argument);
            case "log": return Math.log10(argument);
            case "√": return Math.sqrt(argument);
            }
        }
        if (isOp(token, "(")) {
            const value = expression();
            if (isOp(peek(), ")")) {
                take();
            } else if (pos < tokens.length) {
                throw new Error("bracket");
            }
            return value;
        }
        throw new Error("syntax");
    }

    if (tokens.length === 0) {
        return NaN;
    }
    const value = expression();
    if (pos < tokens.length) {
        throw new Error("syntax");
    }
    return value;
}

function format(value, decimalPoint) {
    if (!isFinite(value)) {
        return value > 0 ? "∞" : value < 0 ? "−∞" : "";
    }
    if (Math.abs(value) < 1e-12) {
        value = 0;
    }
    let text;
    const magnitude = Math.abs(value);
    if (magnitude !== 0 && (magnitude >= 1e15 || magnitude < 1e-9)) {
        text = value.toExponential(9).replace(/\.?0+e/, "e").replace("e+", "E").replace("e-", "E−").replace("e", "E");
    } else {
        text = String(Number(value.toPrecision(12)));
    }
    return text.replace("-", "−").replace(".", decimalPoint);
}
