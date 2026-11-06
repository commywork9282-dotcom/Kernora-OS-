.pragma library

function isAddress(value, address) {
    const text = String(value || "").trim();
    if (/^(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(text))
        return true;
    return /^[0-9a-f]{12}$/i.test(text)
        && text.toLowerCase() === String(address || "").replace(/[:-]/g, "").toLowerCase();
}

function deviceName(device) {
    if (!device)
        return "";
    const alias = String(device.name || "").trim();
    const remote = String(device.remoteName || "").trim();
    const address = device.address;
    if (alias && !isAddress(alias, address))
        return alias;
    if (remote && !isAddress(remote, address))
        return remote;
    return "";
}

function compareDevices(a, b) {
    const left = deviceName(a);
    const right = deviceName(b);
    return (Number(!left) - Number(!right))
        || left.localeCompare(right)
        || String(a.address).localeCompare(String(b.address));
}
