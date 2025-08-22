A simple and performant graph tool for monitoring float values. Can be useful for debugging physics amongst other things.

## Usage
Call `SFG.start_tracking(selector: Callable)` once in your `_ready()` function to create a graph and begin tracking a float value.
`selector` should be a lambda or function that returns the float value.
