local MOD_NAME = "[OblivionRenamer]"
local MOD_VERSION = "0.2.0-item-probe-dev"
local INVENTORY_MENU_PAGE = 1
local MAGIC_MENU_PAGE = 2
local MAX_NAME_LENGTH = 80

local TEXT_EDIT_ASSET = "/Game/UI/Legacy/ModalLayer/WBP_LegacyMenu_TextEdit"
local TEXT_EDIT_CLASS = TEXT_EDIT_ASSET .. ".WBP_LegacyMenu_TextEdit_C"
local TEXT_EDIT_SHORT_CLASS = "WBP_LegacyMenu_TextEdit_C"
local OK_HOOK = TEXT_EDIT_CLASS .. ":OnOkButtonClicked"
local BACK_HOOK = TEXT_EDIT_CLASS .. ":OnBackButtonClicked"
local UNDO_PATH = "ue4ss/Mods/OblivionRenamer/undo/last-rename.txt"
local ITEM_PROBE_PATH = "ue4ss/Mods/OblivionRenamer/diagnostics/item-probe.txt"

local UEHelpers = require("UEHelpers")

local active_dialog = nil
local hooks_registered = false

local function log(message)
    print(string.format("%s %s\n", MOD_NAME, message))
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

local function same_object(left, right)
    if not is_valid_object(left) or not is_valid_object(right) then
        return false
    end
    local left_address = safe("left object address", function()
        return left:GetAddress()
    end)
    local right_address = safe("right object address", function()
        return right:GetAddress()
    end)
    return left_address ~= nil and left_address == right_address
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
            ShowSeconds = 5,
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
        return "<invalid>"
    end
    return safe("object full name", function()
        return object:GetFullName()
    end) or "<unknown>"
end

local function get_visible_player_menu_page()
    local player_menu = find_first_valid("VPlayerMenuViewModel")
    if not player_menu then
        return nil
    end

    local visible = safe("player menu visibility", function()
        return player_menu:IsVisible()
    end)
    if visible ~= true then
        return nil
    end
    return safe("player menu page", function()
        return player_menu:GetCurrentPage()
    end)
end

local function get_magic_menu()
    if get_visible_player_menu_page() ~= MAGIC_MENU_PAGE then
        return nil
    end
    return find_first_valid("VMagicMenuViewModel")
end

local function append(lines, value)
    lines[#lines + 1] = tostring(value or "")
end

local function write_lines(path, lines)
    local file, open_error = io.open(path, "w")
    if not file then
        return false, tostring(open_error)
    end
    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()
    return true, nil
end

local function record_value(value)
    local text = tostring(value or "")
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, "\r", "\\r")
    text = string.gsub(text, "\n", "\\n")
    return text
end

local function inspect_saved_name_map(expected_key, selected_name)
    local result = {
        exact_key_count = 0,
        exact_key_value = nil,
        selected_value_count = 0,
        selected_value_keys = {},
    }
    local objects = safe("FindAllOf UserInputTextSaveData for item probe", function()
        return FindAllOf("UserInputTextSaveData")
    end)
    if not objects then
        return result
    end

    for _, object in ipairs(objects) do
        if is_valid_object(object) then
            local map = safe("read UserInputTextsMap for item probe", function()
                return object.UserInputTextsMap
            end)
            if map then
                safe("scan UserInputTextsMap for item probe", function()
                    map:ForEach(function(key_param, value_param)
                        local key = plain_text(key_param:get())
                        local value = plain_text(value_param:get())
                        if expected_key and key == expected_key then
                            result.exact_key_count = result.exact_key_count + 1
                            result.exact_key_value = value
                        end
                        if selected_name and value == selected_name then
                            result.selected_value_count = result.selected_value_count + 1
                            if #result.selected_value_keys < 10 then
                                result.selected_value_keys[#result.selected_value_keys + 1] = key
                            end
                        end
                    end)
                end)
            end
        end
    end
    return result
end

local function probe_highlighted_inventory_item()
    local lines = {
        "Oblivion Renamer enchanted-item discovery report",
        "version=" .. MOD_VERSION,
        "read_only=true",
    }

    if get_visible_player_menu_page() ~= INVENTORY_MENU_PAGE then
        append(lines, "result=inventory-not-open")
        write_lines(ITEM_PROBE_PATH, lines)
        notify("Open Inventory, highlight a custom enchanted item, then press F2.")
        return
    end

    local ui_subsystem = find_first_valid("VAltarUISubsystem")
    local inventory_menu = find_first_valid("VInventoryMenuViewModel")
    if not ui_subsystem or not inventory_menu then
        append(lines, "result=required-view-model-missing")
        write_lines(ITEM_PROBE_PATH, lines)
        notify("The highlighted inventory item could not be inspected.")
        return
    end

    local hovered_form = safe("read hovered inventory form", function()
        return ui_subsystem:GetInventoryHoveredObjectForm()
    end)
    if not is_valid_object(hovered_form) then
        hovered_form = safe("read hovered inventory form property", function()
            return ui_subsystem.InventoryHoveredObjectForm
        end)
    end
    append(lines, "hovered_form=" .. describe_object(hovered_form))
    if not is_valid_object(hovered_form) then
        append(lines, "result=hovered-form-missing")
        write_lines(ITEM_PROBE_PATH, lines)
        notify("No highlighted inventory item was found.")
        return
    end

    local matching_rows = {}
    local items = safe("read current inventory page items", function()
        return inventory_menu:GetCurrentPageItemsInventory()
    end)
    if items then
        safe("scan current inventory page items", function()
            items:ForEach(function(index, item_param)
                local row = item_param:get()
                local row_form = safe("read inventory row form", function()
                    return row.form
                end)
                if same_object(row_form, hovered_form) then
                    matching_rows[#matching_rows + 1] = {
                        index = index,
                        name = plain_text(safe("read inventory row name", function()
                            return row.Name
                        end)),
                        inventory_index = safe("read inventory row index", function()
                            return row.InventoryIndex
                        end),
                    }
                end
            end)
        end)
    end

    append(lines, "matching_row_count=" .. #matching_rows)
    local row = matching_rows[1]
    if row then
        append(lines, "row_array_index=" .. record_value(row.index))
        append(lines, "row_inventory_index=" .. record_value(row.inventory_index))
        append(lines, "row_name=" .. record_value(row.name))
    end

    local form_name = plain_text(safe("read hovered form FullName", function()
        return hovered_form.FullName
    end))
    local form_id = plain_text(safe("read hovered form ID", function()
        return hovered_form:GetHexFormID()
    end))
    local enchanted = safe("read enchanted-object flag", function()
        return hovered_form.bIsEnchantedObject
    end)
    local enchant_save_data = safe("read enchant save data", function()
        return hovered_form.EnchantSaveData
    end)
    local source_form_id = nil
    if is_valid_object(enchant_save_data) then
        source_form_id = safe("read enchant source form ID", function()
            return enchant_save_data.SourceFormID
        end)
    end

    append(lines, "form_id=" .. record_value(form_id))
    append(lines, "form_full_name=" .. record_value(form_name))
    append(lines, "is_enchanted_object=" .. record_value(enchanted))
    append(lines, "enchant_save_data=" .. describe_object(enchant_save_data))
    append(lines, "source_form_id=" .. record_value(source_form_id))

    local saved_names = inspect_saved_name_map(form_name, row and row.name or nil)
    append(lines, "saved_map_exact_key_count=" .. saved_names.exact_key_count)
    append(lines, "saved_map_exact_key_value=" .. record_value(saved_names.exact_key_value))
    append(lines, "saved_map_selected_value_count=" .. saved_names.selected_value_count)
    for index, key in ipairs(saved_names.selected_value_keys) do
        append(lines, string.format("saved_map_selected_value_key_%d=%s", index, record_value(key)))
    end
    append(lines, "result=complete")

    local report_ok, report_error = write_lines(ITEM_PROBE_PATH, lines)
    if not report_ok then
        log("Could not write item probe report: " .. tostring(report_error))
        notify("The item report could not be saved. No game data was changed.")
        return
    end
    log("Wrote read-only item probe for " .. describe_object(hovered_form))
    notify("Item inspected safely. No game data was changed; close the game and tell me.")
end

local function find_saved_name_target(selected_name)
    local result = {
        count = 0,
        save_object = nil,
        key = nil,
    }
    local objects = safe("FindAllOf UserInputTextSaveData", function()
        return FindAllOf("UserInputTextSaveData")
    end)
    if not objects then
        return result
    end

    for _, object in ipairs(objects) do
        if is_valid_object(object) then
            local map = safe("read UserInputTextsMap", function()
                return object.UserInputTextsMap
            end)
            if map then
                safe("scan UserInputTextsMap", function()
                    map:ForEach(function(key_param, value_param)
                        local key = plain_text(key_param:get())
                        local value = plain_text(value_param:get())
                        if key and value == selected_name then
                            result.count = result.count + 1
                            result.save_object = object
                            result.key = key
                        end
                    end)
                end)
            end
        end
    end
    return result
end

local function mutate_saved_name(save_object, key, old_name, new_name)
    if not is_valid_object(save_object) then
        return false, "The saved-name object is no longer available."
    end

    local map = safe("read saved-name map for rename", function()
        return save_object.UserInputTextsMap
    end)
    if not map then
        return false, "The saved-name map is no longer available."
    end

    local matching_entries = 0
    local iteration_ok = safe("verify saved-name map target", function()
        map:ForEach(function(key_param, value_param)
            local current_key = plain_text(key_param:get())
            local current_value = plain_text(value_param:get())
            if current_key == key and current_value == old_name then
                matching_entries = matching_entries + 1
            end
        end)
        return true
    end)

    if not iteration_ok then
        return false, "The saved-name map could not be updated."
    end
    if matching_entries ~= 1 then
        return false, "The original saved name changed before confirmation."
    end

    -- UserInputTextsMap is TMap<FString, FText>. UE4SS's TextProperty setter
    -- requires FText userdata; passing the Lua string directly makes the native
    -- pusher reinterpret it as FText and crashes before pcall can recover.
    local replacement_text = FText(new_name)
    local replace_ok = safe("replace saved-name map entry", function()
        map:Add(key, replacement_text)
        return true
    end)
    if not replace_ok then
        return false, "The saved-name entry could not be replaced."
    end

    local verified_name = safe("verify replaced saved-name entry", function()
        return plain_text(map:Find(key):get())
    end)
    if verified_name ~= new_name then
        local original_text = FText(old_name)
        safe("restore saved-name entry after failed verification", function()
            map:Add(key, original_text)
        end)
        return false, "The saved-name replacement could not be verified."
    end
    return true, nil
end

local function write_undo_record(state, new_name, status)
    local file, open_error = io.open(UNDO_PATH, "w")
    if not file then
        return false, tostring(open_error)
    end

    file:write("Oblivion Renamer undo record\n")
    file:write("version=" .. MOD_VERSION .. "\n")
    file:write("status=" .. record_value(status) .. "\n")
    file:write("entity_kind=" .. record_value(state.entity_kind) .. "\n")
    file:write("localization_key=" .. record_value(state.saved_key) .. "\n")
    file:write("old_name=" .. record_value(state.old_name) .. "\n")
    file:write("new_name=" .. record_value(new_name) .. "\n")
    file:write("form_id=" .. record_value(state.form_id) .. "\n")
    file:write("source_form_id=" .. record_value(state.source_form_id) .. "\n")
    file:write("inventory_index=" .. record_value(state.inventory_index) .. "\n")
    file:write("school=" .. record_value(state.school) .. "\n")
    file:write("type=" .. record_value(state.spell_type) .. "\n")
    file:close()
    return true, nil
end

local function get_dialog_text(state)
    if not state or not is_valid_object(state.text_field) then
        return nil
    end
    return safe("read rename text", function()
        return state.text_field:GetText():ToString()
    end)
end

local function close_dialog(reason)
    local state = active_dialog
    active_dialog = nil
    if not state then
        return
    end

    if is_valid_object(state.widget) then
        safe("deactivate rename dialog", function()
            state.widget:DeactivateWidget()
        end)
        safe("remove rename dialog", function()
            state.widget:RemoveFromParent()
        end)
    end
    log("Rename dialog closed: " .. tostring(reason))
end

local function valid_new_name(name)
    if name == nil then
        return false, "The name field could not be read."
    end
    if string.find(name, "[\r\n]") then
        return false, "Names cannot contain line breaks."
    end
    if string.match(name, "^%s*$") then
        return false, "Enter a name before confirming."
    end

    local length = #name
    if utf8 and utf8.len then
        length = utf8.len(name) or length
    end
    if length > MAX_NAME_LENGTH then
        return false, string.format("Use %d characters or fewer.", MAX_NAME_LENGTH)
    end
    return true, nil
end

local function commit_dialog()
    local state = active_dialog
    if not state then
        return
    end

    local new_name = get_dialog_text(state)
    local name_ok, name_error = valid_new_name(new_name)
    if not name_ok then
        notify(name_error)
        return
    end
    if new_name == state.old_name then
        close_dialog("unchanged")
        notify("The " .. state.entity_label .. " name was not changed.")
        return
    end

    local undo_ok, undo_error = write_undo_record(state, new_name, "pending")
    if not undo_ok then
        notify("Rename cancelled: the safety record could not be written.")
        log("Could not create undo record: " .. tostring(undo_error))
        return
    end

    local changed, change_error = mutate_saved_name(
        state.save_object,
        state.saved_key,
        state.old_name,
        new_name
    )
    if not changed then
        write_undo_record(state, new_name, "not-applied")
        notify("Rename cancelled: " .. tostring(change_error))
        return
    end

    write_undo_record(state, new_name, "applied")
    close_dialog("confirmed")
    notify("Renamed " .. state.entity_label .. " to: " .. new_name .. ". Save the game to keep it.")
    log(string.format("Renamed %s %s => %s (%s)", state.entity_label, state.old_name, new_name, state.saved_key))
end

local function cancel_dialog()
    if not active_dialog then
        return
    end
    local entity_label = active_dialog.entity_label
    close_dialog("cancelled")
    notify(entity_label .. " rename cancelled.")
end

local function hook_context_object(context)
    if context == nil then
        return nil
    end
    return safe("hook context", function()
        return context:get()
    end)
end

local function ensure_dialog_hooks()
    if hooks_registered then
        return true
    end

    local ok_registered = pcall(function()
        RegisterHook(OK_HOOK, function(context)
            local widget = hook_context_object(context)
            if active_dialog and same_object(widget, active_dialog.widget) then
                commit_dialog()
            end
        end)
        RegisterHook(BACK_HOOK, function(context)
            local widget = hook_context_object(context)
            if active_dialog and same_object(widget, active_dialog.widget) then
                cancel_dialog()
            end
        end)
    end)
    if not ok_registered then
        log("Could not register the native text-edit button hooks.")
        return false
    end

    hooks_registered = true
    return true
end

local function load_text_edit_class()
    local object_path = TEXT_EDIT_ASSET .. ".WBP_LegacyMenu_TextEdit"
    local load_paths = {
        TEXT_EDIT_CLASS,
        TEXT_EDIT_ASSET .. "_C",
        object_path,
        TEXT_EDIT_ASSET,
    }

    for _, load_path in ipairs(load_paths) do
        local loaded = safe("load native text-edit asset " .. load_path, function()
            return LoadAsset(load_path)
        end)
        if is_valid_object(loaded) then
            log("LoadAsset resolved " .. load_path .. " as " .. describe_object(loaded))
        else
            log("LoadAsset returned no object for " .. load_path)
        end

        local direct = safe("find native text-edit class by full path", function()
            return StaticFindObject(TEXT_EDIT_CLASS)
        end)
        if is_valid_object(direct) then
            log("Resolved native text-edit class directly: " .. describe_object(direct))
            return direct
        end

        local by_short_name = safe("find native text-edit class by short name", function()
            return FindObject("Class", TEXT_EDIT_SHORT_CLASS)
        end)
        if is_valid_object(by_short_name) then
            log("Resolved native text-edit class by short name: " .. describe_object(by_short_name))
            return by_short_name
        end
    end

    local discovered = nil
    safe("scan loaded objects for native text-edit class", function()
        ForEachUObject(function(object)
            if discovered == nil and is_valid_object(object) then
                local short_name = safe("loaded object short name", function()
                    return object:GetFName():ToString()
                end)
                if short_name == TEXT_EDIT_SHORT_CLASS then
                    discovered = object
                end
            end
        end)
    end)
    if is_valid_object(discovered) then
        log("Resolved native text-edit class through the loaded-object registry: " .. describe_object(discovered))
        return discovered
    end

    log("Native text-edit class was not present after all load and lookup forms.")
    return nil
end

local function create_text_edit_widget(widget_class)
    local player_controller = safe("get player controller", function()
        return UEHelpers.GetPlayerController()
    end)
    if not is_valid_object(player_controller) then
        return nil
    end

    local widget_library = safe("find WidgetBlueprintLibrary", function()
        return StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    end)
    if not is_valid_object(widget_library) then
        return nil
    end

    local widget = safe("create native text-edit widget", function()
        return widget_library:Create(player_controller, widget_class, player_controller)
    end)
    if not is_valid_object(widget) then
        return nil
    end
    return widget
end

local function set_up_text_edit_widget(state)
    local prompt = safe("read text-edit prompt widget", function()
        return state.widget.textedit_prompt
    end)
    local text_field = safe("read text-edit input widget", function()
        return state.widget.textedit_text
    end)
    if not is_valid_object(text_field) then
        return false
    end
    state.text_field = text_field

    if is_valid_object(prompt) then
        safe("set rename prompt", function()
            prompt:SetText(FText(state.prompt))
        end)
    end
    safe("set current spell name", function()
        text_field:SetText(FText(state.old_name))
    end)
    safe("add rename dialog to viewport", function()
        state.widget:AddToViewport(10000)
    end)
    safe("activate rename dialog", function()
        state.widget:ActivateWidget()
    end)
    safe("focus rename text field", function()
        text_field:SetFocus()
    end)
    safe("give rename field keyboard focus", function()
        text_field:SetKeyboardFocus()
    end)
    return true
end

local function open_spell_rename_dialog()
    if active_dialog then
        notify("A rename is already open.")
        return
    end

    local magic_menu = get_magic_menu()
    if not magic_menu then
        notify("Open Magic, highlight a custom spell, then press F2.")
        return
    end

    local spell = safe("read highlighted spell", function()
        return magic_menu:GetCurrentSpellEquiped()
    end)
    if spell == nil then
        notify("No highlighted spell was found.")
        return
    end
    local selected_name = safe("read highlighted spell name", function()
        return spell.Name:ToString()
    end)
    if not selected_name then
        notify("The highlighted spell name could not be read.")
        return
    end

    local target = find_saved_name_target(selected_name)
    if target.count == 0 then
        notify("Only player-created spells can be renamed.")
        return
    end
    if target.count ~= 1 then
        notify("This name is shared by multiple custom entries; rename cancelled for safety.")
        return
    end

    local widget_class = load_text_edit_class()
    if not widget_class then
        notify("The in-game rename screen could not be loaded.")
        return
    end
    if not ensure_dialog_hooks() then
        notify("The in-game rename buttons could not be connected.")
        return
    end

    local widget = create_text_edit_widget(widget_class)
    if not widget then
        notify("The in-game rename screen could not be created.")
        return
    end

    local state = {
        widget = widget,
        text_field = nil,
        entity_kind = "custom-spell",
        entity_label = "spell",
        prompt = "Rename custom spell",
        save_object = target.save_object,
        saved_key = target.key,
        old_name = selected_name,
        inventory_index = spell.InventoryIndex,
        school = spell.School,
        spell_type = spell.Type,
    }
    active_dialog = state
    if not set_up_text_edit_widget(state) then
        close_dialog("setup failed")
        notify("The in-game name field could not be initialized.")
        return
    end

    ExecuteWithDelay(100, function()
        if active_dialog == state and is_valid_object(state.text_field) then
            safe("restore rename field focus", function()
                state.text_field:SetFocus()
                state.text_field:SetKeyboardFocus()
            end)
        end
    end)
    log("Opened the native rename dialog for: " .. selected_name)
end

local function handle_rename_key()
    local page = get_visible_player_menu_page()
    if page == MAGIC_MENU_PAGE then
        open_spell_rename_dialog()
    elseif page == INVENTORY_MENU_PAGE then
        probe_highlighted_inventory_item()
    else
        notify("Open Magic or Inventory, highlight a custom creation, then press F2.")
    end
end

RegisterKeyBind(Key.F2, function()
    ExecuteInGameThread(handle_rename_key)
end)

RegisterKeyBind(Key.RETURN, function()
    if active_dialog then
        ExecuteInGameThread(commit_dialog)
    end
end)

RegisterKeyBind(Key.ESCAPE, function()
    if active_dialog then
        ExecuteInGameThread(cancel_dialog)
    end
end)

log("Loaded " .. MOD_VERSION .. ". F2 renames custom spells and safely inspects enchanted items.")
