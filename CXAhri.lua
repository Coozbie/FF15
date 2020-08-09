if myHero.charName ~= "Ahri" then return end
local Ahri = {}
local version = 1.5
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
        castRate = "slow"
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
            ValidTarget = function(unit)
                return _G.Prediction.IsValidTarget(unit, 960)
            end,
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

function Ahri:CastQ(target)
    if myHero.spellbook:CanUseSpell(0) == 0 then
        local pred = _G.Prediction.GetPrediction(target, self.q, myHero)
        if pred and pred.castPosition and GetDistanceSqr(pred.castPosition) <= (self.q.range * self.q.range) and not pred:windWallCollision() then
            myHero.spellbook:CastSpell(0, pred.castPosition)
            pred:draw()
        end
    end
end

function Ahri:CastE(target)
    if myHero.spellbook:CanUseSpell(2) == 0 then
        local pred = _G.Prediction.GetPrediction(target, self.e, myHero)
        if pred and pred.castPosition and GetDistanceSqr(pred.castPosition) < (self.e.range * self.e.range) and not pred:windWallCollision() and not pred:minionCollision() then
            myHero.spellbook:CastSpell(2, pred.castPosition)
        end
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

--[[function Ahri:CatchQ()
    self.q.CatchPosition = nil
    Orbwalker:BlockAttack(false)
    Orbwalker:BlockMove(false)
    local target = self:GetTarget(880)
    if self.q.Object ~= nil and self.q.Object.isValid and self.q.Object.position and ValidTarget(target) and self.q.IsReturning and GetDistanceSqr(myHero, target) < GetDistanceSqr(myHero, self.q.Object) then
        local Position = _G.Prediction.GetUnitPosition(target, 0)
        if Position and GetDistanceSqr(myHero, Position) < GetDistanceSqr(myHero, self.q.Object) then
            local TimeLeft = GetDistance(self.q.Object, target)/self.q.speed
            local Extended = Vector(self.q.Object):toDX3() + Vector((Vector(Position) - Vector(self.q.Object)):toDX3()):normalized() * 1500
            local ClosestToTargetLine, pointLine, isOnSegment1 = self:VectorPointProjectionOnLineSegment(Extended, self.q.Object, myHero)
            local ClosestToHeroLine, pointLine, isOnSegment2 = self:VectorPointProjectionOnLineSegment(myHero, self.q.Object, Position)
            ClosestToTargetLine = Vector(ClosestToTargetLine.x, self.q.Object.y, ClosestToTargetLine.y):toDX3()
            ClosestToHeroLine = Vector(ClosestToHeroLine.x, self.q.Object.y, ClosestToHeroLine.y):toDX3()
            if isOnSegment1 and isOnSegment2 and GetDistanceSqr(ClosestToTargetLine, self.q.Object) > GetDistanceSqr(Position, self.q.Object) then
                if GetDistanceSqr(myHero, ClosestToTargetLine) < math.pow(myHero.characterIntermediate.movementSpeed * TimeLeft, 2) then
                    self.q.CatchPosition = ClosestToTargetLine
                    if self.menu.combo.qc:get() and GetDistanceSqr(ClosestToHeroLine, Position) > math.pow(self.q.width, 2) then
                        Orbwalker:BlockAttack(true)
                        Orbwalker:BlockMove(true)
                        if Orbwalker:CanMove() then
                            local x = self.q.CatchPosition.x
                            local z = self.q.CatchPosition.z
                            local y = myHero.y
                            myHero:IssueOrder(GameObjectOrder.MoveTo, D3DXVECTOR3(x,y,z))
                        end
                    end
                elseif GetDistanceSqr(myHero, ClosestToTargetLine) < math.pow(450 + myHero.characterIntermediate.movementSpeed * TimeLeft, 2) then
                    self.q.CatchPosition = ClosestToTargetLine
                    if Orbwalker:GetMode() == "Combo" and self.menu.combo.rc:get() then
                        if GetDistanceSqr(ClosestToHeroLine, Position) > math.pow(self.q.width, 2) then
                            local rPos = myHero + Vector((Vector(self.q.CatchPosition) - Vector(myHero)):toDX3()):normalized() * GetDistance(myHero, self.q.CatchPosition) * 1.2
                            if not self:Collides(rPos) then
                                local x = rPos.x
                                local z = rPos.z
                                local y = myHero.y
                                myHero.spellbook:CastSpell(3, D3DXVECTOR3(x,y,z))
                            end
                        end
                    end
                end
            end
        end
    end
end]]

function Ahri:OnTick()
    local target = self:GetTarget(960)
    if Orbwalker:GetMode() == "Combo" then
        if target and ValidTarget(target) then
            if self.menu.combo.e:get() then                
                self:CastE(target)
            end
            if self.menu.Key.e:get() and myHero.spellbook:CanUseSpell(2) == 0 then return end 
            if self.menu.combo.q:get() then         
                self:CastQ(target)
            end 
            if self.menu.combo.w:get() then 
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
            if self.menu.combo.r:get() and GetDistance(target) <= 700 then    
                self:DelayAction(function() self:CastR(target) end, 1)
            end 
        end
    end
    if Orbwalker:GetMode() == "Harass" then
        if target and ValidTarget(target) then
            if self.menu.harass.e:get() then                
                self:CastE(target)
            end
            if self.menu.harass.q:get() then         
                self:CastQ(target)
            end 
            if self.menu.harass.w:get() then 
                if myHero.spellbook:CanUseSpell(1) == 0 and GetDistanceSqr(target) <= (self.menu.combo.wr:get() * self.menu.combo.wr:get()) then
                    myHero.spellbook:CastSpell(1, myHero.networkId)
                end
            end         
        end
    end
    --[[if self.q.Object ~= nil and self.q.Object.isValid and self.q.Object.position then
                self.q.range = math.huge
                self.q.Source = self.q.Object
                self.q.delay = 0
                if os.clock() - self.q.LastObjectVectorTime > 0 then
                    if self.q.LastObjectVector ~= nil then
                        self.q.Speed = GetDistance(self.q.Object, self.q.LastObjectVector)/(os.clock() - self.q.LastObjectVectorTime)
                    end
                    self.q.LastObjectVector = Vector(self.q.Object):toDX3()
                    self.q.LastObjectVectorTime = os.clock()
                end
            else
                self.q.range = 870
                self.q.Source = myHero
                self.q.delay = 0.25
                self.q.speed = 1700
            end
            self:CatchQ()]]
    for _, target in ipairs(self:GetTarget(self.e.range, true)) do
        if self.menu.antigap[target.charName] and self.menu.antigap[target.charName]:get() then
            local _, canHit = _G.Prediction.IsDashing(target, self.e, myHero)
            if canHit then
                self:CastE(target)
            end
        end
    end
end

function Ahri:Hex(a, r, g, b)
    return string.format("0x%.2X%.2X%.2X%.2X", a, r, g, b)
end

function Ahri:GetTarget(dist, all)
    self.TS.ValidTarget = function(unit)
        return _G.Prediction.IsValidTarget(unit, dist)
    end
    local res = self.TS:update()
    if all then
        return res
    else
        if res and res[1] then
            return res[1]
        end
    end
end

if myHero.charName == "Ahri" then
    Ahri:__init()
end
