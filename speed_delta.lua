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
      - Al subirte aparecen tres pedales grandes del script:
          ACELERAR (mantener) : empuja la moto hacia donde mira,
                                con la aceleración del modelo, hasta su máxima.
          FRENAR   (mantener) : la frena fuerte; si sigues pulsando, reversa.
          TURBO    (mantener) : la lleva a la máxima al instante (insano).
        Si no tocas ninguno, la moto se maneja normal con los
        controles del juego. Los pedales se pueden mover.
      - "Ahora" muestra tu velocidad. Si no coincide con el
        velocímetro del juego, ajusta KMH_POR_STUD.

      - Anti-vuelco: mantiene la moto derecha para que no se caiga
        a alta velocidad (no le quita la inclinación en subidas).

    EXTRA
      - Invencible: rellena tu vida y evita que el personaje muera.
      - Anti-mobs : quita el contacto de los mobs contigo.
      Ambos solo funcionan si el juego maneja eso en tu pantalla.
      - Salto alto    : saltas más alto.
      - Salto infinito: puedes saltar en el aire las veces que quieras.

    GUARDADO AUTOMÁTICO
      - Recuerda tu velocidad, el modelo elegido, la velocidad de cada
        vehículo, los botones encendidos, la posición del panel y tus
        puntos de teletransporte (por cada juego). La próxima vez que
        ejecutes el script, todo vuelve como lo dejaste.
      - Se guarda en el archivo SpeedHub_config.json de Delta.

    AUTO-GOLPE
      - Para juegos de subir fuerza golpeando cosas (árboles, rocas...).
      - Usa sola la herramienta que tengas en la mano, muy rápido,
        sin que tengas que estar tocando. Ajusta los golpes por segundo.
      - No sirve ni se usa contra otros jugadores.

    MIRA
      - Dibuja una retícula fija en el centro de la pantalla, con
        contorno negro para que no se pierda y no se mueve al apuntar.
      - Ajusta color, tamaño, grosor y hueco; es solo visual.

    El panel tiene pestañas arriba: toca VEL, TP, AUTO, EXTRA, GOLPE o MIRA
    para ver solo ese módulo y que ocupe menos espacio.
    El encabezado muestra los FPS y el ping.
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
local REPELER_DISTANCIA  = 28    -- distancia a la que mantiene lejos a los enemigos
local SALTO_ALTO         = 120   -- fuerza del salto alto (normal: 50)
local FUERZA_ANTIVUELCO  = 8     -- qué tan rápido endereza la moto (más = más firme)
local ARCHIVO_CONFIG     = "SpeedHub_config.json"

-- Vehículos
local KMH_POR_STUD        = 0.91 -- 1 stud/s = 0.91 km/h (ajústalo si no coincide con el juego)
local LIMITE_VEHICULO_KMH = 1000 -- máximo que se puede escribir
local FRENO_KMH_S         = 150  -- cuántos km/h pierde por segundo al mantener FRENAR
local INVERTIR_DIRECCION  = false -- true si al acelerar la moto va hacia atrás
local VEHICULO_AL_INICIAR = true -- true: el módulo de vehículo arranca en ON
local PRESET_INICIAL      = 5    -- cuál modelo está elegido al iniciar (número de la lista)

-- Modelos para elegir: { nombre, km/h máximos, aceleración en km/h por segundo }
local PRESETS = {
    { "Moto - Honda CB500",          180,  35 },
    { "Moto - Kawasaki Ninja 400",   190,  40 },
    { "Moto - Yamaha R6",            260,  60 },
    { "Moto - Suzuki Hayabusa",      300,  75 },
    { "Moto - Kawasaki ZX-10R",      300,  80 },
    { "Moto - BMW S1000RR",          305,  85 },
    { "Moto - Ducati Panigale V4 R", 320,  95 },
    { "Moto - Kawasaki H2R",         400, 120 },
    { "Carro - NASCAR",              320,  70 },
    { "Carro - Fórmula 1",           360, 110 },
    { "Carro - Bugatti Chiron",      440, 100 },
    { "Modo cohete",                 600, 200 },
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
local antiVuelco     = false
local saltoAlto      = false
local saltoInfinito  = false
local autoGolpe      = false
local golpesPorSeg   = 10
local miraOn         = false
local miraTam        = 14
local miraGros       = 3
local miraHueco      = 6
local miraColorIdx   = 1

local MIRA_COLORES = {
    { "Verde",    Color3.fromRGB(0, 255, 100) },
    { "Blanco",   Color3.fromRGB(255, 255, 255) },
    { "Rojo",     Color3.fromRGB(255, 40, 40) },
    { "Amarillo", Color3.fromRGB(255, 230, 0) },
    { "Cian",     Color3.fromRGB(0, 220, 255) },
    { "Rosa",     Color3.fromRGB(255, 60, 200) },
}
local pestana        = 3     -- pestaña mostrada al abrir (3 = AUTO)
local sucio          = false -- hay cambios sin guardar

local indicePreset   = math.clamp(PRESET_INICIAL, 1, #PRESETS)
local nombreMeta     = PRESETS[indicePreset][1]
local metaKmh        = PRESETS[indicePreset][2]
local acelKmh        = PRESETS[indicePreset][3]
local vehiculoActual = nil   -- modelo del vehículo en el que vas
local memoria        = {}    -- nombre del vehículo -> { nombre, kmh, aceleración }

----------------------------------------------------------------
-- GUARDADO: cargar la configuración anterior
----------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local puedeGuardar = typeof(writefile) == "function"
    and typeof(readfile) == "function"
    and typeof(isfile) == "function"

local function aVector(t)
    if type(t) == "table" and type(t[1]) == "number" and type(t[2]) == "number" and type(t[3]) == "number" then
        return Vector3.new(t[1], t[2], t[3])
    end
    return nil
end

local function deVector(v)
    return v and { v.X, v.Y, v.Z } or nil
end

local config = nil
if puedeGuardar then
    local ok, datos = pcall(function()
        if not isfile(ARCHIVO_CONFIG) then return nil end
        return HttpService:JSONDecode(readfile(ARCHIVO_CONFIG))
    end)
    if ok and type(datos) == "table" then config = datos end
end

if config then
    if type(config.velocidad) == "number" then
        VELOCIDAD_ELEGIDA = math.clamp(math.floor(config.velocidad), 1, LIMITE_VELOCIDAD)
    end
    local p = config.preset
    if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "string"
        and type(p[3]) == "number" and type(p[4]) == "number" then
        indicePreset = math.clamp(math.floor(p[1]), 1, #PRESETS)
        nombreMeta, metaKmh, acelKmh = p[2], p[3], p[4]
    end
    if type(config.memoria) == "table" then
        for nombre, v in pairs(config.memoria) do
            if type(nombre) == "string" and type(v) == "table" and type(v[1]) == "string"
                and type(v[2]) == "number" and type(v[3]) == "number" then
                memoria[nombre] = { v[1], v[2], v[3] }
            end
        end
    end
    antiVuelco    = config.antiVuelco == true
    saltoAlto     = config.saltoAlto == true
    saltoInfinito = config.saltoInfinito == true
    autoGolpe     = config.autoGolpe == true
    if type(config.golpesPorSeg) == "number" then
        golpesPorSeg = math.clamp(math.floor(config.golpesPorSeg), 1, 40)
    end
    local m = config.mira
    if type(m) == "table" then
        miraOn = m.on == true
        if type(m.tam) == "number" then miraTam = math.clamp(math.floor(m.tam), 2, 60) end
        if type(m.gros) == "number" then miraGros = math.clamp(math.floor(m.gros), 1, 10) end
        if type(m.hueco) == "number" then miraHueco = math.clamp(math.floor(m.hueco), 0, 40) end
        if type(m.color) == "number" then miraColorIdx = math.clamp(math.floor(m.color), 1, #MIRA_COLORES) end
    end
    if type(config.pestana) == "number" then pestana = config.pestana end
    local puntos = type(config.puntos) == "table" and config.puntos[tostring(game.PlaceId)]
    if type(puntos) == "table" then
        origen = aVector(puntos.origen)
        punto  = aVector(puntos.punto)
    end
end

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
    local viejaMira = guiParent:FindFirstChild("SpeedHubMira")
    if viejaMira then viejaMira:Destroy() end
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
local ALTO_PANEL   = 330
local ALTO_HEADER  = 46
local ALTO_TABS    = 34
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
if config and type(config.panel) == "table" and #config.panel == 4 then
    local ok, pos = pcall(UDim2.new, table.unpack(config.panel))
    if ok then frame.Position = pos end
end
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

-- FPS y ping en el encabezado
local cuadros, tiempoFps = 0, 0
table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    cuadros = cuadros + 1
    tiempoFps = tiempoFps + dt
    if tiempoFps >= 1 then
        local ping = 0
        pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
        subtitulo.Text = "root@delta:~$ " .. cuadros .. "fps · " .. ping .. "ms"
        cuadros, tiempoFps = 0, 0
    end
end))

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

-- Barra de pestañas (debajo del encabezado)
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, 0, 0, ALTO_TABS)
tabsFrame.Position = UDim2.new(0, 0, 0, ALTO_HEADER)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = frame

-- Contenido con scroll
local contenido = Instance.new("ScrollingFrame")
contenido.Size = UDim2.new(1, 0, 1, -(ALTO_HEADER + ALTO_TABS + ALTO_ESTADO))
contenido.Position = UDim2.new(0, 0, 0, ALTO_HEADER + ALTO_TABS)
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
local tarjetas = {}  -- { tab = "VEL", card = Frame }
local ordenTarjeta = 0
local function crearTarjeta(numero, nombre, alto, tab)
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
    table.insert(tarjetas, { tab = tab, card = t })
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
local tVel = crearTarjeta("01", "VELOCIDAD", 96, "VEL")
local lblVel     = crearLabel("WALKSPEED: 16", 28, tVel)
local btnToggle  = crearBoton("OFF", 12, 54, 64, 32, tVel)
local txtVel     = crearCaja(tostring(VELOCIDAD_ELEGIDA), 82, 54, 86, 32, "ej: 200", tVel)
local btnAplicar = crearBoton("OK", 174, 54, 44, 32, tVel)

-- [02] Teletransporte
local tTp = crearTarjeta("02", "TELETRANSPORTE", 146, "TP")
local btnGuardarOrigen = crearBoton("Guardar origen", 12, 30, 100, 32, tTp)
local btnVolverOrigen  = crearBoton("Volver origen", 118, 30, 100, 32, tTp)
local btnGuardarPunto  = crearBoton("Guardar punto", 12, 68, 100, 32, tTp)
local btnIrPunto       = crearBoton("Ir a punto",    118, 68, 100, 32, tTp)
local btnIrMedio       = crearBoton("Ir al medio",   12, 106, 100, 32, tTp)
local btnAuto          = crearBoton("AUTO: OFF",     118, 106, 100, 32, tTp)

-- [03] Vehículo
local tVeh = crearTarjeta("03", "VEHÍCULO // motos y carros", 194, "AUTO")
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
local btnAntiVuelco = crearBoton("ANTI-VUELCO: OFF", 12, 154, 206, 30, tVeh)

-- [04] Extra
local tExtra = crearTarjeta("04", "EXTRA", 130, "EXTRA")
local btnInvencible = crearBoton("INVENCIBLE: OFF", 12, 30, 100, 32, tExtra)
local btnAntiMobs   = crearBoton("ANTI-MOBS: OFF", 118, 30, 100, 32, tExtra)
btnInvencible.TextSize = 11
btnAntiMobs.TextSize = 11
local btnSaltoAlto = crearBoton("SALTO ALTO: OFF", 12, 68, 100, 32, tExtra)
local btnSaltoInf  = crearBoton("SALTO INF: OFF", 118, 68, 100, 32, tExtra)
btnSaltoAlto.TextSize = 11
btnSaltoInf.TextSize = 11
local lblMobs = crearLabel("Mobs: -", 106, tExtra, TENUE, 12)

-- [05] Auto-golpe
local tGolpe = crearTarjeta("05", "AUTO-GOLPE // subir fuerza", 120, "GOLPE")
local btnGolpe     = crearBoton("AUTO-GOLPE: OFF", 12, 30, 206, 32, tGolpe)
local lblGolpeVel  = crearLabel("Golpes/seg: 10", 70, tGolpe, TEXTO, 13)
local btnGolpeMenos= crearBoton("-", 150, 66, 30, 26, tGolpe)
local btnGolpeMas  = crearBoton("+", 186, 66, 32, 26, tGolpe)
local lblHerramienta = crearLabel("Herramienta: ninguna", 96, tGolpe, TENUE, 12)
btnGolpe.TextSize = 12

-- [06] Mira
local tMira = crearTarjeta("06", "MIRA // retícula", 160, "MIRA")
local btnMira      = crearBoton("MIRA: OFF", 12, 30, 100, 32, tMira)
local btnMiraColor = crearBoton("Color", 118, 30, 100, 32, tMira)
local lblMiraTam   = crearLabel("Tamaño: 14", 70, tMira, TEXTO, 12)
local btnTamMenos  = crearBoton("-", 150, 66, 30, 26, tMira)
local btnTamMas    = crearBoton("+", 186, 66, 32, 26, tMira)
local lblMiraGros  = crearLabel("Grosor: 3", 100, tMira, TEXTO, 12)
local btnGrosMenos = crearBoton("-", 150, 96, 30, 26, tMira)
local btnGrosMas   = crearBoton("+", 186, 96, 32, 26, tMira)
local lblMiraHueco = crearLabel("Hueco: 6", 130, tMira, TEXTO, 12)
local btnHuecoMenos= crearBoton("-", 150, 126, 30, 26, tMira)
local btnHuecoMas  = crearBoton("+", 186, 126, 32, 26, tMira)
btnMira.TextSize = 12
btnMiraColor.TextSize = 12


local function setEstado(texto)
    lblEstado.Text = "> " .. texto
    sucio = true
end

local function actualizarUI()
    lblVel.Text = "WALKSPEED: " .. (activo and VELOCIDAD_ELEGIDA or VELOCIDAD_NORMAL)
    estiloToggle(btnToggle, activo, "ON", "OFF")
    estiloToggle(btnAuto, autoRegreso, "AUTO: ON", "AUTO: OFF")
    lblPreset.Text = nombreMeta .. "\n" .. metaKmh .. " km/h  +" .. acelKmh .. "/s"
    estiloToggle(btnVeh, vehiculoActivo, "ON", "OFF")
    estiloToggle(btnInvencible, invencible, "INVENCIBLE: ON", "INVENCIBLE: OFF")
    estiloToggle(btnAntiMobs, antiMobs, "ANTI-MOBS: ON", "ANTI-MOBS: OFF")
    estiloToggle(btnAntiVuelco, antiVuelco, "ANTI-VUELCO: ON", "ANTI-VUELCO: OFF")
    estiloToggle(btnSaltoAlto, saltoAlto, "SALTO ALTO: ON", "SALTO ALTO: OFF")
    estiloToggle(btnSaltoInf, saltoInfinito, "SALTO INF: ON", "SALTO INF: OFF")
    estiloToggle(btnGolpe, autoGolpe, "AUTO-GOLPE: ON", "AUTO-GOLPE: OFF")
    lblGolpeVel.Text = "Golpes/seg: " .. golpesPorSeg
    estiloToggle(btnMira, miraOn, "MIRA: ON", "MIRA: OFF")
    lblMiraTam.Text = "Tamaño: " .. miraTam
    lblMiraGros.Text = "Grosor: " .. miraGros
    lblMiraHueco.Text = "Hueco: " .. miraHueco
    sucio = true
end

-- Minimizar
local minimizado = false
btnMin.MouseButton1Click:Connect(function()
    minimizado = not minimizado
    contenido.Visible = not minimizado
    tabsFrame.Visible = not minimizado
    barraEstado.Visible = not minimizado
    linea.Visible = not minimizado
    frame.Size = UDim2.new(0, ANCHO_PANEL, 0, minimizado and ALTO_HEADER or ALTO_PANEL)
    btnMin.Text = minimizado and "+" or "–"
end)

----------------------------------------------------------------
-- PESTAÑAS: mostrar un solo módulo a la vez
----------------------------------------------------------------
local tabBtns = {}
local function mostrarModulo(i)
    i = math.clamp(i, 1, #tarjetas)
    pestana = i
    for idx, info in ipairs(tarjetas) do
        info.card.Visible = (idx == i)
    end
    for idx, b in ipairs(tabBtns) do
        local activa = (idx == i)
        b.BackgroundColor3 = activa and ON_FONDO or BOTON
        b.TextColor3 = activa and NEON or TENUE
        local st = b:FindFirstChildOfClass("UIStroke")
        if st then st.Color = activa and NEON or NEON_DIM end
    end
    sucio = true
end

do
    local n = #tarjetas
    local x0, gap = 8, 3
    local util = ANCHO_PANEL - x0 * 2
    local ancho = math.floor((util - gap * (n - 1)) / n)
    local paso = ancho + gap
    for idx, info in ipairs(tarjetas) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, ancho, 0, 26)
        b.Position = UDim2.new(0, x0 + (idx - 1) * paso, 0, 5)
        b.BackgroundColor3 = BOTON
        b.Font = FUENTE
        b.TextSize = 10
        b.TextColor3 = TENUE
        b.Text = info.tab
        b.AutoButtonColor = true
        b.Parent = tabsFrame
        esquina(b, 6)
        borde(b, NEON_DIM, 1)
        b.MouseButton1Click:Connect(function() mostrarModulo(idx) end)
        tabBtns[idx] = b
    end
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
local UserInputService = game:GetService("UserInputService")
local asientosOriginales = {}  -- asiento -> MaxSpeed original
local tiempoVehUI = 0
local acelerandoBoton = false
local frenandoBoton = false
local turboBoton = false

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

-- Pedales flotantes del script (aparecen al subir a un vehículo)
local pedales = Instance.new("Frame")
pedales.Size = UDim2.new(0, 300, 0, 112)
pedales.Position = UDim2.new(1, -320, 0.32, 0)
pedales.BackgroundColor3 = FONDO
pedales.BorderSizePixel = 0
pedales.Active = true
pedales.Draggable = true
pedales.Visible = false
pedales.Parent = gui
esquina(pedales, 10)
borde(pedales, NEON, 1.5)

local tituloPedales = Instance.new("TextLabel")
tituloPedales.Size = UDim2.new(1, -16, 0, 18)
tituloPedales.Position = UDim2.new(0, 8, 0, 3)
tituloPedales.BackgroundTransparency = 1
tituloPedales.Font = FUENTE
tituloPedales.TextSize = 11
tituloPedales.TextColor3 = TENUE
tituloPedales.TextXAlignment = Enum.TextXAlignment.Left
tituloPedales.TextTruncate = Enum.TextTruncate.AtEnd
tituloPedales.Text = "> pedales // 0 km/h"
tituloPedales.Parent = pedales

local function crearPedal(texto, x, w, colorTexto, colorFondo)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 78)
    b.Position = UDim2.new(0, x, 0, 26)
    b.BackgroundColor3 = colorFondo
    b.Font = FUENTE
    b.TextSize = 14
    b.TextColor3 = colorTexto
    b.Text = texto
    b.AutoButtonColor = false
    b.Parent = pedales
    esquina(b, 8)
    borde(b, colorTexto, 1.5)
    return b
end

local pedalFreno = crearPedal("FRENAR", 8, 92, OFF_TEXTO, OFF_FONDO)
local pedalAcel  = crearPedal("ACELERAR", 104, 92, NEON, ON_FONDO)
local pedalTurbo = crearPedal("TURBO", 200, 92, CIAN, Color3.fromRGB(0, 40, 55))

-- Mantener pulsado: se activa al tocar y se apaga al soltar el mismo dedo
local function botonMantener(boton, alCambiar)
    local entrada = nil
    local fondoNormal = boton.BackgroundColor3
    local function soltar()
        entrada = nil
        boton.BackgroundColor3 = fondoNormal
        alCambiar(false)
    end
    boton.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
            or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            entrada = inp
            boton.BackgroundColor3 = fondoNormal:Lerp(Color3.new(1, 1, 1), 0.25)
            alCambiar(true)
        end
    end)
    table.insert(conexiones, UserInputService.InputEnded:Connect(function(inp)
        if entrada and (inp == entrada
            or (inp.UserInputType == Enum.UserInputType.MouseButton1
                and entrada.UserInputType == Enum.UserInputType.MouseButton1)) then
            soltar()
        end
    end))
end

botonMantener(pedalAcel, function(v) acelerandoBoton = v end)
botonMantener(pedalFreno, function(v) frenandoBoton = v end)
botonMantener(pedalTurbo, function(v) turboBoton = v end)

-- Elegir modelo (y recordarlo para el vehículo en el que vas)
local function elegirMeta(nombre, kmh, acel)
    nombreMeta = nombre
    metaKmh = kmh
    acelKmh = acel
    if vehiculoActual then
        memoria[vehiculoActual.Name] = { nombre, kmh, acel }
        setEstado(nombre .. " guardado para " .. vehiculoActual.Name)
    else
        setEstado("Elegido: " .. nombre .. " (" .. kmh .. " km/h)")
    end
    actualizarUI()
end

local function elegirPreset()
    local p = PRESETS[indicePreset]
    elegirMeta(p[1], p[2], p[3])
end

btnPrev.MouseButton1Click:Connect(function()
    indicePreset = indicePreset - 1
    if indicePreset < 1 then indicePreset = #PRESETS end
    elegirPreset()
end)

btnNext.MouseButton1Click:Connect(function()
    indicePreset = indicePreset + 1
    if indicePreset > #PRESETS then indicePreset = 1 end
    elegirPreset()
end)

local function leerVehiculo()
    local n = tonumber(txtVeh.Text)
    if not n then
        setEstado("Escribe los km/h, ej: 250")
        return
    end
    n = math.clamp(math.floor(n), 10, LIMITE_VEHICULO_KMH)
    txtVeh.Text = tostring(n)
    -- Aceleración proporcional: llega a la máxima en unos 3 segundos
    elegirMeta("Personalizada", n, math.max(20, math.floor(n / 3)))
end

btnVehOK.MouseButton1Click:Connect(leerVehiculo)
txtVeh.FocusLost:Connect(function(enter)
    if enter then leerVehiculo() end
end)

btnVeh.MouseButton1Click:Connect(function()
    vehiculoActivo = not vehiculoActivo
    if not vehiculoActivo then
        restaurarAsientos()
        acelerandoBoton, frenandoBoton, turboBoton = false, false, false
    end
    setEstado(vehiculoActivo and "Vehículo rápido activado" or "Vehículo normal")
    actualizarUI()
end)

local function alSubir(vehiculo)
    vehiculoActual = vehiculo
    lblManejando.Text = "Manejando: " .. vehiculo.Name
    local guardado = memoria[vehiculo.Name]
    if guardado then
        nombreMeta, metaKmh, acelKmh = guardado[1], guardado[2], guardado[3]
        setEstado("Usando " .. nombreMeta .. " en " .. vehiculo.Name)
    else
        setEstado("Subiste a " .. vehiculo.Name)
    end
    actualizarUI()
end

local function alBajar()
    vehiculoActual = nil
    acelerandoBoton, frenandoBoton, turboBoton = false, false, false
    lblManejando.Text = "Manejando: ninguno"
    lblVehVel.Text = "Ahora: 0 km/h | Meta: " .. metaKmh
end

table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    local hum = getHumanoid()
    local asiento = hum and hum.SeatPart

    -- Detecta al subir y al bajar
    pedales.Visible = vehiculoActivo and asiento ~= nil
    if not asiento then
        if vehiculoActual then alBajar() end
        return
    end
    local vehiculo = obtenerVehiculo(asiento)
    if vehiculo ~= vehiculoActual then alSubir(vehiculo) end

    local raiz = asiento.AssemblyRootPart or asiento
    local vel = raiz.AssemblyLinearVelocity

    -- Hacia dónde mira el vehículo (solo horizontal)
    local mira = asiento.CFrame.LookVector
    if INVERTIR_DIRECCION then mira = -mira end
    local adelante = Vector3.new(mira.X, 0, mira.Z)
    if adelante.Magnitude < 0.01 then return end
    adelante = adelante.Unit

    local avance = vel:Dot(adelante)               -- velocidad hacia adelante
    local resto  = vel - adelante * avance         -- lateral + caída
    local rapidez = Vector3.new(vel.X, 0, vel.Z).Magnitude

    -- Muestra la velocidad
    tiempoVehUI = tiempoVehUI + dt
    if tiempoVehUI >= 0.2 then
        tiempoVehUI = 0
        local kmh = math.floor(rapidez * KMH_POR_STUD)
        lblVehVel.Text = "Ahora: " .. kmh .. " km/h | Meta: " .. metaKmh
        tituloPedales.Text = "> " .. kmh .. "/" .. metaKmh .. " km/h"
    end

    if not vehiculoActivo then return end

    local meta = metaKmh / KMH_POR_STUD
    if asiento:IsA("VehicleSeat") then
        if asientosOriginales[asiento] == nil then
            asientosOriginales[asiento] = asiento.MaxSpeed
        end
        asiento.MaxSpeed = math.max(asientosOriginales[asiento], meta)
    end

    if turboBoton then
        -- Turbo: a la máxima al instante
        local lateral = Vector3.new(resto.X, 0, resto.Z) * 0.6
        raiz.AssemblyLinearVelocity = adelante * meta + lateral + Vector3.new(0, resto.Y, 0)
    elseif frenandoBoton then
        -- Frena fuerte; si sigues pulsando, va en reversa
        local minRev = -(meta * 0.4)
        local nuevo = math.max(minRev, avance - (FRENO_KMH_S / KMH_POR_STUD) * dt)
        raiz.AssemblyLinearVelocity = adelante * nuevo + resto
    elseif acelerandoBoton then
        -- Acelera hacia donde mira, con la aceleración del modelo, hasta su máxima.
        -- Se fija cada cuadro para que el motor del juego no la frene.
        local acel = (acelKmh / KMH_POR_STUD) * dt
        local nuevo = math.min(meta, math.max(avance, 0) + acel)
        if nuevo > avance then
            -- Reduce el derrape lateral para que siga la dirección del manubrio
            local lateral = Vector3.new(resto.X, 0, resto.Z) * 0.85
            raiz.AssemblyLinearVelocity = adelante * nuevo + lateral + Vector3.new(0, resto.Y, 0)
        end
    end
end))

----------------------------------------------------------------
-- MÓDULO: ANTI-VUELCO (mantiene la moto derecha)
----------------------------------------------------------------
btnAntiVuelco.MouseButton1Click:Connect(function()
    antiVuelco = not antiVuelco
    setEstado(antiVuelco and "Anti-vuelco activado" or "Anti-vuelco apagado")
    actualizarUI()
end)

local SENO_TOLERANCIA = math.sin(math.rad(3))

table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    if not (antiVuelco and vehiculoActivo) then return end
    local hum = getHumanoid()
    local asiento = hum and hum.SeatPart
    if not asiento then return end

    local raiz = asiento.AssemblyRootPart or asiento
    local cf = asiento.CFrame
    local mira = cf.LookVector
    if math.abs(mira.Y) > 0.95 then return end  -- apuntando casi vertical: no se puede calcular

    -- Solo corrige la inclinación hacia los lados (o si está de cabeza)
    local ladeado = math.abs(cf.RightVector.Y) > SENO_TOLERANCIA
    local deCabeza = cf.UpVector.Y < 0
    if not (ladeado or deCabeza) then return end

    -- Misma dirección y misma subida/bajada, pero sin estar ladeada
    local objetivo = CFrame.lookAt(cf.Position, cf.Position + mira, Vector3.yAxis)
    local giro = (objetivo - objetivo.Position) * (cf - cf.Position):Inverse()
    local paso = CFrame.identity:Lerp(giro, math.min(1, dt * FUERZA_ANTIVUELCO))
    local pivote = CFrame.new(cf.Position)
    raiz.CFrame = pivote * paso * pivote:Inverse() * raiz.CFrame

    -- Quita el giro hacia los lados que la estaba tumbando
    local av = raiz.AssemblyAngularVelocity
    raiz.AssemblyAngularVelocity = av - mira * av:Dot(mira)
end))

----------------------------------------------------------------
-- MÓDULO: SALTO (alto e infinito)
----------------------------------------------------------------
local saltoOriginal = setmetatable({}, { __mode = "k" })  -- humanoide -> fuerza original

local function aplicarSalto()
    local hum = getHumanoid()
    if not hum then return end
    if saltoOriginal[hum] == nil then
        saltoOriginal[hum] = { hum.UseJumpPower, hum.JumpPower }
    end
    if saltoAlto then
        hum.UseJumpPower = true
        hum.JumpPower = SALTO_ALTO
    else
        local orig = saltoOriginal[hum]
        hum.UseJumpPower = orig[1]
        hum.JumpPower = orig[2]
    end
end

btnSaltoAlto.MouseButton1Click:Connect(function()
    saltoAlto = not saltoAlto
    aplicarSalto()
    setEstado(saltoAlto and "Salto alto activado" or "Salto normal")
    actualizarUI()
end)

btnSaltoInf.MouseButton1Click:Connect(function()
    saltoInfinito = not saltoInfinito
    setEstado(saltoInfinito and "Salto infinito activado" or "Salto infinito apagado")
    actualizarUI()
end)

table.insert(conexiones, UserInputService.JumpRequest:Connect(function()
    if not saltoInfinito then return end
    local hum = getHumanoid()
    if hum and not hum.SeatPart and hum.Health > 0 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

----------------------------------------------------------------
-- MÓDULO: AUTO-GOLPE (usa la herramienta sola, para subir fuerza)
----------------------------------------------------------------
local function herramientaEquipada()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Tool")
end

btnGolpe.MouseButton1Click:Connect(function()
    autoGolpe = not autoGolpe
    setEstado(autoGolpe and "Auto-golpe activado" or "Auto-golpe apagado")
    actualizarUI()
end)

btnGolpeMas.MouseButton1Click:Connect(function()
    golpesPorSeg = math.min(40, golpesPorSeg + 1); actualizarUI()
end)
btnGolpeMenos.MouseButton1Click:Connect(function()
    golpesPorSeg = math.max(1, golpesPorSeg - 1); actualizarUI()
end)

local tiempoGolpe = 0
local tiempoGolpeUI = 0
table.insert(conexiones, RunService.Heartbeat:Connect(function(dt)
    -- Muestra qué herramienta hay en la mano
    tiempoGolpeUI = tiempoGolpeUI + dt
    if tiempoGolpeUI >= 0.3 then
        tiempoGolpeUI = 0
        local h = herramientaEquipada()
        lblHerramienta.Text = "Herramienta: " .. (h and h.Name or "ninguna")
    end

    if not autoGolpe then return end
    local tool = herramientaEquipada()
    if not tool then return end
    tiempoGolpe = tiempoGolpe + dt
    if tiempoGolpe >= 1 / golpesPorSeg then
        tiempoGolpe = 0
        pcall(function() tool:Activate() end)
    end
end))

----------------------------------------------------------------
-- MÓDULO: MIRA (retícula fija con contorno, solo visual)
----------------------------------------------------------------
local miraGui = Instance.new("ScreenGui")
miraGui.Name = "SpeedHubMira"
miraGui.ResetOnSpawn = false
miraGui.IgnoreGuiInset = true
miraGui.DisplayOrder = -1
miraGui.Parent = guiParent

-- Cada línea lleva su propio contorno negro (UIStroke)
local function nuevaLinea()
    local l = Instance.new("Frame")
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.BorderSizePixel = 0
    l.Active = false
    l.Visible = false
    l.ZIndex = 2
    l.Parent = miraGui
    local st = Instance.new("UIStroke")
    st.Color = Color3.new(0, 0, 0)
    st.Thickness = 1.5
    st.Transparency = 0.1
    st.Parent = l
    return l
end

local mTop, mBot, mLeft, mRight = nuevaLinea(), nuevaLinea(), nuevaLinea(), nuevaLinea()

local function actualizarMira()
    local color = MIRA_COLORES[miraColorIdx][2]
    for _, l in ipairs({ mTop, mBot, mLeft, mRight }) do
        l.BackgroundColor3 = color
        l.Visible = miraOn
    end
    local medio = miraHueco + miraTam / 2
    mTop.Size    = UDim2.new(0, miraGros, 0, miraTam)
    mBot.Size    = UDim2.new(0, miraGros, 0, miraTam)
    mLeft.Size   = UDim2.new(0, miraTam, 0, miraGros)
    mRight.Size  = UDim2.new(0, miraTam, 0, miraGros)
    mTop.Position   = UDim2.new(0.5, 0, 0.5, -medio)
    mBot.Position   = UDim2.new(0.5, 0, 0.5, medio)
    mLeft.Position  = UDim2.new(0.5, -medio, 0.5, 0)
    mRight.Position = UDim2.new(0.5, medio, 0.5, 0)
end

btnMira.MouseButton1Click:Connect(function()
    miraOn = not miraOn
    actualizarMira()
    setEstado(miraOn and "Mira activada" or "Mira apagada")
    actualizarUI()
end)

btnMiraColor.MouseButton1Click:Connect(function()
    miraColorIdx = miraColorIdx % #MIRA_COLORES + 1
    actualizarMira()
    setEstado("Color: " .. MIRA_COLORES[miraColorIdx][1])
end)

btnTamMas.MouseButton1Click:Connect(function()
    miraTam = math.min(60, miraTam + 2); actualizarMira(); actualizarUI()
end)
btnTamMenos.MouseButton1Click:Connect(function()
    miraTam = math.max(2, miraTam - 2); actualizarMira(); actualizarUI()
end)
btnGrosMas.MouseButton1Click:Connect(function()
    miraGros = math.min(10, miraGros + 1); actualizarMira(); actualizarUI()
end)
btnGrosMenos.MouseButton1Click:Connect(function()
    miraGros = math.max(1, miraGros - 1); actualizarMira(); actualizarUI()
end)
btnHuecoMas.MouseButton1Click:Connect(function()
    miraHueco = math.min(40, miraHueco + 2); actualizarMira(); actualizarUI()
end)
btnHuecoMenos.MouseButton1Click:Connect(function()
    miraHueco = math.max(0, miraHueco - 2); actualizarMira(); actualizarUI()
end)

----------------------------------------------------------------
-- MÓDULO: INVENCIBLE
----------------------------------------------------------------
local function aplicarInvencible()
    local hum = getHumanoid()
    if not hum then return end
    local char = hum.Parent
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not invencible)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not invencible)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not invencible)
        if char then char:SetAttribute("BreakJointsOnDeath", not invencible) end
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

-- RenderStepped rellena la vida más seguido, por si el daño llega entre cuadros
table.insert(conexiones, RunService.RenderStepped:Connect(function()
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
local humsOriginales = {}    -- humanoide -> WalkSpeed original

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
    local h = modelo:FindFirstChildOfClass("Humanoid")
    if h and humsOriginales[h] == nil then
        humsOriginales[h] = h.WalkSpeed
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
    for h, ws in pairs(humsOriginales) do
        if h and h.Parent then pcall(function() h.WalkSpeed = ws end) end
    end
    humsOriginales = {}
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

-- Cada cuadro: mantiene a los enemigos lejos y quietos (solo NPC, no jugadores)
table.insert(conexiones, RunService.Heartbeat:Connect(function()
    if not antiMobs then return end
    local hrp = getHRP()
    if not hrp then return end
    local miPos = hrp.Position
    for modelo in pairs(mobs) do
        if modelo.Parent then
            local h = modelo:FindFirstChildOfClass("Humanoid")
            if h then
                h.WalkSpeed = 0            -- que no te persiga
                pcall(function() h.Jump = false end)
            end
            local raiz = modelo:FindFirstChild("HumanoidRootPart")
                or (h and h.RootPart) or modelo.PrimaryPart
            if raiz then
                local delta = raiz.Position - miPos
                local plano = Vector3.new(delta.X, 0, delta.Z)
                local dist = plano.Magnitude
                if dist < REPELER_DISTANCIA then
                    local dir = dist > 0.1 and plano.Unit or Vector3.new(0, 0, 1)
                    local destino = miPos + dir * REPELER_DISTANCIA
                        + Vector3.new(0, delta.Y, 0)
                    raiz.AssemblyLinearVelocity = Vector3.zero
                    raiz.CFrame = CFrame.new(destino, destino + dir)
                end
            end
        end
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
    for h in pairs(humsOriginales) do
        if not h.Parent then humsOriginales[h] = nil end
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
    aplicarSalto()
end

if player.Character then
    task.spawn(prepararPersonaje, player.Character)
end

table.insert(conexiones, player.CharacterAdded:Connect(prepararPersonaje))

----------------------------------------------------------------
-- GUARDADO: escribir la configuración
----------------------------------------------------------------
local function guardar()
    if not puedeGuardar then return end
    local datos = type(config) == "table" and config or {}
    datos.velocidad     = VELOCIDAD_ELEGIDA
    datos.activo        = activo
    datos.vehiculoActivo = vehiculoActivo
    datos.preset        = { indicePreset, nombreMeta, metaKmh, acelKmh }
    datos.memoria       = memoria
    datos.antiVuelco    = antiVuelco
    datos.saltoAlto     = saltoAlto
    datos.saltoInfinito = saltoInfinito
    datos.autoGolpe     = autoGolpe
    datos.golpesPorSeg  = golpesPorSeg
    datos.mira = { on = miraOn, tam = miraTam, gros = miraGros,
                   hueco = miraHueco, color = miraColorIdx }
    datos.pestana       = pestana
    local pos = frame.Position
    datos.panel = { pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset }
    if type(datos.puntos) ~= "table" then datos.puntos = {} end
    datos.puntos[tostring(game.PlaceId)] = { origen = deVector(origen), punto = deVector(punto) }
    config = datos
    pcall(function()
        writefile(ARCHIVO_CONFIG, HttpService:JSONEncode(datos))
    end)
end

-- Mover el panel también cuenta como cambio
frame:GetPropertyChangedSignal("Position"):Connect(function() sucio = true end)

-- Guarda cada 3 segundos si algo cambió
task.spawn(function()
    while gui.Parent do
        task.wait(3)
        if sucio and gui.Parent then
            sucio = false
            guardar()
        end
    end
end)

----------------------------------------------------------------
-- CERRAR
----------------------------------------------------------------
local function cerrar()
    guardar()
    activo = false
    autoRegreso = false
    vehiculoActivo = false
    invencible = false
    antiMobs = false
    autoGolpe = false
    for _, c in ipairs(conexiones) do c:Disconnect() end
    conexiones = {}
    acelerandoBoton, frenandoBoton, turboBoton = false, false, false
    restaurarAsientos()
    restaurarMobs()
    aplicarInvencible()
    saltoAlto, saltoInfinito, antiVuelco = false, false, false
    aplicarSalto()
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = VELOCIDAD_NORMAL end
    if gui then gui:Destroy() end
    if miraGui then miraGui:Destroy() end
    _G.SpeedHubCerrar = nil
end

_G.SpeedHubCerrar = cerrar
btnCerrar.MouseButton1Click:Connect(cerrar)

-- Arranque: usa lo guardado si existe, si no, la configuración de arriba
vehiculoActivo = VEHICULO_AL_INICIAR
activo = ACTIVAR_AL_INICIAR
if config then
    if type(config.vehiculoActivo) == "boolean" then vehiculoActivo = config.vehiculoActivo end
    if type(config.activo) == "boolean" then activo = config.activo end
end
txtVel.Text = tostring(VELOCIDAD_ELEGIDA)
aplicarVelocidad()
aplicarSalto()
mostrarModulo(pestana)
actualizarMira()
if config then
    setEstado("Configuración cargada")
elseif activo then
    setEstado("Velocidad puesta en " .. VELOCIDAD_ELEGIDA)
end
sucio = false
