# Sample test files #

The `test/samples` folder contains sample files useful for testing the library. Tests will fail if the files listed below are missing or unable to be read. Tests are fed these files with paths relative to project root, ie with `test/samples/` prepended.

## Files ##

* `hello-world.png` – A grayscale, 2×2 PNG file with a zTXt "Description" chunk containing the string "Hello, world!" (no quotes).
* `anim.dmi` – A simple animation made in Dream Maker. Consists of one state, with four directions and two frames. Some icons have hotspots associated. The icons depict arrows and numbers, corresponding to the direction and frame number
* `two-static.dmi` – A simple dmi made in Dream Maker. Contains two states, "left" and "right". Both are static icons depicting the words "left" and "right", respectively.
* `left.png` – Exported version of the "left" state from `two-static.dmi`. Should be identical to the icon in the dmi.
