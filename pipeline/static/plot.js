window.onload = (function () {

  var pr_commit = document.getElementById('pr_commit').textContent;
  var plots = document.getElementsByClassName('current-bench_plot');

  var layout = {
    title: false,
    height: 200,
    margin: {
      l: 50,
      r: 50,
      b: 50,
      t: 1,
      pad: 0
    },

    xaxis: {
      gridcolor: 'rgb(255,255,255)',
      showgrid: true,
      showline: false,
      showticklabels: true,
      tickcolor: 'rgb(125,125,125)',
      ticks: 'outside',
      zeroline: false
    },

    yaxis: {
      showgrid: true,
      showline: false,
      tickcolor: 'rgb(125,125,125)',
      gridcolor: 'rgba(220,220,220,0.5)',
      ticks: 'outside',
      zeroline: false
    },

    paper_bgcolor: "transparent",
    plot_bgcolor: "transparent",

    showlegend: true,
    legend: {
      "orientation": "h",
      x: 1,
      xanchor: 'right',
      yanchor: 'top',
      y: 1.2
    },

    shapes: [
      {
        type: 'line',
        x0: pr_commit,
        x1: pr_commit,
        yref: 'paper',
        y0: 0,
        y1: 1,
        line: {
          color: 'grey',
          width: 1.5,
          dash: 'dot'
        }
      }
    ]
  };

  var config = {
    displayModeBar: false,
    responsive: true
  };

  function go(i) {
    if (i >= plots.length)
      return;

    var plot = plots[i];
    var json = plot.textContent;
    var json = JSON.parse(json);

    var j = i + 1;

    layout.showlegend = json.length > 2;
    Plotly.newPlot(plot.previousSibling, json, layout, config).then(function() {
      setTimeout(function() { go(j); })
    });
  }

  go(0);
});
