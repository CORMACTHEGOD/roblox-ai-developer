-- Orange Juice Mesh Editor, experimental v0.2
-- Separate, local-only Roblox Studio plugin. No OpenAI / Cloudflare / Roblox Assistant.
-- ACTUAL geometry: AssetService:CreateEditableMesh -> CreateMeshPartAsync.
-- Uses Studio's NATIVE Move/Scale/Rotate ribbon tools through a temporary transform proxy.
-- Object Mode transforms the MeshPart. Edit Mode transfers a proxy's native gizmo
-- movement/rotation/scale onto selected EditableMesh vertices. This is experimental.
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
local diagnostics = text(main, "Diagnostics: click Create Editable Cube to verify this plugin receives input.", 100, Color3.fromRGB(255, 208, 147))
local makeRow = row()
local createButton = button(makeRow, "Create Editable Cube", 1)
local modeRow = row()
local objectButton = button(modeRow, "Object Mode", 0.5)
local editButton = button(modeRow, "Edit Mode", 0.5)
local selectRow = row()
local vertexButton = button(selectRow, "Vertex", 1/3)
local edgeButton = button(selectRow, "Edge", 1/3)
local faceButton = button(selectRow, "Face", 1/3)

text(main, "USE ROBLOX STUDIO'S NORMAL TRANSFORM GIZMOS", 32, Color3.fromRGB(255, 184, 91))
text(main,
    "Edit: click Pick Geometry, then click a point, edge or face on the cube. Drag the usual Studio Move (2), Scale (3), or Rotate (4) tools. Pick Geometry again to change selection.",
    91, Color3.fromRGB(196, 226, 255))
local pickRow = row()
local pickButton = button(pickRow, "Pick Geometry in Viewport", 1)
local nativeRow = row()
local moveToolButton = button(nativeRow, "Studio Move", 1/3)
local scaleToolButton = button(nativeRow, "Studio Scale", 1/3)
local rotateToolButton = button(nativeRow, "Studio Rotate", 1/3)
local undoRow = row()
local undoButton = button(undoRow, "Undo Last Edit", 1)

text(main,
    "Prototype limits: one geometry selection at a time. Loop Cut, Bevel and Knife come next. Color and texture come later. No asset uploads.",
    92, Color3.fromRGB(186, 193, 208)
)

-- The EditableMesh is the sole source of the vertex/face topology.
-- IDs are stable but not necessarily sequential; always query them.
local state = {
    part = nil, mesh = nil, mode = "Object", selectionKind = "Vertex",
    selectedVertex = nil, selectedEdge = nil, selectedFace = nil,
    markers = {}, undo = {},
    proxy = nil, proxyConnections = {}, proxySyncing = false, proxyBaseline = nil,
    picking = false, dragging = false, dragRevision = 0,
    ribbonTool = Enum.RibbonTool.Move
}

local function message(msg)
    status.Text = tostring(msg)
end

local function diagnostic(stage, detail, isError)
    local contents = "[Orange Juice Mesh v0.2] " .. tostring(stage)
    if detail ~= nil then contents = contents .. ": " .. tostring(detail) end
    diagnostics.Text = contents
    if isError then
        status.Text = "FAILED at " .. tostring(stage) .. ". See Diagnostics and Studio Output."
        warn(contents)
    else
        status.Text = tostring(stage)
        print(contents)
    end
end

local function clearMarkers()
    for _, marker in ipairs(state.markers) do
        marker:Destroy()
    end
    table.clear(state.markers)
end

local function clearProxy()
    state.proxySyncing = true
    state.proxyBaseline = nil
    state.dragging = false
    state.dragRevision = state.dragRevision + 1
    for _, connection in ipairs(state.proxyConnections) do
        connection:Disconnect()
    end
    table.clear(state.proxyConnections)
    if state.proxy then
        state.proxy:Destroy()
        state.proxy = nil
    end
    state.proxySyncing = false
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
    local baseline = state.proxyBaseline
    table.insert(state.undo, {
        positions = positions,
        cframe = state.part.CFrame,
        size = state.part.Size,
        proxyCFrame = baseline and baseline.cframe or (state.proxy and state.proxy.CFrame),
        proxySize = baseline and baseline.size or (state.proxy and state.proxy.Size)
    })
    if #state.undo > 25 then table.remove(state.undo, 1) end
end

local function safeMeshScale()
    if not state.part then return nil end
    local meshSize = state.part.MeshSize
    if math.abs(meshSize.X) < 0.00001 or math.abs(meshSize.Y) < 0.00001
        or math.abs(meshSize.Z) < 0.00001 then return nil end
    return state.part.Size / meshSize
end

local function recaptureProxyBaseline()
    if not state.mesh or not state.proxy or not state.part then
        state.proxyBaseline = nil
        return
    end
    local ids = selectedIds()
    local meshScale = safeMeshScale()
    if #ids == 0 or not meshScale then
        state.proxyBaseline = nil
        return
    end
    local originalPositions = {}
    for _, id in ipairs(ids) do
        originalPositions[id] = state.mesh:GetPosition(id)
    end
    state.proxyBaseline = {
        ids = ids,
        positions = originalPositions,
        cframe = state.proxy.CFrame,
        size = state.proxy.Size,
        meshCFrame = state.part.CFrame,
        meshScale = meshScale
    }
end

-- The native Studio ribbon tools only transform selected Instances, not
-- EditableMesh subgeometry. An invisible, NON-GEOMETRY Part is selected as
-- a transform pivot. Its CFrame/Size changes are mapped to actual mesh vertices.
-- It is transient; the user-created model is still only ONE MeshPart.
local function onNativeGizmoChanged()
    if state.proxySyncing or not state.proxyBaseline or not state.proxy then return end
    if state.mode ~= "Edit" or state.picking then return end
    local baseline = state.proxyBaseline
    local proxyCF, proxySize = state.proxy.CFrame, state.proxy.Size
    if proxyCF == baseline.cframe and proxySize == baseline.size then return end
    if not state.dragging then
        snapshot()
        state.dragging = true
    end
    local factor = Vector3.new(
        proxySize.X / math.max(baseline.size.X, 0.01),
        proxySize.Y / math.max(baseline.size.Y, 0.01),
        proxySize.Z / math.max(baseline.size.Z, 0.01)
    )
    local success, err = pcall(function()
        for _, id in ipairs(baseline.ids) do
            local original = baseline.positions[id]
            local world = baseline.meshCFrame:PointToWorldSpace(original * baseline.meshScale)
            local relative = baseline.cframe:PointToObjectSpace(world)
            local stretched = relative * factor
            local newWorld = proxyCF:PointToWorldSpace(stretched)
            local newLocal = baseline.meshCFrame:PointToObjectSpace(newWorld) / baseline.meshScale
            state.mesh:SetPosition(id, newLocal)
        end
    end)
    if not success then
        diagnostic("Native gizmo transform", err, true)
        state.proxySyncing = true
        state.proxy.CFrame = baseline.cframe
        state.proxy.Size = baseline.size
        state.proxySyncing = false
        return
    end
    refreshMarkers()
    state.dragRevision = state.dragRevision + 1
    local revision = state.dragRevision
    task.delay(0.5, function()
        if state.dragRevision ~= revision or not state.dragging then return end
        state.dragging = false
        recaptureProxyBaseline()
        message("Applied native Studio transform to selected " .. state.selectionKind
            .. ". Use Pick Geometry to select another.")
    end)
end

local function createProxy()
    if state.proxy then return state.proxy end
    local proxy = Instance.new("Part")
    proxy.Name = "_OJ_Mesh_Gizmo_Pivot_DO_NOT_SAVE"
    proxy.Anchored = true
    proxy.CanCollide = false
    proxy.CanTouch = false
    proxy.CanQuery = false
    proxy.Transparency = 1
    proxy.CastShadow = false
    proxy.Locked = false
    proxy.Archivable = false
    proxy.Size = Vector3.one
    proxy.Parent = workspace
    state.proxy = proxy
    table.insert(state.proxyConnections,
        proxy:GetPropertyChangedSignal("CFrame"):Connect(onNativeGizmoChanged))
    table.insert(state.proxyConnections,
        proxy:GetPropertyChangedSignal("Size"):Connect(onNativeGizmoChanged))
    return proxy
end

local function selectNativeTool(tool)
    if not state.part then message("Create a mesh first."); return end
    local target = state.part
    if state.mode == "Edit" then
        if not state.proxyBaseline or not state.proxy then
            message("First click Pick Geometry, then a mesh vertex, edge or face.")
            return
        end
        target = state.proxy
    end
    local ok, err = pcall(function()
        state.picking = false
        plugin:Deactivate()
        Selection:Set({target})
        plugin:SelectRibbonTool(tool, UDim2.new())
    end)
    if not ok then
        diagnostic("Activate Roblox Studio ribbon tool", err, true)
        return
    end
    state.ribbonTool = tool
    message("Now drag Roblox Studio's normal " .. tostring(tool.Name)
        .. " gizmo. To pick different geometry, click Pick Geometry.")
end

local function prepareProxyForSelection()
    local ids = selectedIds()
    if #ids == 0 or not state.part or not state.mesh then return false end
    local proxy = createProxy()
    local center = Vector3.zero
    local minLocal = Vector3.new(math.huge, math.huge, math.huge)
    local maxLocal = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, id in ipairs(ids) do
        local world = worldOfVertex(id)
        if not world then
            diagnostic("Create edit gizmo", "Mesh dimensions are invalid", true)
            return false
        end
        center = center + world
        minLocal = minLocal:Min(state.mesh:GetPosition(id))
        maxLocal = maxLocal:Max(state.mesh:GetPosition(id))
    end
    center = center / #ids
    local scale = safeMeshScale()
    if not scale then return false end
    local size = (maxLocal - minLocal) * scale
    state.proxySyncing = true
    proxy.CFrame = CFrame.new(center) * state.part.CFrame.Rotation
    proxy.Size = Vector3.new(
        math.max(size.X, 1.0),
        math.max(size.Y, 1.0),
        math.max(size.Z, 1.0)
    )
    state.proxySyncing = false
    state.dragRevision = state.dragRevision + 1
    state.dragging = false
    recaptureProxyBaseline()
    return state.proxyBaseline ~= nil
end

local function activateGeometryPick()
    if state.mode ~= "Edit" or not state.part then
        message("Choose Edit Mode and create a mesh first.")
        return
    end
    state.picking = true
    state.dragRevision = state.dragRevision + 1
    state.dragging = false
    state.proxyBaseline = nil
    -- Geometry is chosen through the plugin mouse. The native ribbon tool
    -- takes over again when selection is complete.
    local ok, err = pcall(function()
        Selection:Set({state.part})
        plugin:Activate(true)
    end)
    if not ok then
        diagnostic("Activate geometry picking", err, true)
        return
    end
    refreshMarkers()
    message("PICK " .. state.selectionKind .. ": click the cube in the viewport.")
end

local function setMode(nextMode)
    state.mode = nextMode
    state.picking = false
    clearGeometrySelection()
    if nextMode == "Object" then
        clearProxy()
    else
        state.proxyBaseline = nil
    end
    objectButton.BackgroundColor3 = nextMode == "Object"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    editButton.BackgroundColor3 = nextMode == "Edit"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    refreshMarkers()
    if not state.part then
        message("Create an Editable Cube first.")
    elseif nextMode == "Edit" then
        activateGeometryPick()
    else
        selectNativeTool(state.ribbonTool)
        message("OBJECT MODE: use Roblox Studio's Move (2), Scale (3), Rotate (4) on the whole MeshPart.")
    end
end

local function setSelectionKind(kind)
    state.selectionKind = kind
    clearGeometrySelection()
    state.proxyBaseline = nil
    state.dragRevision = state.dragRevision + 1
    state.dragging = false
    vertexButton.BackgroundColor3 = kind == "Vertex"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    edgeButton.BackgroundColor3 = kind == "Edge"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    faceButton.BackgroundColor3 = kind == "Face"
        and Color3.fromRGB(213, 122, 35) or Color3.fromRGB(48, 87, 133)
    refreshMarkers()
    if state.mode == "Edit" and state.part then
        activateGeometryPick()
    else
        message("Selection mode: " .. kind)
    end
end

local function makeCube()
    diagnostic("Button click detected", "Attempting real mesh creation")
    local stage = "CreateEditableMesh"
    local ok, result = pcall(function()
        local editable = AssetService:CreateEditableMesh()
        if not editable then error("CreateEditableMesh returned nil (permissions or memory).") end
        diagnostic("EditableMesh created", "Adding eight shared vertices")
        stage = "AddVertex"
        local v = {}
        for _, p in ipairs({
            Vector3.new(-2,-2,-2), Vector3.new(2,-2,-2),
            Vector3.new(2,2,-2), Vector3.new(-2,2,-2),
            Vector3.new(-2,-2,2), Vector3.new(2,-2,2),
            Vector3.new(2,2,2), Vector3.new(-2,2,2)
        }) do
            table.insert(v, editable:AddVertex(p))
        end
        -- TWO TRIANGLES per side, no EditableMesh Quads Studio beta required.
        -- The eight shared vertex IDs keep all twelve triangles connected.
        diagnostic("Vertices created", "Building 12 standard triangle faces")
        stage = "AddTriangle"
        for _, face in ipairs({
            {v[1],v[4],v[3],v[2]}, -- back
            {v[5],v[6],v[7],v[8]}, -- front
            {v[1],v[5],v[8],v[4]}, -- left
            {v[2],v[3],v[7],v[6]}, -- right
            {v[1],v[2],v[6],v[5]}, -- bottom
            {v[4],v[8],v[7],v[3]}  -- top
        }) do
            editable:AddTriangle(face[1],face[2],face[3])
            editable:AddTriangle(face[1],face[3],face[4])
        end
        diagnostic("Triangles created", "Converting connected geometry into MeshPart")
        stage = "CreateMeshPartAsync"
        local part = AssetService:CreateMeshPartAsync(
            Content.fromObject(editable),
            {CollisionFidelity = Enum.CollisionFidelity.Hull}
        )
        if not part then error("CreateMeshPartAsync returned nil.") end
        diagnostic("MeshPart created", "Placing it in Workspace")
        stage = "Place in Workspace"
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
        diagnostic(stage, result, true)
        return
    end
    clearProxy()
    state.mesh, state.part = result.mesh, result.part
    state.undo = {}
    clearGeometrySelection()
    local setupOk, setupErr = pcall(function()
        Selection:Set({state.part})
        widget.Enabled = true
        state.selectionKind = "Vertex"
        setMode("Edit")
    end)
    if not setupOk then
        diagnostic("Mesh created but editor setup", setupErr, true)
        return
    end
    diagnostic("SUCCESS", "Created real MeshPart with 8 shared vertices/12 triangles. Click a vertex, then use Studio Move/Scale/Rotate.")
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
    if not widget.Enabled or state.mode ~= "Edit" or not state.picking
        or not state.mesh or not state.part or mouse.Target ~= state.part then return end
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
                center = center + world
            end
            center = center / #ids
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
        if prepareProxyForSelection() then
            selectNativeTool(state.ribbonTool)
        else
            message("Selected geometry but the gizmo could not be initialized.")
        end
    else
        message("Click closer to the " .. state.selectionKind:lower()
            .. " you want to edit. Try rotating the camera.")
    end
end)

createButton.MouseButton1Click:Connect(function()
    local ok, err = pcall(makeCube)
    if not ok then diagnostic("Unexpected click handler error", err, true) end
end)
objectButton.MouseButton1Click:Connect(function() setMode("Object") end)
editButton.MouseButton1Click:Connect(function() setMode("Edit") end)
vertexButton.MouseButton1Click:Connect(function() setSelectionKind("Vertex") end)
edgeButton.MouseButton1Click:Connect(function() setSelectionKind("Edge") end)
faceButton.MouseButton1Click:Connect(function() setSelectionKind("Face") end)
pickButton.MouseButton1Click:Connect(activateGeometryPick)
moveToolButton.MouseButton1Click:Connect(function() selectNativeTool(Enum.RibbonTool.Move) end)
scaleToolButton.MouseButton1Click:Connect(function() selectNativeTool(Enum.RibbonTool.Scale) end)
rotateToolButton.MouseButton1Click:Connect(function() selectNativeTool(Enum.RibbonTool.Rotate) end)

undoButton.MouseButton1Click:Connect(function()
    if not state.mesh or not state.part then message("No active mesh."); return end
    local last = table.remove(state.undo)
    if not last then message("No mesh edit to undo."); return end
    local ok, err = pcall(function()
        for id, pos in pairs(last.positions) do
            state.mesh:SetPosition(id, pos)
        end
        state.part.CFrame = last.cframe
        state.part.Size = last.size
        if state.proxy and last.proxyCFrame and last.proxySize then
            state.proxySyncing = true
            state.proxy.CFrame = last.proxyCFrame
            state.proxy.Size = last.proxySize
            state.proxySyncing = false
            state.dragRevision = state.dragRevision + 1
            state.dragging = false
            recaptureProxyBaseline()
        end
    end)
    state.proxySyncing = false
    if not ok then diagnostic("Undo", err, true); return end
    refreshMarkers()
    message("Undid last mesh edit (plugin history). Note that Studio's Ctrl+Z is separate.")
end)

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
    if widget.Enabled then
        if state.mode == "Edit" then
            activateGeometryPick()
        elseif state.part then
            selectNativeTool(state.ribbonTool)
        end
    else
        state.picking = false
        clearMarkers()
        clearProxy()
        plugin:Deactivate()
        if state.part then Selection:Set({state.part}) end
    end
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not widget.Enabled then
        state.picking = false
        clearMarkers()
        clearProxy()
    elseif state.mesh and state.part then
        refreshMarkers()
    end
end)

plugin.Unloading:Connect(function()
    clearMarkers()
    clearProxy()
    if state.part and state.part.Parent then
        Selection:Set({state.part})
    end
end)

setMode("Object")
setSelectionKind("Vertex")
message("Create Editable Cube, choose Edit Mode and Pick Geometry. Studio gizmos edit mesh vertices.")
print("[Orange Juice Mesh v0.2] Loaded. This experimental build mirrors native ribbon-tool transformations via a transient pivot.")
