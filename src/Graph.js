import React from "react";
import { Card, CardContent, Typography } from "@material-ui/core";
import { orange, blue } from "@material-ui/core/colors";
import GraphTooltip from "./GraphTooltip.js";

import {
  ComposedChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  Area
} from "recharts";

const Graph = ({ bench }) => {
  const timeColor = [blue[500], blue[200]];
  const opsPerSecColor = [orange[500], orange[200]];

  return (
    <Card className="App-chart-container">
      <CardContent>
        <Typography variant="h6" component="h2" gutterBottom>
          {bench.name}
        </Typography>
        <ComposedChart
          width={700}
          height={500}
          data={bench.chart}
          margin={{
            top: 5,
            right: 30,
            left: 20,
            bottom: 5
          }}
        >
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="relCommit" />
          <Tooltip content={<GraphTooltip />} />
          <Legend />
          <YAxis yAxisId="time" axisLine={true} />
          <YAxis yAxisId="opsPerSec" orientation="right" axisLine={true} />
          <Area
            yAxisId="time"
            type="monotone"
            dataKey="timeLimit"
            stroke="none"
            fill={timeColor[1]}
            legendType="none"
          />
          <Area
            yAxisId="opsPerSec"
            type="monotone"
            dataKey="opsPerSecLimit"
            stroke="none"
            fill={opsPerSecColor[1]}
            legendType="none"
          />
          <Line
            yAxisId="time"
            type="monotone"
            dataKey="time"
            stroke={timeColor[0]}
          />
          <Line
            yAxisId="opsPerSec"
            type="monotone"
            dataKey="opsPerSec"
            stroke={opsPerSecColor[0]}
          />
        </ComposedChart>
      </CardContent>
    </Card>
  );
};

export default Graph;
