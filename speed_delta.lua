--[[
    Speed Hub - script para el ejecutor Delta (Roblox)
    --------------------------------------------------
    El panel se puede mover, minimizar (–) y cerrar (X).
    Si no cabe en la pantalla, desliza hacia abajo dentro del panel.

    VELOCIDAD
      - Escribe la velocidad (100, 200, 300...) y pulsa OK o Enter.
      - ON/OFF: activa o quita la velocidad (OFF = normal, 16).

    TELETRANSPORTE
      - Guardar origen / Volver origen : tu base.
      - Guardar punto / Ir a punto     : cualquier lugar que guardes.
      - Ir al medio                    : centro del mapa.
      - Auto: al agarrar un objeto (Tool) te devuelve al origen.

    VEHÍCULO (motos y carros)
      - Elige un modelo con < y > (Ninja 400, R6, NASCAR, F1...)
        o escribe tus propios km/h y pulsa OK.
      - Al subirte, detecta en qué vehículo vas y lo muestra.
      - Recuerda la velocidad que elegiste para cada vehículo:
        la próxima vez que te subas al mismo, se pone sola.
      - Funciona con los pedales del juego: cuando la moto va
        hacia adelante y no estás frenando, la empuja hasta la
        velocidad elegida. Para bajar la velocidad, frena.
      - "Ahora" muestra tu velocidad. Si no coincide con el
        velocímetro del juego, ajusta KMH_POR_STUD.

    EXTRA
      - Invencible: rellena tu vida y evita que el personaje muera.
      - Anti-mobs : quita el contacto de los mobs contigo.
      Ambos solo funcionan si el juego maneja eso en tu pantalla.
]]

----------------------------------------------------------------
-- CONFIGURACIÓN
----------------------------------------------------------------
local VELOCIDAD_NORMAL   = 16    -- velocidad por defecto de Roblox
local VELOCIDAD_ELEGIDA  = 100   -- velocidad que aparece escrita al iniciar
local LIMITE_VELOCIDAD   = 1000  -- máximo que se puede escribir
local ACTIVAR_AL_INICIAR = true  -- true: la velocidad elegida se aplica al ejecutar
local ALTURA_TP          = 3     -- cuántos studs por encima del punto apareces
local DISTANCIA_ALERTA   = 30    -- a cuántos studs avisa que hay un mob cerca

-- Vehículos
local KMH_POR_STUD        = 0.91 -- 1 stud/s = 0.91 km/h (ajústalo si no coincide con el juego)
local LIMITE_VEHICULO_KMH = 1000 -- máximo que se puede escribir
local ACELERACION_VEH     = 1.5  -- qué tan rápido llega a la velocidad (más = más brusco)
local FRENO_UMBRAL        = 30   -- si la moto pierde más de esto por segundo, cuenta como freno
local VEHICULO_AL_INICIAR = true -- true: el módulo de vehículo arranca en ON
local PRESET_INICIAL      = 3    -- cuál modelo está elegido al iniciar (número de la lista)

-- Modelos para elegir: { nombre, km/h }
local PRESETS = {
    { "Moto - Scooter 125",        90  },
    { "Moto - Honda CB500",        180 },
    { "Moto - Kawasaki Ninja 400", 190 },
    { "Moto - Yamaha R6",          260 },
    { "Moto - Kawasaki ZX-10R",    300 },
    { "Moto - Kawasaki H2R",       400 },
    { "Carro - Sedán",             180 },
    { "Carro - Deportivo",         280 },
    { "Carro - NASCAR",            320 },
    { "Carro - Fórmula 1",         360 },
}

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
local antiMobs       = false
local origen         = nil   -- Vector3
local punto          = nil   -- Vector3
local conexiones     = {}
local vistos         = setmetatable({}, { __mode = "k" })

local indicePreset   = math.clamp(PRESET_INICIAL, 1, #PRESETS)
local nombreMeta     = PRESETS[indicePreset][1]
local metaKmh        = PRESETS[indicePreset][2]
local vehiculoActual = nil   -- modelo del vehículo en el que vas
local memoria        = {}    -- nombre del vehículo -> { nombre, kmh }

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

local ALTO_PANEL = 380

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, ALTO_PANEL)
frame.Position = UDim2.new(0, 20, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local GRIS  = Color3.fromRGB(60, 60, 70)
local ROJO  = Color3.fromRGB(170, 40, 40)
local VERDE = Color3.fromRGB(40, 170, 70)
local AZUL  = Color3.fromRGB(0, 200, 255)
local CLARO = Color3.fromRGB(200, 200, 200)

-- Contenido con scroll (debajo del título)
local contenido = Instance.new("ScrollingFrame")
contenido.Size = UDim2.new(1, 0, 1, -40)
contenido.Position = UDim2.new(0, 0, 0, 40)
contenido.BackgroundTransparency = 1
contenido.BorderSizePixel = 0
contenido.ScrollBarThickness = 4
contenido.ScrollingDirection = Enum.ScrollingDirection.Y
contenido.CanvasSize = UDim2.new(0, 0, 0, 460)
contenido.Parent = frame

local function crearLabel(texto, y, color, tam, padre)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 20)
    l.Position = UDim2.new(0, 10, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = tam or 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Text = texto
    l.Parent = padre or contenido
    return l
end

local function crearBoton(texto, x, y, w, h, color, padre)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = texto
    b.Parent = padre or contenido
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local function crearCaja(texto, x, y, w, h, placeholder)
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(0, w, 0, h)
    t.Position = UDim2.new(0, x, 0, y)
    t.BackgroundColor3 = GRIS
    t.TextColor3 = Color3.new(1, 1, 1)
    t.PlaceholderText = placeholder
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.ClearTextOnFocus = false
    t.Text = texto
    t.Parent = contenido
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 8)
    return t
end

-- Título, minimizar y cerrar (fijos arriba)
local titulo = crearLabel("Speed Hub", 10, AZUL, 16, frame)
titulo.Size = UDim2.new(1, -90, 0, 20)
local btnMin    = crearBoton("–", 154, 7, 26, 26, GRIS, frame)
local btnCerrar = crearBoton("X", 186, 7, 26, 26, ROJO, frame)

-- Velocidad
crearLabel("VELOCIDAD", 0, AZUL, 12)
local lblVel     = crearLabel("Velocidad: 16", 18)
local btnToggle  = crearBoton("OFF", 10, 42, 70, 30, ROJO)
local txtVel     = crearCaja(tostring(VELOCIDAD_ELEGIDA), 86, 42, 76, 30, "Ej: 200")
local btnAplicar = crearBoton("OK", 168, 42, 42, 30, VERDE)

-- Teletransporte
crearLabel("TELETRANSPORTE", 82, AZUL, 12)
local btnGuardarOrigen = crearBoton("Guardar origen", 10, 104, 97, 30, GRIS)
local btnVolverOrigen  = crearBoton("Volver origen", 113, 104, 97, 30, GRIS)
local btnGuardarPunto  = crearBoton("Guardar punto", 10, 140, 97, 30, GRIS)
local btnIrPunto       = crearBoton("Ir a punto",    113, 140, 97, 30, GRIS)
local btnIrMedio       = crearBoton("Ir al medio",   10, 176, 97, 30, GRIS)
local btnAuto          = crearBoton("Auto: OFF",     113, 176, 97, 30, ROJO)

-- Vehículo
crearLabel("VEHÍCULO (motos y carros)", 216, AZUL, 12)
local lblManejando = crearLabel("Manejando: ninguno", 234, CLARO, 12)
local lblVehVel    = crearLabel("Ahora: 0 km/h | Meta: " .. metaKmh, 252, Color3.new(1, 1, 1), 13)
local btnPrev      = crearBoton("<", 10, 276, 30, 34, GRIS)

local lblPreset = Instance.new("TextLabel")
lblPreset.Size = UDim2.new(0, 132, 0, 34)
lblPreset.Position = UDim2.new(0, 44, 0, 276)
lblPreset.BackgroundColor3 = GRIS
lblPreset.TextColor3 = Color3.new(1, 1, 1)
lblPreset.Font = Enum.Font.GothamBold
lblPreset.TextSize = 11
lblPreset.TextWrapped = true
lblPreset.Parent = contenido
Instance.new("UICorner", lblPreset).CornerRadius = UDim.new(0, 8)

local btnNext     = crearBoton(">", 180, 276, 30, 34, GRIS)
local btnVeh      = crearBoton("OFF", 10, 316, 70, 30, ROJO)
local txtVeh      = crearCaja("", 86, 316, 76, 30, "km/h")
local btnVehOK    = crearBoton("OK", 168, 316, 42, 30, VERDE)

-- Extra
crearLabel("EXTRA", 356, AZUL, 12)
local btnInvencible = crearBoton("Invencible: OFF", 10, 374, 97, 30, ROJO)
local btnAntiMobs   = crearBoton("Anti-mobs: OFF",  113, 374, 97, 30, ROJO)
btnInvencible.TextSize = 12
btnAntiMobs.TextSize = 12
local lblMobs = crearLabel("Mobs: -", 410, CLARO, 12)

-- Estado
local lblEstado = crearLabel("Listo", 432, CLARO, 12)

local function setEstado(texto)
    lblEstado.Text = texto
end

local function actualizarUI()
    lblVel.Text = "Velocidad: " .. (activo and VELOCIDAD_ELEGIDA or VELOCIDAD_NORMAL)
    btnToggle.Text = activo and "ON" or "OFF"
    btnToggle.BackgroundColor3 = activo and VERDE or ROJO
    btnAuto.Text = autoRegreso and "Auto: ON" or "Auto: OFF"
    btnAuto.BackgroundColor3 = autoRegreso and VERDE or ROJO
    lblPreset.Text = nombreMeta .. "\n" .. metaKmh .. " km/h"
    btnVeh.Text = vehiculoActivo and "ON" or "OFF"
    btnVeh.BackgroundColor3 = vehiculoActivo and VERDE or ROJO
    btnInvencible.Text = invencible and "Invencible: ON" or "Invencible: OFF"
    btnInvencible.BackgroundColor3 = invencible and VERDE or ROJO
    btnAntiMobs.Text = antiMobs and "Anti-mobs: ON" or "Anti-mobs: OFF"
    btnAntiMobs.BackgroundColor3 = antiMobs and VERDE or ROJO
end

-- Minimizar
local minimizado = false
btnMin.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    contenido.Visible = not minimizado
    frame.Size = UDim2.new(0, 220, 0, minimizado and 40 or ALTO_PANEL)
    btnMin.Text = minimizado and "+" or "–"
end)

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
    activo = true
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
-- MÓDULO: VEHÍCULO (motos y carros)
----------------------------------------------------------------
local asientosOriginales = {}  -- asiento -> MaxSpeed original
local rapidezAnterior = nil
local tiempoVehUI = 0

local function restaurarAsientos()
    for asiento, maxOriginal in pairs(asientosOriginales) do
        if asiento and asiento.Parent then
            pcall(function() asiento.MaxSpeed = maxOriginal end)
        end
    end
    asientosOriginales = {}
end

-- El vehículo es el modelo más grande que contiene el asiento
local function obtenerVehiculo(asiento)
    local modelo = asiento:FindFirstAncestorOfClass("Model")
    while modelo do
        local padre = modelo:FindFirstAncestorOfClass("Model")
        if not padre then break end
        modelo = padre
    end
    return modelo or asiento
end

-- Elegir velocidad (y recordarla para el vehículo en el que vas)
local function elegirMeta(nombre, kmh)
    nombreMeta = nombre
    metaKmh = kmh
    if vehiculoActual then
        memoria[vehiculoActual.Name] = { nombre, kmh }
        setEstado(nombre .. " guardado para " .. vehiculoActual.Name)
    else
        setEstado("Elegido: " .. nombre .. " (" .. kmh .. " km/h)")
    end
    actualizarUI()
end

btnPrev.MouseButton1Click:Connect(function()
    indicePreset = indicePreset - 1
    if indicePreset < 1 then indicePreset = #PRESETS end
    elegirMeta(PRESETS[indicePreset][1], PRESETS[indicePreset][2])
end)

btnNext.MouseButton1Click:Connect(function()
    indicePreset = indicePreset + 1
    if indicePreset > #PRESETS then indicePreset = 1 end
    elegirMeta(PRESETS[indicePreset][1], PRESETS[indicePreset][2])
end)

local function leerVehiculo()
    local n = tonumber(txtVeh.Text)
    if not n then
        setEstado("Escribe los km/h, ej: 250")
        return
    end
    n = math.clamp(math.floor(n), 10, LIMITE_VEHICULO_KMH)
    txtVeh.Text = tostring(n)
    elegirMeta("Personalizada", n)
end

btnVehOK.MouseButton1Click:Connect(leerVehiculo)
txtVeh.FocusLost:Connect(function(enter)
    if enter then leerVehiculo() end
end)

btnVeh.MouseButton1Click:Connect(function()
    vehiculoActivo = not vehiculoActivo
    if not vehiculoActivo then restaurarAsientos() end
    setEstado(vehiculoActivo and "Vehículo rápido activado" or "Vehículo normal")
    actualizarUI()
end)

local function alSubir(vehiculo)
    vehiculoActual = vehiculo
    rapidezAnterior = nil
    lblManejando.Text = "Manejando: " .. vehiculo.Name
    local guardado = memoria[vehiculo.Name]
    if guardado then
        nombreMeta, metaKmh = guardado[1], guardado[2]
        setEstado("Usando " .. nombreMeta .. " en " .. vehiculo.Name)
    else
        setEstado("Subiste a " .. vehiculo.Name)
    end
    actualizarUI()
end

local function alBajar()
    vehiculoActual = nil
    rapidezAnterior = nil
    lblManejando.Text = "Manejando: ninguno"
    lblVehVel.Text = "Ahora: 0 km/h | Meta: " .. metaKmh
end

table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    local hum = getHumanoid()
    local asiento = hum and hum.SeatPart

    -- Detecta al subir y al bajar
    if not asiento then
        if vehiculoActual then alBajar() end
        return
    end
    local vehiculo = obtenerVehiculo(asiento)
    if vehiculo ~= vehiculoActual then alSubir(vehiculo) end

    local raiz = asiento.AssemblyRootPart or asiento
    local vel = raiz.AssemblyLinearVelocity
    local plano = Vector3.new(vel.X, 0, vel.Z)
    local rapidez = plano.Magnitude
    local meta = metaKmh / KMH_POR_STUD

    -- Muestra la velocidad
    tiempoVehUI = tiempoVehUI + dt
    if tiempoVehUI >= 0.2 then
        tiempoVehUI = 0
        lblVehVel.Text = "Ahora: " .. math.floor(rapidez * KMH_POR_STUD) .. " km/h | Meta: " .. metaKmh
    end

    if not vehiculoActivo then
        rapidezAnterior = rapidez
        return
    end

    if asiento:IsA("VehicleSeat") then
        if asientosOriginales[asiento] == nil then
            asientosOriginales[asiento] = asiento.MaxSpeed
        end
        asiento.MaxSpeed = math.max(asientosOriginales[asiento], meta)
    end

    -- ¿Está acelerando? Sirve con el acelerador de Roblox y con los pedales del juego
    local acelerando
    local acelerador = asiento:IsA("VehicleSeat") and asiento.ThrottleFloat or 0
    if acelerador > 0.1 then
        acelerando = true
    elseif acelerador < -0.1 then
        acelerando = false  -- frenando o en reversa
    else
        local cambio = rapidezAnterior and (rapidez - rapidezAnterior) / math.max(dt, 1e-3) or 0
        acelerando = rapidez > 3 and cambio > -FRENO_UMBRAL
    end

    -- No empuja en reversa
    if rapidez > 0.5 and plano.Unit:Dot(asiento.CFrame.LookVector) < 0 then
        acelerando = false
    end

    if acelerando and rapidez < meta and rapidez > 0.5 then
        local direccion = plano.Unit
        local nueva = rapidez + (meta - rapidez) * math.min(1, dt * ACELERACION_VEH)
        raiz.AssemblyLinearVelocity = vel + direccion * (nueva - rapidez)
        rapidezAnterior = nueva
    else
        rapidezAnterior = rapidez
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
-- MÓDULO: ANTI-MOBS
----------------------------------------------------------------
local mobs = {}              -- modelo -> true
local partesOriginales = {}  -- parte -> { CanTouch, CanCollide }

local function esMob(modelo)
    if not modelo or not modelo:IsA("Model") then return false end
    if modelo == player.Character then return false end
    if Players:GetPlayerFromCharacter(modelo) then return false end
    return modelo:FindFirstChildOfClass("Humanoid") ~= nil
end

local function neutralizarParte(parte)
    if not parte:IsA("BasePart") or partesOriginales[parte] then return end
    partesOriginales[parte] = { parte.CanTouch, parte.CanCollide }
    parte.CanTouch = false
    parte.CanCollide = false
end

local function neutralizarMob(modelo)
    mobs[modelo] = true
    for _, d in ipairs(modelo:GetDescendants()) do
        neutralizarParte(d)
    end
end

local function buscarMobs()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") and esMob(d.Parent) then
            neutralizarMob(d.Parent)
        end
    end
end

local function restaurarMobs()
    for parte, orig in pairs(partesOriginales) do
        if parte and parte.Parent then
            pcall(function()
                parte.CanTouch = orig[1]
                parte.CanCollide = orig[2]
            end)
        end
    end
    partesOriginales = {}
    mobs = {}
    lblMobs.Text = "Mobs: -"
end

btnAntiMobs.MouseButton1Click:Connect(function()
    antiMobs = not antiMobs
    if antiMobs then
        buscarMobs()
        setEstado("Anti-mobs activado")
    else
        restaurarMobs()
        setEstado("Anti-mobs apagado")
    end
    actualizarUI()
end)

-- Mobs que aparecen después
table.insert(conexiones, workspace.DescendantAdded:Connect(function(obj)
    if not antiMobs then return end
    if obj:IsA("Humanoid") then
        task.defer(function()
            if esMob(obj.Parent) then neutralizarMob(obj.Parent) end
        end)
    elseif obj:IsA("BasePart") then
        local modelo = obj:FindFirstAncestorOfClass("Model")
        while modelo and not mobs[modelo] do
            modelo = modelo:FindFirstAncestorOfClass("Model")
        end
        if modelo then neutralizarParte(obj) end
    end
end))

-- Cada medio segundo: limpia mobs que ya no existen y avisa del más cercano
local tiempoMobs = 0
table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    if not antiMobs then return end
    tiempoMobs = tiempoMobs + dt
    if tiempoMobs < 0.5 then return end
    tiempoMobs = 0

    local hrp = getHRP()
    local cantidad, cercano = 0, math.huge
    for modelo in pairs(mobs) do
        if not modelo.Parent then
            mobs[modelo] = nil
        else
            cantidad = cantidad + 1
            local pivote = modelo:GetPivot().Position
            if hrp then
                cercano = math.min(cercano, (pivote - hrp.Position).Magnitude)
            end
        end
    end
    for parte in pairs(partesOriginales) do
        if not parte.Parent then partesOriginales[parte] = nil end
    end

    if cantidad == 0 then
        lblMobs.Text = "Mobs: 0"
    elseif cercano <= DISTANCIA_ALERTA then
        lblMobs.Text = "¡Mob cerca! " .. math.floor(cercano) .. " studs (" .. cantidad .. ")"
    else
        lblMobs.Text = "Mobs: " .. cantidad .. " | más cerca: " .. math.floor(cercano)
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
    antiMobs = false
    for _, c in ipairs(conexiones) do c:Disconnect() end
    conexiones = {}
    restaurarAsientos()
    restaurarMobs()
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
