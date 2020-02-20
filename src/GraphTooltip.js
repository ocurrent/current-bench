import React from "react";
import { equals } from "ramda";

const GraphTooltip = ({ active, payload, label }) => {
  if (active) {
    // const commitRel = payload[0].value;

    const branch = "master";
    const ref = equals(label, 0) ? branch : `${branch}~${-label}`;

    const foo = payload[0].payload;

    const opsPerSec = `${foo.opsPerSec.toPrecision(3)} +- ${(
      foo.opsPerSec - foo.opsPerSecLimit[0]
    ).toPrecision(3)}`;

    return (
      <div className="custom-tooltip">
        <p className="label">{`${ref} : ${payload[0].value}`}</p>
        <p className="label">{`opsPerSec : ${opsPerSec}`}</p>
        <p className="desc">{/* JSON.stringify(payload[1].payload) */}</p>
      </div>
    );
  }

  return null;
};

export default GraphTooltip;
