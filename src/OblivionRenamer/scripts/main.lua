local MOD_NAME = "[OblivionRenamer]"
local OUTPUT_PATH = "ue4ss/Mods/OblivionRenamer/diagnostics/latest.txt"
local MAGIC_MENU_PAGE = 2
local PROBE_VERSION = "0.0.2"

local VALUE_KEYWORDS = {
    "name", "text", "form", "spell", "editor", "record", "custom", "type", "index", "id"
}

local CLASS_KEYWORDS = {
    "spell", "magic", "inventory", "form", "enchant", "item", "player", "menu", "save"
}

local FUNCTION_KEYWORDS = {
    "rename", "name", "text", "spell", "magic", "inventory", "form", "enchant", "hover",
    "save", "custom", "create", "clone", "copy", "add", "remove", "delete", "replace", "update"
}

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

local function contains_any(value, keywords)
    local lower = string.lower(value or "")
    for _, keyword in ipairs(keywords) do
        if string.find(lower, keyword, 1, true) then
            return true
        end
    end
    return false
end

local function is_valid_object(value)
    if value == nil or type(value) ~= "userdata" then
        return false
    end

    local valid = safe("object validity", function()
        return value:IsValid()
    end)
    return valid == true
end

local function find_first_valid(short_class_name)
    local objects = FindAllOf(short_class_name)
    if not objects then
        return nil
    end

    for _, object in ipairs(objects) do
        if is_valid_object(object) then
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
    end) or "userdata"

    if is_valid_object(value) then
        local full_name = safe("userdata GetFullName", function()
            return value:GetFullName()
        end)
        local address = safe("userdata GetAddress", function()
            return value:GetAddress()
        end)
        if full_name and address then
            return string.format("%s (type=%s, address=0x%X)", full_name, tostring(ue_type), address)
        elseif full_name then
            return string.format("%s (type=%s)", full_name, tostring(ue_type))
        end
    end

    local text = safe("userdata ToString", function()
        return value:ToString()
    end)
    if text then
        return string.format("%s (%s)", text, tostring(ue_type))
    end

    return string.format("%s (%s)", tostring(value), tostring(ue_type))
end

local function dump_function(lines, func, indent)
    indent = indent or "  "
    local name = safe("function name", function()
        return func:GetFName():ToString()
    end) or "<unknown>"
    local flags = safe("function flags", function()
        return func:GetFunctionFlags()
    end) or 0
    append(lines, string.format("%s%s [flags=0x%X]", indent, name, flags))

    safe("function parameters", function()
        func:ForEachProperty(function(property)
            local property_name = property:GetFName():ToString()
            local property_class = safe("function property class", function()
                return property:GetClass():GetFName():ToString()
            end) or "unknown"
            append(lines, string.format("%s  -> %s [%s]", indent, property_name, property_class))
        end)
    end)
end

local function dump_object(lines, label, object)
    append(lines, "")
    append(lines, "== " .. label .. " ==")
    append(lines, "object: " .. describe_value(object))

    if not is_valid_object(object) then
        append(lines, "No valid UObject was available for this bridge value.")
        return
    end

    local outer = safe(label .. " outer", function()
        return object:GetOuter()
    end)
    append(lines, "outer: " .. describe_value(outer))

    local class = safe(label .. " GetClass", function()
        return object:GetClass()
    end)
    local depth = 0

    while is_valid_object(class) and depth < 16 do
        append(lines, "")
        append(lines, "class: " .. class:GetFullName())
        append(lines, "properties:")
        safe(label .. " class properties", function()
            class:ForEachProperty(function(property)
                local property_name = property:GetFName():ToString()
                local property_class = safe("property class", function()
                    return property:GetClass():GetFName():ToString()
                end) or "unknown"
                local suffix = ""
                if contains_any(property_name, VALUE_KEYWORDS) then
                    local value = safe(label .. " property " .. property_name, function()
                        return object:GetPropertyValue(property_name)
                    end)
                    suffix = " = " .. describe_value(value)
                end
                append(lines, string.format("  %s [%s]%s", property_name, property_class, suffix))
            end)
        end)

        append(lines, "functions:")
        safe(label .. " class functions", function()
            class:ForEachFunction(function(func)
                dump_function(lines, func, "  ")
            end)
        end)

        class = safe(label .. " superclass", function()
            return class:GetSuperStruct()
        end)
        depth = depth + 1
    end
end

local function dump_selected_spell(lines, spell)
    append(lines, "")
    append(lines, "== Selected spell row ==")
    local known_fields = {
        "Name", "Property", "Icon", "Category", "Type", "IsEquiped", "InventoryIndex", "School",
        "EffectValue", "CannotCastReason", "bIsImmuneToSilence", "Count", "bIsFavorite"
    }
    for _, field in ipairs(known_fields) do
        local value = safe("spell field " .. field, function()
            return spell[field]
        end)
        append(lines, string.format("%s: %s", field, describe_value(value)))
    end
end

local function get_bridge_values(ui_subsystem)
    local values = {}
    values.form_property = safe("InventoryHoveredObjectForm property", function()
        return ui_subsystem.InventoryHoveredObjectForm
    end)
    values.form_getter = safe("GetInventoryHoveredObjectForm", function()
        return ui_subsystem:GetInventoryHoveredObjectForm()
    end)
    values.actor_property = safe("InventoryHoveredObjectActor property", function()
        return ui_subsystem.InventoryHoveredObjectActor
    end)
    values.actor_getter = safe("GetInventoryHoveredObjectActor", function()
        return ui_subsystem:GetInventoryHoveredObjectActor()
    end)
    return values
end

local function dump_bridge_values(lines, values)
    append(lines, "")
    append(lines, "== UI bridge snapshot ==")
    append(lines, "InventoryHoveredObjectForm property: " .. describe_value(values.form_property))
    append(lines, "GetInventoryHoveredObjectForm(): " .. describe_value(values.form_getter))
    append(lines, "InventoryHoveredObjectActor property: " .. describe_value(values.actor_property))
    append(lines, "GetInventoryHoveredObjectActor(): " .. describe_value(values.actor_getter))

    local form = is_valid_object(values.form_getter) and values.form_getter or values.form_property
    local actor = is_valid_object(values.actor_getter) and values.actor_getter or values.actor_property
    dump_object(lines, "Underlying hovered form", form)
    if is_valid_object(actor) then
        dump_object(lines, "Underlying hovered actor", actor)
    end
end

local function dump_view_model_bridge_signatures(lines, magic_menu, ui_subsystem)
    append(lines, "")
    append(lines, "== Key bridge function signatures ==")
    local targets = {
        { object = magic_menu, names = { "RegisterSendItemHoverHandler", "GetCurrentSpellEquiped", "SetCurrentSpellEquiped" } },
        { object = ui_subsystem, names = { "GetInventoryHoveredObjectForm", "SetInventoryHoveredObjectForm",
            "GetInventoryHoveredObjectActor", "SetInventoryHoveredObjectActor" } },
    }

    for _, target in ipairs(targets) do
        if is_valid_object(target.object) then
            local class = target.object:GetClass()
            for _, wanted_name in ipairs(target.names) do
                safe("bridge signature " .. wanted_name, function()
                    class:ForEachFunction(function(func)
                        if func:GetFName():ToString() == wanted_name then
                            append(lines, class:GetFullName())
                            dump_function(lines, func, "  ")
                        end
                    end)
                end)
            end
        end
    end
end

local function dump_candidate_altar_apis(lines)
    append(lines, "")
    append(lines, "== Candidate loaded Altar APIs ==")
    append(lines, "Only classes/properties/functions matching rename and persistence keywords are listed.")

    local classes = FindAllOf("Class")
    if not classes then
        append(lines, "FindAllOf(\"Class\") returned no loaded classes.")
        return
    end

    local emitted_classes = 0
    local emitted_functions = 0
    for _, class in ipairs(classes) do
        if emitted_classes >= 250 or emitted_functions >= 1500 then
            append(lines, "Candidate scan stopped at its safety cap.")
            break
        end

        if is_valid_object(class) then
            local full_name = safe("candidate class name", function()
                return class:GetFullName()
            end) or ""
            local lower_name = string.lower(full_name)
            if string.find(lower_name, "/script/altar.", 1, true) and contains_any(lower_name, CLASS_KEYWORDS) then
                local class_lines = {}
                safe("candidate properties", function()
                    class:ForEachProperty(function(property)
                        local property_name = property:GetFName():ToString()
                        if contains_any(property_name, VALUE_KEYWORDS) then
                            local property_class = safe("candidate property class", function()
                                return property:GetClass():GetFName():ToString()
                            end) or "unknown"
                            append(class_lines, string.format("  property %s [%s]", property_name, property_class))
                        end
                    end)
                end)
                safe("candidate functions", function()
                    class:ForEachFunction(function(func)
                        local function_name = func:GetFName():ToString()
                        if contains_any(function_name, FUNCTION_KEYWORDS) then
                            dump_function(class_lines, func, "  function ")
                            emitted_functions = emitted_functions + 1
                        end
                    end)
                end)

                if #class_lines > 0 then
                    append(lines, "")
                    append(lines, full_name)
                    for _, line in ipairs(class_lines) do
                        append(lines, line)
                    end
                    emitted_classes = emitted_classes + 1
                end
            end
        end
    end

    append(lines, "")
    append(lines, string.format("Candidate scan totals: %d classes, %d functions", emitted_classes, emitted_functions))
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

local function write_report(lines)
    local file, open_error = io.open(OUTPUT_PATH, "w")
    if not file then
        log("Could not open diagnostic output: " .. tostring(open_error))
        notify("Bridge probe could not open its diagnostic file. Check UE4SS.log.")
        return false
    end

    file:write(table.concat(lines, "\n"))
    file:write("\n")
    file:close()
    return true
end

local function run_bridge_probe()
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
        return magic_menu:GetCurrentSpellEquiped()
    end)
    if not spell then
        notify("No highlighted spell was found.")
        return
    end

    local ui_subsystem = find_first_valid("VAltarUISubsystem")
    if not ui_subsystem then
        notify("Oblivion Renamer could not find the UI bridge.")
        return
    end

    local lines = {}
    append(lines, "Oblivion Renamer bridge probe " .. PROBE_VERSION)
    append(lines, "This probe is read-only. It does not call hover handlers or change game/save data.")
    dump_selected_spell(lines, spell)
    dump_bridge_values(lines, get_bridge_values(ui_subsystem))
    dump_view_model_bridge_signatures(lines, magic_menu, ui_subsystem)
    dump_candidate_altar_apis(lines)

    if not write_report(lines) then
        return
    end

    local spell_name = safe("selected spell name", function()
        return spell.Name:ToString()
    end) or "selected spell"
    log("Wrote bridge probe for " .. spell_name .. " to " .. OUTPUT_PATH)
    notify("Captured the persistent-record bridge for: " .. spell_name)
end

RegisterKeyBind(Key.F2, function()
    ExecuteAsync(run_bridge_probe)
end)

log("Read-only bridge probe loaded. Highlight a spell in the Magic menu and press F2.")
