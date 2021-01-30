import React from "react";

function parseBranchInformation(branch, commit) {
  const url_arr = branch.split("/");
  const final_url =
    "//github.com/" + url_arr[0] + "/" + url_arr[1] + "/commit/" + commit;
  return final_url;
}

const GraphTooltip = ({ active, payload, _ }) => {
  if (active && payload != null) {
    const foo = payload[0].payload;
    const branch = `${foo.branch}`;

    const opsPerSec = `${foo.opsPerSec.toPrecision(3)}`;
    const time = `${foo.time.toPrecision(3)}`;
    const mbsPerSec = `${foo.mbsPerSec.toPrecision(3)}`;
    const hash = `${foo.name.substring(0, 6)}`;
    const github = parseBranchInformation(branch, `${foo.name}`);

    const onClick = (github) => {
      window.location.href = github;
      return null;
    };

    return (
      <div onClick={onClick(github)}>
        <div className="custom-tooltip">
          <p className="label">
            <a href={"github"}>{`commit: ${hash}`}</a>
          </p>
          <p className="label">{`opsPerSec : ${opsPerSec}`}</p>
          <p className="label">{`time: ${time}`}</p>
          <p className="label">{`mbsPerSec:${mbsPerSec}`}</p>
        </div>
      </div>
    );
  }

  return null;
};

export default GraphTooltip;
