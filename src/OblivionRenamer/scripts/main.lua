local MOD_NAME = "[OblivionRenamer]"
local OUTPUT_PATH = "ue4ss/Mods/OblivionRenamer/diagnostics/latest.txt"
local MAGIC_MENU_PAGE = 2
local PROBE_VERSION = "0.0.4"

local KNOWN_RECORD_CLASSES = {
    "TESMagicItemForm",
    "TESMagicItemObject",
    "SpellItem",
    "MagicItem",
    "MagicItemObject",
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

local function is_valid_object(value)
    if value == nil or type(value) ~= "userdata" then
        return false
    end
    return safe("object validity", function()
        return value:IsValid()
    end) == true
end

local function find_first_valid(short_class_name)
    local objects = safe("FindAllOf " .. short_class_name, function()
        return FindAllOf(short_class_name)
    end)
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

local function plain_text(value)
    if value == nil then
        return nil
    end
    if type(value) == "string" then
        return value
    end
    if type(value) ~= "userdata" then
        return tostring(value)
    end

    return safe("value ToString", function()
        return value:ToString()
    end)
end

local function describe_object(object)
    if not is_valid_object(object) then
        return "<null UObject>"
    end

    local full_name = safe("object full name", function()
        return object:GetFullName()
    end) or "<unknown>"
    local address = safe("object address", function()
        return object:GetAddress()
    end)
    if address then
        return string.format("%s (address=0x%X)", full_name, address)
    end
    return full_name
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
        local text = plain_text(value)
        if text == nil then
            text = tostring(value)
        end
        append(lines, string.format("%s: %s", field, text))
    end
end

local function dump_user_input_map(lines, selected_name)
    append(lines, "")
    append(lines, "== UserInputTextSaveData maps ==")
    local matching_keys = {}
    local objects = safe("FindAllOf UserInputTextSaveData", function()
        return FindAllOf("UserInputTextSaveData")
    end)
    if not objects then
        append(lines, "No UserInputTextSaveData instances were found.")
        return matching_keys
    end

    append(lines, "instance-count: " .. tostring(#objects))
    for object_index, object in ipairs(objects) do
        if is_valid_object(object) then
            append(lines, "")
            append(lines, string.format("instance[%d]: %s", object_index, describe_object(object)))
            local map = safe("read UserInputTextsMap", function()
                return object.UserInputTextsMap
            end)
            if map then
                local entry_count = 0
                local map_ok = safe("iterate UserInputTextsMap", function()
                    map:ForEach(function(key_param, value_param)
                        local key = key_param:get()
                        local value = value_param:get()
                        local key_text = plain_text(key) or tostring(key)
                        local value_text = plain_text(value) or tostring(value)
                        local marker = ""
                        if value_text == selected_name then
                            marker = "  <== SELECTED SPELL NAME"
                            matching_keys[key_text] = true
                        end
                        append(lines, string.format("  %s => %s%s", key_text, value_text, marker))
                        entry_count = entry_count + 1
                    end)
                    return true
                end)
                append(lines, "entry-count: " .. tostring(entry_count))
                if not map_ok then
                    append(lines, "Map iteration was unavailable through this UE4SS build.")
                end
            else
                append(lines, "UserInputTextsMap could not be read.")
            end
        end
    end
    return matching_keys
end

local function class_has_full_name_property(class)
    local current = class
    local depth = 0
    while is_valid_object(current) and depth < 16 do
        local found = false
        safe("inspect class properties", function()
            current:ForEachProperty(function(property)
                if property:GetFName():ToString() == "FullName" then
                    found = true
                    return true
                end
            end)
        end)
        if found then
            return true
        end
        current = safe("inspect superclass", function()
            return current:GetSuperStruct()
        end)
        depth = depth + 1
    end
    return false
end

local function discover_record_classes(lines)
    local class_names = {}
    for _, name in ipairs(KNOWN_RECORD_CLASSES) do
        class_names[name] = true
    end

    append(lines, "")
    append(lines, "== Relevant loaded Altar classes ==")
    ForEachUObject(function(object)
        local full_name = safe("registry object name", function()
            return object:GetFullName()
        end) or ""
        local lower = string.lower(full_name)
        if string.find(lower, "class /script/altar.", 1, true) == 1
            and (string.find(lower, "spell", 1, true)
                or string.find(lower, "magicitem", 1, true)
                or string.find(lower, "userinputtext", 1, true))
        then
            append(lines, full_name)
            local short_name = safe("class short name", function()
                return object:GetFName():ToString()
            end)
            local short_lower = string.lower(short_name or "")
            if short_name and class_has_full_name_property(object)
                and not string.find(short_lower, "viewmodel", 1, true)
                and not string.find(short_lower, "widget", 1, true)
                and not string.find(short_lower, "anim", 1, true)
                and not string.find(short_lower, "projectile", 1, true)
                and not string.find(short_lower, "vfx", 1, true)
            then
                class_names[short_name] = true
            end
        end
    end)
    return class_names
end

local function read_record_field(object, field)
    return safe("record field " .. field, function()
        return object:GetPropertyValue(field)
    end)
end

local function record_matches(full_name, selected_name, matching_keys)
    if not full_name then
        return false
    end
    if full_name == selected_name or matching_keys[full_name] then
        return true
    end
    return string.find(full_name, "UI_UserInputText", 1, true) ~= nil
end

local function dump_record_instances(lines, class_names, selected_name, matching_keys)
    append(lines, "")
    append(lines, "== Candidate legacy spell records ==")
    local emitted = 0

    for short_name, _ in pairs(class_names) do
        local objects = safe("FindAllOf " .. short_name, function()
            return FindAllOf(short_name)
        end)
        if objects then
            local class_matches = 0
            for _, object in ipairs(objects) do
                if is_valid_object(object) then
                    local full_name = plain_text(read_record_field(object, "FullName"))
                    if record_matches(full_name, selected_name, matching_keys) then
                        append(lines, "")
                        append(lines, string.format("class=%s object=%s", short_name, describe_object(object)))
                        append(lines, "FullName: " .. tostring(full_name))
                        for _, field in ipairs({ "m_formID", "m_formEditorID", "m_formType", "m_formFlags" }) do
                            local value = read_record_field(object, field)
                            append(lines, string.format("%s: %s", field, plain_text(value) or tostring(value)))
                        end
                        local hex_id = safe("GetHexFormID", function()
                            return object:GetHexFormID()
                        end)
                        append(lines, "GetHexFormID(): " .. tostring(plain_text(hex_id) or hex_id))
                        if matching_keys[full_name] then
                            append(lines, "MATCH: this record's FullName key resolves to the selected visible name.")
                        end
                        class_matches = class_matches + 1
                        emitted = emitted + 1
                    end
                end
            end
            if class_matches > 0 then
                append(lines, string.format("%s matching-record-count: %d", short_name, class_matches))
            end
        end
    end

    append(lines, "")
    append(lines, "total-matching-records: " .. tostring(emitted))
end

local function write_report(lines)
    local file, open_error = io.open(OUTPUT_PATH, "w")
    if not file then
        log("Could not open diagnostic output: " .. tostring(open_error))
        notify("Localization probe could not open its diagnostic file. Check UE4SS.log.")
        return false
    end

    file:write(table.concat(lines, "\n"))
    file:write("\n")
    file:close()
    return true
end

local function run_localization_probe()
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

    local selected_name = safe("selected spell name", function()
        return spell.Name:ToString()
    end)
    if not selected_name then
        notify("The selected spell name could not be read.")
        return
    end

    local lines = {}
    append(lines, "Oblivion Renamer localization probe " .. PROBE_VERSION)
    append(lines, "This probe is read-only. It does not modify maps, forms, game files, or save data.")
    dump_selected_spell(lines, spell)
    local matching_keys = dump_user_input_map(lines, selected_name)
    local class_names = discover_record_classes(lines)
    dump_record_instances(lines, class_names, selected_name, matching_keys)

    if write_report(lines) then
        log("Wrote localization probe for " .. selected_name .. " to " .. OUTPUT_PATH)
        notify("Captured the saved-name mapping for: " .. selected_name)
    end
end

RegisterKeyBind(Key.F2, function()
    ExecuteAsync(run_localization_probe)
end)

log("Read-only localization probe loaded. Highlight a spell in the Magic menu and press F2.")
