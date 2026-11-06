--[[
    Speed Hub - script para el ejecutor Delta (Roblox)
    --------------------------------------------------
    Módulos del panel:

    VELOCIDAD
      - Escribe la velocidad que quieras (por ejemplo 100, 200, 300)
        y pulsa OK o Enter. Se aplica de una vez, sin ir subiendo.
      - ON/OFF: activa o quita la velocidad (OFF = normal, 16).
      - Límite: 1000.

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

    VEHÍCULO (auto / moto)
      - Cuando te subes a un vehículo y aceleras, lo empuja
        hasta la velocidad elegida.
      - ON/OFF y + / - para cambiar la velocidad (límite 1000).

    INVENCIBLE
      - Rellena tu vida apenas baja y evita que el personaje muera.
      - Solo funciona en juegos donde el daño se maneja en tu
        pantalla; si el servidor controla la vida, no tiene efecto.

    X: cierra todo y deja el personaje normal.
]]

----------------------------------------------------------------
-- CONFIGURACIÓN
----------------------------------------------------------------
local VELOCIDAD_NORMAL   = 16    -- velocidad por defecto de Roblox
local VELOCIDAD_ELEGIDA  = 100   -- velocidad que aparece escrita al iniciar
local LIMITE_VELOCIDAD   = 1000  -- máximo que se puede escribir
local ACTIVAR_AL_INICIAR = true  -- true: la velocidad elegida se aplica al ejecutar
local ALTURA_TP          = 3     -- cuántos studs por encima del punto apareces

local VEL_VEHICULO        = 200  -- velocidad del auto/moto (studs por segundo)
local LIMITE_VEHICULO     = 1000 -- tope de los botones +
local PASO_VEHICULO       = 50   -- cuánto cambian los botones + / -
local ACELERACION_VEH     = 2    -- qué tan rápido llega a la velocidad (más = más brusco)
local VEHICULO_AL_INICIAR = true -- true: el módulo de vehículo arranca en ON

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

local activo         = false
local autoRegreso    = false
local vehiculoActivo = false
local invencible     = false
local origen         = nil   -- Vector3
local punto          = nil   -- Vector3
local conexiones     = {}
local vistos         = setmetatable({}, { __mode = "k" })

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
frame.Size = UDim2.new(0, 220, 0, 420)
frame.Position = UDim2.new(0, 20, 0.15, 0)
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
local btnToggle = crearBoton("OFF", 10, 80, 70, 30, ROJO)

local txtVel = Instance.new("TextBox")
txtVel.Size = UDim2.new(0, 76, 0, 30)
txtVel.Position = UDim2.new(0, 86, 0, 80)
txtVel.BackgroundColor3 = GRIS
txtVel.TextColor3 = Color3.new(1, 1, 1)
txtVel.PlaceholderText = "Ej: 200"
txtVel.Font = Enum.Font.GothamBold
txtVel.TextSize = 14
txtVel.ClearTextOnFocus = false
txtVel.Text = tostring(VELOCIDAD_ELEGIDA)
txtVel.Parent = frame
Instance.new("UICorner", txtVel).CornerRadius = UDim.new(0, 8)

local btnAplicar = crearBoton("OK", 168, 80, 42, 30, VERDE)

-- Teletransporte
crearLabel("TELETRANSPORTE", 120, AZUL, 12)
local btnGuardarOrigen = crearBoton("Guardar origen", 10, 142, 97, 30, GRIS)
local btnVolverOrigen  = crearBoton("Volver origen", 113, 142, 97, 30, GRIS)
local btnGuardarPunto  = crearBoton("Guardar punto", 10, 178, 97, 30, GRIS)
local btnIrPunto       = crearBoton("Ir a punto",    113, 178, 97, 30, GRIS)
local btnIrMedio       = crearBoton("Ir al medio",   10, 214, 97, 30, GRIS)
local btnAuto          = crearBoton("Auto: OFF",     113, 214, 97, 30, ROJO)

-- Vehículo
crearLabel("VEHÍCULO (auto / moto)", 254, AZUL, 12)
local lblVeh      = crearLabel("Vel. vehículo: " .. VEL_VEHICULO, 272)
local btnVeh      = crearBoton("OFF", 10, 296, 104, 30, ROJO)
local btnVehMenos = crearBoton("-",   120, 296, 42, 30, GRIS)
local btnVehMas   = crearBoton("+",   168, 296, 42, 30, GRIS)

-- Invencible
crearLabel("EXTRA", 336, AZUL, 12)
local btnInvencible = crearBoton("Invencible: OFF", 10, 354, 200, 30, ROJO)

-- Estado
local lblEstado = crearLabel("Listo", 394, Color3.fromRGB(200, 200, 200), 12)
lblEstado.Size = UDim2.new(1, -20, 0, 20)

local function setEstado(texto)
    lblEstado.Text = texto
end

local function actualizarUI()
    lblVel.Text = "Velocidad: " .. (activo and VELOCIDAD_ELEGIDA or VELOCIDAD_NORMAL)
    btnToggle.Text = activo and "ON" or "OFF"
    btnToggle.BackgroundColor3 = activo and VERDE or ROJO
    btnAuto.Text = autoRegreso and "Auto: ON" or "Auto: OFF"
    btnAuto.BackgroundColor3 = autoRegreso and VERDE or ROJO
    lblVeh.Text = "Vel. vehículo: " .. VEL_VEHICULO
    btnVeh.Text = vehiculoActivo and "ON" or "OFF"
    btnVeh.BackgroundColor3 = vehiculoActivo and VERDE or ROJO
    btnInvencible.Text = invencible and "Invencible: ON" or "Invencible: OFF"
    btnInvencible.BackgroundColor3 = invencible and VERDE or ROJO
end

----------------------------------------------------------------
-- MÓDULO: VELOCIDAD (se escribe, no sube sola)
----------------------------------------------------------------
local function aplicarVelocidad()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = activo and VELOCIDAD_ELEGIDA or VELOCIDAD_NORMAL
    end
    actualizarUI()
end

local function setActivo(valor)
    activo = valor
    aplicarVelocidad()
end

local function leerTexto()
    local n = tonumber(txtVel.Text)
    if not n then
        setEstado("Escribe solo números, ej: 200")
        txtVel.Text = tostring(VELOCIDAD_ELEGIDA)
        return
    end
    n = math.clamp(math.floor(n), 1, LIMITE_VELOCIDAD)
    VELOCIDAD_ELEGIDA = n
    txtVel.Text = tostring(n)
    if not activo then activo = true end
    aplicarVelocidad()
    setEstado("Velocidad puesta en " .. n)
end

btnToggle.MouseButton1Click:Connect(function()
    setActivo(not activo)
end)

btnAplicar.MouseButton1Click:Connect(leerTexto)
txtVel.FocusLost:Connect(function(enter)
    if enter then leerTexto() end
end)

-- Mantiene la velocidad elegida si el juego la cambia
table.insert(conexiones, RunService.Heartbeat:Connect(function()
    if not activo then return end
    local hum = getHumanoid()
    if hum and hum.WalkSpeed ~= VELOCIDAD_ELEGIDA then
        hum.WalkSpeed = VELOCIDAD_ELEGIDA
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

----------------------------------------------------------------
-- MÓDULO: VEHÍCULO (auto / moto)
----------------------------------------------------------------
local asientosOriginales = {}  -- asiento -> MaxSpeed original

local function restaurarAsientos()
    for asiento, maxOriginal in pairs(asientosOriginales) do
        if asiento and asiento.Parent then
            pcall(function() asiento.MaxSpeed = maxOriginal end)
        end
    end
    asientosOriginales = {}
end

btnVeh.MouseButton1Click:Connect(function()
    vehiculoActivo = not vehiculoActivo
    if not vehiculoActivo then restaurarAsientos() end
    setEstado(vehiculoActivo and "Vehículo rápido activado" or "Vehículo normal")
    actualizarUI()
end)

btnVehMas.MouseButton1Click:Connect(function()
    VEL_VEHICULO = math.min(LIMITE_VEHICULO, VEL_VEHICULO + PASO_VEHICULO)
    actualizarUI()
end)

btnVehMenos.MouseButton1Click:Connect(function()
    VEL_VEHICULO = math.max(PASO_VEHICULO, VEL_VEHICULO - PASO_VEHICULO)
    actualizarUI()
end)

table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    if not vehiculoActivo then return end
    local hum = getHumanoid()
    local asiento = hum and hum.SeatPart
    if not asiento then return end

    -- Hacia dónde acelera el jugador
    local direccion
    if asiento:IsA("VehicleSeat") then
        if asientosOriginales[asiento] == nil then
            asientosOriginales[asiento] = asiento.MaxSpeed
        end
        asiento.MaxSpeed = VEL_VEHICULO
        local acelerador = asiento.ThrottleFloat
        if math.abs(acelerador) < 0.1 then return end
        direccion = asiento.CFrame.LookVector * math.sign(acelerador)
    else
        -- Asiento normal: usa la dirección en la que se mueve el jugador
        local mov = hum.MoveDirection
        if mov.Magnitude < 0.1 then return end
        direccion = mov.Unit
    end

    -- Empuja el vehículo en esa dirección sin tocar la caída
    local raiz = asiento.AssemblyRootPart or asiento
    local vel = raiz.AssemblyLinearVelocity
    local plano = Vector3.new(direccion.X, 0, direccion.Z)
    if plano.Magnitude < 0.01 then return end
    plano = plano.Unit
    local actual = vel:Dot(plano)
    if actual < VEL_VEHICULO then
        local nuevo = actual + (VEL_VEHICULO - actual) * math.min(1, dt * ACELERACION_VEH)
        raiz.AssemblyLinearVelocity = vel + plano * (nuevo - actual)
    end
end))

----------------------------------------------------------------
-- MÓDULO: INVENCIBLE
----------------------------------------------------------------
local function aplicarInvencible()
    local hum = getHumanoid()
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not invencible)
    end)
    if invencible and hum.Health > 0 then
        hum.Health = hum.MaxHealth
    end
end

btnInvencible.MouseButton1Click:Connect(function()
    invencible = not invencible
    aplicarInvencible()
    setEstado(invencible and "Invencible activado" or "Invencible apagado")
    actualizarUI()
end)

table.insert(conexiones, RunService.Heartbeat:Connect(function()
    if not invencible then return end
    local hum = getHumanoid()
    if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
end))

----------------------------------------------------------------
-- PERSONAJE: al iniciar y al reaparecer
----------------------------------------------------------------
local function prepararPersonaje(char)
    char:WaitForChild("Humanoid", 5)
    vigilar(char)
    vigilar(player:WaitForChild("Backpack", 5))
    aplicarVelocidad()
    aplicarInvencible()
end

if player.Character then
    task.spawn(prepararPersonaje, player.Character)
end

table.insert(conexiones, player.CharacterAdded:Connect(prepararPersonaje))

----------------------------------------------------------------
-- CERRAR
----------------------------------------------------------------
local function cerrar()
    activo = false
    autoRegreso = false
    vehiculoActivo = false
    invencible = false
    for _, c in ipairs(conexiones) do c:Disconnect() end
    conexiones = {}
    restaurarAsientos()
    aplicarInvencible()
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = VELOCIDAD_NORMAL end
    if gui then gui:Destroy() end
    _G.SpeedHubCerrar = nil
end

_G.SpeedHubCerrar = cerrar
btnCerrar.MouseButton1Click:Connect(cerrar)

vehiculoActivo = VEHICULO_AL_INICIAR
activo = ACTIVAR_AL_INICIAR
aplicarVelocidad()
if activo then
    setEstado("Velocidad puesta en " .. VELOCIDAD_ELEGIDA)
end
