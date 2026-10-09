.pragma library

function kind(code) {
    if (code === 0) {
        return "clear";
    }
    if (code === 1 || code === 2) {
        return "partly";
    }
    if (code === 3) {
        return "cloudy";
    }
    if (code === 45 || code === 48) {
        return "fog";
    }
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) {
        return "snow";
    }
    if (code >= 95) {
        return "storm";
    }
    if (code >= 51) {
        return "rain";
    }
    return "cloudy";
}

function icon(kind, day) {
    switch (kind) {
    case "clear":
        return day ? "weather-clear" : "weather-clear-night";
    case "partly":
        return day ? "weather-few-clouds" : "weather-few-clouds-night";
    case "fog":
        return "weather-fog";
    case "rain":
        return "weather-showers";
    case "snow":
        return "weather-snow";
    case "storm":
        return "weather-storm";
    default:
        return "weather-clouds";
    }
}

function shape(kind) {
    switch (kind) {
    case "clear":
        return "sunny";
    case "partly":
        return "cookie12";
    case "fog":
        return "pill";
    case "rain":
        return "clover8";
    case "snow":
        return "flower";
    case "storm":
        return "softBurst";
    default:
        return "puffy";
    }
}
