-- Run from a Gen1Recomp checkout:
--   POKEPORT_DATA_DIR=<generated data> KANTO_DEX_TEST_ROOT=<staging root>
--   luajit <this file>

local engineRoot = os.getenv("KANTO_DEX_ENGINE_ROOT") or "."
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Data = require("src.core.Data")
local Screens = require("src.ui.Screens")

local root = assert(os.getenv("KANTO_DEX_TEST_ROOT"),
  "KANTO_DEX_TEST_ROOT is required")

Data:load()
Screens.invalidate()

local run = T.sdk.loadMods({
  "mods/All_Pokemon_Catchable_151_Mod",
  "mods/kanto_dex_atlas",
}, { data = Data, root = root })

T.eq(#run.errors, 0, "both mods load cleanly (" .. tostring(run.errors[1]) .. ")")

local exports = run.loader.exports.kanto_dex_atlas
T.check(type(exports) == "table", "atlas exports are registered")
T.check(type(exports.buildAtlas) == "function", "atlas builder is exported")
T.check(type(exports.sourceMapSpecies) == "function", "map resolver is exported")

local game = {
  data = Data,
  save = {
    flags = {},
    pokedex = { seen = { PIKACHU = true }, owned = { PIKACHU = true } },
  },
}

local atlas = exports.buildAtlas(game)
T.eq(#atlas.species, 151, "all 151 Kanto species are listed")
T.eq(atlas.species[1].id, "BULBASAUR", "list begins with dex number 001")
T.eq(atlas.species[151].id, "MEW", "list ends with dex number 151")

local function hasSource(species, test)
  for _, source in ipairs(atlas.sources[species] or {}) do
    if test(source) then return true end
  end
  return false
end

T.check(hasSource("BULBASAUR", function(s)
  return s.mapId == "SAFARI_ZONE_EAST" and s.kind == "GRASS"
end), "Wowabox Bulbasaur location is read from the merged encounter table")

T.check(hasSource("RAICHU", function(s)
  return s.mapId == "POWER_PLANT"
end), "Wowabox Raichu location is indexed")

T.check(hasSource("MEW", function(s)
  return s.mapId == "POKEMON_MANSION_B1F"
end), "Wowabox Mew location is indexed")

T.check(hasSource("MAGIKARP", function(s)
  return s.name == "ANY WATER" and s.kind == "OLD_ROD" and s.minLevel == 5
end), "Old Rod global source is indexed")

T.check(hasSource("POLIWAG", function(s)
  return s.name == "ANY WATER" and s.kind == "GOOD_ROD"
end), "Good Rod global source is indexed")

T.check(hasSource("LAPRAS", function(s)
  return s.mapId == "SILPH_CO_7F" and s.kind == "GIFT"
end), "Lapras gift is represented")

T.check(hasSource("PORYGON", function(s)
  return s.mapId == "GAME_CORNER_PRIZE_ROOM" and s.kind == "PRIZE"
end), "Porygon prize is represented")

T.check(hasSource("SNORLAX", function(s) return s.mapId == "ROUTE_12" end)
  and hasSource("SNORLAX", function(s) return s.mapId == "ROUTE_16" end),
  "both Snorlax routes are represented")

T.check(hasSource("MEWTWO", function(s)
  return s.mapId == "CERULEAN_CAVE_B1F" and s.kind == "STATIC"
    and s.minLevel == 70
end), "static map objects are indexed without a hard-coded Mewtwo row")

local venusIncoming = atlas.incoming.VENUSAUR or {}
T.eq(venusIncoming[1] and venusIncoming[1].species, "IVYSAUR",
  "reverse evolution index contains Ivysaur to Venusaur")
T.eq(exports.sourceMapSpecies(atlas, "VENUSAUR"), "BULBASAUR",
  "evolution-only species resolves recursively to its catchable ancestor")

for _, row in ipairs(atlas.species) do
  T.check(exports.sourceMapSpecies(atlas, row.id) ~= nil,
    ("#%03d %s has an acquisition/map source"):format(row.dex, row.id))
end

-- Start-menu injection decorates the downstream list and anchors before SAVE.
local vanilla = {
  { label = "POKEDEX" }, { label = "SAVE" }, { label = "OPTION" },
}
local hooked = Runtime.call("ui.start_menu.items",
  function(_, rows) return rows end, game, vanilla)
T.eq(#hooked, 4, "Start-menu hook adds exactly one row")
T.eq(hooked[2].label, "DEX ATLAS", "DEX ATLAS is anchored before SAVE")
T.eq(hooked[3].label, "SAVE", "vanilla rows retain their order")

-- Registered screens build real, navigable states through the production
-- registry. Graphics are deliberately absent here; the map degrades safely.
Screens.invalidate()
local atlasFactory = Screens.get(game, "KantoDexAtlas")
local list = atlasFactory.new(game)
T.eq(#list.items, 151, "atlas screen contains 151 rows")
T.eq(list.title, "ATLAS 1/1", "atlas screen reports owned/seen counts")
T.eq(list.items[25].right, "O", "owned status is displayed")
T.check(type(list.onCancel) == "function", "B can restore the Start menu")

local detailFactory = Screens.get(game, "KantoDexAtlasDetail")
local detail = detailFactory.new(game, "VENUSAUR")
T.eq(detail.title, "VENUSAUR", "detail screen uses the species name")
T.eq(detail.items[1].label, "SOURCE AREA MAP",
  "evolution-only species exposes its ancestor map")

local mapFactory = Screens.get(game, "KantoDexAtlasMap")
local habitat = mapFactory.new(game, {
  species = "VENUSAUR", sourceSpecies = "BULBASAUR", atlas = atlas,
})
T.check(#habitat.markers > 0, "custom habitat map includes inherited markers")

local fishingMap = mapFactory.new(game, {
  species = "MAGIKARP", sourceSpecies = "MAGIKARP", atlas = atlas,
})
T.check(#fishingMap.markers > 0,
  "global rod encounters use mapped fishable-water locations")

-- Exercise the production draw path with the engine's graphics stub. This
-- catches bad tile, quad, Font, and marker calls without distributing or
-- screenshotting the ROM-generated Town Map asset.
_G.love = require("tests.love_stub")
require("src.render.Font").load(Data)
local renderedMap = mapFactory.new(game, {
  species = "MEW", sourceSpecies = "MEW", atlas = atlas,
})
local drew, drawError = pcall(renderedMap.draw, renderedMap)
T.check(drew, "custom Kanto map draw path is graphics-safe: " .. tostring(drawError))

run.release()
Screens.invalidate()
T.finish("kanto dex atlas")
