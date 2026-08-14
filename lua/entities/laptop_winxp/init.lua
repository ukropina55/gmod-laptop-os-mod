AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("Laptop_ToggleUse")

function ENT:Initialize()
    self:SetModel("models/props_lab/monitor01a.mdl") -- Временная базовая модель монитора
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if not activator:IsPlayer() then return end

    -- Если игрок уже за ним сидит — закрываем операционку
    if activator:GetNWEntity("UsingLaptop") == self then
        activator:SetNWEntity("UsingLaptop", NULL)
        activator:Freeze(false)
        net.Start("Laptop_ToggleUse")
            net.WriteEntity(self)
            net.WriteBool(false)
        net.Send(activator)
    else
        -- Игрок включает операционку
        activator:SetNWEntity("UsingLaptop", self)
        activator:Freeze(true)
        net.Start("Laptop_ToggleUse")
            net.WriteEntity(self)
            net.WriteBool(true)
        net.Send(activator)
    end
end

-- Размораживаем игрока, если ноутбук удалили через инструмент Undo или Remover
function ENT:OnRemove()
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWEntity("UsingLaptop") == self then
            ply:SetNWEntity("UsingLaptop", NULL)
            ply:Freeze(false)
        end
    end
end
