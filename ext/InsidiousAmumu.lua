if myHero.charName ~= "Amumu" then return end

local path = SCRIPT_PATH.."ExtLib.lua"

if FileExist(path) then
	_G.Enable_Ext_Lib = true
	loadfile(path)()
else
	print("ExtLib Not Found. Please update it")
end

local Ts = TargetSelector
local Pred = Prediction
local ENEMY, JUNGLE, ALLY = 1,2,3
local Q = {Range = 1100, Delay = .15, Width = 130, Speed = 2000, Type="Line"}
local W = {Radius = 300}
local E = {Radius = 350}
local R = {Radius = 550}

function CanCast(spell)
	return Game.CanUseSpell(spell) == READY
end

function ValidMinion(m, dist)
	return m and m.team ~= myHero.team and m.distance < dist and not m.dead and m.isTargetable and m.visible
end

function GetValidMinions(dist)
	if dist == nil then dist = 1200 end
	local validcreeps = {}
	local minions = Game.MinionCount()
	if minions == 0 then return {} end

	for i = 1, minions do
		local minion = Game.Minion(i)
		if ValidMinion(minion, dist) then
			table.insert(validcreeps, minion)
		end
	end
	
	if validcreep ~= nil then return validcreeps end

	local minions = Game.CampCount()
	if minions == 0 then return {} end

	for i = 1, minions do
		local camp = Game.Camp(i)
		--for i, monster in pairs(camp) do
			if ValidMinion(camp, dist) then
				print(Vector(Vector(myHero.pos) - Vector(camp.pos)):Len())
				if Vector(Vector(myHero.pos) - Vector(camp.pos)):Len() < dist then
					table.insert(validcreeps, camp)
				end
			end
		--end
	end
	return validcreeps
end

function CountEnemiesInRange(vector, distance, objlist)
	local Enemies = {}
	local count = 0
	if objlist == nil then
		for i =1, Game.HeroCount() do
			local hero = Game.Hero(i)
			if not hero.isAlly then
				table.insert(Enemies, hero)
			end
		end
		objlist = Enemies
	end

	for i, enemy in pairs(objlist) do
		if ValidTarget(enemy) then
			if vector:DistanceTo(Vector(enemy.pos)) <= distance then
				count = count + 1
			end
		end
	end

	return count
end

function GetDistanceSqr(p1, p2)
    p2 = p2 or myHero.pos
    return (p1.x - p2.x) ^ 2 + ((p1.z or p1.y) - (p2.z or p2.y)) ^ 2
end
function VectorPointProjectionOnLineSegment(v1,v2,v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
	return pointSegment, pointLine, isOnSegment
end
function CountObjectsOnLineSegment(StartPos, EndPos, width, objects)
	local n = 0
    for i, object in pairs(objects) do
    	if ValidTarget(object) then
	        local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, object.pos)
	        if isOnSegment and GetDistanceSqr(pointSegment, object.pos) < width * width then
	            n = n + 1
	        end
	    end
    end

    return n
end


class "Amumu"

function Amumu:__init()
	Ts:PresetMode("LESS_CAST")
	self.Allies = {}
	self.Enemies = {}
	for i =1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero.isAlly then
			table.insert(self.Allies, hero)
		else
			table.insert(self.Enemies, hero)
		end
	end
	self:LoadMenu()
	OnActiveMode(function(...) self:OnActiveMode(...) end)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Amumu:LoadMenu()
	self.Menu = MenuElement({type= MENU, id="ScriptAmumu", name="Insidious Amumu"})

	self.Menu:MenuElement({type = MENU,id = "Combo",name = "Combo Settings"})
	self.Menu.Combo:MenuElement({id = "UseQ",name = "Use Q",value = true})
	self.Menu.Combo:MenuElement({id = "UseW",name = "Use W",value = true})
	self.Menu.Combo:MenuElement({id = "UseE",name = "Use E",value = true})
	self.Menu.Combo:MenuElement({id = "AutoE",name = "Use E automatically",value = true})
	self.Menu.Combo:MenuElement({id = "MinHitE",name = "E to hit x number of enemies",value = 3,min = 1,max = 5, step = 1})
	self.Menu.Combo:MenuElement({id = "UseR",name = "Use R",value = true})
	self.Menu.Combo:MenuElement({id = "AutoR",name = "Use R automatically",value = true})
	self.Menu.Combo:MenuElement({id = "MinHitR",name = "R to hit x number of enemies",value = 3,min = 1,max = 5, step = 1})
	
	self.Menu:MenuElement({type = MENU,id = "Harass",name = "Harass Settings"})
	self.Menu.Harass:MenuElement({id = "UseQ",name = "Use Q",value = true})
	self.Menu.Harass:MenuElement({id = "UseW",name = "Use W",value = false})
	self.Menu.Harass:MenuElement({id = "MinMana",name = "Don't use spells if mana% goes below",value = 70,min = 0,max = 100, step = 1})
	
	self.Menu:MenuElement({type = MENU,id = "LaneClear",name = "LaneClear Settings"})
	self.Menu.LaneClear:MenuElement({id = "MinMana",name = "Don't use spells if mana% goes below",value = 30,min = 0,max = 100, step = 1})
	self.Menu.LaneClear:MenuElement({id = "Enable",name = "Use spells to clear ",value = true})
	self.Menu.LaneClear:MenuElement({id = "UseW",name = "Use W",value = true})
	self.Menu.LaneClear:MenuElement({id = "MinHitW",name = "W to hit x number of lane minions",value = 4,min = 1,max = 7, step = 1})
	self.Menu.LaneClear:MenuElement({id = "UseE",name = "Use E",value = false})
	self.Menu.LaneClear:MenuElement({id = "MinHitE",name = "E to hit x number of lane minions",value = 4,min = 1,max = 7, step = 1})
	
	self.Menu:MenuElement({type = MENU,id = "JngClear",name = "JungleClear Settings"})
	self.Menu.JngClear:MenuElement({id = "Enable",name = "Use spells to clear ",value = true})
	self.Menu.JngClear:MenuElement({id = "UseQ",name = "Use Q",value = true})
	self.Menu.JngClear:MenuElement({id = "UseW",name = "Use W",value = true})
	self.Menu.JngClear:MenuElement({id = "UseE",name = "Use E",value = true})

	self.Menu:MenuElement({type = MENU,id = "Drawing",name = "Drawing Settings"})
	self.Menu.Drawing:MenuElement({id = "DrawQ",name = "Draw Q Range",value = true})
	self.Menu.Drawing:MenuElement({id = "DrawR",name = "Draw R Range",value = false})

	self.Menu:MenuElement({id = "SaveMana",name = "Turn off W to save mana if it isn't dealing damage",value = true})
end

function Amumu:GetTarget(range)
	return Ts:GetTarget(range)
end

function Amumu:GetDamage(spell, unit)
	return getdmg(spell, unit)
end

function Amumu:CastQ(target, minions)
	local CastPosition, Hitchance = Pred:GetPrediction(target, Q)
	if Hitchance == "High" then
		local startP = Vector(myHero.pos)
		local endP = Vector(Vector(CastPosition) - startP):Normalized() * Q.Range
		local width = Q.Width
		local objects = minions
		local collisions = CountObjectsOnLineSegment(startP, endP, width, objects)


		if collisions == 0 then
			SpellCast:Add("Q", CastPosition)
		end
	end
end

function Amumu:CastW(target)
	if myHero:GetSpellData(_W).toggleState == 1 and ValidTarget(target, W.Radius) then
		Control.CastSpell(HK_W)
	end
end

function Amumu:CastE(target)
	if ValidTarget(target, E.Radius) then
		Control.CastSpell(HK_E)
	end
end

function Amumu:CheckE()
	if not CanCast(_E) then return end
	if not self.Menu.Combo.UseE:Value() then return end
	if not self.Menu.Combo.AutoE:Value() then return end

	for _, enemy in pairs(self.Enemies) do
		if CountEnemiesInRange(Vector(myHero.pos), E.Radius) >= self.Menu.Combo.MinHitE:Value() then
			Control.CastSpell(HK_E)
		end
	end
end

function Amumu:ProtectMana()
	if not self.Menu.SaveMana:Value() then return end

	local validcreeps = GetValidMinions()

	local wuseful = false

	if myHero:GetSpellData(_W).toggleState == 2 then
		for i, minion in pairs(validcreeps) do
			if ValidTarget(minion, W.Radius) then
				wuseful = true
			end
		end
	end

	if wuseful == false and myHero:GetSpellData(_W).toggleState == 2 then
		if CountEnemiesInRange(Vector(myHero.pos), W.Radius) == 0 then
			Control.CastSpell(HK_W)
		end
	end
end

function Amumu:CheckUlt()
	if not CanCast(_R) then return end
	if not self.Menu.Combo.AutoR:Value() then return end

	for _, enemy in pairs(self.Enemies) do
		if CountEnemiesInRange(Vector(myHero.pos), R.Radius) >= self.Menu.Combo.MinHitR:Value() then
			Control.CastSpell(HK_R)
		end
	end
end

function Amumu:OnActiveMode(OW, Minions)
	if OW.Mode == "Combo" then
		self:Combo(OW,Minions)
		OW.enableAttack = true
	elseif 	OW.Mode == "LaneClear" then	
		OW.enableAttack = true
		self:Clear(OW,Minions)
	elseif OW.Mode == "Harass" then		
		OW.enableAttack = true
		self:Harass(OW,Minions)
	end
	OW.enableAttack = true
end

function Amumu:Combo(OW, Minions)
	local useq = self.Menu.Combo.UseQ:Value()
	local usew = self.Menu.Combo.UseW:Value()
	local usee = self.Menu.Combo.UseE:Value()

	local target = self:GetTarget(Q.Range)

	if ValidTarget(target, Q.Range) and useq and CanCast(_Q) then
		self:CastQ(target, Minions)
	end
	if ValidTarget(target, W.Radius) and usew and CanCast(_W) then
		self:CastW(target)
	end
	if ValidTarget(target, E.Radius) and usee and CanCast(_E) then
		self:CastE(target)
	end
end

function Amumu:Harass(OW, Minions)

	if myHero.mana < myHero.maxMana/100 * self.Menu.Harass.MinMana:Value()  then return end

	local useq = self.Menu.Harass.UseQ:Value()
	local usew = self.Menu.Harass.UseW:Value()
	local usee = self.Menu.Combo.UseE:Value()

	local target = self:GetTarget(Q.Range)

	if ValidTarget(target, Q.Range) and useq and CanCast(_Q) then
		self:CastQ(target, Minions)
	end
	if ValidTarget(target, W.Radius) and usew and CanCast(_W) then
		self:CastW(target)
	end
	if ValidTarget(target, E.Radius) and usee and CanCast(_E) then
		self:CastE(target)
	end
end

function Amumu:Clear(OW, Minions)
	if Minions == nil then return end

	if myHero.mana > myHero.maxMana/100 * self.Menu.LaneClear.MinMana:Value()  then
	
		if self.Menu.LaneClear.Enable:Value() then
			for _, minion in pairs(Minions[ENEMY]) do
				if self.Menu.LaneClear.UseE:Value() then
					local numhit = self.Menu.LaneClear.MinHitE:Value() 
					local hitnumber = CountEnemiesInRange(Vector(myHero.pos), E.Radius, Minions[ENEMY])
					if hitnumber > numhit and CanCast(_E) then
						Control.CastSpell(HK_E)
					end
				end
				if self.Menu.LaneClear.UseW:Value() then
					local numhit = self.Menu.LaneClear.MinHitW:Value() 
					local hitnumber = CountEnemiesInRange(Vector(myHero.pos), W.Radius, Minions[ENEMY])
					if hitnumber > numhit and CanCast(_W) and myHero:GetSpellData(_W).toggleState == 1 then
						Control.CastSpell(HK_W)
					end
				end
			end
		end
	end
	for _, minion in pairs(Minions[JUNGLE]) do
		if ValidTarget(minion, 1100) then
			if not self.Menu.JngClear.Enable:Value() then return end
			if self.Menu.JngClear.UseQ:Value() and ValidTarget(minion, Q.Range) and CanCast(_Q) then
				Control.CastSpell(HK_Q, minion)
			end
			if self.Menu.JngClear.UseW:Value() and ValidTarget(minion, W.Radius) and CanCast(_W) and myHero:GetSpellData(_W).toggleState == 1 then
				Control.CastSpell(HK_W, minion)
			end
			if self.Menu.JngClear.UseE:Value() and ValidTarget(minion, E.Radius) and CanCast(_E) then
				Control.CastSpell(HK_E, minion)
			end
		end
	end
end

function Amumu:Tick()
	self:CheckUlt()
	self:CheckE()
	self:ProtectMana()
end

function Amumu:Draw()
	if myHero.dead then return end
	if self.Menu.Drawing.DrawQ:Value() and myHero:GetSpellData(0).level > 0 then
		local qcolor = isReady(0) and  Draw.Color(189, 183, 107, 255) or Draw.Color(150,255,0,0)
		Draw.Circle(Vector(myHero.pos),Q.Range,1,qcolor)
	end
	if self.Menu.Drawing.DrawR:Value() and myHero:GetSpellData(3).level > 0  then
		local rcolor = isReady(3) and  Draw.Color(240,30,144,255) or Draw.Color(150,255,0,0)
		Draw.Circle(Vector(myHero.pos),R.Range,3,rcolor)
	end
end

Amumu()