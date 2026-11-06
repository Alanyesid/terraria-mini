--[[
    Speed Hub - script para el ejecutor Delta (Roblox)
    --------------------------------------------------
    Módulos del panel:

    VELOCIDAD
      - ON/OFF: la velocidad sube poco a poco hasta la máxima.
      - + / - : cambia la velocidad máxima (límite 1000).

    TELETRANSPORTE
      - Guardar origen : guarda dónde estás (tu base).
      - Volver origen  : te lleva al origen guardado.
      - Guardar punto  : guarda un lugar al que quieras ir después.
      - Ir a punto     : te lleva a ese lugar.
      - Ir al medio    : te lleva al centro del mapa.
      Si vas a un punto o al medio sin haber guardado origen,
      el origen se guarda solo en el lugar donde estabas.

    AUTO-REGRESO
      - Cuando está en ON y agarras un objeto (Tool),
        te teletransporta solo al origen.

    X: cierra todo y vuelve a la velocidad normal.
]]

----------------------------------------------------------------
-- CONFIGURACIÓN
----------------------------------------------------------------
local VELOCIDAD_NORMAL  = 16    -- velocidad por defecto de Roblox
local VELOCIDAD_INICIAL = 20    -- desde dónde empieza a subir
local VELOCIDAD_MAXIMA  = 1000  -- hasta dónde llega
local LIMITE_MAXIMA     = 1000  -- tope de los botones +
local INCREMENTO        = 10    -- cuánto sube en cada paso
local INTERVALO         = 0.1   -- segundos entre cada subida
local PASO_MAXIMA       = 50    -- cuánto cambian los botones + / -
local ALTURA_TP         = 3     -- cuántos studs por encima del punto apareces

----------------------------------------------------------------
-- SI YA HABÍA UNA COPIA ABIERTA, SE CIERRA
----------------------------------------------------------------
if _G.SpeedHubCerrar then
    pcall(_G.SpeedHubCerrar)
end

----------------------------------------------------------------
-- SERVICIOS Y ESTADO
----------------------------------------------------------------
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer

local activo          = false
local velocidadActual = VELOCIDAD_NORMAL
local acumulado       = 0
local autoRegreso     = false
local origen          = nil   -- Vector3
local punto           = nil   -- Vector3
local conexiones      = {}
local vistos          = setmetatable({}, { __mode = "k" })

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

----------------------------------------------------------------
-- INTERFAZ
----------------------------------------------------------------
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local viejo = guiParent:FindFirstChild("SpeedHubGui")
    if viejo then viejo:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedHubGui"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 310)
frame.Position = UDim2.new(0, 20, 0.25, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local GRIS  = Color3.fromRGB(60, 60, 70)
local ROJO  = Color3.fromRGB(170, 40, 40)
local VERDE = Color3.fromRGB(40, 170, 70)
local AZUL  = Color3.fromRGB(0, 200, 255)

local function crearLabel(texto, y, color, tam)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -50, 0, 20)
    l.Position = UDim2.new(0, 10, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = tam or 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = texto
    l.Parent = frame
    return l
end

local function crearBoton(texto, x, y, w, h, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = texto
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- Título y cerrar
crearLabel("Speed Hub", 8, AZUL, 16)
local btnCerrar = crearBoton("X", 186, 6, 26, 26, ROJO)

-- Velocidad
crearLabel("VELOCIDAD", 38, AZUL, 12)
local lblVel = crearLabel("Velocidad: 16", 56)
local lblMax = crearLabel("Máxima: " .. VELOCIDAD_MAXIMA, 76)
local btnToggle = crearBoton("OFF", 10, 100, 104, 34, ROJO)
local btnMenos  = crearBoton("-",   120, 100, 42, 34, GRIS)
local btnMas    = crearBoton("+",   168, 100, 42, 34, GRIS)

-- Teletransporte
crearLabel("TELETRANSPORTE", 144, AZUL, 12)
local btnGuardarOrigen = crearBoton("Guardar origen", 10, 166, 97, 30, GRIS)
local btnVolverOrigen  = crearBoton("Volver origen", 113, 166, 97, 30, GRIS)
local btnGuardarPunto  = crearBoton("Guardar punto", 10, 202, 97, 30, GRIS)
local btnIrPunto       = crearBoton("Ir a punto",    113, 202, 97, 30, GRIS)
local btnIrMedio       = crearBoton("Ir al medio",   10, 238, 97, 30, GRIS)
local btnAuto          = crearBoton("Auto: OFF",     113, 238, 97, 30, ROJO)

-- Estado
local lblEstado = crearLabel("Listo", 278, Color3.fromRGB(200, 200, 200), 12)
lblEstado.Size = UDim2.new(1, -20, 0, 20)

local function setEstado(texto)
    lblEstado.Text = texto
end

local function actualizarUI()
    lblVel.Text = "Velocidad: " .. math.floor(velocidadActual)
    lblMax.Text = "Máxima: " .. VELOCIDAD_MAXIMA
    btnToggle.Text = activo and "ON" or "OFF"
    btnToggle.BackgroundColor3 = activo and VERDE or ROJO
    btnAuto.Text = autoRegreso and "Auto: ON" or "Auto: OFF"
    btnAuto.BackgroundColor3 = autoRegreso and VERDE or ROJO
end

----------------------------------------------------------------
-- MÓDULO: VELOCIDAD
----------------------------------------------------------------
local function setActivo(valor)
    activo = valor
    acumulado = 0
    velocidadActual = activo and VELOCIDAD_INICIAL or VELOCIDAD_NORMAL
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = velocidadActual end
    actualizarUI()
end

btnToggle.MouseButton1Click:Connect(function()
    setActivo(not activo)
end)

btnMas.MouseButton1Click:Connect(function()
    VELOCIDAD_MAXIMA = math.min(LIMITE_MAXIMA, VELOCIDAD_MAXIMA + PASO_MAXIMA)
    actualizarUI()
end)

btnMenos.MouseButton1Click:Connect(function()
    VELOCIDAD_MAXIMA = math.max(VELOCIDAD_INICIAL, VELOCIDAD_MAXIMA - PASO_MAXIMA)
    if velocidadActual > VELOCIDAD_MAXIMA then velocidadActual = VELOCIDAD_MAXIMA end
    actualizarUI()
end)

table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    if not activo then return end
    local hum = getHumanoid()
    if not hum then return end

    acumulado = acumulado + dt
    if acumulado >= INTERVALO then
        acumulado = 0
        if velocidadActual < VELOCIDAD_MAXIMA then
            velocidadActual = math.min(velocidadActual + INCREMENTO, VELOCIDAD_MAXIMA)
            actualizarUI()
        end
    end

    if hum.WalkSpeed ~= velocidadActual then
        hum.WalkSpeed = velocidadActual
    end
end))

----------------------------------------------------------------
-- MÓDULO: TELETRANSPORTE
----------------------------------------------------------------
local function teletransportar(pos)
    local hrp = getHRP()
    if not hrp or not pos then return false end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, ALTURA_TP, 0))
    return true
end

local function posicionActual()
    local hrp = getHRP()
    return hrp and hrp.Position
end

-- Si no hay origen guardado, se guarda donde estás antes de irte
local function asegurarOrigen()
    if not origen then
        origen = posicionActual()
        if origen then setEstado("Origen guardado automáticamente") end
    end
end

local function centroDelMapa()
    local ok, cf, size = pcall(function()
        return workspace:GetBoundingBox()
    end)
    if not ok or not cf then return nil end

    -- Busca el suelo bajando desde arriba del centro
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }
    local desde = Vector3.new(cf.Position.X, cf.Position.Y + size.Y / 2 + 50, cf.Position.Z)
    local hit = workspace:Raycast(desde, Vector3.new(0, -(size.Y + 100), 0), params)
    return hit and hit.Position or cf.Position
end

btnGuardarOrigen.MouseButton1Click:Connect(function()
    origen = posicionActual()
    setEstado(origen and "Origen guardado" or "No se encontró el personaje")
end)

btnVolverOrigen.MouseButton1Click:Connect(function()
    if not origen then setEstado("Primero guarda un origen") return end
    setEstado(teletransportar(origen) and "En el origen" or "No se pudo teletransportar")
end)

btnGuardarPunto.MouseButton1Click:Connect(function()
    punto = posicionActual()
    setEstado(punto and "Punto guardado" or "No se encontró el personaje")
end)

btnIrPunto.MouseButton1Click:Connect(function()
    if not punto then setEstado("Primero guarda un punto") return end
    asegurarOrigen()
    setEstado(teletransportar(punto) and "En el punto" or "No se pudo teletransportar")
end)

btnIrMedio.MouseButton1Click:Connect(function()
    local centro = centroDelMapa()
    if not centro then setEstado("No se pudo calcular el medio") return end
    asegurarOrigen()
    setEstado(teletransportar(centro) and "En el medio del mapa" or "No se pudo teletransportar")
end)

----------------------------------------------------------------
-- MÓDULO: AUTO-REGRESO AL AGARRAR UN OBJETO
----------------------------------------------------------------
btnAuto.MouseButton1Click:Connect(function()
    autoRegreso = not autoRegreso
    if autoRegreso and not origen then
        setEstado("Auto ON - guarda un origen")
    else
        setEstado(autoRegreso and "Auto-regreso activado" or "Auto-regreso apagado")
    end
    actualizarUI()
end)

local function alAgregarObjeto(obj)
    if not obj:IsA("Tool") or vistos[obj] then return end
    vistos[obj] = true
    if autoRegreso and origen then
        task.wait(0.1)
        if teletransportar(origen) then
            setEstado("Agarraste " .. obj.Name .. " - de vuelta al origen")
        end
    end
end

local function vigilar(contenedor)
    if not contenedor then return end
    -- Lo que ya tenías no cuenta como objeto nuevo
    for _, obj in ipairs(contenedor:GetChildren()) do
        if obj:IsA("Tool") then vistos[obj] = true end
    end
    table.insert(conexiones, contenedor.ChildAdded:Connect(alAgregarObjeto))
end

local function prepararPersonaje(char)
    vigilar(char)
    vigilar(player:WaitForChild("Backpack", 5))
end

if player.Character then
    task.spawn(prepararPersonaje, player.Character)
end

-- Al reaparecer: vigila el nuevo personaje y reinicia la rampa
table.insert(conexiones, player.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    prepararPersonaje(char)
    if activo then
        velocidadActual = VELOCIDAD_INICIAL
        acumulado = 0
        actualizarUI()
    end
end))

----------------------------------------------------------------
-- CERRAR
----------------------------------------------------------------
local function cerrar()
    activo = false
    autoRegreso = false
    for _, c in ipairs(conexiones) do c:Disconnect() end
    conexiones = {}
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = VELOCIDAD_NORMAL end
    if gui then gui:Destroy() end
    _G.SpeedHubCerrar = nil
end

_G.SpeedHubCerrar = cerrar
btnCerrar.MouseButton1Click:Connect(cerrar)

actualizarUI()
