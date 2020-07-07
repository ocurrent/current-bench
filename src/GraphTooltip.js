import React from "react";
import { equals } from "ramda";

const GraphTooltip = ({ active, payload, label }) => {
  if (active) {
    const branch = "master";
    const ref = equals(label, 0) ? branch : `${branch}~${-label}`;

    const foo = payload[0].payload;

    const opsPerSec = `${foo.opsPerSec.toPrecision(3)}`;
    const time = `${foo.time.toPrecision(3)}`;
    const mbsPerSec = `${foo.mbsPerSec.toPrecision(3)}`;
    const hash = `${foo.name}`;
    return (
      <div className="custom-tooltip">
        <p className="label">{`${ref} : ${payload[0].value}`}</p>
        <p className="label">{`commitHash:${hash}`}</p>
        <p className="label">{`opsPerSec : ${opsPerSec}`}</p>
        <p className="label">{`time: ${time}`}</p>
        <p className="label">{`mbsPerSec:${mbsPerSec}`}</p>
      </div>
    );
  }

  return null;
};

export default GraphTooltip;
