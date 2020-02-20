import { equals, multiply, map, reverse, unfold } from "ramda";
import { randomHash } from "./utils.js";

function generateFakeData(lastCommit) {
  function inner([prev, size]) {
    if (equals(size, 0)) return false;

    const delta = (Math.random() - 0.5) * 0.005;
    const delta2 = (Math.random() - 0.5) * 0.1;
    const delta3 = (Math.random() - 0.5) * 0.2;

    const stats = map(({ name, mean, standardDeviation }) => {
      return {
        name: name,
        mean: multiply(mean, 1.02 + delta2) + delta,
        standardDeviation: multiply(standardDeviation, 1 + delta3)
      };
    }, prev.stats);

    const commit = {
      hash: randomHash(),
      stats: stats
    };

    return [commit, [commit, size - 1]];
  }

  const result = reverse(unfold(inner, [lastCommit, 50]));
  return result;
}

export { generateFakeData };
