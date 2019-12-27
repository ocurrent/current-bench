let reasonReactBlue = "#48a9dc";

// The {j|...|j} feature is just string interpolation, from
// bucklescript.github.io/docs/en/interop-cheatsheet#string-unicode-interpolation
// This allows us to conveniently write CSS, together with variables, by
// constructing a string
let style = {j|
   @import url('https://rsms.me/inter/inter.css');
   html { font-family: 'Inter', sans-serif; }
   @supports (font-variation-settings: normal) {
     html { font-family: 'Inter var', sans-serif; }
   }

   html, body, #root { width: 100%; height: 10000000000% }
   #root {
    display: flex;
    flex-direction: column;
    align-items: center;
   }

  .header {
    width: 100%;
    /* max-width: 600px; */
    text-align: center;
    font-weight: 800;
    border-bottom: 2px dashed lightgray;
    margin-bottom: 2em;
  }

  a {
    text-decoration: none;
    color: inherit;
    border-bottom: medium solid lightgray;
    transition: border-color 500ms;
  }

  a:hover {
    border-color: darkgray;
  }

  .header a {
    text-decoration: none;
    font-size: 95%;
    text-transform: uppercase;
  }

  body {
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  button {
    background-color: white;
    color: $reasonReactBlue;
    box-shadow: 0 0 0 1px $reasonReactBlue;
    border: none;
    padding: 8px;
    font-size: 16px;
  }
  button:active {
    background-color: $reasonReactBlue;
    color: white;
  }
  .container {
    margin: 12px 0px;
    width: 820px;
    border: 1px solid rgb(200, 200, 200);
    border-radius: 8px;
  }
  .containerTitle {
    background-color: rgb(242, 243, 245);
    border-radius: 12px 12px 0px 0px;
    padding: 15px 20px;
    font-weight: bold;
    font-size: 1.3em;
  }
  .containerContent {
    background-color: white;
    padding: 16px;
    border-radius: 0px 0px 12px 12px;
  }

  /*-- Chart --*/
  .c3 svg {
    font: 10px sans-serif;
    -webkit-tap-highlight-color: rgba(0, 0, 0, 0);
  }

  .c3 path, .c3 line {
    fill: none;
    stroke: #000;
  }

  .c3 text {
    -webkit-user-select: none;
    -moz-user-select: none;
    user-select: none;
  }

  .c3-legend-item-tile,
  .c3-xgrid-focus,
  .c3-ygrid,
  .c3-event-rect,
  .c3-bars path {
    shape-rendering: crispEdges;
  }

  .c3-chart-arc path {
    stroke: #fff;
  }

  .c3-chart-arc rect {
    stroke: white;
    stroke-width: 1;
  }

  .c3-chart-arc text {
    fill: #fff;
    font-size: 13px;
  }

  /*-- Axis --*/
  /*-- Grid --*/
  .c3-grid line {
    stroke: #aaa;
  }

  .c3-grid text {
    fill: #aaa;
  }

  .c3-xgrid, .c3-ygrid {
    stroke-dasharray: 3 3;
  }

  /*-- Text on Chart --*/
  .c3-text.c3-empty {
    fill: #808080;
    font-size: 2em;
  }

  /*-- Line --*/
  .c3-line {
    stroke-width: 1px;
  }

  /*-- Point --*/
  .c3-circle {
    fill: currentColor;
  }

  .c3-circle._expanded_ {
    stroke-width: 1px;
    stroke: white;
  }

  .c3-selected-circle {
    fill: white;
    stroke-width: 2px;
  }

  /*-- Bar --*/
  .c3-bar {
    stroke-width: 0;
  }

  .c3-bar._expanded_ {
    fill-opacity: 1;
    fill-opacity: 0.75;
  }

  /*-- Focus --*/
  .c3-target.c3-focused {
    opacity: 1;
  }

  .c3-target.c3-focused path.c3-line, .c3-target.c3-focused path.c3-step {
    stroke-width: 2px;
  }

  .c3-target.c3-defocused {
    opacity: 0.3 !important;
  }

  /*-- Region --*/
  .c3-region {
    fill: steelblue;
    fill-opacity: 0.1;
  }
  .c3-region text {
    fill-opacity: 1;
  }

  /*-- Brush --*/
  .c3-brush .extent {
    fill-opacity: 0.1;
  }

  /*-- Select - Drag --*/
  /*-- Legend --*/
  .c3-legend-item {
    font-size: 12px;
  }

  .c3-legend-item-hidden {
    opacity: 0.15;
  }

  .c3-legend-background {
    opacity: 0.75;
    fill: white;
    stroke: lightgray;
    stroke-width: 1;
  }

  /*-- Title --*/
  .c3-title {
    font: 14px sans-serif;
  }

  /*-- Tooltip --*/
  .c3-tooltip-container {
    z-index: 10;
  }

  .c3-tooltip {
    border-collapse: collapse;
    border-spacing: 0;
    background-color: #fff;
    empty-cells: show;
    -webkit-box-shadow: 7px 7px 12px -9px #777777;
    -moz-box-shadow: 7px 7px 12px -9px #777777;
    box-shadow: 7px 7px 12px -9px #777777;
    opacity: 0.9;
  }

  .c3-tooltip tr {
    border: 1px solid #CCC;
  }

  .c3-tooltip th {
    background-color: #aaa;
    font-size: 14px;
    padding: 2px 5px;
    text-align: left;
    color: #FFF;
  }

  .c3-tooltip td {
    font-size: 13px;
    padding: 3px 6px;
    background-color: #fff;
    border-left: 1px dotted #999;
  }

  .c3-tooltip td > span {
    display: inline-block;
    width: 10px;
    height: 10px;
    margin-right: 6px;
  }

  .c3-tooltip .value {
    text-align: right;
  }

  /*-- Area --*/
  .c3-area {
    stroke-width: 0;
    opacity: 0.2;
  }

  /*-- Arc --*/
  .c3-chart-arcs-title {
    dominant-baseline: middle;
    font-size: 1.3em;
  }

  .c3-chart-arcs .c3-chart-arcs-background {
    fill: #e0e0e0;
    stroke: #FFF;
  }

  .c3-chart-arcs .c3-chart-arcs-gauge-unit {
    fill: #000;
    font-size: 16px;
  }

  .c3-chart-arcs .c3-chart-arcs-gauge-max {
    fill: #777;
  }

  .c3-chart-arcs .c3-chart-arcs-gauge-min {
    fill: #777;
  }

  .c3-chart-arc .c3-gauge-value {
    fill: #000;
    /*  font-size: 28px !important;*/
  }

  .c3-chart-arc.c3-target g path {
    opacity: 1;
  }

  .c3-chart-arc.c3-target.c3-focused g path {
    opacity: 1;
  }

  /*-- Zoom --*/
  .c3-drag-zoom.enabled {
    pointer-events: all !important;
    visibility: visible;
  }

  .c3-drag-zoom.disabled {
    pointer-events: none !important;
    visibility: hidden;
  }

  .c3-drag-zoom .extent {
    fill-opacity: 0.1;
  }
|j};
