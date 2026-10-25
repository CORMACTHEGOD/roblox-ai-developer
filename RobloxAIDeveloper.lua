-- Roblox AI Developer
-- v0.4: nested inspector, approval-gated local actions, model preference UI. No AI/backend connected.
-- This plugin never uploads game contents or runs generated scripts.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

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
    "Inspect actual objects and locations, then preview an exact change for approval. AI is not connected yet.",
    48, 14
)

-- Model choices are local UI preferences only. Actual provider calls require
-- a separate authenticated backend. Never store API keys in this plugin.
local modelOptions = {
    { id = "gemini-3.8-flash", provider = "Google", name = "Gemini 3.8 Flash", tier = "Free tier if eligible" },
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
    "Selection only. No AI backend is connected; choosing a model does not send requests.",
    52, 12
)

local function refreshModelDisplay()
    local option = modelOptions[modelIndex]
    modelButton.Text = option.name .. "  (click to change)"
    modelInfo.Text = option.provider .. " | " .. option.tier ..
        "\nNot connected yet. No API keys or game data are sent."
end

modelButton.MouseButton1Click:Connect(function()
    modelIndex = (modelIndex % #modelOptions) + 1
    refreshModelDisplay()
    pcall(function()
        plugin:SetSetting("PreferredModelId", modelOptions[modelIndex].id)
    end)
end)
refreshModelDisplay()

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

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function clearProposal(reason)
    pending = nil
    proposal.Text = reason
    status.Text = "Status: No change is awaiting approval."
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
    if pending and prompt.Text ~= pending.original then
        clearProposal("Request changed. Prepare a new proposal before approving.")
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

openButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

print("Roblox AI Developer v0.4 loaded (model preference; nested inspector; local actions only).")
