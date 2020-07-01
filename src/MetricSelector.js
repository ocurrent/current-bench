import React from "react";
import { Switch, FormGroup, FormControlLabel } from "@material-ui/core";

import { createMuiTheme, ThemeProvider } from "@material-ui/core/styles";
import { orange, blue, red } from "@material-ui/core/colors";

const MetricSelector = ({ metrics }) => {
  const [state, setState] = React.useState({
    time: true,
    opsPerSec: true,
    mbsPerSec: false
  });

  const handleChange = name => event => {
    setState({ ...state, [name]: event.target.checked });
  };

  const timeTheme = createMuiTheme({
    palette: {
      primary: blue
    }
  });

  const opsPerSecTheme = createMuiTheme({
    palette: {
      primary: orange
    }
  });

  const mbsPerSecTheme = createMuiTheme({
    palette: {
      primary: red
    }
  });
  return (
    <FormGroup row>
      <ThemeProvider theme={timeTheme}>
        <FormControlLabel
          control={
            <Switch
              checked={state.time}
              onChange={handleChange("time")}
              value="time"
              color="primary"
            />
          }
          label="Time"
        />
      </ThemeProvider>
      <ThemeProvider theme={opsPerSecTheme}>
        <FormControlLabel
          control={
            <Switch
              checked={state.opsPerSec}
              onChange={handleChange("opsPerSec")}
              value="opsPerSec"
              color="primary"
            />
          }
          label="Operations per second"
        />
      </ThemeProvider>
     <ThemeProvider theme={mbsPerSecTheme}>
        <FormControlLabel
          control={
            <Switch
              checked={state.mbsPerSec}
              onChange={handleChange("mbsPerSec")}
              value="mbsPerSec"
              color="primary"
            />
          }
          label="Mbs per second"
        />
      </ThemeProvider>
    </FormGroup>
  );
};

export default MetricSelector;
