local MOD_NAME = "[OblivionRenamer]"
local OUTPUT_PATH = "ue4ss/Mods/OblivionRenamer/diagnostics/latest.txt"
local MAGIC_MENU_PAGE = 2

local function log(message)
    print(string.format("%s %s\n", MOD_NAME, message))
end

local function append(lines, value)
    table.insert(lines, tostring(value))
end

local function safe(label, callback)
    local ok, value = pcall(callback)
    if ok then
        return value
    end
    log(string.format("%s failed: %s", label, tostring(value)))
    return nil
end

local function find_first_valid(short_class_name)
    local objects = FindAllOf(short_class_name)
    if not objects then
        return nil
    end

    for _, object in ipairs(objects) do
        if object and object:IsValid() then
            return object
        end
    end
    return nil
end

local function notify(message)
    local model = find_first_valid("VHUDSubtitleViewModel")
    if not model then
        log(message)
        return
    end

    safe("notification", function()
        model:AddNotification({
            Text = FText(message),
            ShowSeconds = 4,
            Icon = nil,
            bIsQuest = false,
        })
    end)
end

local function describe_value(value)
    if value == nil then
        return "<nil>"
    end

    local lua_type = type(value)
    if lua_type ~= "userdata" then
        return string.format("%s (%s)", tostring(value), lua_type)
    end

    local ue_type = safe("userdata type", function()
        return value:type()
    end)
    local text = safe("userdata ToString", function()
        return value:ToString()
    end)
    if text then
        return string.format("%s (%s)", text, tostring(ue_type))
    end

    local full_name = safe("userdata GetFullName", function()
        return value:GetFullName()
    end)
    if full_name then
        return string.format("%s (%s)", full_name, tostring(ue_type))
    end

    return string.format("%s (%s)", tostring(value), tostring(ue_type))
end

local function dump_class(lines, label, object)
    append(lines, "")
    append(lines, "== " .. label .. " ==")
    append(lines, "object: " .. describe_value(object))

    local class = safe(label .. " GetClass", function()
        return object:GetClass()
    end)
    local depth = 0

    while class and class:IsValid() and depth < 16 do
        append(lines, "")
        append(lines, "class: " .. class:GetFullName())
        append(lines, "properties:")
        class:ForEachProperty(function(property)
            local property_class = safe("property class", function()
                return property:GetClass():GetFName():ToString()
            end) or "unknown"
            append(lines, string.format("  %s [%s]", property:GetFName():ToString(), property_class))
        end)

        append(lines, "functions:")
        class:ForEachFunction(function(func)
            local flags = safe("function flags", function()
                return func:GetFunctionFlags()
            end) or 0
            append(lines, string.format("  %s [flags=0x%X]", func:GetFName():ToString(), flags))
        end)

        class = class:GetSuperStruct()
        depth = depth + 1
    end
end

local function dump_relevant_structs(lines)
    local structs = FindAllOf("ScriptStruct")
    if not structs then
        append(lines, "")
        append(lines, "No ScriptStruct objects were available.")
        return
    end

    append(lines, "")
    append(lines, "== Relevant loaded script structs ==")
    for _, struct in ipairs(structs) do
        local name = safe("script struct name", function()
            return struct:GetFullName()
        end)
        local lower = name and string.lower(name) or ""
        if string.find(lower, "magicmenu", 1, true)
            or string.find(lower, "magic_menu", 1, true)
            or string.find(lower, "spell", 1, true)
        then
            append(lines, name)
            safe("script struct properties", function()
                struct:ForEachProperty(function(property)
                    append(lines, "  " .. property:GetFName():ToString())
                end)
            end)
        end
    end
end

local function magic_menu_is_open()
    local player_menu = find_first_valid("VPlayerMenuViewModel")
    if not player_menu then
        return false
    end

    local visible = safe("player menu visibility", function()
        return player_menu:IsVisible()
    end)
    local page = safe("player menu page", function()
        return player_menu:GetCurrentPage()
    end)
    return visible == true and page == MAGIC_MENU_PAGE
end

local function run_probe()
    if not magic_menu_is_open() then
        notify("Open the Magic menu, highlight a spell, then press F2.")
        return
    end

    local magic_menu = find_first_valid("VMagicMenuViewModel")
    if not magic_menu then
        notify("Oblivion Renamer could not find the Magic menu view model.")
        return
    end

    local spell = safe("selected spell", function()
        return magic_menu:getCurrentSpellEquiped()
    end)
    if not spell then
        notify("No highlighted spell was found.")
        return
    end

    local lines = {}
    append(lines, "Oblivion Renamer reflection probe 0.0.1")
    append(lines, "This probe is read-only.")
    append(lines, "")
    append(lines, "== Selected spell ==")

    local known_fields = { "Name", "InventoryIndex", "School", "Type", "Count" }
    for _, field in ipairs(known_fields) do
        local value = safe("spell field " .. field, function()
            return spell[field]
        end)
        append(lines, string.format("%s: %s", field, describe_value(value)))
    end

    dump_class(lines, "VMagicMenuViewModel", magic_menu)

    local player_menu = find_first_valid("VPlayerMenuViewModel")
    if player_menu then
        dump_class(lines, "VPlayerMenuViewModel", player_menu)
    end

    local ui_subsystem = find_first_valid("VAltarUISubsystem")
    if ui_subsystem then
        dump_class(lines, "VAltarUISubsystem", ui_subsystem)
    end

    dump_relevant_structs(lines)

    local file, open_error = io.open(OUTPUT_PATH, "w")
    if not file then
        log("Could not open diagnostic output: " .. tostring(open_error))
        notify("Probe failed to open its diagnostic file. Check UE4SS.log.")
        return
    end

    file:write(table.concat(lines, "\n"))
    file:write("\n")
    file:close()

    local spell_name = safe("selected spell name", function()
        return spell.Name:ToString()
    end) or "selected spell"
    log("Wrote reflection probe for " .. spell_name .. " to " .. OUTPUT_PATH)
    notify("Captured spell data for: " .. spell_name)
end

RegisterKeyBind(Key.F2, function()
    ExecuteAsync(run_probe)
end)

log("Read-only probe loaded. Highlight a spell in the Magic menu and press F2.")

