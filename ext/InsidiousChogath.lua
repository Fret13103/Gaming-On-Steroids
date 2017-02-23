if myHero.charName ~= "Chogath" then return end

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
local Q = {Range = 1000, Delay = .65, Radius = 200, Speed = math.huge, Type="Circle"}
local W = {Range = 675, Delay = 0, Radius = 100, Speed = math.huge, Angle = 60}
local E = {Range = 500}

function CanCast(spell)
	return Game.CanUseSpell(spell) == READY
end

function CountEnemiesInRange(vector, objlist)
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
			if vector:DistanceTo(Vector(enemy.pos)) <= Q.Radius then
				count = count + 1
			end
		end
	end

	return count
end

local R = {Range = 175}

class "Chogath"

function Chogath:__init()
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

function Chogath:LoadMenu()
	self.Menu = MenuElement({type= MENU, id="ScriptChogath", name="Insidious Chogath"})

	self.Menu:MenuElement({type = MENU,id = "Combo",name = "Combo Settings"})
	self.Menu.Combo:MenuElement({id = "UseQ",name = "Use Q",value = true})
	self.Menu.Combo:MenuElement({id = "AutoQ",name = "Use Q automatically to knock up enemies",value = true})
	self.Menu.Combo:MenuElement({id = "AutoQNum",name = "Number of enemies to knock up",value = 3,min = 1,max = 5, step = 1})
	self.Menu.Combo:MenuElement({id = "UseW",name = "Use W",value = true})
	self.Menu.Combo:MenuElement({id = "UseE",name = "Use E",value = true})
	self.Menu.Combo:MenuElement({id = "UseR",name = "Use R",value = true})
	self.Menu.Combo:MenuElement({id = "AutoR",name = "Use R to killsteal",value = true})
	
	self.Menu:MenuElement({type = MENU,id = "Harass",name = "Harass Settings"})
	self.Menu.Harass:MenuElement({id = "UseQ",name = "Use Q",value = true})
	self.Menu.Harass:MenuElement({id = "UseW",name = "Use W",value = false})
	self.Menu.Harass:MenuElement({id = "MinMana",name = "Don't use spells if mana% goes below",value = 70,min = 0,max = 100, step = 1})
	
	self.Menu:MenuElement({type = MENU,id = "LaneClear",name = "LaneClear Settings"})
	self.Menu.LaneClear:MenuElement({id = "Enable",name = "Use spells to clear ",value = true})
	self.Menu.LaneClear:MenuElement({id = "UseQ",name = "Use Q",value = true})
	self.Menu.LaneClear:MenuElement({id = "MinHitQ",name = "Q to hit x number of minions",value = 4,min = 1,max = 7, step = 1})
	self.Menu.LaneClear:MenuElement({id = "UseW",name = "Use W",value = false})
	self.Menu.LaneClear:MenuElement({id = "MinHitW",name = "Q to hit x number of minions",value = 4,min = 1,max = 7, step = 1})
	self.Menu.LaneClear:MenuElement({id = "UseE",name = "Use E",value = true})
	self.Menu.LaneClear:MenuElement({id = "MinMana",name = "Don't use spells if mana% goes below",value = 30,min = 0,max = 100, step = 1})
	
	self.Menu:MenuElement({type = MENU,id = "Drawing",name = "Drawing Settings"})
	self.Menu.Drawing:MenuElement({id = "DrawQ",name = "Draw Q Range",value = true})
	self.Menu.Drawing:MenuElement({id = "DrawW",name = "Draw W Range",value = false})
end

function Chogath:IsMarkeredTarget(unit)
	local ultDmgs = {300, 475, 650}
	local lvl = myHero:GetSpellData(3) and myHero:GetSpellData(3).level or 0
	local Dmg = ultDmgs[lvl] + myHero.ap*.7
	print(tostring(Dmg>unit.health))
	return Dmg > unit.health
end

function Chogath:GetTarget(range)
	return Ts:GetTarget(range)
end

function Chogath:GetDamage(spell, unit)
	return getdmg(spell, unit)
end

function Chogath:CastQ(target)
	local CastPosition, Hitchance = Pred:GetPrediction(target, Q)
	if Hitchance == "High" then
		SpellCast:Add("Q", CastPosition)
	end
end

function Chogath:CastW(target)
	local CastPosition, Hitchance = Pred:GetPrediction(target, W)
	if Hitchance == "High" then
		SpellCast:Add("W",CastPosition)
	end
end

function Chogath:CheckUlt()
	if not CanCast(_R) then return end
	for _, enemy in pairs(self.Enemies) do
		if ValidTarget(enemy, (R.Range + myHero.boundingRadius)) and self:IsMarkeredTarget(enemy) then
			Control.CastSpell(HK_R, enemy)
		end
	end
end

function Chogath:AutoQKnock()
	if not CanCast(_Q) then return end
	if not self.Menu.Combo.AutoQ:Value() then return end

	local min = self.Menu.Combo.AutoQNum:Value()

	for i, enemy in pairs(self.Enemies) do
		if ValidTarget(enemy, 1200) then
			local num = CountEnemiesInRange(Vector(enemy.pos))
			if num >= min then
				self:CastQ(enemy)
				return
			end
		end
	end
end

function Chogath:OnActiveMode(OW, Minions)
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

function Chogath:Combo(OW, Minions)
	local useq = self.Menu.Combo.UseQ:Value()
	local usew = self.Menu.Combo.UseW:Value()
	local user = self.Menu.Combo.UseR:Value()

	local target = self:GetTarget(Q.Range)

	if ValidTarget(target, Q.Range) and useq and CanCast(_Q) then
		self:CastQ(target)
	end
	if ValidTarget(target, W.Range) and usew and CanCast(_W) then
		self:CastW(target)
	end
end

function Chogath:Harass(OW, Minions)
	local useq = self.Menu.Harass.UseQ:Value()
	local usew = self.Menu.Harass.UseW:Value()

	local target = self:GetTarget(Q.Range)

	if myHero.mana < myHero.maxMana / 100 * self.Menu.Harass.MinMana:Value() then return end

	if ValidTarget(target, Q.Range) and useq and CanCast(_Q) then
		self:CastQ(target)
	end
	if ValidTarget(target, W.Range) and usew and CanCast(_W) then
		self:CastW(target)
	end
end

function Chogath:Clear(OW, Minions)
	if Minions == nil then return end

	if myHero.mana < myHero.maxMana/100 * self.Menu.LaneClear.MinMana:Value()  then return end
	for _, minion in pairs(Minions[ENEMY]) do
		if ValidTarget(minion, 650) and CanCast(_W) then
			local hitby = {minion}

			for i, creep in pairs(Minions[ENEMY]) do
				if creep ~= minion and ValidTarget(creep, 650) then --annotated section to pay hommage to the hour wasted on it testing different ways of getting the angle before common sense hit me
					--anglebetween = Vector(myHero.pos):AngleBetween(Vector(minion.pos), Vector(creep.pos)) returned 0 i must have used it wrong, hue
					local v1, v2, v3 = Vector(myHero.pos), Vector(minion.pos), Vector(creep.pos) --get the lengths of the distances from the 3 points, treat them like oblique triangle
					local a = (v2-v3):Len() --length a
					local b = (v3-v1):Len() --length b
					local c = (v2-v1):Len() --length c

					local cosA = ((b^2) + (c^2) - (a^2))/(2*b*c) --Rearranged cosine formula
					anglebetween = math.deg(math.acos(cosA)) --making it into angle in degrees

					if anglebetween < W.Angle then --if the angle is < cho w angle width
						table.insert(hitby, creep) --the creep will be hit, we know this since it's distance too is less than 650 (cho w range) int he validtarget check
					end
				end
			end
			--print(#hitby)
			if #hitby >= self.Menu.LaneClear.MinHitW:Value() and self.Menu.LaneClear.UseW:Value() then
				self:CastW(minion)
			end
		end
		if ValidTarget(minion, 1200) and CanCast(_Q) then
			for i, v in pairs(Minions[ENEMY]) do
				if ValidTarget(v, Q.Range) then
					local num = CountEnemiesInRange(Vector(v.pos), Minions[ENEMY])
					if num >= self.Menu.LaneClear.MinHitQ:Value() and self.Menu.LaneClear.UseQ:Value() then
						self:CastQ(minion)
					end
				end
			end 
		end
	end
end

function Chogath:Tick()
	self:CheckUlt()
	self:AutoQKnock()
end

function Chogath:Draw()
	if myHero.dead then return end
	if self.Menu.Drawing.DrawQ:Value() and myHero:GetSpellData(0).level > 0 then
		local qcolor = isReady(0) and  Draw.Color(189, 183, 107, 255) or Draw.Color(150,255,0,0)
		Draw.Circle(Vector(myHero.pos),Q.Range,1,qcolor)
	end
	if self.Menu.Drawing.DrawW:Value() and myHero:GetSpellData(1).level > 0  then
		local rcolor = isReady(1) and  Draw.Color(240,30,144,255) or Draw.Color(150,255,0,0)
		Draw.Circle(Vector(myHero.pos),W.Range,1,rcolor)
	end
end

Chogath()