--[[
    Speed Ramp - script para el ejecutor Delta (Roblox)
    ---------------------------------------------------
    - Al activarlo, la velocidad (WalkSpeed) va subiendo poco a poco
      desde VELOCIDAD_INICIAL hasta VELOCIDAD_MAXIMA.
    - Botón ON/OFF para activar/desactivar.
    - Botones + / - para cambiar la velocidad máxima.
    - Se mantiene después de morir/reaparecer.
    - Al desactivarlo vuelve a la velocidad normal (16).
]]

----------------------------------------------------------------
-- CONFIGURACIÓN
----------------------------------------------------------------
local VELOCIDAD_NORMAL  = 16    -- velocidad por defecto de Roblox
local VELOCIDAD_INICIAL = 20    -- desde dónde empieza a subir
local VELOCIDAD_MAXIMA  = 100   -- hasta dónde llega
local INCREMENTO        = 2     -- cuánto sube en cada paso
local INTERVALO         = 0.25  -- segundos entre cada subida
local PASO_MAXIMA       = 10    -- cuánto cambian los botones + / -

----------------------------------------------------------------
-- SERVICIOS
----------------------------------------------------------------
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer

local activo          = false
local velocidadActual = VELOCIDAD_NORMAL
local acumulado       = 0

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

----------------------------------------------------------------
-- INTERFAZ
----------------------------------------------------------------
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local viejo = guiParent:FindFirstChild("SpeedRampGui")
    if viejo then viejo:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedRampGui"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 130)
frame.Position = UDim2.new(0, 20, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local function crearLabel(texto, y)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 22)
    l.Position = UDim2.new(0, 10, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.new(1, 1, 1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 14
    l.Text = texto
    l.Parent = frame
    return l
end

local function crearBoton(texto, pos, size, color)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Text = texto
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local titulo     = crearLabel("Speed Ramp", 6)
local lblVel     = crearLabel("Velocidad: 16", 30)
local lblMax     = crearLabel("Máxima: " .. VELOCIDAD_MAXIMA, 52)
titulo.TextColor3 = Color3.fromRGB(0, 200, 255)

local btnToggle = crearBoton("OFF", UDim2.new(0, 10, 0, 82), UDim2.new(0, 90, 0, 38), Color3.fromRGB(170, 40, 40))
local btnMenos  = crearBoton("-",   UDim2.new(0, 108, 0, 82), UDim2.new(0, 38, 0, 38), Color3.fromRGB(60, 60, 70))
local btnMas    = crearBoton("+",   UDim2.new(0, 152, 0, 82), UDim2.new(0, 38, 0, 38), Color3.fromRGB(60, 60, 70))

local function actualizarUI()
    lblVel.Text = "Velocidad: " .. math.floor(velocidadActual)
    lblMax.Text = "Máxima: " .. VELOCIDAD_MAXIMA
    btnToggle.Text = activo and "ON" or "OFF"
    btnToggle.BackgroundColor3 = activo and Color3.fromRGB(40, 170, 70) or Color3.fromRGB(170, 40, 40)
end

----------------------------------------------------------------
-- LÓGICA
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
    VELOCIDAD_MAXIMA = VELOCIDAD_MAXIMA + PASO_MAXIMA
    actualizarUI()
end)

btnMenos.MouseButton1Click:Connect(function()
    VELOCIDAD_MAXIMA = math.max(VELOCIDAD_INICIAL, VELOCIDAD_MAXIMA - PASO_MAXIMA)
    if velocidadActual > VELOCIDAD_MAXIMA then velocidadActual = VELOCIDAD_MAXIMA end
    actualizarUI()
end)

-- Sube la velocidad gradualmente y la mantiene aplicada
RunService.Heartbeat:Connect(function(dt)
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

    -- Algunos juegos resetean la WalkSpeed; la volvemos a poner
    if hum.WalkSpeed ~= velocidadActual then
        hum.WalkSpeed = velocidadActual
    end
end)

-- Al reaparecer, reinicia la rampa si estaba activo
player.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    if activo then
        velocidadActual = VELOCIDAD_INICIAL
        acumulado = 0
        actualizarUI()
    end
end)

actualizarUI()
