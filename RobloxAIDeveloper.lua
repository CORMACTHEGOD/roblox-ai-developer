-- Orange Juice AI v0.7: one request, Prepare, review, Apply.
-- Safe allowlisted multi-object proposals. No automatic Studio modifications.
-- Private beta: do NOT distribute the shared CLIENT_TOKEN to other users.

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local toolbar = plugin:CreateToolbar("Orange Juice AI")
local openButton = toolbar:CreateButton(
    "OrangeJuiceAI", "Open Orange Juice AI", "rbxassetid://14978048121", "Orange AI"
)
openButton.ClickableWhenViewportHidden = true
local info = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right, false, false, 450, 675, 320, 450
)
local widget = plugin:CreateDockWidgetPluginGui("RobloxAIDeveloperWidget", info)
widget.Title = "Orange Juice AI"

local bg = Color3.fromRGB(28, 31, 39)
local panel = Color3.fromRGB(42, 46, 56)
local fg = Color3.fromRGB(236, 239, 245)
local blue = Color3.fromRGB(68, 106, 219)
local green = Color3.fromRGB(44, 146, 93)

local root = Instance.new("ScrollingFrame")
root.Name = "Main"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = bg
root.BorderSizePixel = 0
root.ScrollBarThickness = 6
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.CanvasSize = UDim2.fromOffset(0, 0)
root.Parent = widget
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 15)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 16)
pad.Parent = root
local stack = Instance.new("UIListLayout")
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Padding = UDim.new(0, 9)
stack.Parent = root

local function label(parent, name, content, height, size)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Size = UDim2.new(1, 0, 0, height)
    l.BackgroundTransparency = 1
    l.TextColor3 = fg
    l.Text = content
    l.Font = Enum.Font.Gotham
    l.TextSize = size or 13
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = parent
    return l
end

local function button(parent, name, content, color, height)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(1, 0, 0, height or 40)
    b.Text = content
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Parent = parent
    return b
end

local function input(parent, name, placeholder, height, multiline)
    local t = Instance.new("TextBox")
    t.Name = name
    t.Size = UDim2.new(1, 0, 0, height)
    t.BackgroundColor3 = panel
    t.TextColor3 = fg
    t.PlaceholderColor3 = Color3.fromRGB(159, 168, 181)
    t.PlaceholderText = placeholder
    t.Text = ""
    t.TextSize = 13
    t.Font = Enum.Font.Code
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Top
    t.TextWrapped = multiline or false
    t.MultiLine = multiline or false
    t.ClearTextOnFocus = false
    t.BorderSizePixel = 0
    t.Parent = parent
    return t
end

local header = label(root, "Heading", "Orange Juice AI", 35, 23)
header.Font = Enum.Font.GothamBold
label(root, "Hint", "Describe what you want. Prepare checks your game and plans everything needed. Apply only after review.", 55, 13)

local request = input(root, "Request", "Example: Make a working door with a model and a touch script", 124, true)
local actionRow = Instance.new("Frame")
actionRow.Name = "Actions"
actionRow.BackgroundTransparency = 1
actionRow.Size = UDim2.new(1, 0, 0, 42)
actionRow.Parent = root
local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 8)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actionRow
local prepareButton = button(actionRow, "Prepare", "Prepare", blue, 42)
prepareButton.Size = UDim2.new(0.5, -4, 0, 42)
local applyButton = button(actionRow, "Apply", "Apply", Color3.fromRGB(78, 84, 96), 42)
applyButton.Size = UDim2.new(0.5, -4, 0, 42)

local status = label(root, "Status", "Ready. Configure connection and game-context consent below.", 52, 13)
local previewTitle = label(root, "PreviewHeading", "Proposal preview — no changes yet", 25, 15)
previewTitle.Font = Enum.Font.GothamBold
local previewFrame = Instance.new("ScrollingFrame")
previewFrame.Name = "FullProposalPreview"
previewFrame.Size = UDim2.new(1, 0, 0, 310)
previewFrame.BackgroundColor3 = panel
previewFrame.BorderSizePixel = 0
previewFrame.ScrollBarThickness = 7
previewFrame.CanvasSize = UDim2.fromOffset(0, 0)
previewFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
previewFrame.Parent = root
local previewPad = Instance.new("UIPadding")
previewPad.PaddingLeft = UDim.new(0, 9)
previewPad.PaddingRight = UDim.new(0, 14)
previewPad.PaddingTop = UDim.new(0, 9)
previewPad.PaddingBottom = UDim.new(0, 9)
previewPad.Parent = previewFrame
local previewText = Instance.new("TextLabel")
previewText.Name = "ProposalText"
previewText.Size = UDim2.new(1, 0, 0, 0)
previewText.AutomaticSize = Enum.AutomaticSize.Y
previewText.BackgroundTransparency = 1
previewText.TextColor3 = fg
previewText.Text = "Prepared object changes and full script source will appear here."
previewText.Font = Enum.Font.Code
previewText.TextSize = 13
previewText.TextWrapped = true
previewText.TextXAlignment = Enum.TextXAlignment.Left
previewText.TextYAlignment = Enum.TextYAlignment.Top
previewText.Parent = previewFrame

local setupButton = button(root, "SettingsToggle", "Connection & privacy settings", Color3.fromRGB(58, 65, 78), 32)
setupButton.TextSize = 12
local setupFrame = Instance.new("Frame")
setupFrame.Name = "Settings"
setupFrame.BackgroundTransparency = 1
setupFrame.Size = UDim2.new(1, 0, 0, 160)
setupFrame.AutomaticSize = Enum.AutomaticSize.Y
setupFrame.Parent = root
local settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0, 7)
settingsLayout.Parent = setupFrame
local urlInput = input(setupFrame, "WorkerURL", "https://YOUR-WORKER.workers.dev", 33, false)
local tokenInput = input(setupFrame, "SessionToken", "Paste CLIENT_TOKEN, then press Enter", 33, false)
local contextButton = button(
    setupFrame, "ContextPermission", "Share game structure with AI: OFF", Color3.fromRGB(105, 69, 69), 34
)
contextButton.TextSize = 12
label(setupFrame, "Privacy", "Opt-in shares up to 220 object paths/classes and selected properties when you press Prepare. Never sends script Source.", 62, 12)
local settingsOpen = false
local consent = false
local token = nil
local preferredModel = "gpt-6-luna"
local okModel, savedModel = pcall(function()
    return plugin:GetSetting("PreferredModelId")
end)
local modelWhitelist = { ["gpt-6-luna"] = true, ["gpt-6.1-sol"] = true, ["gpt-6-astra"] = true }
if okModel and modelWhitelist[savedModel] then
    preferredModel = savedModel
end
local okURL, savedURL = pcall(function()
    return plugin:GetSetting("AiBackendUrl")
end)
if okURL and type(savedURL) == "string" then
    urlInput.Text = savedURL
end
local okConsent, savedConsent = pcall(function()
    return plugin:GetSetting("OrangeJuiceGameContextConsent")
end)
if okConsent and savedConsent == true then
    consent = true
end

local function refreshSettings()
    setupFrame.Visible = settingsOpen
    contextButton.Text = "Share game structure with AI: " .. (consent and "ON" or "OFF")
    contextButton.BackgroundColor3 = consent and green or Color3.fromRGB(105, 69, 69)
end

settingsOpen = not consent or not okURL or not savedURL or savedURL == ""
refreshSettings()
setupButton.MouseButton1Click:Connect(function()
    settingsOpen = not settingsOpen
    refreshSettings()
end)

local function trim(text)
    return (text:match("^%s*(.-)%s*$"))
end

local pending = nil
local generation = 0
local function setCanApply(enabled)
    applyButton.Active = enabled
    applyButton.AutoButtonColor = enabled
    applyButton.BackgroundColor3 = enabled and green or Color3.fromRGB(78, 84, 96)
end
setCanApply(false)

local function cancel(reason)
    pending = nil
    generation = generation + 1
    setCanApply(false)
    if reason then
        status.Text = reason
    end
end
request:GetPropertyChangedSignal("Text"):Connect(function()
    if pending then
        cancel("Request edited. Press Prepare to review a fresh proposal.")
    else
        generation = generation + 1
    end
end)
urlInput.FocusLost:Connect(function()
    local raw = trim(urlInput.Text):gsub("/+$", "")
    if raw:match("^https://[%w%.%-]+$") then
        urlInput.Text = raw
        pcall(function() plugin:SetSetting("AiBackendUrl", raw) end)
    end
    cancel("Connection updated. Prepare a fresh proposal.")
end)
tokenInput.FocusLost:Connect(function()
    local entered = trim(tokenInput.Text)
    if entered ~= "" then
        token = entered
    end
    tokenInput.Text = ""
    tokenInput.PlaceholderText = token and "Private token loaded for this Studio session" or "Paste CLIENT_TOKEN, then press Enter"
    cancel(token and "Private token loaded. You can press Prepare." or "Enter private CLIENT_TOKEN.")
end)
contextButton.MouseButton1Click:Connect(function()
    consent = not consent
    pcall(function() plugin:SetSetting("OrangeJuiceGameContextConsent", consent) end)
    refreshSettings()
    cancel("Context sharing " .. (consent and "enabled" or "disabled") .. ". Prepare again.")
end)

local roots = {
    Workspace = true, ReplicatedStorage = true, ServerStorage = true,
    ServerScriptService = true, StarterGui = true, StarterPack = true,
    StarterPlayer = true
}
local rootList = {
    "Workspace", "ServerScriptService", "StarterGui", "StarterPlayer",
    "ReplicatedStorage", "ServerStorage", "StarterPack"
}
local allowedClass = {
    Folder = true, Model = true, Part = true, WedgePart = true,
    SpawnLocation = true, ScreenGui = true, Frame = true,
    TextLabel = true, TextButton = true, ImageLabel = true,
    UICorner = true, UIStroke = true, UIListLayout = true,
    UIPadding = true, ProximityPrompt = true, ClickDetector = true,
    Script = true, LocalScript = true, ModuleScript = true
}
local allowedProperty = {
    BasePart = {
        Size=true, Position=true, Orientation=true, Anchored=true,
        CanCollide=true, Transparency=true, Color=true, Material=true, Shape=true
    },
    GuiObject = {
        Size=true, Position=true, AnchorPoint=true, BackgroundColor3=true,
        BackgroundTransparency=true, Visible=true, ZIndex=true
    },
    TextObject = { Text=true, TextColor3=true, TextSize=true, TextWrapped=true, Font=true },
    ScreenGui = { ResetOnSpawn=true, IgnoreGuiInset=true },
    UICorner = { CornerRadius=true },
    UIStroke = { Thickness=true, Color=true },
    UIListLayout = { FillDirection=true, Padding=true },
    UIPadding = { PaddingTop=true, PaddingLeft=true, PaddingRight=true, PaddingBottom=true },
    ProximityPrompt = {
        ActionText=true, ObjectText=true, HoldDuration=true, MaxActivationDistance=true
    }
}
local function safeProperty(instance, prop)
    local function inGroup(group)
        return allowedProperty[group] and allowedProperty[group][prop]
    end
    if instance:IsA("BasePart") and inGroup("BasePart") then return true end
    if instance:IsA("GuiObject") and inGroup("GuiObject") then return true end
    if (instance:IsA("TextLabel") or instance:IsA("TextButton")) and inGroup("TextObject") then return true end
    return inGroup(instance.ClassName) == true
end

local function components(path)
    if type(path) ~= "string" or #path > 340 then return nil end
    local parts = string.split(path, "/")
    if #parts < 1 or #parts > 9 or not roots[parts[1]] then return nil end
    for _, p in ipairs(parts) do
        if #p < 1 or #p > 50 or not p:match("^[%w_][%w_ %-]*$") then
            return nil
        end
    end
    return parts
end
local function resolve(path)
    local parts = components(path)
    if not parts then return nil end
    local obj = game:GetService(parts[1])
    for i = 2, #parts do
        obj = obj:FindFirstChild(parts[i])
        if not obj then return nil end
    end
    return obj
end
local function pathOf(instance)
    local chain = {}
    local here = instance
    while here and here ~= game do
        table.insert(chain, 1, here.Name)
        if roots[here.Name] and here.Parent == game then
            local result = table.concat(chain, "/")
            return components(result) and result or nil
        end
        here = here.Parent
    end
    return nil
end

local function snapshotOfGame(searchText)
    local words = {}
    for word in searchText:lower():gmatch("[%w_]+") do
        if #word >= 4 and not ({
            make=true,create=true,with=true,when=true,that=true,what=true,
            script=true,working=true,please=true,have=true,from=true
        })[word] then
            table.insert(words, word)
        end
    end
    local records = {}
    local inspected = 0
    local serviceCounts = {}
    for _, rootName in ipairs(rootList) do
        local service = game:GetService(rootName)
        serviceCounts[rootName] = #service:GetChildren()
        for _, obj in ipairs(service:GetDescendants()) do
            inspected = inspected + 1
            if inspected > 4500 then break end
            local p = pathOf(obj)
            if p and #p <= 260 and not p:find("/Camera/") and
                not p:find("/Terrain/") and obj.ClassName ~= "Terrain" then
                local text = (p .. " " .. obj.ClassName):lower()
                local score = 0
                for _, word in ipairs(words) do
                    if text:find(word, 1, true) then score = score + 12 end
                end
                if obj:IsA("BasePart") or obj:IsA("GuiObject") then score = score + 2 end
                if obj:IsA("LuaSourceContainer") then score = score + 1 end
                local details = ""
                if obj:IsA("BasePart") then
                    local v = obj.Size
                    details = string.format(" size=(%.1f,%.1f,%.1f)", v.X,v.Y,v.Z)
                elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    details = " text=" .. obj.Text:sub(1, 35):gsub("[%c]", " ")
                end
                table.insert(records, {p=p, value=p .. " [" .. obj.ClassName .. "]" .. details, score=score})
            end
        end
        if inspected > 4500 then break end
    end
    table.sort(records, function(a,b)
        if a.score == b.score then return a.p < b.p end
        return a.score > b.score
    end)
    local lines = {"GAME HIERARCHY SNAPSHOT. EXISTING OBJECTS ONLY. No script source included."}
    for _, rootName in ipairs(rootList) do
        table.insert(lines, rootName .. " direct children: " .. tostring(serviceCounts[rootName] or "?"))
    end
    table.insert(lines, "Selected objects, full paths:")
    local listed = 0
    for _, record in ipairs(records) do
        if listed >= 220 then break end
        if #table.concat(lines, "\n") + #record.value > 10300 then break end
        table.insert(lines, record.value)
        listed = listed + 1
    end
    table.insert(lines, "Objects listed: " .. listed .. "; sampled " .. inspected ..
        ". Snapshot may be incomplete: check runtime before referring to unlisted objects.")
    return table.concat(lines, "\n"):sub(1, 11000)
end

local function parseNumbers(raw, count)
    local values = {}
    for segment in (raw .. ","):gmatch("(.-),") do
        local number = tonumber(trim(segment))
        if not number or number ~= number or math.abs(number) > 20000 then
            return nil
        end
        table.insert(values, number)
    end
    if #values ~= count then return nil end
    return values
end
local function parseValue(instance, name, raw)
    if not safeProperty(instance, name) or type(raw) ~= "string" or #raw > 400 then
        return nil, "Unsupported property: " .. tostring(name)
    end
    local ok, previous = pcall(function() return instance[name] end)
    if not ok then return nil, "Cannot inspect property " .. name end
    local kind = typeof(previous)
    if kind == "string" then return raw end
    if kind == "boolean" then
        if raw == "true" then return true end
        if raw == "false" then return false end
        return nil, "Expected true/false for " .. name
    end
    if kind == "number" then
        local n = tonumber(raw)
        if n and n == n and math.abs(n) <= 20000 then
            return n
        end
        return nil, "Invalid number for " .. name
    end
    if kind == "Vector3" then
        local p = parseNumbers(raw, 3)
        return p and Vector3.new(p[1],p[2],p[3]) or nil, "Invalid Vector3 " .. name
    end
    if kind == "Vector2" then
        local p = parseNumbers(raw, 2)
        return p and Vector2.new(p[1],p[2]) or nil, "Invalid Vector2 " .. name
    end
    if kind == "UDim2" then
        local p = parseNumbers(raw, 4)
        return p and UDim2.new(p[1],p[2],p[3],p[4]) or nil, "Invalid UDim2 " .. name
    end
    if kind == "UDim" then
        local p = parseNumbers(raw, 2)
        return p and UDim.new(p[1],p[2]) or nil, "Invalid UDim " .. name
    end
    if kind == "Color3" then
        local p = parseNumbers(raw, 3)
        if not p then return nil, "Invalid RGB " .. name end
        for _, n in ipairs(p) do
            if n < 0 or n > 255 then return nil, "RGB outside 0-255 for " .. name end
        end
        return Color3.fromRGB(p[1],p[2],p[3])
    end
    if kind == "EnumItem" then
        local enumType = ({
            Material = Enum.Material, Shape = Enum.PartType,
            Font = Enum.Font, FillDirection = Enum.FillDirection
        })[name]
        local result = enumType and enumType[raw] or nil
        return result, result and nil or "Unknown enum for " .. name
    end
    return nil, "Unsupported value type " .. kind
end

local function safeScriptLocation(className, path)
    if className == "LocalScript" then
        return path:match("^StarterGui/") ~= nil or
            path:match("^StarterPlayer/StarterPlayerScripts/") ~= nil
    end
    return className ~= "Script" or
        path:match("^ServerScriptService/") ~= nil or
        path:match("^Workspace/") ~= nil
end
local function isScript(className)
    return className == "Script" or className == "LocalScript" or className == "ModuleScript"
end

local function validatePlan(data)
    if type(data) ~= "table" or type(data.summary) ~= "string" or
        type(data.steps) ~= "table" or #data.steps < 1 or #data.steps > 24 then
        return nil, "AI returned an invalid plan."
    end
    local out = {}
    local seen = {}
    local preview = {
        "AI PLAN — NOTHING HAS CHANGED", "",
        data.summary:sub(1, 700), "",
        "Prepare checks every path. Apply will make the exact listed changes.",
        "All created Scripts / LocalScripts are DISABLED.", ""
    }
    for i, step in ipairs(data.steps) do
        if type(step) ~= "table" or type(step.path) ~= "string" or
            type(step.className) ~= "string" or not allowedClass[step.className] or
            type(step.properties) ~= "table" or #step.properties > 16 or
            type(step.source) ~= "string" then
            return nil, "Unsupported AI step #" .. i
        end
        local path = step.path
        local parts = components(path)
        if not parts or #parts < 2 or seen[path] then
            return nil, "Invalid or duplicate path: " .. path
        end
        seen[path] = true
        local parentPath = table.concat(parts, "/", 1, #parts - 1)
        if not resolve(parentPath) and not seen[parentPath] then
            return nil, "Missing parent " .. parentPath .. ". AI must include it first."
        end
        if not safeScriptLocation(step.className, path) then
            return nil, "Script location not supported: " .. path
        end
        local existing = resolve(path)
        if existing and existing.ClassName ~= step.className then
            return nil, "Conflict: " .. path .. " is " .. existing.ClassName ..
                ", not " .. step.className
        end
        if existing and isScript(step.className) then
            return nil, "Existing script at " .. path ..
                ". This version never overwrites existing script source."
        end
        if isScript(step.className) and (step.source == "" or #step.source > 9000) then
            return nil, "Script source is missing or too long: " .. path
        end
        if not isScript(step.className) and step.source ~= "" then
            return nil, "Non-script includes executable source: " .. path
        end
        if step.source:find("loadstring%s*%(") or
            step.source:find("require%s*%(%s*%d+") then
            return nil, "Proposal contains unsupported dynamic code loading."
        end
        local probe = existing or Instance.new(step.className)
        local typed = {}
        local baseline = {}
        local properties = {}
        local unique = {}
        for _, prop in ipairs(step.properties) do
            if type(prop) ~= "table" or type(prop.name) ~= "string" or
                type(prop.value) ~= "string" or unique[prop.name] then
                return nil, "Malformed or repeated property in " .. path
            end
            unique[prop.name] = true
            local value, err = parseValue(probe, prop.name, prop.value)
            if value == nil then
                return nil, err or "Bad value"
            end
            typed[prop.name] = value
            if existing then
                baseline[prop.name] = existing[prop.name]
            end
            table.insert(properties, {name=prop.name, printed=prop.value})
        end
        local mode = existing and (next(typed) and "UPDATE / REUSE" or "REUSE") or "CREATE"
        table.insert(preview, tostring(i) .. ". " .. mode .. " " .. path .. " [" .. step.className .. "]")
        for _, prop in ipairs(properties) do
            table.insert(preview, "   " .. prop.name .. " = " .. prop.printed)
        end
        if isScript(step.className) then
            table.insert(preview, "   FULL LUAU SOURCE (will be disabled):")
            table.insert(preview, step.source)
            table.insert(preview, "   END SOURCE")
        end
        table.insert(preview, "")
        table.insert(out, {
            path=path, parentPath=parentPath, name=parts[#parts], className=step.className,
            existing=existing ~= nil, instance=existing, properties=typed,
            previous=baseline, source=step.source
        })
    end
    table.insert(preview, "Nothing changes until you click APPLY. Ctrl+Z can undo the applied change.")
    return {steps=out, summary=data.summary, preview=table.concat(preview, "\n")}, nil
end

prepareButton.MouseButton1Click:Connect(function()
    cancel()
    local text = trim(request.Text)
    if #text < 2 or #text > 3000 then
        status.Text = "Enter a request of 2-3000 characters."
        return
    end
    local worker = trim(urlInput.Text):gsub("/+$", "")
    if not worker:match("^https://[%w%.%-]+$") then
        status.Text = "Open Connection settings and enter your HTTPS Worker URL."
        settingsOpen = true; refreshSettings()
        return
    end
    if not token or token == "" then
        status.Text = "Open Connection settings and load your private CLIENT_TOKEN."
        settingsOpen = true; refreshSettings()
        return
    end
    if not consent then
        status.Text = "To automatically check your existing objects, enable game structure sharing in Connection settings."
        settingsOpen = true; refreshSettings()
        return
    end

    -- Every Prepare refreshes the structure from the REAL open game.
    local outline = snapshotOfGame(text)
    local original = request.Text
    local serial = generation
    status.Text = "Preparing a combined plan. No game changes made."
    previewText.Text = "Inspecting existing models, UI and scripts. Asking AI to propose missing pieces..."
    previewTitle.Text = "Preparing..."
    task.spawn(function()
        local ok, response = pcall(function()
            return HttpService:RequestAsync({
                Url=worker .. "/v1/prepare",
                Method="POST",
                Headers={
                    ["Content-Type"]="application/json",
                    ["Authorization"]="Bearer " .. token
                },
                Body=HttpService:JSONEncode({
                    prompt=text, model=preferredModel, gameOutline=outline
                })
            })
        end)
        if generation ~= serial or request.Text ~= original then return end
        if not ok then
            status.Text = "Network error. Check Worker URL and Roblox Studio HTTP permission."
            previewText.Text = tostring(response)
            return
        end
        local parsedOK, decoded = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if not response.Success then
            local message = parsedOK and type(decoded) == "table" and decoded.error
            status.Text = "Prepare failed: " .. tostring(message or response.StatusCode)
            previewText.Text = "No changes made."
            return
        end
        if not parsedOK or type(decoded) ~= "table" then
            status.Text = "Worker returned invalid JSON. No changes made."
            return
        end
        local plan, err = validatePlan(decoded.plan)
        if not plan then
            status.Text = "Proposal needs a correction: " .. tostring(err)
            previewText.Text = "Nothing changed. Try describing a smaller feature."
            return
        end
        plan.original = original
        plan.serial = serial
        pending = plan
        previewText.Text = plan.preview
        previewFrame.CanvasPosition = Vector2.new(0, 0)
        previewTitle.Text = "Review the full plan before Apply"
        status.Text = "Prepared " .. #plan.steps .. " objects/changes. Nothing changed yet."
        setCanApply(true)
    end)
end)

applyButton.MouseButton1Click:Connect(function()
    if not pending then
        status.Text = "Nothing is prepared. Press Prepare first."
        return
    end
    local plan = pending
    pending = nil
    generation = generation + 1
    setCanApply(false)
    if request.Text ~= plan.original then
        status.Text = "Request changed. Prepare again."
        return
    end

    -- Recheck every object before starting the single undo recording.
    for _, step in ipairs(plan.steps) do
        local existing = resolve(step.path)
        if step.existing then
            if existing ~= step.instance or not existing or existing.ClassName ~= step.className then
                status.Text = "Game changed after Prepare: " .. step.path .. ". Prepare again."
                return
            end
            for propertyName, oldValue in pairs(step.previous) do
                if existing[propertyName] ~= oldValue then
                    status.Text = "Property changed after Prepare: " .. step.path .. ". Prepare again."
                    return
                end
            end
        elseif existing then
            status.Text = "Object appeared after Prepare: " .. step.path .. ". Prepare again."
            return
        end
    end

    local okRec, recording = pcall(function()
        return ChangeHistoryService:TryBeginRecording("OrangeJuiceAI_ApplyPlan")
    end)
    if not okRec or not recording then
        status.Text = "Studio Undo recording unavailable. No changes made."
        return
    end
    local made = {}
    local changed = {}
    local changedCount = 0
    local disabledScripts = 0
    local ok, err = pcall(function()
        for _, step in ipairs(plan.steps) do
            local target = step.existing and resolve(step.path) or Instance.new(step.className)
            if not target then error("Missing target " .. step.path) end
            if not step.existing then
                target.Name = step.name
                if isScript(step.className) then
                    if step.className ~= "ModuleScript" then
                        target.Enabled = false
                    end
                    target.Source = step.source
                    if step.className ~= "ModuleScript" then
                        disabledScripts = disabledScripts + 1
                    end
                end
            end
            for propName, value in pairs(step.properties) do
                if step.existing then
                    table.insert(changed, {instance=target, prop=propName, value=target[propName]})
                end
                target[propName] = value
                changedCount = changedCount + 1
            end
            if not step.existing then
                -- Parent was checked in Prepare or constructed by an earlier step.
                local parent = resolve(step.parentPath)
                if not parent then
                    target:Destroy()
                    error("Missing parent on Apply: " .. step.parentPath)
                end
                target.Parent = parent
                table.insert(made, target)
            end
        end
    end)
    if not ok then
        -- Explicit rollback in addition to Studio's cancelled Undo recording.
        for i = #changed, 1, -1 do
            local c = changed[i]
            pcall(function() c.instance[c.prop] = c.value end)
        end
        for i = #made, 1, -1 do
            pcall(function() made[i]:Destroy() end)
        end
    end
    local finishOK = pcall(function()
        ChangeHistoryService:FinishRecording(
            recording,
            ok and Enum.FinishRecordingOperation.Commit
                or Enum.FinishRecordingOperation.Cancel
        )
    end)
    if ok and finishOK then
        previewTitle.Text = "Applied — inspect your new objects"
        status.Text = "Applied: " .. #made .. " created, " .. changedCount ..
            " property assignments. " .. disabledScripts ..
            " Scripts disabled. Use Ctrl+Z to undo."
    elseif not ok then
        status.Text = "Apply failed and attempted rollback: " .. tostring(err)
    else
        status.Text = "Studio could not finish Undo recording. Inspect Explorer before continuing."
    end
end)

openButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

print("Orange Juice AI v0.7 loaded — automatic context-based combined proposals; explicit Apply.")
