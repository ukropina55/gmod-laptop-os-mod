include("shared.lua")

surface.CreateFont("XP_Start", { font = "Tahoma", size = 16, weight = 700, extended = true })
surface.CreateFont("XP_Taskbar", { font = "Tahoma", size = 13, weight = 400, extended = true })
surface.CreateFont("XP_Clock", { font = "Tahoma", size = 13, weight = 700, extended = true })

local function CreateXPDesktop(ent)
    if IsValid(ent.XP_Desktop) then ent.XP_Desktop:Remove() end

    -- Главный рабочий стол (Родитель для всего)
    local desktop = vgui.Create("DPanel")
    desktop:SetSize(ScrW(), ScrH())
    desktop:MakePopup()
    ent.XP_Desktop = desktop

    -- Отлавливаем нажатие ESC или других клавиш, чтобы выйти без зависания игры
    desktop.OnKeyCodePressed = function(self, key)
        -- KEY_ESCAPE = 70 в Garry's Mod
        if key == KEY_ESCAPE then
            -- Отправляем серверу сигнал, что мы выходим из ноута
            net.Start("Laptop_ToggleUse")
                net.WriteEntity(ent)
                net.WriteBool(false)
            net.SendToServer()
            ent:CloseLaptop()
        end
    end

    -- Обои (DHTML) — теперь они лежат в самом низу и не перекрывают окна
    local bg = vgui.Create("DHTML", desktop)
    bg:SetSize(desktop:GetWide(), desktop:GetTall() - 30)
    bg:SetHTML([[
        <style>
            body { 
                margin: 0; 
                background: url('https://imgur.com') no-repeat center center fixed; 
                background-size: cover; 
                overflow: hidden; 
            }
        </style>
    ]])
    bg:SetMouseInputEnabled(false) -- Клики проходят сквозь фон на иконки рабочего стола

    -- Панель задач (Taskbar)
    local taskbar = vgui.Create("DPanel", desktop)
    taskbar:SetSize(desktop:GetWide(), 30)
    taskbar:SetPos(0, desktop:GetTall() - 30)
    taskbar.Paint = function(self, w, h)
        surface.SetDrawColor(36, 95, 212) -- Классический синий цвет панели XP
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(50, 130, 245)
        surface.DrawRect(0, 0, w, 2) -- Верхняя светлая полоса
    end

    -- Кнопка ПУСК (Start)
    local startBtn = vgui.Create("DButton", taskbar)
    startBtn:SetSize(100, 30)
    startBtn:SetPos(0, 0)
    startBtn:SetText("")
    startBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            surface.SetDrawColor(60, 180, 60)
        else
            surface.SetDrawColor(45, 150, 45) -- Зеленая кнопка Пуск
        end
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("пуск", "XP_Start", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    startBtn.DoClick = function()
        ent:ToggleStartMenu()
    end

    -- Трей с часами
    local tray = vgui.Create("DPanel", taskbar)
    tray:SetSize(80, 30)
    tray:SetPos(taskbar:GetWide() - 80, 0)
    tray.Paint = function(self, w, h)
        surface.SetDrawColor(16, 115, 215) -- Синий градиент трея
        surface.DrawRect(0, 0, w, h)
    end

    local clock = vgui.Create("DLabel", tray)
    clock:SetSize(80, 30)
    clock:SetFont("XP_Clock")
    clock:SetTextColor(Color(255, 255, 255))
    -- ИСПРАВЛЕНО: Выравнивание текста по центру без SetAlignment
    clock:SetText(os.date("%H:%M"))
    clock.Think = function(self)
        self:SetText(os.date("%H:%M"))
    end
    clock.Paint = function(self, w, h)
        draw.SimpleText(self:GetText(), "XP_Clock", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    clock:SetText("") -- Текст рисуем вручную через Paint для идеального выравнивания

    -- Контейнер для запущенных программ на панели задач
    ent.XP_TaskbarApps = vgui.Create("DPanel", taskbar)
    ent.XP_TaskbarApps:SetPos(110, 0)
    ent.XP_TaskbarApps:SetSize(taskbar:GetWide() - 200, 30)
    ent.XP_TaskbarApps.Paint = nil

    -- Создаем базовые иконки на рабочем столе
    ent:CreateDesktopIcon("Мой компьютер", "https://imgur.com", 20, 20, function()
        ent:CreateXPWindow("Мой компьютер", 500, 400, function(body)
            local lbl = vgui.Create("DLabel", body)
            lbl:SetText("Система: Garry's Mod OS\nПроцессор: Lua Engine\nПамять: Хватает\n\nНажмите ESC для выхода из ноутбука.")
            lbl:Dock(FILL)
            lbl:SetDark(true)
        end)
    end)

    ent:CreateDesktopIcon("Internet Explorer", "https://imgur.com", 20, 110, function()
        ent:CreateXPWindow("Internet Explorer", 800, 600, function(body)
            local browser = vgui.Create("DHTML", body)
            browser:Dock(FILL)
            browser:OpenURL("https://google.com")
        end)
    end)
end

-- Функция создания красивого XP Окна
function ENT:CreateXPWindow(title, w, h, populateFunc)
    if not IsValid(self.XP_Desktop) then return end

    local frame = vgui.Create("DFrame", self.XP_Desktop)
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:SetDeleteOnClose(true)
    frame:MakePopup()

    frame.Paint = function(self, w, h)
        surface.SetDrawColor(240, 240, 230)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(36, 95, 212)
        surface.DrawRect(0, 0, w, 25)
        draw.SimpleText(title, "XP_Taskbar", 10, 5, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        surface.SetDrawColor(36, 95, 212)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(21, 21)
    closeBtn:SetPos(w - 23, 2)
    closeBtn:SetText("X")
    closeBtn:SetFont("XP_Clock")
    closeBtn:SetTextColor(Color(255, 255, 255))
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then surface.SetDrawColor(230, 80, 50) else surface.SetDrawColor(215, 60, 35) end
        surface.DrawRect(0, 0, w, h)
    end
    closeBtn.DoClick = function()
        frame:Close()
        self:RefreshTaskbar()
    end

    local body = vgui.Create("DPanel", frame)
    body:SetPos(4, 27)
    body:SetSize(w - 8, h - 31)
    body.Paint = nil

    if populateFunc then populateFunc(body) end

    self:RefreshTaskbar()
    return frame
end

-- Функция создания иконки на рабочем столе
function ENT:CreateDesktopIcon(name, iconUrl, x, y, onClickFunc)
    if not IsValid(self.XP_Desktop) then return end

    local icon = vgui.Create("DButton", self.XP_Desktop)
    icon:SetPos(x, y)
    icon:SetSize(80, 80)
    icon:SetText("")
    icon.Paint = function(self, w, h)
        if self:IsHovered() then
            surface.SetDrawColor(255, 255, 255, 30)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(50, 150, 255, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        draw.DrawText(name, "XP_Taskbar", w/2, 60, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    end

    local img = vgui.Create("DHTML", icon)
    img:SetSize(48, 48)
    img:SetPos(16, 5)
    img:SetHTML([[
        <style>body{margin:0; overflow:hidden;}</style>
        <img src="]] .. iconUrl .. [[" width="48" height="48">
    ]])
    img:SetMouseInputEnabled(false)

    icon.DoClick = onClickFunc
end

function ENT:RefreshTaskbar()
    if not IsValid(self.XP_TaskbarApps) then return end
    self.XP_TaskbarApps:Clear()

    local windows = self.XP_Desktop:GetChildren()
    local count = 0

    for _, v in pairs(windows) do
        if v:GetName() == "DFrame" and IsValid(v) then
            local appBtn = vgui.Create("DButton", self.XP_TaskbarApps)
            appBtn:SetSize(120, 26)
            appBtn:SetPos(count * 125, 2)
            appBtn:SetText("")
            appBtn.Paint = function(self, w, h)
                surface.SetDrawColor(60, 120, 230)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(255, 255, 255, 50)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            appBtn.DoClick = function()
                v:MakePopup()
            end
            count = count + 1
        end
    end
end

-- Меню ПУСК
function ENT:ToggleStartMenu()
    if IsValid(self.XP_StartMenu) then
        self.XP_StartMenu:Remove()
        return
    end

    local sm = vgui.Create("DPanel", self.XP_Desktop)
    sm:SetSize(250, 350)
    sm:SetPos(0, self.XP_Desktop:GetTall() - 380)
    sm.Paint = function(self, w, h)
        surface.SetDrawColor(40, 100, 220)
        surface.DrawRect(0, 0, w, 40)
        surface.SetDrawColor(240, 240, 230)
        surface.DrawRect(0, 40, w, h - 40)
    end
    self.XP_StartMenu = sm
end

function ENT:Initialize()
    self.ZoomProgress = 0
    self.IsUsing = false
end

function ENT:OnPlayerUse(ply)
    if ply == LocalPlayer() then
        self.IsUsing = true
        CreateXPDesktop(self)
    end
end

function ENT:CloseLaptop()
    self.IsUsing = false
    if IsValid(self.XP_Desktop) then self.XP_Desktop:Remove() end
    gui.EnableScreenClicker(false)
end

net.Receive("Laptop_ToggleUse", function()
    local ent = net.ReadEntity()
    local state = net.ReadBool()
    if IsValid(ent) then
        if state then
            ent:OnPlayerUse(LocalPlayer())
            gui.EnableScreenClicker(true)
        else
            ent:CloseLaptop()
        end
    end
end)

-- ИСПРАВЛЕНО: Рендеринг 3D экрана теперь подогнан под модель лабораторного монитора HL2
function ENT:Draw()
    self:DrawModel()
    
    -- Корректируем позицию и угол матрицы 3D2D, чтобы она не улетала сквозь модель
    local Pos = self:GetPos() + self:GetUp() * 15.6 + self:GetForward() * 7.4 + self:GetRight() * -9.1
    local Ang = self:GetAngles()
    Ang:RotateAroundAxis(Ang:Up(), 90)
    Ang:RotateAroundAxis(Ang:Forward(), 74.5)

    cam.Start3D2D(Pos, Ang, 0.036)
        surface.SetDrawColor(0, 78, 152) -- Классический экран загрузки XP
        surface.DrawRect(0, 0, 505, 395)
    cam.End3D2D()
end

function ENT:OnRemove()
    if IsValid(self.XP_Desktop) then self.XP_Desktop:Remove() end
end

-- Плавная камера
hook.Add("CalcView", "Laptop_CameraZoom", function(ply, pos, angles, fov)
    local lapt = ply:GetNWEntity("UsingLaptop")
