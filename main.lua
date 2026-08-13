-- Kanto Dex Atlas
--
-- A read-only Start-menu tool built entirely on the API-2 public surface.
-- Species and encounter data are read when the screen opens, after every
-- enabled content mod has merged.  This lets the atlas follow encounter
-- overhauls (including All Pokemon Catchable 151) without copying their
-- tables or growing stale when those tables change.

local ATLAS_SCREEN = "KantoDexAtlas"
local DETAIL_SCREEN = "KantoDexAtlasDetail"
local MAP_SCREEN = "KantoDexAtlasMap"

local KANTO_DEX_SIZE = 151

-- Non-random acquisitions that are not represented by Data.encounters.
-- These are stable vanilla Kanto story placements; encounter mods can add a
-- random location for the same species and both sources will be shown.
local SPECIAL = {
  LAPRAS = {
    { mapId = "SILPH_CO_7F", name = "SILPH CO. 7F", kind = "GIFT" },
  },
  PORYGON = {
    { mapId = "GAME_CORNER_PRIZE_ROOM", name = "GAME CORNER", kind = "PRIZE" },
  },
  SNORLAX = {
    { mapId = "ROUTE_12", name = "ROUTE 12", kind = "STATIC" },
    { mapId = "ROUTE_16", name = "ROUTE 16", kind = "STATIC" },
  },
}

local KIND_CODE = {
  GRASS = "G", WATER = "W", OLD_ROD = "R", GOOD_ROD = "R",
  SUPER_ROD = "R", GIFT = "GF", PRIZE = "PR", STATIC = "ST",
}

local function copyArray(source)
  local out = {}
  for i, value in ipairs(source or {}) do out[i] = value end
  return out
end

local function prettyId(id)
  return tostring(id or "UNKNOWN"):gsub("_", " ")
end

local function displayName(name)
  name = tostring(name or "UNKNOWN")
  local replacements = {
    { "POKEMON MANSION", "MANSION" },
    { "POKéMON MANSION", "MANSION" },
    { "CERULEAN CAVE", "CERULEAN" },
    { "VICTORY ROAD", "VICTORY RD" },
    { "SEAFOAM ISLANDS", "SEAFOAM" },
    { "SAFARI ZONE", "SAFARI" },
    { "CINNABAR ISLAND", "CINNABAR" },
  }
  for _, replacement in ipairs(replacements) do
    name = name:gsub(replacement[1], replacement[2])
  end
  return name
end

local function townMapLocations(game)
  local townMap = ((game.data or {}).field or {}).townMap or {}
  return townMap.locations or townMap
end

local function entryCoords(entry)
  if type(entry) ~= "table" then return nil end
  local coords = entry.coords or entry
  return tonumber(coords.x or coords.col), tonumber(coords.y or coords.row)
end

local function mapName(game, mapId)
  local entry = townMapLocations(game)[mapId]
  local floor = tostring(mapId or ""):match("_([B]?%d+F)$")
  if type(entry) == "table" then
    local name = entry.name or entry.label or prettyId(mapId)
    if floor and not tostring(name):find(floor, 1, true) then
      name = name .. " " .. floor
    end
    return name
  end
  return prettyId(mapId)
end

local function speciesRows(mod)
  local rows = {}
  for id, mon in mod.content.pokemon:each() do
    local dex = tonumber(mon.dex)
    if dex and dex >= 1 and dex <= KANTO_DEX_SIZE then
      rows[#rows + 1] = {
        id = id,
        dex = dex,
        name = mon.name or id,
        evolutions = mon.evolutions or {},
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.dex ~= b.dex then return a.dex < b.dex end
    return a.id < b.id
  end)
  return rows
end

local function dexState(game)
  local dex = ((game or {}).save or {}).pokedex or {}
  return dex.seen or {}, dex.owned or {}
end

local function addSource(index, species, source)
  if type(species) ~= "string" then return end
  local rows = index[species]
  if not rows then
    rows = {}
    index[species] = rows
  end

  local key = table.concat({
    tostring(source.kind), tostring(source.mapId), tostring(source.name),
  }, "\0")
  for _, existing in ipairs(rows) do
    if existing._key == key then
      local level = tonumber(source.level)
      if level then
        existing.minLevel = math.min(existing.minLevel or level, level)
        existing.maxLevel = math.max(existing.maxLevel or level, level)
      end
      existing.slots = (existing.slots or 1) + (source.slots or 1)
      return
    end
  end

  local row = {
    _key = key,
    kind = source.kind,
    mapId = source.mapId,
    name = source.name,
    minLevel = tonumber(source.level),
    maxLevel = tonumber(source.level),
    slots = source.slots or 1,
  }
  rows[#rows + 1] = row
end

local function indexRandomEncounters(game, index)
  for mapId, encounter in pairs((game.data or {}).encounters or {}) do
    if type(encounter) == "table" then
      for kind, group in pairs(encounter) do
        if type(group) == "table" then
          for _, slot in ipairs(group.slots or {}) do
            addSource(index, slot.species, {
              kind = tostring(kind):upper(),
              mapId = mapId,
              name = mapName(game, mapId),
              level = slot.level,
            })
          end
        end
      end
    end
  end
end

local function indexFishing(game, index)
  local field = (game.data or {}).field or {}
  local fishing = field.fishing or {}

  -- Old/Good Rod pools are global in Gen 1, so "ANY WATER" is more useful
  -- and more accurate than painting every square on the map.
  for rod, definition in pairs(fishing) do
    if type(definition) == "table" then
      if type(definition.always) == "table" then
        addSource(index, definition.always.species, {
          kind = rod, name = "ANY WATER", level = definition.always.level,
        })
      end
      for _, slot in ipairs(definition.pool or {}) do
        addSource(index, slot.species, {
          kind = rod, name = "ANY WATER", level = slot.level,
        })
      end
      local perMap = definition.perMap and field[definition.perMap]
      for mapId, slots in pairs(type(perMap) == "table" and perMap or {}) do
        for _, slot in ipairs(slots or {}) do
          addSource(index, slot.species, {
            kind = rod,
            mapId = mapId,
            name = mapName(game, mapId),
            level = slot.level,
          })
        end
      end
    end
  end
end

local function indexSpecials(index)
  for species, rows in pairs(SPECIAL) do
    for _, row in ipairs(rows) do addSource(index, species, row) end
  end
end

local function indexStaticObjects(game, index)
  for mapId, map in pairs((game.data or {}).maps or {}) do
    for _, object in ipairs(type(map) == "table" and (map.objects or {}) or {}) do
      if type(object) == "table" and type(object.pokemon) == "string" then
        addSource(index, object.pokemon, {
          kind = "STATIC",
          mapId = mapId,
          name = mapName(game, mapId),
          level = object.level,
        })
      end
    end
  end
end

local function buildIncoming(rows)
  local incoming = {}
  for _, from in ipairs(rows) do
    for _, evolution in ipairs(from.evolutions or {}) do
      local target = evolution.species
      if type(target) == "string" then
        incoming[target] = incoming[target] or {}
        incoming[target][#incoming[target] + 1] = {
          species = from.id,
          name = from.name,
          method = evolution.method,
          level = evolution.level,
          item = evolution.item,
        }
      end
    end
  end
  return incoming
end

local function sortSources(rows)
  table.sort(rows, function(a, b)
    local an, bn = a.name or "", b.name or ""
    if an ~= bn then return an < bn end
    if a.kind ~= b.kind then return tostring(a.kind) < tostring(b.kind) end
    return tostring(a.mapId or "") < tostring(b.mapId or "")
  end)
end

local function buildAtlas(mod, game)
  local species = speciesRows(mod)
  local sources = {}
  indexRandomEncounters(game, sources)
  indexFishing(game, sources)
  indexStaticObjects(game, sources)
  indexSpecials(sources)
  for _, rows in pairs(sources) do sortSources(rows) end
  return {
    species = species,
    sources = sources,
    incoming = buildIncoming(species),
  }
end

local function acquisitionLabel(source)
  local code = KIND_CODE[source.kind] or tostring(source.kind or "?"):sub(1, 1)
  local level
  if source.minLevel and source.maxLevel then
    level = source.minLevel == source.maxLevel
      and tostring(source.minLevel)
      or (tostring(source.minLevel) .. "-" .. tostring(source.maxLevel))
  end
  if level and #code <= 1 then return code .. level end
  return code
end

local function evolutionLabel(evolution)
  if evolution.method == "LEVEL" and evolution.level then
    return "L" .. tostring(evolution.level)
  elseif evolution.method == "ITEM" then
    return prettyId(evolution.item or "STONE")
  elseif evolution.method == "TRADE" then
    return "TRADE"
  end
  return prettyId(evolution.method or "EVOLVE")
end

local function sourceMapSpecies(atlas, species, visited)
  visited = visited or {}
  if visited[species] then return nil end
  visited[species] = true

  for _, source in ipairs(atlas.sources[species] or {}) do
    if source.mapId or source.name == "ANY WATER" then return species end
  end
  for _, evolution in ipairs(atlas.incoming[species] or {}) do
    local found = sourceMapSpecies(atlas, evolution.species, visited)
    if found then return found end
  end
  return nil
end

local function openAreaMap(mod, game, atlas, species)
  local mapSpecies = sourceMapSpecies(atlas, species)
  if not mapSpecies then return false end
  mod.ui.push(game, MAP_SCREEN, {
    species = species,
    sourceSpecies = mapSpecies,
    atlas = atlas,
  })
  return true
end

local function statusFor(game, species)
  local seen, owned = dexState(game)
  if owned[species] then return "OWNED" end
  if seen[species] then return "SEEN" end
  return "UNSEEN"
end

return function(mod)
  -- Public exports make the read-only index independently testable and let
  -- another UI mod reuse it without reaching into this module's internals.
  mod.exports.buildAtlas = function(game) return buildAtlas(mod, game) end
  mod.exports.specialSources = function(species)
    return copyArray(SPECIAL[species])
  end

  mod.exports.sourceMapSpecies = sourceMapSpecies

  mod.content.screens:register(MAP_SCREEN, {
    new = function(game, opts)
      opts = opts or {}
      local atlas = opts.atlas or buildAtlas(mod, game)
      local sourceSpecies = opts.sourceSpecies
        or sourceMapSpecies(atlas, opts.species)
      local pokemon = (game.data.pokemon or {})[opts.species]
      local title = (pokemon and pokemon.name) or opts.species or "KANTO"
      local tm = ((game.data or {}).field or {}).townMap or {}
      local locations = tm.locations or tm
      local background = tm.background
      local markers, markerSeen = {}, {}

      local function addMarker(mapId)
        local entry = mapId and locations[mapId]
        local x, y = entryCoords(entry)
        if not (x and y) then return end
        local key = tostring(x) .. ":" .. tostring(y)
        if markerSeen[key] then return end
        markerSeen[key] = true
        markers[#markers + 1] = { x = x, y = y }
      end

      for _, source in ipairs(atlas.sources[sourceSpecies] or {}) do
        if source.mapId then
          addMarker(source.mapId)
        elseif source.name == "ANY WATER" then
          -- Gen 1's Old/Good Rod work globally.  The Super Rod table is the
          -- engine's authoritative list of mapped fishable areas, so use its
          -- squares as a readable "any water" illustration instead of
          -- claiming one arbitrary town.
          for mapId in pairs(((game.data or {}).field or {}).superRod or {}) do
            addMarker(mapId)
          end
        end
      end

      local state = {
        game = game,
        markers = markers,
        title = title,
        blink = 0,
        bg = nil,
        isOpaque = true,
      }

      if background and background.map and background.tiles
         and love and love.graphics then
        local ok, image = pcall(love.graphics.newImage, background.tiles.path)
        if ok and image then
          local quads = {}
          local iw, ih = image:getDimensions()
          local across = iw / 8
          for i = 0, across * (ih / 8) - 1 do
            quads[i] = love.graphics.newQuad((i % across) * 8,
              math.floor(i / across) * 8, 8, 8, iw, ih)
          end
          state.bg = { image = image, quads = quads, map = background.map }
        end
      end

      function state:update()
        self.blink = (self.blink + 1) % 32
        local input = self.game.input
        if input:wasPressed("a") or input:wasPressed("b") then
          self.game.stack:pop()
        end
      end

      function state:draw()
        local graphics = love.graphics
        local Font = mod.ui.Font
        graphics.setColor(1, 1, 1, 1)
        graphics.rectangle("fill", 0, 0, 160, 144)

        if self.bg then
          for i, tile in ipairs(self.bg.map) do
            local col = (i - 1) % 20
            local row = math.floor((i - 1) / 20)
            graphics.draw(self.bg.image, self.bg.quads[tile], col * 8, row * 8)
          end
        else
          graphics.setColor(0, 0, 0, 1)
          Font.drawBox(0, 0, 20, 18)
        end

        if self.blink % 16 < 10 then
          graphics.setColor(0, 0, 0, 1)
          for _, marker in ipairs(self.markers) do
            graphics.rectangle("fill", marker.x * 8 + 18,
              marker.y * 8 + 10, 4, 4)
          end
        end

        graphics.setColor(1, 1, 1, 1)
        graphics.rectangle("fill", 0, 0, 160, 8)
        graphics.setColor(0, 0, 0, 1)
        Font.draw(#self.markers > 0
          and (self.title .. " AREA")
          or (self.title .. " AREA UNKNOWN"), 8, 0)
        graphics.setColor(1, 1, 1, 1)
      end

      return state
    end,
  })

  mod.content.screens:register(DETAIL_SCREEN, {
    new = function(game, species)
      local atlas = buildAtlas(mod, game)
      local definition = (game.data.pokemon or {})[species]
      local name = (definition and definition.name) or species
      local items = {}
      local mapSpecies = sourceMapSpecies(atlas, species)

      if mapSpecies then
        items[#items + 1] = {
          label = mapSpecies == species and "AREA MAP" or "SOURCE AREA MAP",
          right = mapSpecies == species and "A" or prettyId(mapSpecies),
          value = { kind = "map" },
        }
      end

      for _, source in ipairs(atlas.sources[species] or {}) do
        items[#items + 1] = {
          label = displayName(source.name),
          right = acquisitionLabel(source),
          value = { kind = "source", source = source },
        }
      end

      for _, evolution in ipairs(atlas.incoming[species] or {}) do
        items[#items + 1] = {
          label = evolution.name,
          right = "E:" .. evolutionLabel(evolution),
          value = { kind = "evolution", species = evolution.species },
        }
      end

      if #items == 0 then
        items[1] = { label = "LOCATION UNKNOWN", right = "-" }
      end

      return mod.ui.ListMenu.new(game, name, items, {
        pageJump = true,
        footer = statusFor(game, species),
        onChoose = function(item)
          local value = item and item.value
          if type(value) ~= "table" then return end
          if value.kind == "map" or value.kind == "source" then
            openAreaMap(mod, game, atlas, species)
          elseif value.kind == "evolution" then
            mod.ui.push(game, DETAIL_SCREEN, value.species)
          end
        end,
      })
    end,
  })

  mod.content.screens:register(ATLAS_SCREEN, {
    new = function(game)
      local atlas = buildAtlas(mod, game)
      local seen, owned = dexState(game)
      local seenCount, ownedCount = 0, 0
      local items = {}

      for _, row in ipairs(atlas.species) do
        local state = owned[row.id] and "O" or (seen[row.id] and "S" or "-")
        if seen[row.id] then seenCount = seenCount + 1 end
        if owned[row.id] then ownedCount = ownedCount + 1 end
        items[#items + 1] = {
          label = ("%03d %s"):format(row.dex, row.name),
          right = state,
          value = row.id,
        }
      end

      return mod.ui.ListMenu.new(game,
        ("ATLAS %d/%d"):format(ownedCount, seenCount), items, {
          pageJump = true,
          keyRepeat = true,
          footer = "O OWN  S SEEN",
          onCancel = function() mod.ui.push(game, "StartMenu") end,
          onChoose = function(item)
            if item and item.value then
              mod.ui.push(game, DETAIL_SCREEN, item.value)
            end
          end,
        })
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    for _, item in ipairs(out) do
      if item.label == "DEX ATLAS" then return out end
    end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "DEX ATLAS",
      onSelect = function() mod.ui.push(game, ATLAS_SCREEN) end,
    })
  end)
end
