# Tests

`atlas_test.lua` runs the production API-2 loader with Kanto Dex Atlas and the
official All Pokemon Catchable 151 v0.3.3 package against an imported Gen 1
dataset. It verifies:

- all 151 species and status rows;
- live Wowabox encounter discovery;
- global and per-map fishing sources;
- map-object static encounters;
- the three non-table gift/prize/Snorlax sources;
- recursive evolution-map resolution;
- complete 151-species acquisition coverage;
- Start-menu composition and all registered screen factories;
- custom map markers, including global rod water markers.

The package does not include the third-party mod or generated game data. The
test runner stages the user's official downloaded ZIP temporarily.
