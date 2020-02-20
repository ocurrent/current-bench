import { mean, sum, map } from "ramda";

function standardDeviation(xs) {
    const mu = mean(xs);
    const variance = sum(map(n => Math.pow(n - mu, 2), xs));

    return Math.sqrt(variance);
}

function randomHash() {
    const length = 40;
    const characters = "0123456789abcdef";
    const charactersLength = characters.length;

    var result = "";
    for (var i = 0; i < length; i++) {
        result += characters.charAt(Math.floor(Math.random() * charactersLength));
    }
    return result;
}

export { standardDeviation, randomHash };
