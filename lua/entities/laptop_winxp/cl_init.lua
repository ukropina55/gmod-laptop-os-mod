include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- ======================================================================
--  LAPTOP WINDOWS XP — клиентская логика камеры и интерфейса
-- ======================================================================

local LERP_TIME  = 0.55   -- время подлёта/отлёта камеры
local BOOT_TIME  = 1.9    -- время "загрузки" системы

local ActiveLaptop = nil        -- entity, за которым сейчас "сидит" игрок
local State         = nil       -- nil | "zoomin" | "boot" | "desktop" | "zoomout"
local StateTime      = 0
local StartPos, StartAng, StartFov

local RootPanel      = nil      -- полноэкранная панель (создаётся после zoomin)
local StartMenuPanel = nil

local GRADIENT_U = Material("vgui/gradient-u")
local GRADIENT_D = Material("vgui/gradient-d")

-- ----------------------------------------------------------------
-- Шрифты
-- ----------------------------------------------------------------
surface.CreateFont("XP_Icon",  { font = "Tahoma", size = 13, weight = 500, antialias = true, shadow = true })
surface.CreateFont("XP_Title", { font = "Tahoma", size = 15, weight = 700, antialias = true })
surface.CreateFont("XP_Text",  { font = "Tahoma", size = 14, weight = 400, antialias = true })
surface.CreateFont("XP_Small", { font = "Tahoma", size = 12, weight = 400, antialias = true })
surface.CreateFont("XP_Start", { font = "Tahoma", size = 19, weight = 800, antialias = true, italic = true })
surface.CreateFont("XP_Boot",  { font = "Tahoma", size = 34, weight = 700, antialias = true })
surface.CreateFont("XP_Clock", { font = "Tahoma", size = 13, weight = 400, antialias = true })

-- ----------------------------------------------------------------
-- Вспомогательные функции
-- ----------------------------------------------------------------

local function EaseInOut(t)
    return t * t * (3 - 2 * t)
end

local function GetScreenCamera()
    if not IsValid(ActiveLaptop) then return Vector(0,0,0), Angle(0,0,0) end
    local screenPos = ActiveLaptop:LocalToWorld(ActiveLaptop.ScreenOffset)
    local camPos    = screenPos + ActiveLaptop:GetForward() * ActiveLaptop.ScreenForwardOffset
    local camAng    = (screenPos - camPos):Angle()
    return camPos, camAng
end

local function DrawGradientRect(x, y, w, h, colTop, colBottom)
    surface.SetMaterial(GRADIENT_D)
    surface.SetDrawColor(colTop.r, colTop.g, colTop.b, colTop.a or 255)
    surface.DrawTexturedRect(x, y, w, h)
    surface.SetMaterial(GRADIENT_U)
    surface.SetDrawColor(colBottom.r, colBottom.g, colBottom.b, colBottom.a or 255)
    surface.DrawTexturedRect(x, y, w, h)
end

-- ----------------------------------------------------------------
-- Закрытие ноутбука
-- ----------------------------------------------------------------

local function CloseLaptop()
    if not IsValid(ActiveLaptop) then return end
    if State == "zoomout" or State == nil then return end

    net.Start("laptop_winxp_close")
    net.SendToServer()

    if IsValid(RootPanel) then
        RootPanel:Remove()
        RootPanel = nil
    end
    StartMenuPanel = nil

    gui.EnableScreenClicker(false)

    State     = "zoomout"
    StateTime = CurTime()
end

hook.Add("OnPauseMenuShow", "laptop_winxp_escape", function()
    if IsValid(ActiveLaptop) and State ~= nil and State ~= "zoomout" then
        CloseLaptop()
        return false
    end
end)

-- ----------------------------------------------------------------
-- Интерфейс: иконки рабочего стола (нарисованы кодом, без картинок)
-- ----------------------------------------------------------------

local function PaintMyComputerIcon(w, h)
    draw.RoundedBox(2, w*0.15, h*0.25, w*0.7, h*0.5, Color(210, 210, 215))
    draw.RoundedBox(1, w*0.22, h*0.32, w*0.56, h*0.32, Color(70, 130, 210))
    draw.RoundedBox(1, w*0.15, h*0.78, w*0.7, h*0.1, Color(180, 180, 185))
end

local function PaintBinIcon(w, h)
    draw.RoundedBox(2, w*0.25, h*0.35, w*0.5, h*0.5, Color(190, 195, 200))
    draw.RoundedBox(1, w*0.2, h*0.28, w*0.6, h*0.1, Color(150, 155, 160))
    surface.SetDrawColor(120,125,130)
    surface.DrawRect(w*0.4, h*0.42, 2, h*0.35)
    surface.DrawRect(w*0.5, h*0.42, 2, h*0.35)
    surface.DrawRect(w*0.6, h*0.42, 2, h*0.35)
end

local function PaintIEIcon(w, h)
    draw.NoTexture()
    surface.SetDrawColor(40, 110, 210)
    surface.DrawPoly({
        {x=w*0.5, y=h*0.1}, {x=w*0.85, y=h*0.35}, {x=w*0.7, y=h*0.85}, {x=w*0.3, y=h*0.85}, {x=w*0.15, y=h*0.35}
    })
    surface.SetDrawColor(255, 200, 40)
    surface.DrawRect(w*0.32, h*0.42, w*0.36, w*0.36)
    draw.SimpleText("e", "XP_Title", w*0.5, h*0.58, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function PaintNotepadIcon(w, h)
    draw.RoundedBox(1, w*0.22, h*0.15, w*0.56, h*0.7, Color(250, 250, 250))
    surface.SetDrawColor(255, 220, 60)
    surface.DrawPoly({ {x=w*0.62, y=h*0.15}, {x=w*0.78, y=h*0.15}, {x=w*0.78, y=h*0.31} })
    surface.SetDrawColor(120, 120, 120)
    for i = 0, 3 do
        surface.DrawRect(w*0.3, h*0.34 + i*h*0.1, w*0.34, 2)
    end
end

local function CreateDesktopIcon(parent, x, y, label, paintFunc, onOpen)
    local icon = vgui.Create("DButton", parent)
    icon:SetPos(x, y)
    icon:SetSize(76, 74)
    icon:SetText("")
    icon.Depressed = false
    icon.DoDoubleClick = function() onOpen() end
    icon.DoClick = function() onOpen() end
    icon.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(2, 2, 2, w-4, w-4, Color(90, 140, 220, 90))
        end
        paintFunc(w, w-4)
        draw.SimpleText(label, "XP_Icon", w/2, w+2, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    return icon
end

-- ----------------------------------------------------------------
-- XP-окно (упрощённый DFrame в стиле Luna)
-- ----------------------------------------------------------------

local function CreateXPWindow(parent, title, w, h)
    local win = vgui.Create("DFrame", parent)
    win:SetSize(w, h)
    win:Center()
    win:SetTitle("")
    win:SetDraggable(true)
    win:ShowCloseButton(false)
    win:MakePopup()
    win.btnMaxim:SetVisible(false)
    win.btnMinim:SetVisible(false)
    win.btnClose:SetVisible(false)

    win.Paint = function(self, sw, sh)
        draw.RoundedBoxEx(6, 0, 0, sw, sh, Color(235, 240, 250), true, true, false, false)
        DrawGradientRect(3, 3, sw-6, 26, Color(30, 100, 220), Color(110, 175, 250))
        draw.SimpleText(title, "XP_Title", 10, 16, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(60, 60, 60, 60)
        surface.DrawOutlinedRect(0, 0, sw, sh, 1)
    end

    local close = vgui.Create("DButton", win)
    close:SetText("")
    close:SetSize(20, 18)
    close:SetPos(w - 26, 6)
    close.Paint = function(self, cw, ch)
        draw.RoundedBox(3, 0, 0, cw, ch, self:IsHovered() and Color(230, 60, 60) or Color(200, 70, 70))
        draw.SimpleText("✕", "XP_Small", cw/2, ch/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() win:Close() end

    return win
end

local function OpenMyComputer(parent)
    local win = CreateXPWindow(parent, "Мой компьютер", 420, 300)
    local function drive(y, name)
        local p = vgui.Create("DPanel", win)
        p:SetPos(20, y)
        p:SetSize(380, 50)
        p.Paint = function(self, w, h)
            draw.RoundedBox(3, 0, 0, w, h, Color(255,255,255,200))
            draw.RoundedBox(2, 8, 10, 30, 30, Color(210,210,215))
            draw.RoundedBox(1, 12, 14, 22, 16, Color(70,130,210))
            draw.SimpleText(name, "XP_Text", 48, h/2, Color(20,20,20), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    drive(40, "Локальный диск (C:)")
    drive(96, "Локальный диск (D:)")
    drive(152, "Дисковод гибких дисков (A:)")
end

local function OpenNotepad(parent)
    local win = CreateXPWindow(parent, "Безымянный — Блокнот", 460, 340)
    local menu = vgui.Create("DPanel", win)
    menu:SetPos(4, 30)
    menu:SetSize(452, 20)
    menu.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(240,240,240))
        draw.SimpleText("Файл   Правка   Формат   Вид   Справка", "XP_Small", 6, h/2, Color(30,30,30), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local text = vgui.Create("DTextEntry", win)
    text:SetPos(4, 52)
    text:SetSize(452, 280)
    text:SetMultiline(true)
    text:SetFont("XP_Text")
    text:SetText("Добро пожаловать в Блокнот Windows XP!\n\nЭто демонстрационное окно из мода для Garry's Mod.\nЗдесь можно печатать что угодно :)")
end

local function OpenInternetExplorer(parent)
    local win = CreateXPWindow(parent, "Новая страница — Internet Explorer", 640, 460)

    local bar = vgui.Create("DPanel", win)
    bar:SetPos(4, 30)
    bar:SetSize(632, 30)
    bar.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(236,236,236)) end

    local addr = vgui.Create("DTextEntry", bar)
    addr:SetPos(56, 4)
    addr:SetSize(500, 22)
    addr:SetText("http://www.msn.com")

    local go = vgui.Create("DButton", bar)
    go:SetPos(562, 4)
    go:SetSize(64, 22)
    go:SetText("Переход")

    local html = vgui.Create("DHTML", win)
    html:SetPos(4, 64)
    html:SetSize(632, win:GetTall() - 70)
    html:SetHTML([[
        <html><body style="margin:0;font-family:Tahoma,Verdana,sans-serif;background:#ffffff;">
        <div style="background:linear-gradient(#0a58c9,#3b8bff);padding:14px 20px;color:white;">
            <div style="font-size:22px;font-weight:bold;">MSN.com — Стартовая страница</div>
            <div style="font-size:12px;opacity:.85;">Ваш веб-браузер работает в режиме эмуляции Windows XP</div>
        </div>
        <div style="padding:20px;color:#222;">
            <p>Это демонстрационная веб-страница внутри виртуального Internet Explorer,
            встроенного в аддон "Ноутбук Windows XP" для Garry's Mod.</p>
            <p>Введите адрес выше и нажмите «Переход», чтобы открыть настоящую страницу — 
            DHTML-панель Garry's Mod поддерживает загрузку реальных сайтов.</p>
            <hr>
            <p style="color:#888;font-size:12px;">© 2000-е, ностальгия гарантирована.</p>
        </div>
        </body></html>
    ]])

    local function Navigate()
        local url = addr:GetText()
        if not string.find(url, "^https?://") then url = "http://" .. url end
        html:OpenURL(url)
    end
    go.DoClick = Navigate
    addr.OnEnter = Navigate
end

-- ----------------------------------------------------------------
-- Диалог выключения
-- ----------------------------------------------------------------

local function OpenShutdownDialog(parent)
    local win = vgui.Create("DPanel", parent)
    win:SetSize(360, 190)
    win:Center()
    win.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 40, 90, 245))
        surface.SetDrawColor(120, 160, 230, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Выключение компьютера", "XP_Title", w/2, 20, color_white, TEXT_ALIGN_CENTER)
    end

    local function btn(x, label, onClick)
        local b = vgui.Create("DButton", win)
        b:SetPos(x, 60)
        b:SetSize(84, 84)
        b:SetText("")
        b.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(60, 90, 150) or Color(40, 65, 120))
            draw.SimpleText(label, "XP_Small", w/2, h - 14, color_white, TEXT_ALIGN_CENTER)
        end
        b.DoClick = onClick
        return b
    end

    btn(20, "Ждущий\nрежим", function() win:Remove() end)
    btn(138, "Выключение", function()
        win:Remove()
        CloseLaptop()
    end)
    btn(256, "Отмена", function() win:Remove() end)
end

-- ----------------------------------------------------------------
-- Стартовое меню
-- ----------------------------------------------------------------

local function ToggleStartMenu(parent)
    if IsValid(StartMenuPanel) then
        StartMenuPanel:Remove()
        StartMenuPanel = nil
        return
    end

    local menu = vgui.Create("DPanel", parent)
    menu:SetSize(230, 300)
    menu:SetPos(4, ScrH() - 34 - 300)
    menu.Paint = function(self, w, h)
        draw.RoundedBoxEx(8, 0, 0, w, h, Color(245, 248, 255), true, true, false, false)
        DrawGradientRect(0, 0, 40, h, Color(20, 90, 200), Color(60, 140, 230))
        draw.SimpleText("ИГРОК", "XP_Title", 50, 14, Color(20,20,20))
    end

    local function item(y, label, paintIcon, onClick)
        local b = vgui.Create("DButton", menu)
        b:SetPos(6, y)
        b:SetSize(218, 34)
        b:SetText("")
        b.Paint = function(self, w, h)
            if self:IsHovered() then draw.RoundedBox(3, 0, 0, w, h, Color(190, 215, 250)) end
            if paintIcon then paintIcon(6, h/2 - 10, 20, 20) end
            draw.SimpleText(label, "XP_Text", 34, h/2, Color(20,20,20), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            onClick()
            if IsValid(StartMenuPanel) then StartMenuPanel:Remove() StartMenuPanel = nil end
        end
    end

    item(46,  "Мой компьютер",       nil, function() OpenMyComputer(parent) end)
    item(84,  "Блокнот",             nil, function() OpenNotepad(parent) end)
    item(122, "Internet Explorer",   nil, function() OpenInternetExplorer(parent) end)

    local sep = vgui.Create("DPanel", menu)
    sep:SetPos(6, 250)
    sep:SetSize(218, 1)
    sep.Paint = function(self, w, h) surface.SetDrawColor(200,200,200) surface.DrawRect(0,0,w,h) end

    item(258, "Завершение работы...", nil, function() OpenShutdownDialog(parent) end)

    StartMenuPanel = menu
end

-- ----------------------------------------------------------------
-- Рабочий стол
-- ----------------------------------------------------------------

local function BuildDesktop()
    if not IsValid(RootPanel) then return end

    local desktop = vgui.Create("DPanel", RootPanel)
    desktop:SetPos(0, 0)
    desktop:SetSize(ScrW(), ScrH())
    desktop.Paint = function(self, w, h)
        -- небо
        DrawGradientRect(0, 0, w, h - 34, Color(60, 130, 220), Color(150, 200, 250))
        -- солнце
        surface.SetDrawColor(255, 250, 210, 220)
        draw.NoTexture()
        surface.DrawPoly((function()
            local pts, n = {}, 24
            for i = 1, n do
                local a = math.rad(i / n * 360)
                table.insert(pts, {x = w*0.85 + math.cos(a)*40, y = h*0.18 + math.sin(a)*40})
            end
            return pts
        end)())
        -- холмы
        surface.SetDrawColor(70, 160, 60)
        surface.DrawPoly({
            {x = 0, y = h*0.62}, {x = w*0.35, y = h*0.45}, {x = w*0.7, y = h*0.6},
            {x = w, y = h*0.5}, {x = w, y = h - 34}, {x = 0, y = h - 34}
        })
        surface.SetDrawColor(50, 140, 45)
        surface.DrawPoly({
            {x = 0, y = h*0.72}, {x = w*0.3, y = h*0.6}, {x = w*0.65, y = h*0.75},
            {x = w, y = h*0.66}, {x = w, y = h - 34}, {x = 0, y = h - 34}
        })
    end

    CreateDesktopIcon(desktop, 24, 24, "Мой компьютер", PaintMyComputerIcon, function() OpenMyComputer(desktop) end)
    CreateDesktopIcon(desktop, 24, 110, "Корзина", PaintBinIcon, function() end)
    CreateDesktopIcon(desktop, 24, 196, "Internet Explorer", PaintIEIcon, function() OpenInternetExplorer(desktop) end)
    CreateDesktopIcon(desktop, 24, 282, "Блокнот", PaintNotepadIcon, function() OpenNotepad(desktop) end)

    -- панель задач
    local taskbar = vgui.Create("DPanel", RootPanel)
    taskbar:SetPos(0, ScrH() - 34)
    taskbar:SetSize(ScrW(), 34)
    taskbar.Paint = function(self, w, h)
        DrawGradientRect(0, 0, w, h, Color(30, 130, 20), Color(90, 190, 60))
        surface.SetDrawColor(20, 90, 15)
        surface.DrawRect(0, 0, w, 2)
    end

    local startBtn = vgui.Create("DButton", taskbar)
    startBtn:SetPos(4, 3)
    startBtn:SetSize(94, 28)
    startBtn:SetText("")
    startBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and Color(60, 190, 60) or Color(40, 165, 40))
        draw.SimpleText("Пуск", "XP_Start", 30, h/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    startBtn.DoClick = function() ToggleStartMenu(RootPanel) end

    local clock = vgui.Create("DLabel", taskbar)
    clock:SetPos(ScrW() - 90, 0)
    clock:SetSize(84, 34)
    clock:SetFont("XP_Clock")
    clock:SetTextColor(color_white)
    clock:SetContentAlignment(5)
    clock.Think = function(self) self:SetText(os.date("%H:%M:%S")) end

    -- подсказка о выходе
    local hint = vgui.Create("DLabel", RootPanel)
    hint:SetPos(10, 8)
    hint:SetSize(400, 20)
    hint:SetFont("XP_Small")
    hint:SetTextColor(Color(255,255,255,210))
    hint:SetText("ESC или крестик — выйти из ноутбука")

    local exitBtn = vgui.Create("DButton", RootPanel)
    exitBtn:SetPos(ScrW() - 40, 6)
    exitBtn:SetSize(30, 26)
    exitBtn:SetText("")
    exitBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(230,60,60,230) or Color(190,50,50,200))
        draw.SimpleText("✕", "XP_Text", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    exitBtn.DoClick = CloseLaptop
end

local function BuildBootScreen()
    if not IsValid(RootPanel) then return end
    local boot = vgui.Create("DPanel", RootPanel)
    boot:SetPos(0, 0)
    boot:SetSize(ScrW(), ScrH())
    local startedAt = CurTime()
    boot.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0))
        draw.SimpleText("Windows XP", "XP_Boot", w/2, h/2 - 40, color_white, TEXT_ALIGN_CENTER)

        local barW, barH = 220, 16
        local bx, by = w/2 - barW/2, h/2 + 30
        draw.RoundedBox(2, bx, by, barW, barH, Color(40,40,40))
        local t = (CurTime() - startedAt) % 1
        local blockW = 40
        local pos = t * (barW + blockW) - blockW
        surface.SetDrawColor(0, 140, 220)
        surface.DrawRect(bx + math.Clamp(pos, 0, barW - blockW), by + 2, blockW, barH - 4)
        surface.SetDrawColor(80,80,80)
        surface.DrawOutlinedRect(bx, by, barW, barH, 1)
    end
end

-- ----------------------------------------------------------------
-- Открытие ноутбука (сеть)
-- ----------------------------------------------------------------

net.Receive("laptop_winxp_open", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    if IsValid(ActiveLaptop) then return end

    ActiveLaptop = ent
    State        = "zoomin"
    StateTime    = CurTime()

    local ply = LocalPlayer()
    StartPos = ply:EyePos()
    StartAng = ply:EyeAngles()
    StartFov = ply:GetFOV()

    timer.Simple(LERP_TIME, function()
        if State ~= "zoomin" then return end
        State = "boot"
        StateTime = CurTime()

        RootPanel = vgui.Create("EditablePanel")
        RootPanel:SetPos(0, 0)
        RootPanel:SetSize(ScrW(), ScrH())
        RootPanel:MakePopup()
        RootPanel:SetKeyboardInputEnabled(true)
        RootPanel:SetMouseInputEnabled(true)
        RootPanel.OnKeyCodePressed = function(self, key)
            if key == KEY_ESCAPE then CloseLaptop() end
        end

        BuildBootScreen()

        timer.Simple(BOOT_TIME, function()
            if State ~= "boot" or not IsValid(RootPanel) then return end
            State = "desktop"
            RootPanel:Clear()
            BuildDesktop()
        end)
    end)
end)

net.Receive("laptop_winxp_close", function()
    -- сервер попросил закрыть (например, ноутбук удалили)
    if IsValid(RootPanel) then RootPanel:Remove() RootPanel = nil end
    StartMenuPanel = nil
    gui.EnableScreenClicker(false)
    if State ~= nil and State ~= "zoomout" then
        State = "zoomout"
        StateTime = CurTime()
    end
end)

-- ----------------------------------------------------------------
-- Камера
-- ----------------------------------------------------------------

hook.Add("CalcView", "laptop_winxp_calcview", function(ply, pos, angle, fov)
    if State == nil then return end
    if not IsValid(ActiveLaptop) and State ~= "zoomout" then State = nil return end

    local camPos, camAng = GetScreenCamera()

    if State == "zoomin" then
        local frac = EaseInOut(math.Clamp((CurTime() - StateTime) / LERP_TIME, 0, 1))
        local view = {}
        view.origin = LerpVector(frac, StartPos, camPos)
        view.angles = LerpAngle(frac, StartAng, camAng)
        view.fov    = Lerp(frac, StartFov, 42)
        view.drawviewer = true
        return view
    elseif State == "boot" or State == "desktop" then
        return { origin = camPos, angles = camAng, fov = 42, drawviewer = true }
    elseif State == "zoomout" then
        local frac = EaseInOut(math.Clamp((CurTime() - StateTime) / LERP_TIME, 0, 1))
        local view = {}
        view.origin = LerpVector(frac, camPos, StartPos)
        view.angles = LerpAngle(frac, camAng, StartAng)
        view.fov    = Lerp(frac, 42, StartFov)
        view.drawviewer = true
        if frac >= 1 then
            State = nil
            ActiveLaptop = nil
        end
        return view
    end
end)

-- Полная блокировка движения/атаки, пока игрок "сидит" за ноутбуком
hook.Add("CreateMove", "laptop_winxp_block_move", function(cmd)
    if State ~= nil then
        cmd:ClearMovement()
        cmd:ClearButtons()
    end
end)

-- Прячем HUD, пока открыт ноутбук
local HIDDEN_HUD = {
    CHudCrosshair = true, CHudWeaponSelection = true, CHudSecondaryAmmo = true,
    CHudAmmo = true, CHudHealth = true, CHudBattery = true, CHudDamageIndicator = true,
}
hook.Add("HUDShouldDraw", "laptop_winxp_hide_hud", function(name)
    if State ~= nil and HIDDEN_HUD[name] then return false end
end)
