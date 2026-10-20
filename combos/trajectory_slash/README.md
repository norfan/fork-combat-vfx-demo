# Trajectory ribbon study

Open `trajectory_slash.tscn` and press F6, or choose Trajectory Slash in the gallery.
Space replays; 2 toggles half speed; Esc returns to the gallery.

One ice-blue overhead diagonal cut, with a deliberately visible pivot. The demo
samples an authored blade pose at 240 Hz, connects each pair of inner/outer blade
points into an indexed triangle strip, and stores breadth/birth time in UVs.
Old geometry narrows towards its outer edge, loses bright colour bands through a
shader, and is deleted at 0.19 action seconds. The newest edge is bright only while
the blade moves. A 3-world-pixel render target supplies the pixel grain.

This is a study of the reference video's construction method, not a recovered
copy of its source or its exact trajectory. The existing crescent renderer remains
available. `advance(delta)` is externally clocked for eventual action integration.
