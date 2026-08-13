# Kanto Dex Atlas

Kanto Dex Atlas adds a **DEX ATLAS** entry to the Gen1Recomp Start menu.
It is a read-only companion for Red, Blue, and Yellow.

## Features

- Lists all 151 Kanto Pokemon from the beginning, even if they are unseen.
- Shows **O** for owned, **S** for seen, and **-** for unseen.
- Shows every effective grass and water encounter after enabled mods merge.
- Includes Old Rod, Good Rod, Super Rod, gift, prize, static-legendary, and
  evolution acquisition hints.
- Opens Gen1Recomp's real Kanto AREA map and blinks every known location.
- Automatically follows encounter changes made by compatible mods.

The atlas is designed to pair with
[All Pokemon Catchable 151](https://github.com/wowabox/All_Pokemon_Catchable_151_Mod).
That mod is optional: without it, the atlas shows the current vanilla game's
locations; with it, the newly merged encounter locations appear automatically.

## Controls

- **Up/Down**: move one Pokemon or location.
- **Left/Right**: jump one page.
- **A**: open the selected Pokemon, source Pokemon, or AREA map.
- **B**: go back.

On a detail page, `G` means grass, `W` means water, `R` means a fishing
rod, `GF` means gift, `PR` means prize, and `ST` means a static encounter.
Levels are printed after the single-letter encounter code when available.

## Installation

1. In Gen1Recomp, open the puzzle-piece **MODS** screen.
2. Import `kanto_dex_atlas-0.1.0.zip`.
3. Enable **Kanto Dex Atlas**.
4. Enable **All Pokemon Catchable 151** too if you want its expanded tables.
5. Restart Gen1Recomp and launch Red, Blue, or Yellow.

After this release is installed, Gen1Recomp can check
[this mod's GitHub Releases](https://github.com/ScottExplores/gen1recomp-kanto-dex-atlas/releases)
from the puzzle-piece MODS screen and offer later version updates.

## Compatibility and safety

- Mod API 2; tested with Gen1Recomp 0.1.75 and 0.1.80.
- Uses public Start-menu, screen-registry, list-menu, and Town Map APIs.
- Makes no save, Pokemon, encounter, item, or map mutations.
- Does not affect link compatibility.
- Contains no ROM-derived images, data dumps, or copied third-party tables.

## License

MIT. See `LICENSE`.
