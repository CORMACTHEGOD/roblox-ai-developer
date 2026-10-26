-- Roblox AI Developer
-- v0.6: adds AI script proposals, complete preview, explicit approval and Undo.
-- Generated Script instances are created DISABLED; the plugin never runs their code.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")

local toolbar = plugin:CreateToolbar("Roblox AI Developer")
local openButton = toolbar:CreateButton(
    "OpenAI",
    "Open Roblox AI Developer",
    "rbxassetid://14978048121",
    "OpenAI"
)
openButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right, false, false, 420, 600, 320, 400
)
local widget = plugin:CreateDockWidgetPluginGui("RobloxAIDeveloperWidget", widgetInfo)
widget.Title = "Roblox AI Developer"

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Content"
scroll.Size = UDim2.fromScale(1, 1)
scroll.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = scroll

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local function makeLabel(name, text, height, fontSize, background)
    local element = Instance.new("TextLabel")
    element.Name = name
    element.Size = UDim2.new(1, 0, 0, height)
    element.BackgroundColor3 = background or Color3.fromRGB(30, 32, 40)
    element.BackgroundTransparency = background and 0 or 1
    element.BorderSizePixel = 0
    element.Text = text
    element.TextColor3 = Color3.fromRGB(225, 229, 239)
    element.TextSize = fontSize
    element.Font = Enum.Font.Gotham
    element.TextWrapped = true
    element.TextXAlignment = Enum.TextXAlignment.Left
    element.TextYAlignment = Enum.TextYAlignment.Top
    element.Parent = scroll
    return element
end

local function makeButton(name, text, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(1, 0, 0, 42)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 15
    button.Font = Enum.Font.GothamBold
    button.Parent = scroll
    return button
end

local title = makeLabel("Title", "Roblox AI Developer", 35, 22)
title.Font = Enum.Font.GothamBold

makeLabel(
    "Description",
    "Inspect the game, ask AI for suggestions, or review a generated script before creating it disabled.",
    48, 14
)

-- Model choices are local UI preferences only. Actual provider calls require
-- a separate authenticated backend. Never store API keys in this plugin.
local modelOptions = {
    { id = "gpt-6-luna", provider = "OpenAI", name = "GPT-6 Luna", tier = "Budget paid" },
    { id = "gpt-6.1-sol", provider = "OpenAI", name = "GPT-6.1 Sol", tier = "Balanced paid" },
    { id = "gpt-6-astra", provider = "OpenAI", name = "GPT-6 Astra", tier = "Advanced paid" }
}

local modelIndex = 1
local okSaved, savedModelId = pcall(function()
    return plugin:GetSetting("PreferredModelId")
end)
if okSaved and type(savedModelId) == "string" then
    for index, option in ipairs(modelOptions) do
        if option.id == savedModelId then
            modelIndex = index
            break
        end
    end
end

local modelTitle = makeLabel("ModelTitle", "AI model preference", 23, 15)
modelTitle.Font = Enum.Font.GothamBold
local modelButton = makeButton("ModelSelector", "", Color3.fromRGB(77, 75, 112))
local modelInfo = makeLabel(
    "ModelInfo",
    "Your model choice is saved locally. Set up your private AI backend to make real requests.",
    52, 12
)

local function refreshModelDisplay()
    local option = modelOptions[modelIndex]
    modelButton.Text = option.name .. "  (click to change)"
    modelInfo.Text = option.provider .. " | " .. option.tier ..
        "\nRequests require your own configured private backend."
end

modelButton.MouseButton1Click:Connect(function()
    modelIndex = (modelIndex % #modelOptions) + 1
    refreshModelDisplay()
    pcall(function()
        plugin:SetSetting("PreferredModelId", modelOptions[modelIndex].id)
    end)
end)
refreshModelDisplay()


-- The AI bridge is a private-beta feature, not a publicly authenticated service.
-- Only the operator's own backend URL may be entered here. No shared secrets
-- or OpenAI API keys are embedded in the plugin or stored in Plugin Settings.
local aiTitle = makeLabel("AiBridgeTitle", "AI Bridge (Private Beta)", 23, 15)
aiTitle.Font = Enum.Font.GothamBold
makeLabel("AiNotice", "Ask AI for suggestions or request a Script proposal. Script proposals require review and approval. Share object names only if you opt in.", 55, 13)

local function makeInput(name, placeholder, height)
    local field = Instance.new("TextBox")
    field.Name = name
    field.Size = UDim2.new(1, 0, 0, height)
    field.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    field.BorderSizePixel = 0
    field.TextColor3 = Color3.new(1, 1, 1)
    field.PlaceholderText = placeholder
    field.Text = ""
    field.TextSize = 13
    field.Font = Enum.Font.Code
    field.ClearTextOnFocus = false
    field.TextXAlignment = Enum.TextXAlignment.Left
    field.Parent = scroll
    return field
end

local backendUrlInput = makeInput("BackendURL", "https://YOUR-WORKER.workers.dev", 36)
local okUrl, savedUrl = pcall(function()
    return plugin:GetSetting("AiBackendUrl")
end)
if okUrl and type(savedUrl) == "string" then
    backendUrlInput.Text = savedUrl
end
backendUrlInput.FocusLost:Connect(function()
    local url = backendUrlInput.Text:match("^%s*(.-)%s*$")
    if url:match("^https://[%w%.%-]+/?$") then
        backendUrlInput.Text = url
        pcall(function()
            plugin:SetSetting("AiBackendUrl", url)
        end)
    end
end)

local sessionToken = nil
local tokenInput = makeInput("SessionToken", "Paste private test token, then press Enter", 36)
tokenInput.FocusLost:Connect(function()
    local typed = tokenInput.Text:match("^%s*(.-)%s*$")
    if typed ~= "" then
        sessionToken = typed
        tokenInput.PlaceholderText = "Private token loaded for this Studio session"
    end
    -- Remove token from visible TextBox. Do not persist it to plugin settings.
    tokenInput.Text = ""
end)

local shareOutline = false
local outlineToggle = makeButton("OutlineToggle", "Share Game Outline: OFF", Color3.fromRGB(77, 75, 112))
outlineToggle.MouseButton1Click:Connect(function()
    shareOutline = not shareOutline
    outlineToggle.Text = shareOutline and "Share Game Outline: ON" or "Share Game Outline: OFF"
end)

local askAIButton = makeButton("AskAI", "Ask AI (Suggestion Only)", Color3.fromRGB(65, 105, 210))
local aiResultFrame = Instance.new("ScrollingFrame")
aiResultFrame.Name = "AIResults"
aiResultFrame.Size = UDim2.new(1, 0, 0, 185)
aiResultFrame.BackgroundColor3 = Color3.fromRGB(37, 40, 49)
aiResultFrame.BorderSizePixel = 0
aiResultFrame.ScrollBarThickness = 6
aiResultFrame.CanvasSize = UDim2.fromOffset(0, 0)
aiResultFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
aiResultFrame.Parent = scroll

local aiResultPadding = Instance.new("UIPadding")
aiResultPadding.PaddingLeft = UDim.new(0, 8)
aiResultPadding.PaddingRight = UDim.new(0, 12)
aiResultPadding.PaddingTop = UDim.new(0, 8)
aiResultPadding.PaddingBottom = UDim.new(0, 8)
aiResultPadding.Parent = aiResultFrame

local aiResultText = Instance.new("TextLabel")
aiResultText.Name = "AIText"
aiResultText.Size = UDim2.new(1, 0, 0, 0)
aiResultText.AutomaticSize = Enum.AutomaticSize.Y
aiResultText.BackgroundTransparency = 1
aiResultText.TextColor3 = Color3.fromRGB(220, 225, 235)
aiResultText.Font = Enum.Font.Code
aiResultText.TextSize = 13
aiResultText.TextWrapped = true
aiResultText.TextXAlignment = Enum.TextXAlignment.Left
aiResultText.TextYAlignment = Enum.TextYAlignment.Top
aiResultText.Text = "AI suggestions appear here. Nothing in this panel changes your game."
aiResultText.Parent = aiResultFrame

-- A separate, scrollable, full-source preview for AI-generated scripts.
-- No edits are applied by generating or viewing a proposal.
local generateScriptButton = makeButton(
    "GenerateScript", "Generate Script Proposal (AI)", Color3.fromRGB(65, 105, 210)
)
local scriptPreviewTitle = makeLabel(
    "ScriptPreviewTitle", "AI SCRIPT PROPOSAL - NOT APPLIED", 25, 15
)
scriptPreviewTitle.Font = Enum.Font.GothamBold
local scriptPreviewInfo = makeLabel(
    "ScriptPreviewInfo",
    "No script proposed. AI output is untrusted: review ALL code before approving. " ..
        "Approved scripts are created disabled in ServerScriptService.",
    75, 13
)
local scriptPreviewFrame = Instance.new("ScrollingFrame")
scriptPreviewFrame.Name = "ScriptSourcePreview"
scriptPreviewFrame.Size = UDim2.new(1, 0, 0, 300)
scriptPreviewFrame.BackgroundColor3 = Color3.fromRGB(37, 40, 49)
scriptPreviewFrame.BorderSizePixel = 0
scriptPreviewFrame.ScrollBarThickness = 7
scriptPreviewFrame.CanvasSize = UDim2.fromOffset(0, 0)
scriptPreviewFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scriptPreviewFrame.Parent = scroll

local scriptPreviewPadding = Instance.new("UIPadding")
scriptPreviewPadding.PaddingLeft = UDim.new(0, 8)
scriptPreviewPadding.PaddingRight = UDim.new(0, 12)
scriptPreviewPadding.PaddingTop = UDim.new(0, 8)
scriptPreviewPadding.PaddingBottom = UDim.new(0, 8)
scriptPreviewPadding.Parent = scriptPreviewFrame

local scriptPreviewText = Instance.new("TextLabel")
scriptPreviewText.Name = "CompleteScriptSource"
scriptPreviewText.Size = UDim2.new(1, 0, 0, 0)
scriptPreviewText.AutomaticSize = Enum.AutomaticSize.Y
scriptPreviewText.BackgroundTransparency = 1
scriptPreviewText.TextColor3 = Color3.fromRGB(220, 225, 235)
scriptPreviewText.Font = Enum.Font.Code
scriptPreviewText.TextSize = 13
scriptPreviewText.TextWrapped = true
scriptPreviewText.TextXAlignment = Enum.TextXAlignment.Left
scriptPreviewText.TextYAlignment = Enum.TextYAlignment.Top
scriptPreviewText.Text = "No script code to review yet."
scriptPreviewText.Parent = scriptPreviewFrame

local approveScriptButton = makeButton(
    "ApproveGeneratedScript", "Approve & Insert Disabled Script", Color3.fromRGB(45, 145, 90)
)
local discardScriptButton = makeButton(
    "DiscardGeneratedScript", "Discard Script Proposal", Color3.fromRGB(105, 65, 65)
)

local inspectButton = makeButton("InspectGame", "Inspect Game (Read Only)", Color3.fromRGB(74, 79, 95))

-- The inspector has its own scroll area so large trees are still readable.
local hierarchyFrame = Instance.new("ScrollingFrame")
hierarchyFrame.Name = "HierarchyResults"
hierarchyFrame.Size = UDim2.new(1, 0, 0, 220)
hierarchyFrame.BackgroundColor3 = Color3.fromRGB(37, 40, 49)
hierarchyFrame.BorderSizePixel = 0
hierarchyFrame.ScrollBarThickness = 6
hierarchyFrame.CanvasSize = UDim2.fromOffset(0, 0)
hierarchyFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
hierarchyFrame.Parent = scroll

local hierarchyPadding = Instance.new("UIPadding")
hierarchyPadding.PaddingTop = UDim.new(0, 7)
hierarchyPadding.PaddingBottom = UDim.new(0, 7)
hierarchyPadding.PaddingLeft = UDim.new(0, 8)
hierarchyPadding.PaddingRight = UDim.new(0, 12)
hierarchyPadding.Parent = hierarchyFrame

local hierarchyText = Instance.new("TextLabel")
hierarchyText.Name = "HierarchyText"
hierarchyText.Size = UDim2.new(1, 0, 0, 0)
hierarchyText.AutomaticSize = Enum.AutomaticSize.Y
hierarchyText.BackgroundTransparency = 1
hierarchyText.Text = "Click Inspect Game to see objects and scripts inside your open place."
hierarchyText.TextColor3 = Color3.fromRGB(220, 225, 235)
hierarchyText.TextSize = 13
hierarchyText.Font = Enum.Font.Code
hierarchyText.TextWrapped = true
hierarchyText.TextXAlignment = Enum.TextXAlignment.Left
hierarchyText.TextYAlignment = Enum.TextYAlignment.Top
hierarchyText.Parent = hierarchyFrame

local prompt = Instance.new("TextBox")
prompt.Name = "Request"
prompt.Size = UDim2.new(1, 0, 0, 110)
prompt.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
prompt.BorderSizePixel = 0
prompt.TextColor3 = Color3.new(1, 1, 1)
prompt.PlaceholderText = "Create folder Inventory in ReplicatedStorage"
prompt.Text = ""
prompt.TextSize = 14
prompt.Font = Enum.Font.Gotham
prompt.TextWrapped = true
prompt.TextXAlignment = Enum.TextXAlignment.Left
prompt.TextYAlignment = Enum.TextYAlignment.Top
prompt.MultiLine = true
prompt.ClearTextOnFocus = false
prompt.Parent = scroll

local prepareButton = makeButton("Prepare", "Prepare Proposal", Color3.fromRGB(65, 105, 210))
local proposal = makeLabel(
    "Proposal",
    "No change proposed.\n\nSupported local command:\nCreate folder Inventory in ReplicatedStorage",
    165, 14, Color3.fromRGB(40, 43, 53)
)

local approveButton = makeButton("Approve", "Approve & Apply", Color3.fromRGB(45, 145, 90))
local status = makeLabel("Status", "Status: No changes made.", 60, 13)

local allowedParents = {
    workspace = "Workspace",
    replicatedstorage = "ReplicatedStorage",
    serverstorage = "ServerStorage",
    serverscriptservice = "ServerScriptService",
    startergui = "StarterGui",
    starterpack = "StarterPack"
}

local pending = nil
local pendingScript = nil
local scriptRequestIndex = 0

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function clearProposal(reason)
    pending = nil
    proposal.Text = reason
    status.Text = "Status: No change is awaiting approval."
end

local function clearScriptProposal(reason)
    pendingScript = nil
    scriptPreviewInfo.Text = reason
    scriptPreviewText.Text = "No script is awaiting approval."
    scriptPreviewFrame.CanvasPosition = Vector2.new(0, 0)
end

-- Walk the real Explorer hierarchy. No source code is read or transmitted.
-- Limits keep inspection responsive even in large places.
local INSPECT_MAX_OBJECTS = 250
local INSPECT_MAX_DEPTH = 6
local INSPECT_SERVICES = {
    "Workspace", "ReplicatedStorage", "ServerStorage",
    "ServerScriptService", "StarterGui", "StarterPack"
}

inspectButton.MouseButton1Click:Connect(function()
    local lines = {
        "LIVE GAME HIERARCHY (READ ONLY)",
        "Open place: " .. game.Name,
        "Name [ClassName]",
        ""
    }
    local inspected = 0
    local scriptsFound = 0
    local truncatedByCount = false
    local truncatedByDepth = false

    local function getSortedChildren(parent)
        local children = parent:GetChildren()
        table.sort(children, function(a, b)
            local left, right = a.Name:lower(), b.Name:lower()
            if left == right then
                return a.ClassName < b.ClassName
            end
            return left < right
        end)
        return children
    end

    local function visit(instance, depth)
        if inspected >= INSPECT_MAX_OBJECTS then
            truncatedByCount = true
            return
        end

        inspected = inspected + 1
        if instance:IsA("LuaSourceContainer") then
            scriptsFound = scriptsFound + 1
        end

        table.insert(
            lines,
            string.rep("  ", depth) .. "- " .. instance.Name .. " [" .. instance.ClassName .. "]"
        )

        local children = getSortedChildren(instance)
        if #children == 0 then
            return
        end

        if depth >= INSPECT_MAX_DEPTH then
            truncatedByDepth = true
            table.insert(lines, string.rep("  ", depth + 1) .. "... deeper objects hidden")
            return
        end

        for _, child in ipairs(children) do
            if inspected >= INSPECT_MAX_OBJECTS then
                truncatedByCount = true
                break
            end
            visit(child, depth + 1)
        end
    end

    for _, serviceName in ipairs(INSPECT_SERVICES) do
        local service = game:GetService(serviceName)
        local children = getSortedChildren(service)
        table.insert(lines, serviceName .. " (" .. tostring(#children) .. " direct children)")

        for _, child in ipairs(children) do
            if inspected >= INSPECT_MAX_OBJECTS then
                truncatedByCount = true
                break
            end
            visit(child, 1)
        end
        table.insert(lines, "")
        if truncatedByCount then
            break
        end
    end

    table.insert(lines, "Objects listed: " .. tostring(inspected))
    table.insert(lines, "Script objects listed: " .. tostring(scriptsFound))
    if truncatedByCount then
        table.insert(lines, "Limited to 250 objects. The game may contain more.")
    end
    if truncatedByDepth then
        table.insert(lines, "Some objects deeper than 6 levels were hidden.")
    end
    table.insert(lines, "Names and classes only. Script contents were NOT read.")

    hierarchyText.Text = table.concat(lines, "\n")
    hierarchyFrame.CanvasPosition = Vector2.new(0, 0)
    pending = nil
    status.Text = "Status: Read-only inspection finished. Nothing changed."
end)

prepareButton.MouseButton1Click:Connect(function()
    local request = trim(prompt.Text)
    pending = nil

    if request == "" then
        clearProposal("Type a request first. No changes made.")
        return
    end

    local folderName, parentText = request:match(
        "^[Cc][Rr][Ee][Aa][Tt][Ee]%s+[Ff][Oo][Ll][Dd][Ee][Rr]%s+(.+)%s+[Ii][Nn]%s+(%w+)$"
    )

    local parentService = parentText and allowedParents[parentText:lower()]
    folderName = folderName and trim(folderName)

    if not folderName or not parentService then
        clearProposal(
            "AI is not connected yet, so I cannot interpret free-form requests.\n\n" ..
            "Supported format:\nCreate folder Inventory in ReplicatedStorage\n\n" ..
            "Allowed locations: Workspace, ReplicatedStorage, ServerStorage, " ..
            "ServerScriptService, StarterGui, StarterPack."
        )
        return
    end

    if #folderName > 50 or folderName:find("[^%w _%-]") then
        clearProposal("Folder names must be 1-50 letters, numbers, spaces, underscores or hyphens.")
        return
    end

    local parent = game:GetService(parentService)
    if parent:FindFirstChild(folderName) then
        clearProposal("A child named '" .. folderName .. "' already exists in " .. parentService .. ".")
        return
    end

    pending = {
        original = prompt.Text,
        name = folderName,
        service = parentService
    }

    proposal.Text =
        "PROPOSED CHANGE (NOT YET APPLIED)\n\n" ..
        "Action: Create one Folder instance\n" ..
        "Name: " .. folderName .. "\n" ..
        "Parent: " .. parentService .. "\n\n" ..
        "No scripts will run. No other objects will change.\n" ..
        "Approve only if this is what you want."
    status.Text = "Status: Waiting for your approval. Nothing changed."
end)

-- Editing the prompt after preview always invalidates approval.
prompt:GetPropertyChangedSignal("Text"):Connect(function()
    scriptRequestIndex = scriptRequestIndex + 1 -- invalidate in-flight AI proposal if edited
    if not pendingScript and scriptPreviewInfo.Text:find("Generating", 1, true) then
        clearScriptProposal("Request edited. Generate a fresh script proposal.")
    end
    if pending and prompt.Text ~= pending.original then
        clearProposal("Request changed. Prepare a new proposal before approving.")
    end
    if pendingScript and prompt.Text ~= pendingScript.original then
        clearScriptProposal("Request changed. Generate a fresh Script proposal.")
    end
end)

approveButton.MouseButton1Click:Connect(function()
    if not pending then
        status.Text = "Status: Nothing to apply. Prepare a proposal first."
        return
    end

    local approved = pending
    pending = nil

    if prompt.Text ~= approved.original then
        clearProposal("Request changed. Prepare a new proposal before approving.")
        return
    end

    local parent = game:GetService(approved.service)
    if parent:FindFirstChild(approved.name) then
        clearProposal("That name is already used. No changes made.")
        return
    end

    -- Require a Studio undo recording before making even this small change.
    local recordingOK, recording = pcall(function()
        return ChangeHistoryService:TryBeginRecording("RobloxAIDeveloper_CreateFolder")
    end)
    if not recordingOK or not recording then
        clearProposal("Studio could not start an undo recording. No changes made.")
        return
    end

    local ok, err = pcall(function()
        local folder = Instance.new("Folder")
        folder.Name = approved.name
        folder.Parent = parent
    end)

    ChangeHistoryService:FinishRecording(
        recording,
        ok and Enum.FinishRecordingOperation.Commit
            or Enum.FinishRecordingOperation.Cancel
    )

    if ok then
        proposal.Text = "APPLIED: Created " .. approved.service .. "." .. approved.name
        status.Text = "Status: One folder created. Use Studio Undo (Ctrl+Z) to revert."
    else
        proposal.Text = "Could not create folder: " .. tostring(err)
        status.Text = "Status: The action failed; recording cancelled."
    end
end)


-- Send only what the user chose: prompt by default, optionally a short outline.
-- Never read Script.Source or execute AI output.
local function buildGameOutline()
    local lines = {}
    local listed = 0
    local services = {
        "Workspace", "ReplicatedStorage", "ServerStorage",
        "ServerScriptService", "StarterGui", "StarterPack"
    }
    local function walk(instance, level)
        if listed >= 80 or level > 3 then
            return
        end
        listed = listed + 1
        local safeName = instance.Name:gsub("[%c]", " "):sub(1, 75)
        table.insert(lines, string.rep("  ", level) .. safeName .. " [" .. instance.ClassName .. "]")
        if level >= 3 then
            return
        end
        local children = instance:GetChildren()
        table.sort(children, function(a, b)
            return a.Name:lower() < b.Name:lower()
        end)
        for _, child in ipairs(children) do
            if listed >= 80 then
                break
            end
            walk(child, level + 1)
        end
    end
    for _, serviceName in ipairs(services) do
        if listed >= 80 then
            break
        end
        table.insert(lines, serviceName .. ":")
        local service = game:GetService(serviceName)
        local children = service:GetChildren()
        table.sort(children, function(a, b)
            return a.Name:lower() < b.Name:lower()
        end)
        for _, child in ipairs(children) do
            if listed >= 80 then
                break
            end
            walk(child, 1)
        end
    end
    return table.concat(lines, "\n"):sub(1, 6000)
end

local aiRequestIndex = 0
askAIButton.MouseButton1Click:Connect(function()
    local request = trim(prompt.Text)
    if request == "" or #request > 3000 then
        aiResultText.Text = "Enter a request of 1-3000 characters in the description box."
        return
    end
    local url = trim(backendUrlInput.Text):gsub("/+$", "")
    if not url:match("^https://[%w%.%-]+$") then
        aiResultText.Text = "Enter your own HTTPS backend URL first."
        return
    end
    if not sessionToken or sessionToken == "" then
        aiResultText.Text = "Enter the private test token, then press Enter to load it for this session."
        return
    end
    pending = nil -- AI suggestions do not become executable proposals.
    aiRequestIndex = aiRequestIndex + 1
    local currentIndex = aiRequestIndex
    aiResultText.Text = "Contacting your configured AI backend..."
    status.Text = "Status: Waiting for AI suggestion. No game changes made."

    local body = {
        prompt = request,
        model = modelOptions[modelIndex].id
    }
    if shareOutline then
        body.gameOutline = buildGameOutline()
    end

    task.spawn(function()
        local success, response = pcall(function()
            return HttpService:RequestAsync({
                Url = url .. "/v1/plan",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. sessionToken
                },
                Body = HttpService:JSONEncode(body)
            })
        end)
        if aiRequestIndex ~= currentIndex then
            return
        end
        if not success then
            aiResultText.Text = "Network request failed. Check backend URL, plugin HTTP permission, and Output for errors."
            status.Text = "Status: AI request failed. Nothing changed."
            return
        end
        local parsedOK, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if not response.Success then
            local reason = parsedOK and type(data) == "table" and data.error
            aiResultText.Text = "AI error: " .. tostring(reason or response.StatusCode)
            status.Text = "Status: AI request failed. Nothing changed."
            return
        end
        if not parsedOK or type(data) ~= "table" or type(data.suggestion) ~= "string" then
            aiResultText.Text = "The AI backend returned an unexpected response."
            status.Text = "Status: AI response invalid. Nothing changed."
            return
        end
        aiResultText.Text = "AI SUGGESTION (NOT APPLIED)\n\n" .. data.suggestion:sub(1, 7000)
        aiResultFrame.CanvasPosition = Vector2.new(0, 0)
        status.Text = "Status: AI suggestion received. No changes made."
    end)
end)


-- Script creation is a separate user-controlled, two-step operation:
-- generate complete code for review, then click Approve to create ONE disabled Script.
-- It intentionally cannot overwrite files, edit live scripts, or run code.
local function getBackendSettings()
    local url = trim(backendUrlInput.Text):gsub("/+$", "")
    if not url:match("^https://[%w%.%-]+$") then
        return nil, "Enter your HTTPS backend URL first."
    end
    if not sessionToken or sessionToken == "" then
        return nil, "Enter the private test token, then press Enter."
    end
    return url, nil
end

generateScriptButton.MouseButton1Click:Connect(function()
    local request = trim(prompt.Text)
    scriptRequestIndex = scriptRequestIndex + 1
    local index = scriptRequestIndex
    clearScriptProposal("No script proposed.")
    if request == "" or #request > 3000 then
        scriptPreviewInfo.Text = "Enter a request of 1-3000 characters in the request box."
        return
    end

    local url, configError = getBackendSettings()
    if not url then
        scriptPreviewInfo.Text = configError
        return
    end

    local original = prompt.Text
    local chosenModel = modelOptions[modelIndex].id
    local payload = { prompt = request, model = chosenModel }
    if shareOutline then
        payload.gameOutline = buildGameOutline()
    end
    scriptPreviewInfo.Text = "Generating proposed code... No game changes made."
    scriptPreviewText.Text = "Contacting AI backend..."
    status.Text = "Status: Generating AI Script proposal. No changes made."

    task.spawn(function()
        local success, response = pcall(function()
            return HttpService:RequestAsync({
                Url = url .. "/v1/propose-script",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. sessionToken
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        if scriptRequestIndex ~= index then
            return
        end
        if prompt.Text ~= original or modelOptions[modelIndex].id ~= chosenModel then
            clearScriptProposal("Request or model changed. Generate a fresh script proposal.")
            return
        end
        if not success then
            clearScriptProposal("Network error. Check plugin HTTP permission and your Worker URL.")
            return
        end
        local decodedOK, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if not response.Success then
            local reason = decodedOK and type(data) == "table" and data.error
            clearScriptProposal("AI error: " .. tostring(reason or response.StatusCode))
            return
        end
        local item = decodedOK and type(data) == "table" and data.proposal
        if type(item) ~= "table" or item.service ~= "ServerScriptService" or
            type(item.name) ~= "string" or #item.name > 50 or
            not item.name:match("^[%a][%w_ ]*$") or
            type(item.code) ~= "string" or #item.code == 0 or
            #item.code > 9000 or not item.code:match("%S") then
            clearScriptProposal("Invalid script proposal received. Nothing changed.")
            return
        end
        local parent = game:GetService("ServerScriptService")
        if parent:FindFirstChild(item.name) then
            clearScriptProposal("A child named '" .. item.name ..
                "' already exists in ServerScriptService. Request a different script name.")
            return
        end

        pendingScript = {
            original = original,
            model = chosenModel,
            name = item.name,
            code = item.code
        }
        scriptPreviewInfo.Text =
            "ACTION: Create one DISABLED Script\n" ..
            "NAME: " .. item.name .. "\n" ..
            "LOCATION: ServerScriptService\n" ..
            "Review the ENTIRE Luau code below. It may contain mistakes or unsafe behavior."
        scriptPreviewText.Text = item.code
        scriptPreviewFrame.CanvasPosition = Vector2.new(0, 0)
        status.Text = "Status: AI Script ready for review. No changes made."
    end)
end)

discardScriptButton.MouseButton1Click:Connect(function()
    scriptRequestIndex = scriptRequestIndex + 1
    clearScriptProposal("Script proposal discarded. Nothing was inserted.")
    status.Text = "Status: Script proposal discarded. Nothing changed."
end)

approveScriptButton.MouseButton1Click:Connect(function()
    if not pendingScript then
        status.Text = "Status: No AI Script to approve. Generate a proposal first."
        return
    end

    local approved = pendingScript
    clearScriptProposal("Approval received. Attempting to create disabled script...")
    scriptRequestIndex = scriptRequestIndex + 1

    if prompt.Text ~= approved.original or
        modelOptions[modelIndex].id ~= approved.model then
        scriptPreviewInfo.Text = "Request or model changed. Generate a fresh proposal."
        return
    end
    local parent = game:GetService("ServerScriptService")
    if parent:FindFirstChild(approved.name) then
        scriptPreviewInfo.Text = "Name already exists. Nothing was inserted."
        return
    end

    local recordingOK, recording = pcall(function()
        return ChangeHistoryService:TryBeginRecording("OrangeJuiceAI_CreateDisabledScript")
    end)
    if not recordingOK or not recording then
        scriptPreviewInfo.Text = "Unable to start an Undo recording. Nothing was inserted."
        return
    end

    local createdScript = nil
    local ok, err = pcall(function()
        createdScript = Instance.new("Script")
        createdScript.Enabled = false
        createdScript.Name = approved.name
        createdScript.Source = approved.code
        createdScript.Parent = parent
    end)
    if not ok and createdScript then
        pcall(function()
            createdScript:Destroy()
        end)
    end
    ChangeHistoryService:FinishRecording(
        recording,
        ok and Enum.FinishRecordingOperation.Commit
            or Enum.FinishRecordingOperation.Cancel
    )

    if ok then
        scriptPreviewInfo.Text =
            "CREATED: ServerScriptService." .. approved.name ..
            "\nSTATE: DISABLED. Inspect Source before manually enabling it in Studio." ..
            "\nUse Ctrl+Z to undo the insertion."
        scriptPreviewText.Text = approved.code
        status.Text = "Status: One disabled Script inserted after approval. Undo: Ctrl+Z."
    else
        scriptPreviewInfo.Text = "Could not insert the script: " .. tostring(err)
        status.Text = "Status: Script insertion failed. No code was enabled."
    end
end)

-- Model changes also invalidate any pending approval or in-flight proposal.
modelButton.MouseButton1Click:Connect(function()
    scriptRequestIndex = scriptRequestIndex + 1
    if pendingScript then
        clearScriptProposal("Model changed. Generate a fresh proposal.")
    end
end)

openButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

print("Roblox AI Developer v0.6 loaded (AI script proposals require explicit approval; inserted disabled).")
