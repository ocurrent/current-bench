type window
@send external windowOpen: (window, string) => unit = "open"
@val external window: window = "window"
