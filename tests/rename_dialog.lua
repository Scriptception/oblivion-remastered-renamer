-- Run from the repository root with Lua 5.3. These are UE4SS contract doubles,
-- not a substitute for running the exact archive in Oblivion Remastered.
local source_path = arg[1] or "src/OblivionRenamer/scripts/main.lua"
local cases = 0
local function scenario(options, check)
    options = options or {}
    local resources, data = {}, {}
    local game_thread = false
    local queue, delayed, keys, logs, notifications, records = {}, {}, {}, {}, {}, {}
    local native_calls, replacements, dialog, input = 0, 0, nil, nil
    local values = { UI_UserInputText_item = options.old_name or "Fresh enchantment" }
    if options.duplicate then
        values.UI_UserInputText_other = values.UI_UserInputText_item
    end
    local function in_game_thread()
        assert(game_thread, "Unreal access outside the game thread")
    end
    local function object(fields)
        local value = assert(io.tmpfile())
        local original_metatable = debug.getmetatable(value)
        resources[#resources + 1] = { value, original_metatable }
        data[value] = fields or {}
        data[value].IsValid = function()
            in_game_thread()
            return data[value].valid ~= false
        end
        data[value].GetAddress = function()
            in_game_thread()
            return value
        end
        debug.setmetatable(value, {
            __index = function(_, name)
                in_game_thread()
                return data[value][name]
            end,
            __newindex = function(_, name, item)
                in_game_thread()
                data[value][name] = item
            end,
        })
        return value
    end
    local function text(value)
        return object({
            text = value,
            ToString = function()
                in_game_thread()
                return value
            end,
        })
    end
    local function parameter(value)
        return {
            get = function()
                in_game_thread()
                return value
            end,
        }
    end
    local map = {
        ForEach = function(_, callback)
            in_game_thread()
            for key, value in pairs(values) do
                callback(parameter(key), parameter(text(value)))
            end
        end,
        Add = function(_, key, value)
            in_game_thread()
            assert(type(value) == "userdata", "map replacement must be typed FText")
            replacements = replacements + 1
            values[key] = data[value].text
        end,
        Find = function(_, key)
            return parameter(text(values[key]))
        end,
    }
    local save = object({ UserInputTextsMap = map })
    local menu = object({
        IsVisible = function()
            return true
        end,
        GetCurrentPage = function()
            return options.page or 1
        end,
    })
    local form = object({
        bIsEnchantedObject = options.unenchanted ~= true,
        EnchantSaveData = object({ SourceFormID = 123 }),
        FullName = "UI_UserInputText_item",
        GetHexFormID = function()
            return "ff000123"
        end,
    })
    local row = { Name = text(values.UI_UserInputText_item), InventoryIndex = 1 }
    local hovered = object({
        GetProperties = function()
            in_game_thread()
            return row
        end,
    })
    local inventory = object({
        CurrentHoveredItem = hovered,
        CurrentFormID = form,
        ObjectHoveredFormID = form,
        HasFocusedDescendants = function()
            return true
        end,
        IsInViewport = function()
            return false
        end,
    })
    local stale = object({
        CurrentHoveredItem = object({
            GetProperties = function()
                error("Stale row was inspected")
            end,
        }),
        HasFocusedDescendants = function()
            return false
        end,
        IsInViewport = function()
            return false
        end,
    })
    local subtitle = object({
        AddNotification = function(_, notification)
            notifications[#notifications + 1] = data[notification.Text].text
        end,
    })
    local function make_widget(path)
        local fields = {}
        for _, method in ipairs({
            "SetAutoWrapText",
            "SetBrushColor",
            "SetPadding",
            "SetContent",
            "SetClearKeyboardFocusOnCommit",
            "AddToViewport",
            "SetDesiredSizeInViewport",
            "SetAnchorsInViewport",
            "SetAlignmentInViewport",
            "ActivateWidget",
            "DeactivateWidget",
            "SetFocus",
            "SetKeyboardFocus",
        }) do
            fields[method] = function()
                in_game_thread()
                if options.setup_failure and method == "AddToViewport" then
                    error("Setup failed")
                end
            end
        end
        fields.SetText = function(_, value)
            in_game_thread()
            fields.text = data[value].text
        end
        fields.GetText = function()
            in_game_thread()
            return text(fields.text)
        end
        fields.AddChildToVerticalBox = function()
            in_game_thread()
            return make_widget("slot")
        end
        fields.RemoveFromParent = function()
            in_game_thread()
            fields.removed = true
        end
        local widget = object(fields)
        if path == "/Script/UMG.EditableTextBox" then
            input = widget
        end
        return widget
    end
    local library = object({
        Create = function(_, controller, class)
            in_game_thread()
            assert(data[class].path == "/Script/Altar.VAltarWidget", "Legacy text-edit screen must not be created")
            dialog = make_widget("host")
            return dialog
        end,
    })
    local environment = setmetatable({
        Key = { F2 = 1, RETURN = 2, ESCAPE = 3 },
        print = function(message)
            logs[#logs + 1] = message
        end,
        require = function(name)
            assert(name == "UEHelpers")
            return {
                GetPlayerController = function()
                    in_game_thread()
                    return object()
                end,
            }
        end,
        FindAllOf = function(class)
            in_game_thread()
            if class == "VPlayerMenuViewModel" then
                return { menu }
            end
            if class == "VHUDSubtitleViewModel" then
                return { subtitle }
            end
            if class == "UserInputTextSaveData" then
                return { save }
            end
            if class == "WBP_OriginalMenu_Inventory_C" then
                return { stale, inventory }
            end
            if class == "WBP_ModernMenu_MagicMenu_C" then
                return { inventory }
            end
            error("Unexpected class lookup: " .. class)
        end,
        StaticFindObject = function(path)
            in_game_thread()
            if path == "/Script/UMG.Default__WidgetBlueprintLibrary" then
                return library
            end
            if options.missing_class and path == "/Script/Altar.VAltarWidget" then
                return nil
            end
            return object({ path = path })
        end,
        StaticConstructObject = function(class)
            in_game_thread()
            return make_widget(data[class].path)
        end,
        FText = function(value)
            in_game_thread()
            return text(value)
        end,
        RegisterKeyBind = function(key, callback)
            keys[key] = callback
        end,
        ExecuteInGameThread = function(callback)
            queue[#queue + 1] = callback
        end,
        ExecuteWithDelay = function(_, callback)
            delayed[#delayed + 1] = callback
        end,
        LoadAsset = function()
            native_calls = native_calls + 1
            error("Legacy asset loading is forbidden")
        end,
        RegisterHook = function()
            native_calls = native_calls + 1
            error("Legacy handlers are forbidden")
        end,
        io = {
            open = function(path, mode)
                if mode == "r" then
                    return nil
                end
                if options.undo_failure then
                    return nil, "Cannot write recovery record"
                end
                local record = ""
                return {
                    write = function(_, value)
                        record = record .. value
                    end,
                    close = function()
                        records[#records + 1] = record
                    end,
                }
            end,
        },
    }, { __index = _G })
    local function drain()
        while #queue > 0 do
            local callback = table.remove(queue, 1)
            game_thread = true
            callback()
            game_thread = false
        end
    end
    local api = {
        press = function(key)
            keys[key]()
            drain()
        end,
        flush_delay = function()
            for _, callback in ipairs(delayed) do
                callback()
            end
            delayed = {}
            drain()
        end,
        enter = function(value)
            assert(input, "Rename input was not created")
            data[input].text = value
        end,
        value = function()
            return values.UI_UserInputText_item
        end,
        replacements = function()
            return replacements
        end,
        is_closed = function()
            return dialog and data[dialog].removed
        end,
        records = records,
        notifications = notifications,
        invalidate = function()
            data[dialog].valid = false
            data[input].valid = false
        end,
        change_saved_name = function(value)
            values.UI_UserInputText_item = value
        end,
    }
    local ok, failure = pcall(function()
        assert(loadfile(source_path, "t", environment))()
        check(api)
        assert(native_calls == 0, "Legacy callbacks or assets were used")
        for _, message in ipairs(logs) do
            assert(not message:find("outside the game thread"), message)
            assert(not message:find("Stale row was inspected"), message)
        end
    end)
    for _, resource in ipairs(resources) do
        debug.setmetatable(resource[1], resource[2])
        resource[1]:close()
    end
    assert(ok, failure)
    cases = cases + 1
end

-- Fresh enchantment: exact saved key, stale non-focused widget, no chest cycle.
for _, length in ipairs({ 30, 31, 80 }) do
    scenario({}, function(api)
        api.press(1)
        api.flush_delay()
        api.enter(string.rep("a", length))
        api.press(2)
        assert(api.value() == string.rep("a", length))
        assert(api.replacements() == 1 and api.is_closed())
        assert(api.records[1]:find("status=pending") and api.records[2]:find("status=applied"))
    end)
end
for _, name in ipairs({ "", "   ", "bad\nname", string.rep("x", 81), string.rep("é", 81) }) do
    scenario({}, function(api)
        api.press(1)
        api.enter(name)
        api.press(2)
        assert(api.replacements() == 0 and not api.is_closed() and #api.records == 0)
    end)
end
scenario({}, function(api)
    api.press(1)
    api.enter(string.rep("é", 80))
    api.press(2)
    assert(api.value() == string.rep("é", 80))
end)
scenario({}, function(api)
    api.press(1)
    api.press(3)
    api.flush_delay()
    api.press(2)
    assert(api.is_closed() and api.replacements() == 0 and #api.records == 0)
end)
scenario({}, function(api)
    api.press(1)
    api.invalidate()
    api.flush_delay()
    api.press(2)
    api.press(3)
    assert(api.replacements() == 0)
end)
scenario({}, function(api)
    api.press(1)
    api.press(1)
    api.press(2)
    assert(api.replacements() == 0 and api.is_closed()) -- unchanged
end)
scenario({ duplicate = true }, function(api)
    api.press(1)
    api.enter("Duplicate-safe rename")
    api.press(2)
    api.press(1)
    api.enter("Second rename on stale row")
    api.press(2)
    assert(api.value() == "Second rename on stale row" and api.replacements() == 2)
end)
scenario({}, function(api)
    api.press(1)
    api.change_saved_name("Externally changed")
    api.enter("My rename")
    api.press(2)
    assert(api.value() == "Externally changed" and api.replacements() == 0)
end)
for _, options in ipairs({
    { missing_class = true },
    { setup_failure = true },
    { unenchanted = true },
    { page = 9 },
    { undo_failure = true },
}) do
    scenario(options, function(api)
        api.press(1)
        api.press(2)
        api.flush_delay()
        assert(api.replacements() == 0)
    end)
end
scenario({ page = 2 }, function(api)
    api.press(1)
    api.enter("Renamed spell")
    api.press(2)
    assert(api.value() == "Renamed spell" and api.replacements() == 1)
end)
print(string.format("Passed %d rename-dialog regression scenarios.", cases))
