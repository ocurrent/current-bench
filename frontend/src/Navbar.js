import React from "react";

import {
  AppBar,
  Container,
  Toolbar,
  Typography,
  Tooltip,
  IconButton,
} from "@material-ui/core";
import { makeStyles } from "@material-ui/core/styles";

import GitHubIcon from "@material-ui/icons/GitHub";
import HomeIcon from '@material-ui/icons/Home';
import MergeIcon from '@material-ui/icons/MergeType';

const projectUrl = "https://github.com/CraigFe/current-bench";

const useStyles = makeStyles((theme) => ({
  root: {
    flexGrow: 1,
  },
  title: {
    // marginLeft: theme.spacing(2),
    flexGrow: 0,
    display: "none",
    [theme.breakpoints.up("sm")]: {
      display: "block",
    },
  },
}));

const Navbar = ({ title }) => {
  const classes = useStyles();

  return (
    <div className={classes.root}>
      <AppBar position="sticky">
        <Container>
          <Toolbar>
            <Typography className={classes.title} variant="h6" noWrap>
              Benchmarks for{" "}
              <a
                className="App-header-link"
                href="https://github.com/mirage/index"
              >
                {title}
              </a>
            </Typography>
            <div style={{ flexGrow: 1 }} />
                        <Tooltip title={"home"} enterDelay={300}>
              <IconButton
                edge="end"
                component="a"
                color="inherit"
                href="/"
                data-ga-event-category="AppBar"
                data-ga-event-action="home"
              >
                <HomeIcon/>
              </IconButton>
            </Tooltip>

    <Tooltip title={"pull requests"} enterDelay={300}>
              <IconButton
                edge="end"
                component="a"
                color="inherit"
                href="/prs"
                data-ga-event-category="AppBar"
                data-ga-event-action="pull requests"
              >
                <MergeIcon />
              </IconButton>
            </Tooltip>

<Tooltip title={"github"} enterDelay={300}>
              <IconButton
                edge="end"
                component="a"
                color="inherit"
                href={projectUrl}
                data-ga-event-category="AppBar"
                data-ga-event-action="github"
              >
                <GitHubIcon />
              </IconButton>
            </Tooltip>
            


          </Toolbar>
        </Container>
      </AppBar>
    </div>
  );
};

export default Navbar;
