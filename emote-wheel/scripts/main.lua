-- Emote wheel: hold a key (G) or a controller button (D-pad down) for a ring of your cat's emotes and the
-- game's photo-mode poses. Point at one with the mouse or the right stick and let go to play it; let go in
-- the middle to close it without playing anything. While the wheel is open the world holds still, as in
-- photo mode, so the camera doesn't turn with the mouse.
--
-- The ring is drawn with WCModsDraw in the game's own UI, from the cat maker's art: its round slots, the
-- gold ring it puts round the chosen one, its sitting-cat icon for the poses, and the paw for emotes.
-- Emotes are every mod's animations.json emotes (WCModsAnims, through Game.anims); poses are the game's
-- 14 photo-mode poses (A_CatMaster_Pose_Photo_Mode_1..14), held until the cat moves. More than fit on
-- one ring go on more pages: 1 and 2, the mouse wheel, or LB and RB turn them.
local okDraw, Draw = pcall(require, "WCModsDraw")
if not okDraw then
    MOD.log("WCModsDraw didn't load, so there's no wheel to draw: %s", tostring(Draw))
    return
end
if not Game then
    MOD.log("WCModsGame didn't load, so the wheel can't play anything")
    return
end

local S = MOD.settings
local function setting(name, default)
    local v = S[name]
    if v == nil then return default end
    return v
end

local UI = "/Game/Art/UXD/Textures/"
local function tex(folder, name) return UI .. folder .. "/" .. name .. "." .. name end
local ART = {
    base = tex("gui_screens/gui_screens_customization", "T_UI_Customization_CategoryBase_D"),
    slot = tex("gui_screens/gui_screens_customization", "T_UI_Customization_CategoryBase_Normal_D"),
    ring = tex("gui_screens/gui_screens_customization", "T_UI_Customization_CategoryBase_Border_D"),
    paw = tex("gui_icons/gui_icons_popups", "T_UI_Icon_Popup_Reward_Paw"),
    catChosen = tex("gui_icons/gui_icons_customization", "T_UI_Icon_Customization_CatsNatureSelected_D"),
}
local POSES = 14
local POSE_PATH = "/Game/Art/Characters/CatMaster/Animations/PhotoMode/A_CatMaster_Pose_Photo_Mode_%d.A_CatMaster_Pose_Photo_Mode_%d"
-- The poses' names when the game's string table can't be read (Strings_EN.csv, STR_PHOTOMODE_POSE_n).
local POSE_NAMES = { "Feral Frenzy", "Loafing Lunar", "Yoga Master", "Biiiiiig Stretch", "Polished Paws",
                     "Cosmic Stare", "Scritch-Scratch", "Shadow Sneak", "Floof Nap", "Spicy Mood", "Belly Trap",
                     "Twitchy Sleeper", "Zoomie Mode", "Side-Eye Void" }
local PER_RING = 8         -- emotes a ring
local POSES_PER_RING = 7   -- the 14 poses make two even rings
local MOVING = 40          -- cm a second: faster than this is walking, which ends what's playing
local GRACE = 0.5          -- seconds after something starts before walking ends it
local DEAD = 0.3           -- how far from the middle (of the ring's radius) points at nothing
local NEXT_PAGE = { "Two", "MouseScrollDown", "Gamepad_RightShoulder" }
local PREVIOUS_PAGE = { "One", "MouseScrollUp", "Gamepad_LeftShoulder" }

local function log(fmt, ...) MOD.log(fmt, ...) end
local function valid(o) return o ~= nil and type(o) == "userdata" and o.IsValid ~= nil and o:IsValid() end

-- ---------------------------------------------------------------------------------------- what's on it
local function poseName(n)
    local ok, text = pcall(function()
        local lib = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
        return lib:TextFromStringTable(FName("SwtStrings"), "STR_PHOTOMODE_POSE_" .. n):ToString()
    end)
    if ok and type(text) == "string" and text ~= "" and not text:find("MISSING") then return text end
    return POSE_NAMES[n]
end

-- The rings: { { title, items = { { kind, name, id or path, icon, iconChosen } } } }.
local function buildPages()
    local pages = {}
    local anims = Game.anims.list()
    local emotes = {}
    for id, a in pairs(anims) do
        if a.emote and (a.kind or "cat") == "cat" then emotes[#emotes + 1] = { kind = "emote", id = id, name = a.name or id } end
    end
    table.sort(emotes, function(a, b) return a.name:lower() < b.name:lower() end)
    for i = 1, #emotes, PER_RING do
        local items = {}
        for j = i, math.min(i + PER_RING - 1, #emotes) do
            emotes[j].icon, emotes[j].iconChosen = ART.paw, ART.paw
            items[#items + 1] = emotes[j]
        end
        pages[#pages + 1] = { title = "Emotes", items = items }
    end
    if setting("poses", true) then
        for first = 1, POSES, POSES_PER_RING do
            local items = {}
            for n = first, math.min(first + POSES_PER_RING - 1, POSES) do
                -- The white sitting cat (the cat maker's chosen one): its plain one is too dark on the slots.
                items[#items + 1] = { kind = "pose", n = n, name = poseName(n), path = POSE_PATH:format(n, n),
                                      icon = ART.catChosen, iconChosen = ART.catChosen }
            end
            pages[#pages + 1] = { title = "Poses", items = items }
        end
    end
    -- Number the titles when a kind has several rings: "Poses 1/2".
    local count, seen = {}, {}
    for _, p in ipairs(pages) do count[p.title] = (count[p.title] or 0) + 1 end
    for _, p in ipairs(pages) do
        if count[p.title] > 1 then
            seen[p.title] = (seen[p.title] or 0) + 1
            p.label = string.format("%s %d/%d", p.title, seen[p.title], count[p.title])
        else
            p.label = p.title
        end
    end
    return pages
end

-- ------------------------------------------------------------------------------------ playing and ending
local playing, startedAt = nil, 0     -- the item playing, and when it started

local function stop()
    if playing then Game.anims.stop() end
    playing = nil
end

local function play(item)
    if playing and playing.name == item.name and Game.anims.playing() then
        stop()                        -- choosing what's playing again ends it
        return
    end
    local montage, why
    if item.kind == "emote" then
        montage, why = Game.anims.play(nil, item.id)
    else
        montage, why = Game.anims.play(nil, item.path, { loop = true, blend = 0.3 })
    end
    if not montage then
        log("%s: %s", item.name, tostring(why))
        playing = nil
        return
    end
    playing, startedAt = item, os.clock()
end

-- Walking off ends what the wheel started; something that ended by itself is forgotten.
Game.every(0.15, function()
    if not playing then return end
    if not Game.anims.playing() then
        playing = nil
        return
    end
    if os.clock() - startedAt < GRACE then return end
    local cat = Game.player()
    if not cat then return end
    local ok, v = pcall(function() return cat:GetVelocity() end)
    if ok and v and (v.X or 0) ^ 2 + (v.Y or 0) ^ 2 > MOVING * MOVING then stop() end
end)

-- ------------------------------------------------------------------------------------------- the wheel
local wheel = nil   -- while open: { pages, page, key, x, y, chosen, paused }

local function analog(pc, key)
    local ok, v = pcall(function() return pc:GetInputAnalogKeyState({ KeyName = FName(key) }) end)
    return ok and type(v) == "number" and v or 0
end

local function anyPressed(keys)
    for _, k in ipairs(keys) do if Game.pressed(k) then return true end end
    return false
end

local function setPaused(on)
    local ok, err = pcall(function()
        StaticFindObject("/Script/Engine.Default__GameplayStatics"):SetGamePaused(Game.controller(), on)
    end)
    if not ok then log("couldn't %s the game: %s", on and "pause" or "unpause", tostring(err)) end
    return ok
end

local function canOpen()
    if not Game.player() or not Game.controller() then return false end
    local okMenu, Menu = pcall(require, "WCModsMenu")
    if okMenu and Menu.isOpen and Menu.isOpen() then return false end
    local ok, shown = pcall(Game.screens)
    if ok and shown and #shown > 0 then return false end      -- the inventory, the map, a fight, a dialogue...
    local okP, paused = pcall(function()
        return StaticFindObject("/Script/Engine.Default__GameplayStatics"):IsGamePaused(Game.controller())
    end)
    return not (okP and paused)
end

local function open(key)
    local pages = buildPages()
    if #pages == 0 then
        log("nothing to put on the wheel: no emotes installed, and poses are off")
        return
    end
    if not canOpen() then return end
    wheel = { pages = pages, page = 1, key = key, x = 0, y = 0, chosen = nil, paused = false }
    if setting("pause", true) then wheel.paused = setPaused(true) end
end

local function close(playChosen)
    local w = wheel
    wheel = nil
    if not w then return end
    if w.paused then setPaused(false) end
    if playChosen and w.chosen then
        local item = w.pages[w.page].items[w.chosen]
        -- After unpausing, so the montage starts in a running world.
        Game.after(0.05, function() play(item) end)
    end
end

-- Which item a direction points at: item 1 straight up, then clockwise.
local function pointedAt(x, y, n)
    if x * x + y * y < DEAD * DEAD then return nil end
    local angle = math.deg(math.atan(y, x)) + 90      -- 0 = up, clockwise (y grows downward)
    local step = 360 / n
    return math.floor(((angle + step / 2) % 360) / step) + 1
end

Game.onFrame(function()
    if not wheel then
        local keys = { setting("key", "G"), setting("pad", "Gamepad_DPad_Down") }
        for _, k in ipairs(keys) do
            if k and k ~= "" and Game.pressed(k) then
                open(k)
                return
            end
        end
        return
    end
    local pc = Game.controller()
    if not pc then
        close(false)
        return
    end
    if not Game.keyDown(wheel.key) then
        close(true)                           -- let go: play what's pointed at, if anything
        return
    end
    if Game.pressed("LeftMouseButton") then   -- or click it
        close(true)
        return
    end
    local pages = wheel.pages
    if anyPressed(NEXT_PAGE) then
        wheel.page, wheel.x, wheel.y = wheel.page % #pages + 1, 0, 0
    elseif anyPressed(PREVIOUS_PAGE) then
        wheel.page, wheel.x, wheel.y = (wheel.page - 2) % #pages + 1, 0, 0
    end
    -- The mouse moves a pointer from the middle (screen up is the mouse's +Y); the right stick points
    -- straight at a direction, and wins while it's pushed.
    local sens = tonumber(setting("mouse", 1)) or 1
    wheel.x = wheel.x + analog(pc, "MouseX") * 0.04 * sens
    wheel.y = wheel.y - analog(pc, "MouseY") * 0.04 * sens
    local len = math.sqrt(wheel.x ^ 2 + wheel.y ^ 2)
    if len > 1 then wheel.x, wheel.y = wheel.x / len, wheel.y / len end
    local sx, sy = analog(pc, "Gamepad_RightX"), analog(pc, "Gamepad_RightY")
    if sx * sx + sy * sy > 0.16 then wheel.x, wheel.y = sx, -sy end
    -- A test (or another script) can point the wheel through the shared variable "EmoteWheel.point": "x,y".
    local okP, point = pcall(function() return ModRef:GetSharedVariable("EmoteWheel.point") end)
    if okP and type(point) == "string" and point ~= "" then
        local px, py = point:match("^%s*(-?[%d.]+)%s*,%s*(-?[%d.]+)%s*$")
        if px then wheel.x, wheel.y = tonumber(px), tonumber(py) end
    end
    wheel.chosen = pointedAt(wheel.x, wheel.y, #pages[wheel.page].items)
end)

-- --------------------------------------------------------------------------------------------- drawing
Draw.onFrame(function(d)
    local w = wheel
    if not w or d.width <= 0 then return end
    local page = w.pages[w.page]
    local n = #page.items
    local cx, cy = d.width / 2, d.height / 2
    local unit = math.min(d.width, d.height)
    local radius = unit * 0.26
    local size = unit * 0.15                     -- a slot
    local icon = size * 0.5
    -- The cat maker's dark disc behind the ring (its circle fills 56% of the texture).
    local back = (radius + size * 0.75) * 2 / 0.56
    d.rect(cx - back / 2, cy - back / 2, back, back, { texture = ART.base, color = "#ffffffe8" })
    for i, item in ipairs(page.items) do
        local a = math.rad(-90 + (i - 1) * 360 / n)
        local x, y = cx + radius * math.cos(a), cy + radius * math.sin(a)
        local chosen = (i == w.chosen)
        local s = chosen and size * 1.15 or size
        d.rect(x - s / 2, y - s / 2, s, s, { texture = ART.slot })
        if chosen then d.rect(x - s * 0.62, y - s * 0.62, s * 1.24, s * 1.24, { texture = ART.ring }) end
        local i_ = chosen and icon * 1.15 or icon
        d.rect(x - i_ / 2, y - i_ / 2, i_, i_, { texture = chosen and item.iconChosen or item.icon,
                                                  color = chosen and "#ffffff" or "#ffffffb0" })
        d.text(x, y + s / 2 + 4, item.name, { size = math.floor(unit * (chosen and 0.024 or 0.019)), align = "center",
                                              color = chosen and "#ffd36a" or "#f0ece2" })
    end
    -- The middle: the ring's title, what's pointed at, and how to page.
    local chosenItem = w.chosen and page.items[w.chosen]
    d.text(cx, cy - unit * 0.035, page.label, { size = math.floor(unit * 0.022), align = "center", valign = "middle",
                                                 color = "#9fe8dc" })
    d.text(cx, cy + unit * 0.005, chosenItem and chosenItem.name or "", { size = math.floor(unit * 0.03),
                                                                           align = "center", valign = "middle", color = "#ffd36a" })
    if #w.pages > 1 then
        d.text(cx, cy + unit * 0.05, string.format("%d / %d   (1 and 2, the wheel, LB/RB)", w.page, #w.pages),
               { size = math.floor(unit * 0.016), align = "center", valign = "middle", color = "#f0ece2c0" })
    end
end)

-- If the script is reloaded or the game left with the wheel open, don't leave the world paused.
Game.every(1, function()
    if wheel and not Game.player() then close(false) end
end)

MOD.log("ready: hold %s (or %s on a controller) for the wheel", tostring(setting("key", "G")),
        tostring(setting("pad", "Gamepad_DPad_Down")))
