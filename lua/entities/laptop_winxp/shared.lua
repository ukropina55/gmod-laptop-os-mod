AddCSLuaFile()

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Ноутбук (Windows XP)"
ENT.Author          = "YourName"
ENT.Contact         = ""
ENT.Purpose         = "Интерактивный ноутбук: E открывает 'экран' с ОС в стиле Windows XP"
ENT.Instructions    = "Нажмите E рядом с ноутбуком, чтобы включить его. ESC или кнопка (X) — выключить."
ENT.Category        = "Интерактивные пропы"
ENT.Spawnable       = true
ENT.AdminSpawnable  = true

-- ==========================================================
--  НАСТРОЙКИ МОДЕЛИ
-- ==========================================================
-- Модель по умолчанию — стандартный HL2 монитор (гарантированно есть у всех).
-- Замените на модель настоящего ноутбука, если она есть у вас/на сервере,
-- например модель с воркшопа (поиск "laptop model" в Steam Workshop) или
-- "models/props/cs_office/computer.mdl" (требует контента CS:S).
ENT.LaptopModel = "models/props_lab/monitor01a.mdl"

-- Локальное смещение точки "экрана" относительно центра модели.
-- Подберите под свою модель, если замените её на другую.
ENT.ScreenOffset        = Vector(0, 0, 9)
-- Насколько далеко перед экраном должна "зависнуть" камера.
ENT.ScreenForwardOffset = 14
