if myHero.charName ~= "Ahri" then return end
local Ahri = {}
local version = 2
GetInternalWebResultAsync('CXAhri.version', function(v)
    if v and tonumber(v) > version then
        DownloadInternalFileAsync('CXAhri.lua', SCRIPT_PATH, function(success)
            if success then
                PrintChat("<font color=\"#E41B17\">[<b>¤ Cyrex ¤</b>]:</font>" .. "CXAhri updated to v" .. v .. ", please press F5 to reload.")
            end
        end)
    end
end)
require "FF15Menu"
require "utils"
local GeometryLib = require 'GeometryLib'
local DreamTS = require("DreamTS")
local dmgLib = require("FF15DamageLib")
local Orbwalker = require "FF15OL"

local dependencies =
{
    {"DreamPred", _G.PaidScript.DREAM_PRED, function() return _G.Prediction end},
    {"LegitOrb", _G.PaidScript.REBORN_ORB, function() return _G.LegitOrbwalker end}
}

function OnLoad()
    _G.LoadDependenciesAsync(dependencies, function(success)
        if success then
            Orbwalker:Setup()
            Ahri:__init()
        end
    end)
end

function Ahri:__init()
    self.q = {
        type = "linear",
        speed = 2500,
        range = 930,
        delay = 0.25,
        width = 200,
        LastObjectVector = nil,
        LastObjectVectorTime = 0,
        IsReturning = false,
        CatchPosition = nil,
        Target = nil,
        LastCastTime = 0,
        Object = nil,
        Source = myHero,
        castRate = "slow"
    }
    self.e = {
        type = "linear",
        speed = 1500,
        range = 935,
        delay = 0.25,
        width = 120,
        castRate = "slow",
        collision = {
            ["Wall"] = true,
            ["Hero"] = true,
            ["Minion"] = true
        }
    }
    self:Menu()
    self.RHaveBuff = false
    self.RLastCastTime = 0
    self.RFirstCastTime = 0
    Vector = GeometryLib.Vector
    self.TS =
        DreamTS(
        self.menu.dreamTs,
        {
            Damage = function(unit)
                return dmgLib:CalculateMagicDamage(myHero, unit, 100)
            end
        }
    )
    AddEvent(Events.OnTick, function() self:OnTick() end)
    AddEvent(Events.OnDraw, function() self:OnDraw() end)
    AddEvent(Events.OnProcessSpell, function(unit, spell) self:OnProcessSpell(unit, spell) end)
    AddEvent(Events.OnCreateObject, function(obj) self:OnCreateObject(obj) end)
    AddEvent(Events.OnDeleteObject, function(obj) self:OnDeleteObject(obj) end)
    AddEvent(Events.OnSpellbookCastSpell, function(iSpell, startPos, endPos, targetUnit) self:OnCastSpell(iSpell, startPos, endPos, targetUnit) end)
    PrintChat("<font color=\"#E41B17\">[<b>¤ Cyrex ¤</b>]:</font>" .. " <font color=\"#" .. "FFFFFF" .. "\">" .. "Ahri Loaded" .. "</font>")
    self.font = DrawHandler:CreateFont("Calibri", 12)
end

function Ahri:Menu()
    self.menu = Menu("cxahri", "Cyrex Ahri")
    self.menu:sub("dreamTs", "Target Selector")

    self.menu:sub("Key", "Key Settings")
        self.menu.Key:checkbox("e", "Start Combo With E", true, string.byte("K"))

    self.menu:sub("combo", "Combo Settings")
        self.menu.combo:label("xd", "Q Settings")
        self.menu.combo:checkbox("q", "Use Q", true)
        --self.menu.combo:checkbox("qc", "Catch Q", true)
        self.menu.combo:label("xd1", "W Settings")
        self.menu.combo:checkbox("w", "Use W", true)
        self.menu.combo:checkbox("wc", "Cast Only if Enemy is Charmed?", false)
        self.menu.combo:slider("wr", "Min. W Range To Cast", 300, 700, 600, 50)
        self.menu.combo:label("xd2", "E Settings")
        self.menu.combo:checkbox("e", "Use E", true)
        self.menu.combo:label("xd3", "R Settings")
        self.menu.combo:checkbox("r", "Use R [Mouse & Beta]", false)
        --self.menu.combo:checkbox("rc", "Use R to Cacth Q", false)

    self.menu:sub("harass", "Harass Settings")
        self.menu.harass:checkbox("q", "Use Q", true)
        self.menu.harass:checkbox("w", "Use W", true)
        self.menu.harass:checkbox("e", "Use E", true)
        self.menu.harass:slider("mana", "Min. Mana Percent: ", 0, 100, 10, 5)

    self.menu:sub("antigap", "Anti Gapclose")
        self.antiGapHeros = {}
        for _, enemy in ipairs(ObjectManager:GetEnemyHeroes()) do
            self.menu.antigap:checkbox(enemy.charName, enemy.charName, true)
            self.antiGapHeros[enemy.networkId] = true
        end

    self.menu:sub("draws", "Draw")
        self.menu.draws:checkbox("q", "Q", true)
        self.menu.draws:checkbox("w", "W", true)
        self.menu.draws:checkbox("e", "E", true)
        --self.menu.draws:checkbox("l", "Q Line", false)

    self.menu:sub("antigap", "Anti Gapclose")
    for _, enemy in ipairs(ObjectManager:GetEnemyHeroes()) do
        self.menu.antigap:checkbox(enemy.charName, enemy.charName, true)
    end
end

function Ahri:OnDraw()
    if self.menu.draws.q:get() and myHero.spellbook:CanUseSpell(0) == 0 and myHero.visibleOnScreen then
        DrawHandler:Circle3D(myHero.position, self.q.range, self:Hex(255,255,255,255))
    end
    if self.menu.draws.w:get() and myHero.spellbook:CanUseSpell(1) == 0 and myHero.visibleOnScreen then
        DrawHandler:Circle3D(myHero.position, self.menu.combo.wr:get(), self:Hex(255,255,255,255))
    end
    if self.menu.draws.e:get() and myHero.spellbook:CanUseSpell(2) == 0 and myHero.visibleOnScreen then
        DrawHandler:Circle3D(myHero.position, self.e.range, self:Hex(255,255,255,255))
    end
    --[[if self.menu.draws.l:get() and self.q.Object ~= nil and self.q.Object.isValid and self.q.Object.position then
                local Start = Vector(self.q.Object):toDX3()
                local End = Vector(myHero.position):toDX3()
                if GetDistanceSqr(Start, End) < math.pow(self.q.range * 1.8, 2) then
                    local P1 = Renderer:WorldToScreen(D3DXVECTOR3(myHero.x, myHero.y, myHero.z))
                    local P2 = Renderer:WorldToScreen(D3DXVECTOR3(self.q.Object.x, self.q.Object.y, self.q.Object.z))
                    DrawHandler:Line(P1, P2, self:Hex(255,254,50,47))
                end
                if self.q.CatchPosition ~= nil then
                    local P1 = Renderer:WorldToScreen(D3DXVECTOR3(self.q.CatchPosition.x, self.q.CatchPosition.y, self.q.CatchPosition.z))
                    local P2 = Renderer:WorldToScreen(D3DXVECTOR3(myHero.x, myHero.y, myHero.z))
                    DrawHandler:Line(P1, P2, self:Hex(255, 7, 141, 237))
                end
            end]]
end

function Ahri:VectorPointProjectionOnLineSegment(aZ, b0, b3)
local bw, bx, by, bz, bA, bB = b3.x, b3.z or b3.y, aZ.x, aZ.z or aZ.y, b0.x, b0.z or b0.y
local bC = ((bw - by) * (bA - by) + (bx - bz) * (bB - bz)) / ((bA - by) ^ 2 + (bB - bz) ^ 2)
local bD = {
    x = by + bC * (bA - by),
    y = bz + bC * (bB - bz)
}
local bE = bC < 0 and 0 or(bC > 1 and 1 or bC)
local bF = bE == bC
local bG = bF and bD or {
    x = by + bE * (bA - by), y = bz + bE * (bB - bz)
}
return bG, bD, bF end

local delayedActions, delayedActionsExecuter = {}, nil
function Ahri:DelayAction(func, delay, args) --delay in seconds
  if not delayedActionsExecuter then
    function delayedActionsExecuter()
      for t, funcs in pairs(delayedActions) do
        if t <= os.clock() then
          for i = 1, #funcs do
            local f = funcs[i]
            if f and f.func then
              f.func(unpack(f.args or {}))
            end
          end
          delayedActions[t] = nil
        end
      end
    end
    AddEvent(Events.OnTick, delayedActionsExecuter)
  end
  local t = os.clock() + (delay or 0)
  if delayedActions[t] then
    delayedActions[t][#delayedActions[t] + 1] = {func = func, args = args}
  else
    delayedActions[t] = {{func = func, args = args}}
  end
end

function Ahri:OnProcessSpell(unit, spell)
    if unit ~= nil and spell ~= nil and unit == myHero then
        local name = spell.spellData.name:lower()
        if name == "ahriorbofdeception" then
            self.q.Object = nil
            self.q.LastCastTime = os.clock()
            self.q.IsReturning = false
            self:DelayAction(function()
                self.q.Object = nil
            end, self.q.delay + 2 * GetDistance(myHero, Vector(unit.endPos):toDX3())/self.q.speed + 0.8 )
        elseif name == "ahritumble" then 
            if os.clock() - self.RLastCastTime > 15 then self.RFirstCastTime = os.clock() end
            self.RLastCastTime = os.clock()
        end
    end
end

function Ahri:OnCreateObject(obj)
    if obj and obj.name then
        if (obj.name:lower():find("missile") or obj.name:lower():find("return")) and obj.asMissile.spellCaster and obj.asMissile.spellCaster.NetworkId == myHero.NetworkId then
            if obj.asMissile.name == "AhriOrbMissile" then
                self.q.IsReturning = false
                self.q.Object = obj
            elseif obj.asMissile.name == "AhriOrbReturn" then
                self.q.Object = obj
                self.q.IsReturning = true
                self:DelayAction(function() self.q.Object = nil end, self.q.range/2600)
            end
        end
    end
end

function Ahri:OnDeleteObject(obj)
    if obj and obj.name then
        local name = tostring(obj.name):lower()
        if (obj.name:lower():find("missile") or obj.name:lower():find("return")) and obj.asMissile.spellCaster and obj.asMissile.spellCaster.NetworkId == myHero.NetworkId then
            if obj.asMissile.name == "AhriOrbMissile" then
            elseif obj.asMissile.name == "AhriOrbReturn" then
                self.q.Object = nil 
                self.q.IsReturning = false
                self.q.Target = nil
                self.q.LastObjectVector = nil
            end
        end
    end
end

function Ahri:OnCastSpell(iSpell, startPos, endPos, targetUnit)
    if iSpell == 0 then
        self.q.Object = nil
        self.q.LastCastTime = os.clock() + 5 * NetClient.ping/2000
        self.q.IsReturning = false
    elseif iSpell == 3 then 
        if os.clock() - self.RLastCastTime > 15 then self.RFirstCastTime = os.clock() + 5 * NetClient.ping/2000 end
        self.RLastCastTime = os.clock() + 5 * NetClient.ping/2000
    end
end

function Ahri:GetPercentHealth(obj)
  local obj = obj or myHero
  return (obj.health / obj.maxHealth) * 100
end

function Ahri:CastQ(pred)
    if pred.rates["slow"] then
        myHero.spellbook:CastSpell(SpellSlot.Q, pred.castPosition)
        pred:draw()
        return true
    end
end

function Ahri:CastE(pred)
    if pred.rates["slow"] then
        myHero.spellbook:CastSpell(SpellSlot.E, pred.castPosition)
        pred:draw()
        return true
    end
end

function Ahri:CastR()
    if myHero.spellbook:CanUseSpell(3) == 0 and self.menu.combo.r:get() then
        myHero.spellbook:CastSpell(3, pwHud.hudManager.virtualCursorPos)
    end
end

function Ahri:Collides(vec)
    return NavMesh:IsWall(D3DXVECTOR3(vec.x, vec.y, vec.z))
end

function Ahri:CastToVector(vector)
    if vector ~= nil then
        self.LastSentTime = os.clock()
        CastSpell(self.Slot, vector.x, vector.z)
    end
end

function Ahri:OnTick()
    if myHero.isDead then
        return
    end

    local ComboMode = Orbwalker:GetMode() == "Combo"
    local HarassMode = Orbwalker:GetMode() == "Harass"

    if myHero.spellbook:CanUseSpell(SpellSlot.E) == 0 then

        -- Hybrid mode -> less cast priority but peel close targets if needed
        local e_targets, e_preds =
            self.TS:GetTargets(self.e, myHero, nil, nil, self.TS.Modes["Hybrid [1.0]"])

        for i = 1, #e_targets do
            local unit = e_targets[i]
            local pred = e_preds[unit.networkId]
            if pred then
                if
                    pred.targetDashing and self.antiGapHeros[unit.networkId] and
                        self.menu.antigap[unit.charName]:get() and
                        self:CastE(pred)
                 then
                    return
                end
                if pred.isInterrupt and self:CastE(pred) then
                    return
                end
            end
        end

        if (ComboMode and self.menu.combo.e:get()) or (HarassMode and self.menu.harass.e:get()) then
            local target = e_targets[1]
            if target then
                local pred = e_preds[target.networkId]

                if pred and self:CastE(pred) then
                    return
                end
            end
        end

        if ComboMode and self.menu.Key.e:get() then
            return
        end
    end

    if myHero.spellbook:CanUseSpell(SpellSlot.Q) == 0 then
        local q_targets, q_preds =
            self.TS:GetTargets(self.q, myHero)

        if (ComboMode and self.menu.combo.q:get()) or (HarassMode and self.menu.harass.q:get()) then
            local target = q_targets[1]
            if target then
                local pred = q_preds[target.networkId]

                if pred and self:CastQ(pred) then
                    return
                end
            end
        end
    end

    if myHero.spellbook:CanUseSpell(SpellSlot.W) == 0 then
        local target = self:GetTargetNormal(self.menu.combo.wr:get())

        if target then
            if (ComboMode and self.menu.combo.w:get()) or (HarassMode and self.menu.harass.w:get()) then 
                if myHero.spellbook:CanUseSpell(1) == 0 and GetDistance(target) <= (self.menu.combo.wr:get()) then
                    if self.menu.combo.wc:get() and target.buffManager:HasBuffOfType(22) then 
                        myHero.spellbook:CastSpell(1, myHero.networkId)
                    elseif not self.menu.combo.wc:get() or self:GetPercentHealth(target) < 40 then
                        myHero.spellbook:CastSpell(1, myHero.networkId)
                    elseif not self.menu.combo.wc:get() and myHero.spellbook:CanUseSpell(0) ~= 0 and myHero.spellbook:CanUseSpell(2) ~= 0 then
                        myHero.spellbook:CastSpell(1, myHero.networkId)
                    end
                end
            end
        end
    end
end

function Ahri:Hex(a, r, g, b)
    return string.format("0x%.2X%.2X%.2X%.2X", a, r, g, b)
end

-- For targetted abilities (aka Ahri W)
function Ahri:GetTargetNormal(dist, all)
    local res = self.TS:update(function(unit) return _G.Prediction.IsValidTarget(unit, dist) end)
    if all then
        return res
    else
        if res and res[1] then
            return res[1]
        end
    end
end
