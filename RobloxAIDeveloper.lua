-- Roblox AI Developer
-- v0.2: local, approval-gated actions only. No AI/backend connected.
-- This plugin never uploads game contents or runs generated scripts.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local toolbar = plugin:CreateToolbar("Roblox AI Developer")
local openButton = toolbar:CreateButton(
    "OpenAI",
    "Open Roblox AI Developer",
    ""
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
    "Preview an exact change, then approve it. AI and online features are not connected yet.",
    48, 14
)

local inspectButton = makeButton("InspectGame", "Inspect Game (Read Only)", Color3.fromRGB(74, 79, 95))

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

-- Does not read scripts, contact the network, or change the game.
inspectButton.MouseButton1Click:Connect(function()
    local lines = {"GAME OVERVIEW (READ ONLY)"}
    for _, serviceName in ipairs({
        "Workspace", "ReplicatedStorage", "ServerStorage",
        "ServerScriptService", "StarterGui", "StarterPack"
    }) do
        local parent = game:GetService(serviceName)
        local children = parent:GetChildren()
        table.insert(lines, serviceName .. ": " .. tostring(#children) .. " direct children")
    end
    proposal.Text = table.concat(lines, "\n")
    pending = nil
    status.Text = "Status: Read-only inspection completed. No changes made."
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

print("Roblox AI Developer v0.2 loaded (local actions only).")
