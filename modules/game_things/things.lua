ThingsLoaderController = Controller:new()

local filename = nil
local loaded = false

function setFileName(name)
    filename = name
end

function isLoaded()
    return loaded
end

local function tryLoadDatWithFallbacks(datPath)
    if g_things.loadDat(datPath) then
        return true
    end

    local featureFlags = {
        GameSpritesU32,
        GameEnhancedAnimations,
        GameIdleAnimations
    }

    local combinations = {
        { 1 }, { 2 }, { 3 },
        { 1, 2 }, { 1, 3 }, { 2, 3 },
        { 1, 2, 3 }
    }

    for _, combo in ipairs(combinations) do
        for _, idx in ipairs(combo) do
            g_game.enableFeature(featureFlags[idx])
        end

        if g_things.loadDat(datPath) then
            return true
        end
    end

    return false
end

local function load(version)
    local errorList = {}

    if version >= 1281 and not g_game.getFeature(GameLoadSprInsteadProtobuf) then
        local filePath = resolvepath(string.format('/things/%d/', version))
        if not g_things.loadAppearances(filePath) then
            errorList[#errorList + 1] = "Couldn't load assets"
        end
        if not g_things.loadStaticData(filePath) then
            errorList[#errorList + 1] = "Couldn't load staticdata"
        end
    else
        local datPath, sprPath
        if filename then
            datPath = resolvepath('/data/things/' .. filename)
            sprPath = resolvepath('/data/things/' .. filename)
        else
            datPath = resolvepath('/data/things/' .. version .. '/Tibia')
            sprPath = resolvepath('/data/things/' .. version .. '/Tibia')
        end

        g_logger.setLevel(5)
        if not tryLoadDatWithFallbacks(datPath) then
            errorList[#errorList + 1] = tr('Unable to load dat file, please place a valid dat in \'%s.dat\'', datPath)
        end
        g_logger.setLevel(1)

        if not g_sprites.loadSpr(sprPath) then
            errorList[#errorList + 1] = tr('Unable to load spr file, please place a valid spr in \'%s.spr\'', sprPath)
        end

        -- Narutibia hybrid: Tibia.dat/spr 10.98 + appearances.dat 13.x (flag metadata only).
        -- The 13.x protocol parser reads optional bytes (count, podium block, classification,
        -- clock/expire, charges, container types, shader, tooltip, deco kit) based on item-type
        -- flags. The 10.98 .dat lacks these flags for ids > ~10.98 range, so we layer the
        -- appearances.dat on top: existing ids get patched flags, unknown ids get a flags-only
        -- stub. Sprites still come from Tibia.spr 10.98 (missing ids render as null/placeholder).
        local appearancesPath
        if filename then
            appearancesPath = resolvepath('/data/things/appearances')
        else
            appearancesPath = resolvepath('/data/things/' .. version .. '/appearances')
        end
        if g_resources.fileExists(appearancesPath .. '.dat') then
            if not g_things.loadAppearances(appearancesPath) then
                g_logger.warning(string.format("Narutibia: appearances.dat present but failed to load at '%s.dat' — protocol parser may desync for 13.x items.", appearancesPath))
            end
        else
            g_logger.warning(string.format("Narutibia: no appearances.dat at '%s.dat' — running pure 10.98 flags. Server-side 13.x items beyond the 10.98 range will desync the protocol parser.", appearancesPath))
        end
    end

    loaded = #errorList == 0
    if loaded then
        -- loading client files was successful, try to load sounds now
        -- sound files are optional, this means that failing to load them
        -- will not block logging into game
        g_sounds.loadClientFiles(resolvepath(string.format('/sounds/%d/', version)))
        return
    end

    local messageBox = displayErrorBox(tr('Error'), table.concat(errorList, "\n"))
    addEvent(function()
        messageBox:raise()
        messageBox:focus()
    end)

    g_game.setClientVersion(0)
    g_game.setProtocolVersion(0)
end

function ThingsLoaderController:onInit()
    self:registerEvents(g_game, {
        onClientVersionChange = load
    })
end
