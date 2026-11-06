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
-- INTERFAZ (estilo terminal hacker)
----------------------------------------------------------------
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local viejo = guiParent:FindFirstChild("SpeedHubGui")
    if viejo then viejo:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedHubGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

-- Paleta
local FONDO     = Color3.fromRGB(6, 9, 10)
local TARJETA   = Color3.fromRGB(12, 17, 18)
local BOTON     = Color3.fromRGB(16, 24, 25)
local NEON      = Color3.fromRGB(0, 255, 140)
local NEON_DIM  = Color3.fromRGB(0, 110, 65)
local CIAN      = Color3.fromRGB(0, 220, 255)
local TEXTO     = Color3.fromRGB(190, 255, 215)
local TENUE     = Color3.fromRGB(90, 140, 110)
local ON_FONDO  = Color3.fromRGB(0, 60, 35)
local OFF_FONDO = Color3.fromRGB(45, 12, 18)
local OFF_TEXTO = Color3.fromRGB(255, 85, 100)
local FUENTE    = Enum.Font.Code

local ANCHO_PANEL  = 250
local ALTO_PANEL   = 420
local ALTO_HEADER  = 46
local ALTO_ESTADO  = 26

local function esquina(obj, r)
    Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r or 6)
end

local function borde(obj, color, grosor, transp)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = grosor or 1
    s.Transparency = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

-- Marco principal
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, ANCHO_PANEL, 0, ALTO_PANEL)
frame.Position = UDim2.new(0, 20, 0.1, 0)
frame.BackgroundColor3 = FONDO
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = true
frame.Parent = gui
esquina(frame, 10)
borde(frame, NEON, 1.5)

local degradado = Instance.new("UIGradient")
degradado.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 190, 170))
degradado.Rotation = 90
degradado.Parent = frame

-- Encabezado
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, ALTO_HEADER)
header.BackgroundTransparency = 1
header.Parent = frame

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -90, 0, 22)
titulo.Position = UDim2.new(0, 12, 0, 5)
titulo.BackgroundTransparency = 1
titulo.Font = FUENTE
titulo.TextSize = 18
titulo.TextColor3 = NEON
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Text = "> SPEED_HUB_"
titulo.Parent = header

local subtitulo = Instance.new("TextLabel")
subtitulo.Size = UDim2.new(1, -90, 0, 14)
subtitulo.Position = UDim2.new(0, 12, 0, 26)
subtitulo.BackgroundTransparency = 1
subtitulo.Font = FUENTE
subtitulo.TextSize = 11
subtitulo.TextColor3 = TENUE
subtitulo.TextXAlignment = Enum.TextXAlignment.Left
subtitulo.Text = "root@delta:~$ online"
subtitulo.Parent = header

local function botonHeader(texto, x, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Position = UDim2.new(1, x, 0, 9)
    b.BackgroundColor3 = BOTON
    b.Font = FUENTE
    b.TextSize = 16
    b.TextColor3 = color
    b.Text = texto
    b.AutoButtonColor = true
    b.Parent = header
    esquina(b, 6)
    borde(b, color, 1)
    return b
end

local btnMin    = botonHeader("–", -72, NEON)
local btnCerrar = botonHeader("X", -38, OFF_TEXTO)

local linea = Instance.new("Frame")
linea.Size = UDim2.new(1, -24, 0, 1)
linea.Position = UDim2.new(0, 12, 0, ALTO_HEADER - 1)
linea.BackgroundColor3 = NEON_DIM
linea.BorderSizePixel = 0
linea.Parent = frame

-- Cursor que parpadea en el título
task.spawn(function()
    local visible = true
    while gui.Parent do
        visible = not visible
        titulo.Text = visible and "> SPEED_HUB_" or "> SPEED_HUB "
        task.wait(0.5)
    end
end)

-- Contenido con scroll
local contenido = Instance.new("ScrollingFrame")
contenido.Size = UDim2.new(1, 0, 1, -(ALTO_HEADER + ALTO_ESTADO))
contenido.Position = UDim2.new(0, 0, 0, ALTO_HEADER)
contenido.BackgroundTransparency = 1
contenido.BorderSizePixel = 0
contenido.ScrollBarThickness = 3
contenido.ScrollBarImageColor3 = NEON
contenido.ScrollingDirection = Enum.ScrollingDirection.Y
contenido.CanvasSize = UDim2.new(0, 0, 0, 0)
contenido.AutomaticCanvasSize = Enum.AutomaticSize.Y
contenido.Parent = frame

local lista = Instance.new("UIListLayout")
lista.Padding = UDim.new(0, 8)
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Parent = contenido

local relleno = Instance.new("UIPadding")
relleno.PaddingTop = UDim.new(0, 8)
relleno.PaddingBottom = UDim.new(0, 8)
relleno.PaddingLeft = UDim.new(0, 8)
relleno.PaddingRight = UDim.new(0, 8)
relleno.Parent = contenido

-- Barra de estado (abajo)
local barraEstado = Instance.new("Frame")
barraEstado.Size = UDim2.new(1, 0, 0, ALTO_ESTADO)
barraEstado.Position = UDim2.new(0, 0, 1, -ALTO_ESTADO)
barraEstado.BackgroundColor3 = Color3.fromRGB(3, 5, 6)
barraEstado.BorderSizePixel = 0
barraEstado.Parent = frame

local lblEstado = Instance.new("TextLabel")
lblEstado.Size = UDim2.new(1, -20, 1, 0)
lblEstado.Position = UDim2.new(0, 10, 0, 0)
lblEstado.BackgroundTransparency = 1
lblEstado.Font = FUENTE
lblEstado.TextSize = 12
lblEstado.TextColor3 = NEON
lblEstado.TextXAlignment = Enum.TextXAlignment.Left
lblEstado.TextTruncate = Enum.TextTruncate.AtEnd
lblEstado.Text = "> listo"
lblEstado.Parent = barraEstado

-- Piezas
local ordenTarjeta = 0
local function crearTarjeta(numero, nombre, alto)
    ordenTarjeta = ordenTarjeta + 1
    local t = Instance.new("Frame")
    t.Size = UDim2.new(1, 0, 0, alto)
    t.BackgroundColor3 = TARJETA
    t.BorderSizePixel = 0
    t.LayoutOrder = ordenTarjeta
    t.Parent = contenido
    esquina(t, 8)
    borde(t, NEON_DIM, 1)

    local acento = Instance.new("Frame")
    acento.Size = UDim2.new(0, 3, 1, -16)
    acento.Position = UDim2.new(0, 0, 0, 8)
    acento.BackgroundColor3 = NEON
    acento.BorderSizePixel = 0
    acento.Parent = t

    local cab = Instance.new("TextLabel")
    cab.Size = UDim2.new(1, -24, 0, 18)
    cab.Position = UDim2.new(0, 12, 0, 6)
    cab.BackgroundTransparency = 1
    cab.Font = FUENTE
    cab.TextSize = 13
    cab.TextColor3 = CIAN
    cab.TextXAlignment = Enum.TextXAlignment.Left
    cab.Text = "[" .. numero .. "] " .. nombre
    cab.Parent = t
    return t
end

local function crearLabel(texto, y, padre, color, tam)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -24, 0, 18)
    l.Position = UDim2.new(0, 12, 0, y)
    l.BackgroundTransparency = 1
    l.Font = FUENTE
    l.TextSize = tam or 13
    l.TextColor3 = color or TEXTO
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Text = texto
    l.Parent = padre
    return l
end

local function crearBoton(texto, x, y, w, h, padre)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = BOTON
    b.Font = FUENTE
    b.TextSize = 12
    b.TextColor3 = TEXTO
    b.Text = texto
    b.AutoButtonColor = true
    b.Parent = padre
    esquina(b, 6)
    borde(b, NEON_DIM, 1)
    return b
end

local function crearCaja(texto, x, y, w, h, placeholder, padre)
    local c = Instance.new("TextBox")
    c.Size = UDim2.new(0, w, 0, h)
    c.Position = UDim2.new(0, x, 0, y)
    c.BackgroundColor3 = Color3.fromRGB(4, 7, 8)
    c.Font = FUENTE
    c.TextSize = 14
    c.TextColor3 = NEON
    c.PlaceholderText = placeholder
    c.PlaceholderColor3 = TENUE
    c.ClearTextOnFocus = false
    c.Text = texto
    c.Parent = padre
    esquina(c, 6)
    borde(c, NEON, 1, 0.3)
    return c
end

-- Botón ON/OFF con colores de estado
local function estiloToggle(b, encendido, textoOn, textoOff)
    b.Text = encendido and textoOn or textoOff
    b.BackgroundColor3 = encendido and ON_FONDO or OFF_FONDO
    b.TextColor3 = encendido and NEON or OFF_TEXTO
    local s = b:FindFirstChildOfClass("UIStroke")
    if s then s.Color = encendido and NEON or OFF_TEXTO end
end

-- [01] Velocidad
local tVel = crearTarjeta("01", "VELOCIDAD", 96)
local lblVel     = crearLabel("WALKSPEED: 16", 28, tVel)
local btnToggle  = crearBoton("OFF", 12, 54, 64, 32, tVel)
local txtVel     = crearCaja(tostring(VELOCIDAD_ELEGIDA), 82, 54, 86, 32, "ej: 200", tVel)
local btnAplicar = crearBoton("OK", 174, 54, 44, 32, tVel)

-- [02] Teletransporte
local tTp = crearTarjeta("02", "TELETRANSPORTE", 146)
local btnGuardarOrigen = crearBoton("Guardar origen", 12, 30, 100, 32, tTp)
local btnVolverOrigen  = crearBoton("Volver origen", 118, 30, 100, 32, tTp)
local btnGuardarPunto  = crearBoton("Guardar punto", 12, 68, 100, 32, tTp)
local btnIrPunto       = crearBoton("Ir a punto",    118, 68, 100, 32, tTp)
local btnIrMedio       = crearBoton("Ir al medio",   12, 106, 100, 32, tTp)
local btnAuto          = crearBoton("AUTO: OFF",     118, 106, 100, 32, tTp)

-- [03] Vehículo
local tVeh = crearTarjeta("03", "VEHÍCULO // motos y carros", 158)
local lblManejando = crearLabel("Manejando: ninguno", 28, tVeh, TENUE, 12)
local lblVehVel    = crearLabel("Ahora: 0 km/h | Meta: " .. metaKmh, 46, tVeh, TEXTO, 13)
local btnPrev      = crearBoton("<", 12, 70, 30, 38, tVeh)

local lblPreset = Instance.new("TextLabel")
lblPreset.Size = UDim2.new(0, 132, 0, 38)
lblPreset.Position = UDim2.new(0, 47, 0, 70)
lblPreset.BackgroundColor3 = Color3.fromRGB(4, 7, 8)
lblPreset.Font = FUENTE
lblPreset.TextSize = 11
lblPreset.TextColor3 = NEON
lblPreset.TextWrapped = true
lblPreset.Parent = tVeh
esquina(lblPreset, 6)
borde(lblPreset, NEON, 1, 0.3)

local btnNext   = crearBoton(">", 184, 70, 34, 38, tVeh)
local btnVeh    = crearBoton("OFF", 12, 116, 64, 32, tVeh)
local txtVeh    = crearCaja("", 82, 116, 86, 32, "km/h", tVeh)
local btnVehOK  = crearBoton("OK", 174, 116, 44, 32, tVeh)
btnPrev.TextSize = 16
btnNext.TextSize = 16

-- [04] Extra
local tExtra = crearTarjeta("04", "EXTRA", 92)
local btnInvencible = crearBoton("INVENCIBLE: OFF", 12, 30, 100, 32, tExtra)
local btnAntiMobs   = crearBoton("ANTI-MOBS: OFF", 118, 30, 100, 32, tExtra)
btnInvencible.TextSize = 11
btnAntiMobs.TextSize = 11
local lblMobs = crearLabel("Mobs: -", 68, tExtra, TENUE, 12)

local function setEstado(texto)
    lblEstado.Text = "> " .. texto
end

local function actualizarUI()
    lblVel.Text = "WALKSPEED: " .. (activo and VELOCIDAD_ELEGIDA or VELOCIDAD_NORMAL)
    estiloToggle(btnToggle, activo, "ON", "OFF")
    estiloToggle(btnAuto, autoRegreso, "AUTO: ON", "AUTO: OFF")
    lblPreset.Text = nombreMeta .. "\n" .. metaKmh .. " km/h"
    estiloToggle(btnVeh, vehiculoActivo, "ON", "OFF")
    estiloToggle(btnInvencible, invencible, "INVENCIBLE: ON", "INVENCIBLE: OFF")
    estiloToggle(btnAntiMobs, antiMobs, "ANTI-MOBS: ON", "ANTI-MOBS: OFF")
end

-- Minimizar
local minimizado = false
btnMin.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    contenido.Visible = not minimizado
    barraEstado.Visible = not minimizado
    linea.Visible = not minimizado
    frame.Size = UDim2.new(0, ANCHO_PANEL, 0, minimizado and ALTO_HEADER or ALTO_PANEL)
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
