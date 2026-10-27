-- Orange Juice Mesh Editor, experimental v0.1
-- Separate, local-only Roblox Studio plugin. No OpenAI / Cloudflare / Roblox Assistant.
-- ACTUAL geometry: AssetService:CreateEditableMesh -> CreateMeshPartAsync.
-- Prototype: new connected cube, Object/Edit, vertex/edge/face picking, move/rotate/scale, undo.
-- Loop Cut, Bevel, Knife, color and texture workflows are NOT implemented yet.
-- Do not publish this experimental version until viewport/persistence testing.

local AssetService = game:GetService("AssetService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local toolbar = plugin:CreateToolbar("Orange Juice Mesh")
local toggleButton = toolbar:CreateButton(
    "OpenOrangeJuiceMeshEditor", "Toggle the local mesh editor", "", "OJ Mesh"
)
toggleButton.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right, true, false, 332, 570, 280, 380
)
local widget = plugin:CreateDockWidgetPluginGuiAsync("OrangeJuiceMeshEditorPrototypeV01", info)
widget.Title = "Orange Juice Mesh Editor • Prototype"

local main = Instance.new("ScrollingFrame")
main.Name = "EditorControls"
main.Size = UDim2.fromScale(1, 1)
main.ScrollBarThickness = 5
main.BackgroundColor3 = Color3.fromRGB(23, 28, 44)
main.BorderSizePixel = 0
main.CanvasSize = UDim2.fromOffset(0, 0)
main.AutomaticCanvasSize = Enum.AutomaticSize.Y
main.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = main

local stack = Instance.new("UIListLayout")
stack.FillDirection = Enum.FillDirection.Vertical
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Padding = UDim.new(0, 8)
stack.Parent = main

local function text(parent, value, height, color)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, height)
    label.BackgroundTransparency = 1
    label.Text = value
    label.TextWrapped = true
    label.TextColor3 = color or Color3.fromRGB(237, 244, 255)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function button(parent, value, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(width or 1, -4, 0, 33)
    b.BackgroundColor3 = Color3.fromRGB(48, 87, 133)
    b.BorderSizePixel = 0
    b.Text = value
    b.TextColor3 = Color3.fromRGB(245, 251, 255)
    b.TextSize = 12
    b.TextWrapped = true
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = b
    b.Parent = parent
    return b
end

local function row()
    local result = Instance.new("Frame")
    result.Size = UDim2.new(1, 0, 0, 34)
    result.BackgroundTransparency = 1
    result.Parent = main
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = result
    return result
end

text(main, "REAL MESH MODELING  •  LOCAL ONLY", 26, Color3.fromRGB(255, 177, 80))
text(main, "New mesh from scratch; no ordinary Parts. Click mesh geometry in the 3D viewport to select it.", 48)

local status = text(main, "Create a cube to start editing.", 56, Color3.fromRGB(179, 211, 253))
local makeRow = row()
local createButton = button(makeRow, "Create Editable Cube", 1)
local modeRow = row()
local objectButton = button(modeRow, "Object Mode", 0.5)
local editButton = button(modeRow, "Edit Mode", 0.5)
local selectRow = row()
local vertexButton = button(selectRow, "Vertex", 1/3)
local edgeButton = button(selectRow, "Edge", 1/3)
local faceButton = button(selectRow, "Face", 1/3)

text(main, "MOVE • 0.25 STUD IN LOCAL AXIS", 22)
local xRow = row()
local moveXN = button(xRow, "X −", 1/3)
local moveXP = button(xRow, "X +", 1/3)
local moveYN = button(xRow, "Y −", 1/3)
local yRow = row()
local moveYP = button(yRow, "Y +", 1/3)
local moveZN = button(yRow, "Z −", 1/3)
local moveZP = button(yRow, "Z +", 1/3)

text(main, "SCALE / ROTATE • LOCAL AXES", 22)
local scaleRow = row()
local scaleDown = button(scaleRow, "Scale −10%", 0.5)
local scaleUp = button(scaleRow, "Scale +10%", 0.5)
local rotRow = row()
local rotLeft = button(rotRow, "Rotate Z −15°", 0.5)
local rotRight = button(rotRow, "Rotate Z +15°", 0.5)
local undoRow = row()
local undoButton = button(undoRow, "Undo Last Transform", 1)

text(main,
    "Prototype limits: one geometry selection at a time. Loop Cut, Bevel and Knife come next. Color and texture come later. No asset uploads.",
    92, Color3.fromRGB(186, 193, 208)
)

-- The EditableMesh is the sole source of the vertex/face topology.
-- IDs are stable but not necessarily sequential; always query them.
local state = {
    part = nil, mesh = nil, mode = "Object", selectionKind = "Vertex",
    selectedVertex = nil, selectedEdge = nil, selectedFace = nil,
    markers = {}, undo = {}
}

local function message(msg)
    status.Text = tostring(msg)
end

local function clearMarkers()
    for _, marker in ipairs(state.markers) do
        marker:Destroy()
    end
    table.clear(state.markers)
end

local function clearGeometrySelection()
    state.selectedVertex = nil
    state.selectedEdge = nil
    state.selectedFace = nil
end

local function selectedIds()
    local mesh = state.mesh
    if not mesh then return {} end
    if state.selectionKind == "Vertex" and state.selectedVertex then
        return {state.selectedVertex}
    end
    if state.selectionKind == "Edge" and state.selectedEdge then
        return {state.selectedEdge[1], state.selectedEdge[2]}
    end
    if state.selectionKind == "Face" and state.selectedFace then
        return mesh:GetFaceVertices(state.selectedFace)
    end
    return {}
end

local function selectedSet()
    local result = {}
    for _, id in ipairs(selectedIds()) do result[id] = true end
    return result
end

local function worldOfVertex(id)
    local meshPart, editable = state.part, state.mesh
    if not meshPart or not editable then return nil end
    local localPos = editable:GetPosition(id)
    -- For a newly-created cube the mesh and MeshPart have the same unit scale.
    -- Account for subsequent Object Mode scaling of the MeshPart.
    local meshSize = meshPart.MeshSize
    if math.abs(meshSize.X) < 0.001 or math.abs(meshSize.Y) < 0.001
        or math.abs(meshSize.Z) < 0.001 then return nil end
    local scale = meshPart.Size / meshSize
    return meshPart.CFrame:PointToWorldSpace(localPos * scale)
end

local function refreshMarkers()
    clearMarkers()
    if state.mode ~= "Edit" or not state.mesh or not state.part then return end
    local selected = selectedSet()
    for _, id in ipairs(state.mesh:GetVertices()) do
        local pos = state.mesh:GetPosition(id)
        local dot = Instance.new("SphereHandleAdornment")
        dot.Name = "OJ_TemporaryVertexHandle"
        dot.Adornee = state.part
        dot.CFrame = CFrame.new(pos)
        dot.Radius = selected[id] and 0.16 or 0.105
        dot.Color3 = selected[id]
            and Color3.fromRGB(255, 175, 52) or Color3.fromRGB(62, 220, 255)
        dot.Transparency = 0.08
        dot.AlwaysOnTop = true
        dot.ZIndex = 10
        dot.Parent = state.part
        table.insert(state.markers, dot)
    end
end

local function snapshot()
    if not state.mesh or not state.part then return end
    local positions = {}
    for _, id in ipairs(state.mesh:GetVertices()) do
        positions[id] = state.mesh:GetPosition(id)
    end
    table.insert(state.undo, {
        positions = positions, cframe = state.part.CFrame, size = state.part.Size
    })
    if #state.undo > 25 then table.remove(state.undo, 1) end
end

local function transformVertices(fn)
    local ids = selectedIds()
    if #ids == 0 then
        message("Edit Mode: click one vertex, edge or face first.")
        return
    end
    snapshot()
    local pivot = Vector3.zero
    for _, id in ipairs(ids) do pivot += state.mesh:GetPosition(id) end
    pivot /= #ids
    for _, id in ipairs(ids) do
        local old = state.mesh:GetPosition(id)
        state.mesh:SetPosition(id, fn(old, pivot))
    end
    refreshMarkers()
    message("Transformed " .. #ids .. " shared mesh vertices.")
end

local function move(dx, dy, dz)
    if not state.part then message("Create a mesh first."); return end
    if state.mode == "Object" then
        snapshot()
        state.part.CFrame *= CFrame.new(dx, dy, dz)
        message("Moved mesh object.")
    else
        transformVertices(function(p)
            return p + Vector3.new(dx, dy, dz)
        end)
    end
end

local function scale(multiplier)
    if not state.part then message("Create a mesh first."); return end
    if state.mode == "Object" then
        snapshot()
        state.part.Size *= multiplier
        message("Scaled mesh object.")
    else
        transformVertices(function(p, pivot)
            return pivot + (p - pivot) * multiplier
        end)
    end
end

local function rotate(angle)
    if not state.part then message("Create a mesh first."); return end
    local rotation = CFrame.Angles(0, 0, math.rad(angle))
    if state.mode == "Object" then
        snapshot()
        state.part.CFrame *= rotation
        message("Rotated mesh object on local Z.")
    else
        transformVertices(function(p, pivot)
            return pivot + rotation:VectorToWorldSpace(p - pivot)
        end)
    end
end

local function setMode(nextMode)
    state.mode = nextMode
    clearGeometrySelection()
    objectButton.BackgroundColor3 = nextMode == "Object"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    editButton.BackgroundColor3 = nextMode == "Edit"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    refreshMarkers()
    message(nextMode .. " Mode. " .. (nextMode == "Edit"
        and "Click a vertex, edge or face in the viewport."
        or "Transform the complete mesh."))
end

local function setSelectionKind(kind)
    state.selectionKind = kind
    clearGeometrySelection()
    vertexButton.BackgroundColor3 = kind == "Vertex"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    edgeButton.BackgroundColor3 = kind == "Edge"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    faceButton.BackgroundColor3 = kind == "Face"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    refreshMarkers()
    message("Edit " .. kind .. " selection: click your mesh.")
end

local function makeCube()
    if state.mesh then clearMarkers() end
    local ok, result = pcall(function()
        local editable = AssetService:CreateEditableMesh()
        if not editable then error("CreateEditableMesh returned nil.") end
        local v = {}
        for _, p in ipairs({
            Vector3.new(-2,-2,-2), Vector3.new(2,-2,-2),
            Vector3.new(2,2,-2), Vector3.new(-2,2,-2),
            Vector3.new(-2,-2,2), Vector3.new(2,-2,2),
            Vector3.new(2,2,2), Vector3.new(-2,2,2)
        }) do
            table.insert(v, editable:AddVertex(p))
        end
        -- CCW winding as viewed from outside. Shared IDs join neighboring faces.
        for _, face in ipairs({
            {v[1],v[4],v[3],v[2]}, -- rear
            {v[5],v[6],v[7],v[8]}, -- front
            {v[1],v[5],v[8],v[4]}, -- left
            {v[2],v[3],v[7],v[6]}, -- right
            {v[1],v[2],v[6],v[5]}, -- bottom
            {v[4],v[8],v[7],v[3]}  -- top
        }) do
            editable:AddFace(face)
        end
        local part = AssetService:CreateMeshPartAsync(
            Content.fromObject(editable),
            {CollisionFidelity = Enum.CollisionFidelity.Hull}
        )
        part.Name = "Orange Juice Editable Cube"
        part.Anchored = true
        part.CanCollide = true
        part.Size = Vector3.new(4,4,4)
        part.Color = Color3.fromRGB(255, 159, 72)
        part.Material = Enum.Material.SmoothPlastic
        part.Position = Vector3.new(0, 5, 0)
        part.Parent = workspace
        return {mesh = editable, part = part}
    end)
    if not ok then
        message("Mesh API unavailable: " .. tostring(result))
        return
    end
    state.mesh, state.part = result.mesh, result.part
    state.undo = {}
    clearGeometrySelection()
    Selection:Set({state.part})
    widget.Enabled = true
    plugin:Activate(true)
    setMode("Edit")
    setSelectionKind("Vertex")
    message("Created ONE real MeshPart with 8 shared vertices and 6 quad faces.")
end

local function screenPoint(pos)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local point, inFront = camera:WorldToViewportPoint(pos)
    if not inFront then return nil end
    return Vector2.new(point.X, point.Y)
end

local function mouseDistToSegment(m, a, b)
    local d = b - a
    local denom = d:Dot(d)
    if denom < 1e-4 then return (m - a).Magnitude end
    local t = math.clamp((m - a):Dot(d) / denom, 0, 1)
    return (m - (a + d*t)).Magnitude
end

local function gatherEdges()
    local result, seen = {}, {}
    for _, faceId in ipairs(state.mesh:GetFaces()) do
        local corners = state.mesh:GetFaceVertices(faceId)
        for i = 1, #corners do
            local a, b = corners[i], corners[i % #corners + 1]
            local low, high = math.min(a,b), math.max(a,b)
            local key = tostring(low) .. ":" .. tostring(high)
            if not seen[key] then
                seen[key] = true
                table.insert(result, {a,b})
            end
        end
    end
    return result
end

local mouse = plugin:GetMouse()
mouse.Button1Down:Connect(function()
    if not widget.Enabled or state.mode ~= "Edit" or not state.mesh
        or not state.part or mouse.Target ~= state.part then return end
    local m = Vector2.new(mouse.X, mouse.Y)
    local best = math.huge
    local chosen
    if state.selectionKind == "Vertex" then
        for _, id in ipairs(state.mesh:GetVertices()) do
            local world = worldOfVertex(id)
            local point = world and screenPoint(world)
            if point then
                local d = (m-point).Magnitude
                if d < best then best, chosen = d, id end
            end
        end
        if best <= 30 then
            clearGeometrySelection()
            state.selectedVertex = chosen
        end
    elseif state.selectionKind == "Edge" then
        for _, edge in ipairs(gatherEdges()) do
            local a, b = worldOfVertex(edge[1]), worldOfVertex(edge[2])
            local sa, sb = a and screenPoint(a), b and screenPoint(b)
            if sa and sb then
                local d = mouseDistToSegment(m, sa, sb)
                if d < best then best, chosen = d, edge end
            end
        end
        if best <= 27 then
            clearGeometrySelection()
            state.selectedEdge = chosen
        end
    elseif state.selectionKind == "Face" then
        for _, id in ipairs(state.mesh:GetFaces()) do
            local ids = state.mesh:GetFaceVertices(id)
            local center = Vector3.zero
            for _, vertexId in ipairs(ids) do
                local world = worldOfVertex(vertexId)
                if not world then return end
                center += world
            end
            center /= #ids
            local projected = screenPoint(center)
            if projected then
                local d = (m-projected).Magnitude
                if d < best then best, chosen = d, id end
            end
        end
        if best <= 165 then
            clearGeometrySelection()
            state.selectedFace = chosen
        end
    end
    refreshMarkers()
    if chosen then
        message("Selected " .. state.selectionKind .. ". Move / Scale / Rotate to edit.")
    end
end)

createButton.MouseButton1Click:Connect(makeCube)
objectButton.MouseButton1Click:Connect(function() setMode("Object") end)
editButton.MouseButton1Click:Connect(function() setMode("Edit") end)
vertexButton.MouseButton1Click:Connect(function() setSelectionKind("Vertex") end)
edgeButton.MouseButton1Click:Connect(function() setSelectionKind("Edge") end)
faceButton.MouseButton1Click:Connect(function() setSelectionKind("Face") end)

moveXN.MouseButton1Click:Connect(function() move(-0.25,0,0) end)
moveXP.MouseButton1Click:Connect(function() move(0.25,0,0) end)
moveYN.MouseButton1Click:Connect(function() move(0,-0.25,0) end)
moveYP.MouseButton1Click:Connect(function() move(0,0.25,0) end)
moveZN.MouseButton1Click:Connect(function() move(0,0,-0.25) end)
moveZP.MouseButton1Click:Connect(function() move(0,0,0.25) end)
scaleDown.MouseButton1Click:Connect(function() scale(0.9) end)
scaleUp.MouseButton1Click:Connect(function() scale(1.1) end)
rotLeft.MouseButton1Click:Connect(function() rotate(-15) end)
rotRight.MouseButton1Click:Connect(function() rotate(15) end)

undoButton.MouseButton1Click:Connect(function()
    if not state.mesh or not state.part then message("No active mesh."); return end
    local last = table.remove(state.undo)
    if not last then message("No transform to undo."); return end
    local ok, err = pcall(function()
        for id, pos in pairs(last.positions) do
            state.mesh:SetPosition(id, pos)
        end
        state.part.CFrame = last.cframe
        state.part.Size = last.size
    end)
    if not ok then message("Undo failed: " .. tostring(err)); return end
    refreshMarkers()
    message("Undid the last transform.")
end)

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
    if widget.Enabled then
        plugin:Activate(true)
    else
        clearMarkers()
        plugin:Deactivate()
    end
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not widget.Enabled then
        clearMarkers()
    elseif state.mesh and state.part then
        refreshMarkers()
    end
end)

plugin.Unloading:Connect(function()
    clearMarkers()
end)

setMode("Object")
setSelectionKind("Vertex")
message("Create an Editable Cube, then switch between Object and Edit Mode.")
