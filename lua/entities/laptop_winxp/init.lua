AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("laptop_winxp_open")
util.AddNetworkString("laptop_winxp_close")

function ENT:Initialize()
    self:SetModel(self.LaptopModel)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

-- Игрок нажал E на ноутбуке
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- Повторное нажатие E на том же ноутбуке — закрыть
    if activator.InLaptop == self then
        self:CloseFor(activator)
        return
    end

    -- Игрок уже сидит за другим ноутбуком
    if IsValid(activator.InLaptop) then return end

    activator.InLaptop         = self
    activator.InLaptopOldMove  = activator:GetMoveType()
    activator:SetMoveType(MOVETYPE_NONE)

    net.Start("laptop_winxp_open")
        net.WriteEntity(self)
    net.Send(activator)
end

-- Закрыть ноутбук для конкретного игрока (используется и с клиента, и при очистке)
function ENT:CloseFor(ply)
    if not IsValid(ply) then return end
    if ply.InLaptop == self then
        ply.InLaptop = nil
        if IsValid(ply) then
            ply:SetMoveType(ply.InLaptopOldMove or MOVETYPE_WALK)
        end
    end
end

net.Receive("laptop_winxp_close", function(len, ply)
    local ent = ply.InLaptop
    if IsValid(ent) then
        ent:CloseFor(ply)
    end
end)

-- Если ноутбук удалили, пока игрок им пользовался — вернуть управление
function ENT:OnRemove()
    for _, ply in ipairs(player.GetAll()) do
        if ply.InLaptop == self then
            self:CloseFor(ply)
            if IsValid(ply) then
                net.Start("laptop_winxp_close")
                net.Send(ply)
            end
        end
    end
end

-- На случай дисконнекта игрока прямо во время использования
hook.Add("PlayerDisconnected", "laptop_winxp_cleanup", function(ply)
    if IsValid(ply.InLaptop) then
        ply.InLaptop:CloseFor(ply)
    end
end)
