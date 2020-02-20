import React from "react";
import { Switch, FormGroup, FormControlLabel } from "@material-ui/core";

import { createMuiTheme, ThemeProvider } from "@material-ui/core/styles";
import { orange, blue } from "@material-ui/core/colors";

const MetricSelector = ({ metrics }) => {
  const [state, setState] = React.useState({
    time: true,
    opsPerSec: true
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
    </FormGroup>
  );
};

export default MetricSelector;
