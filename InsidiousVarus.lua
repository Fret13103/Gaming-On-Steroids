local myHero = GetMyHero()

if GetObjectName(myHero) ~= "Varus" then return end

local LocalVersion = 1.01
local UpdateURL = ""
local pred = nil
local vishandle = nil

local LaneClearMode = 1

function VarusMessage(msg)
	print("<font color=\"#00f0ff\"><b>Insidious Varus:</b></font><font color=\"#ffffff\"> "..msg.."</font>")
end

local skills = {
	Q = { delay = 0, speed = 1750, width = 75, minRange = 1050, maxRange = 1675, range=1675},
	E = { delay = 0.1, speed = 1600, width = 550, range = 975, radius = 275},
	R = { delay = 0.1, speed = 1850, width = 120, range = 1075}
}

local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}

local items = {trinket = 3363, bork = 3153, cutlass = 3144, youmuus = 3142}

local LastComboSpellTime = 0
local IsKSChannel = false
local shop = nil

AutoUpdater(LocalVersion, 
 true, 
 "raw.githubusercontent.com", 
 "/Fret13103/Gaming-On-Steroids/master/InsidiousVarus.ver.lua".. "?no-cache=".. math.random(9999, 1001020201), 
 "/Fret13103/Gaming-On-Steroids/master/InsidiousVarus.lua".. "?no-cache=".. math.random(9999, 1001020201), 
 SCRIPT_PATH .. "InsidiousVarus.lua", 
 function() VarusMessage("Update completed successfully!") return end, 
 function() VarusMessage("You are up to date!") return end, 
 function() VarusMessage("Update found - starting update!") return end, 
 function() VarusMessage("Failed to update!") return end)

if not pcall( require, "OpenPredict" ) then VarusMessage("Please install OpenPredict!") return end

--																		SCRIPT MENU CREATION

local mainMenu = Menu("varus", "Insidious Varus")

mainMenu:SubMenu("qconfig", "Varus: Q")
mainMenu.qconfig:Slider("qstacks", "Minimum stacks on target to Q", 3, 1, 3 , 1)
mainMenu.qconfig:Boolean("comboq", "Use Q in combo", true)
mainMenu.qconfig:Boolean("harassq", "Use Q in harass", true)

mainMenu.qconfig:Info("blank", " ")
mainMenu.qconfig:Info("separator", "Laneclear") --SEPARATOR 

mainMenu.qconfig:Boolean("laneclearQ", "Use Q in laneclear", true)
mainMenu.qconfig:Slider("QMinionsNumber", "Q to hit x minions", 3, 1, 7, 1)
mainMenu.qconfig:Slider("QChargeTime", "Charge Q for (x) ms", 500, 1, 1500, 10)
mainMenu.qconfig:Boolean("ShoveQ", "Use Q to shove", true)

mainMenu:SubMenu("econfig", "Varus: E")
mainMenu.econfig:Slider("estacks", "Minimum stacks on target to E", 3, 1, 3 , 1)
mainMenu.econfig:Boolean("comboe", "Use E in combo", true)
mainMenu.econfig:Boolean("harasse", "Use E in harass", true)

mainMenu.econfig:Info("blank", " ")
mainMenu.econfig:Info("separator", "Laneclear") --SEPARATOR 

mainMenu.econfig:Boolean("laneclearE", "Use E in laneclear", true)
mainMenu.econfig:Slider("EMinionsNumber", "E to hit x minions", 4, 1, 7, 1)
mainMenu.econfig:Boolean("ShoveE", "Use E to shove", true)
mainMenu.econfig:Slider("ClearManaE", "Shove min% mana to ult", 60, 1, 100, 1)


mainMenu:SubMenu("keyconfig", "Varus: Keys")
mainMenu.keyconfig:Key("combo", "Combo key", string.byte(" "))
mainMenu.keyconfig:Key("harass", "Harass key", string.byte("C"))
mainMenu.keyconfig:Key("clear", "Lane & Jungle clear", string.byte("V"))

mainMenu:SubMenu("autolevel", "Varus: Autolevel")
mainMenu.autolevel:Boolean("allowLeveling", "Autolevel skills", true)
mainMenu.autolevel:Slider("skillOrder", "Skill order priority", 2, 1, 2, 1)
mainMenu.autolevel:Info("displayOrder", "Skill order is: E")

--																		SCRIPT CLASSES 

local SkillOrders = {
	{_Q,_E,_E, _Q, _Q, _R,_Q,_E,_Q,_E,_R,_E,_E,_W,_W,_R,_W,_W},
	{_Q,_W,_E, _Q, _Q, _R,_Q,_W,_Q,_W,_R,_W,_W,_E,_E,_R,_E,_E}
}

class "PredictMain"

function PredictMain:__init()
	self.EnemyHeroes = {}
	for i, enemy in pairs(GetEnemyHeroes()) do
		table.insert(self.EnemyHeroes, EnemyHero(enemy, GetGameTimer(), GetOrigin(EnemyHero), GetDirection(enemy) or Vector(0,0,1), GetMoveSpeed(enemy) or 360))
	end
	OnTick(function() self:Tick() end)
end

function PredictMain:EstimateMissingPos(EnemyHero, time)
	if EnemyHero == nil then return end

	local ms = EnemyHero.LastSpeed
	if not EnemyHero.LastDirection then print ("no direction") return end
	local dir = EnemyHero.LastDirection
	local time = GetGameTimer() - EnemyHero.LastSeen

	if dir == nil then return end

	local missingtime = GetGameTimer() - EnemyHero.LastSeen

	if missingtime > 2 then print("not missing PREDMAIN") return end

	local vec = GetOrigin(EnemyHero.Hero) + Vector(Vector(dir):normalized() * time * ms)

	return vec
end

function PredictMain:GetEnemyHeroObject(champ)
	for _, enemyhero in pairs(self.EnemyHeroes) do
		if enemyhero.Hero.networkID == champ.networkID then
			return enemyhero
		end
	end
end

function PredictMain:Tick()
	for _, enemyhero in pairs(self.EnemyHeroes) do
		if IsVisible(enemyhero) then
			enemyhero.LastSeen = GetGameTimer()
			enemyhero.LastPos = GetOrigin(enemyhero)
			enemyhero.LastSpeed = GetMoveSpeed(enemyhero)
			enemyhero.LastDirection = GetDirection(enemyhero)
		end
	end
end

class "EnemyHero"

function EnemyHero:__init(champ, lastseen, lastpos, lastdirection, lastspeed, lasthp)
	self.Hero = champ
	self.LastSeen = lastseen
	self.LastPos = lastpos
	self.LastDirection = lastdirection
	self.LastSpeed = lastspeed
	self.LastHP = lasthp

	return {Hero = self.Hero, LastSeen = self.LastSeen, LastPos = self.LastPos, LastDirection = self.LastDirection, LastHP = self.LastHP}
end

class "VisionHandler"

function VisionHandler:__init()
	self.VisibleEnemies = {}
	self.EnemyDatas = {}
	self.BlueTrinketID = 3363
	self.DefaultTrinketID = 3340


	for i, unit in pairs(GetEnemyHeroes()) do
		table.insert(self.EnemyDatas, EnemyHero(unit, GetGameTimer(), Vector(0,0,0), GetDirection(unit) or Vector(0,0,1), 300, unit.health))
	end

	OnTick(function() self:Tick() end)
end

function VisionHandler:GetVisibleEnemies()
	local visibles = {}
	for i, unit in pairs(GetEnemyHeroes()) do
		if unit.visible then
			table.insert(visibles, unit)
		end
	end
	return visibles
end

function VisionHandler:Tick()
	for _, enemy in pairs(self:GetVisibleEnemies()) do
		local contains = false
		for i, enemydata in pairs(self.EnemyDatas) do
			if enemydata.Hero.networkID == enemy.networkID then
				contains = true
				enemydata.LastSeen = GetGameTimer()
				enemydata.LastPos = GetOrigin(enemy)
				enemydata.LastSpeed = GetMoveSpeed(enemy)
				enemydata.LastDirection = GetDirection(enemy)
				enemydata.LastHP = enemy.health
			end
		end
		if contains == false then
			table.insert(self.EnemyDatas, EnemyHero(unit, GetGameTimer(), GetOrigin(enemy), GetDirection(enemy), 300, enemy.health))
		end
	end
	self:WardMissing()
end

function VisionHandler:LastSeenTime(unit)
	for _, enemydata in pairs(self.EnemyDatas) do
		if enemydata.Hero.networkID == unit.networkID then
			return enemydata.LastSeen
			--return MapPositionGos:inBush(enemydata.LastSeen)
		end
	end
end

function VisionHandler:GetMissing()
	local missings = {}
	for i, enemydata in pairs(self.EnemyDatas) do
		if not IsVisible(enemydata.Hero) and GetGameTimer() - self:LastSeenTime(enemydata.Hero) <= .5 then
			table.insert(missings, enemydata)
		end
	end
	return missings
end

function VisionHandler:UseTrinket(enemyhero)
	local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}
	if enemyhero.LastHP <= 0 then return end
	local pos = pred:EstimateMissingPos(enemyhero, GetGameTimer() - enemyhero.LastSeen)
	if pos == nil then print("Insidious Varus Debug - VISIONHANDLER:USETRINKET ~ nil pos") return end

	if myHero:DistanceTo(pos) <= skills.E.range and CanCast(2) then
		CastSkillShot(2, pos)
		return
	end

	for _, item in pairs(itemconstants) do
		if GetItemID(myHero, item) == self.DefaultTrinketID then
			if myHero:DistanceTo(pos) <= 600 then
				CastSkillShot(item, pos)
			end
		elseif GetItemID(myHero, item) == self.BlueTrinketID then
			if myHero:DistanceTo(pos) <= 2000 then
				CastSkillShot(item, pos)
			end
		end
	end
end

function VisionHandler:WardMissing()
	local missings = self:GetMissing()

	for i, enemydata in pairs(missings) do
		trinketdata = { delay = 0.0, speed = math.huge, width = 238, range = 3500, radius = 475}
		if enemydata.LastHP > 0 then
			self:UseTrinket(enemydata)
		end
	end
end

class "autolevel"

function autolevel:__init() -- I would've done self.SkillOrders but it always returned nil... ?!?
	OnTick(function() autolevel:Tick() end)
end

function autolevel:displayPriority()
	if mainMenu.autolevel.skillOrder:Value() == 1 then
		mainMenu.autolevel.displayOrder.name = "Skill order is: ".. "QWE"
	elseif mainMenu.autolevel.skillOrder:Value() == 2 then
		mainMenu.autolevel.displayOrder.name = "Skill order is: ".. "QEW"
	end
end

function autolevel:Tick()
	self:displayPriority()

	if SkillOrders == nil then print("Skillorder nil error") return end

	if GetLevelPoints(myHero) > 0 and mainMenu.autolevel.allowLeveling:Value() then
		if (myHero.level + 1 - GetLevelPoints(myHero)) then
			LevelSpell(SkillOrders[mainMenu.autolevel.skillOrder:Value()][myHero.level + 1 - GetLevelPoints(myHero)])
		end
	end
end

--																		SCRIPT USEFUL FUNCTIONS

local wDatas = {}

DelayAction(function()
for i, v in pairs(GetEnemyHeroes()) do
	wDatas[v.networkID] = 0
end

end, 1)

local QCastData = {casting, starttime}

function CalcQRange(timer)
	local rangediff = skills.Q.maxRange - skills.Q.minRange
	local min = skills.Q.minRange

	local total = rangediff / 1.4 * timer + min

	if total > skills.Q.maxRange then total = skills.Q.maxRange end

	return total
end

function DrawQRange()
	if QCastData.casting then
		local timecasting = GetGameTimer() - QCastData.starttime
		local range = CalcQRange(timecasting)

		DrawCircle(GetOrigin(myHero), range, 1, 10, GoS.White)
	else
		DrawCircle(GetOrigin(myHero), skills.Q.minRange, 1, 10, GoS.White)
	end
end

function stackDmg(unit)
	if wDatas[unit.networkID] then
		local wDmg = GetMaxHP(unit)*((1.25+GetCastLevel(myHero,_W)*0.75)+GetBonusAP(myHero)*0.02)*.01
		return CalcDamage(myHero, unit, 0, wDmg*wDatas[unit.networkID])
	else
		return 0
	end
end

function qDmg(unit, timer)
	local minDmg = GetCastLevel(myHero,_Q)*55-30+GetBonusDmg(myHero)*1.6+GetBaseDamage(myHero)*1.6
	local maxDmg = minDmg/16*10

	local diff = maxDmg - minDmg

	if timer == nil then timer = 1 end

	local dmgadded = diff / 4 * timer

	local dmgtot = minDmg + dmgadded

	if not CanCast(_Q) then return 0 end

	return CalcDamage(myHero, unit, dmgtot , 0) + stackDmg(unit)
end

function eDmg(unit)
	if not CanCast(_E) then return 0 end

	return CalcDamage(myHero, unit, GetCastLevel(myHero,_E)*35+30+GetBonusDmg(myHero)*.6 ,0) + stackDmg(unit)
end

function rDmg(unit)
	if not CanCast(_R) then return 0 end

	return CalcDamage(myHero, unit, 0 ,GetCastLevel(myHero,_R)*75+25+GetBonusAP(myHero)) + stackDmg(unit)
end

function ComboWillKill(unit)
	local dmg = 0

	if QCastData.casting then
		dmg = qDmg(unit, GetGameTimer() - QCastData.starttime)
	else
		dmg = qDmg(unit, 1)
	end
	dmg = dmg + eDmg(unit)
	dmg = dmg + rDmg(unit)
	dmg = dmg + GetBonusDmg(myHero)

	return unit.health <= dmg
end

function DrawDamageHealth(unit)
	local dmg = 0

	if QCastData.casting then
		dmg = qDmg(unit, GetGameTimer() - QCastData.starttime)
	else
		dmg = qDmg(unit, 1)
	end
	dmg = dmg + eDmg(unit)
	dmg = dmg + rDmg(unit)

	DrawDmgOverHpBar(unit,GetCurrentHP(unit), dmg, 0, GoS.Blue)
end

function Ghostblade()
	for i, item in pairs(itemconstants) do
		local bork = nil
		if GetItemID(myHero, item) == items.bork then
			bork = item
		elseif GetItemID(myHero, item) == items.cutlass then
			bork = item
		end
		if bork ~= nil then
			if CanCast(item) and ValidTarget(GetCurrentTarget()) then
				CastTargetSpell(GetCurrentTarget(), item)
			end
		end
	end
end

function PrintItems()
	for i, item in pairs(itemconstants) do
		PrintChat(GetItemID(myHero, item))
	end
end

--																		SCRIPT LOGICS COMBO

function CanCast(slot)
	return myHero:CanUseSpell(slot) == 0
end

function ComboQ()
	if not mainMenu.keyconfig.combo:Value() then return end
	if isAttacking then return end
	if not CanCast(_Q) then return end
	if not mainMenu.qconfig.comboq:Value() then return end
	if QCastData.casting then 
		local timecasting = GetGameTimer() - QCastData.starttime

		local QPredData = {delay = skills.Q.delay, speed = skills.Q.speed, width = skills.Q.width, range = CalcQRange(timecasting)}
		local predictinfo = GetLinearAOEPrediction(GetCurrentTarget(), QPredData, GetOrigin(myHero))

		local castpos = predictinfo.castPos

		if predictinfo.hitChance >= .6 and ValidTarget(GetCurrentTarget())  and GetGameTimer() - LastComboSpellTime >= 1.5 then
			CastSkillShot2(0, castpos)
			LastComboSpellTime = GetGameTimer()
		end
		--print(predictinfo)
	elseif ValidTarget(GetCurrentTarget()) and myHero:DistanceTo(GetCurrentTarget()) <= skills.Q.maxRange then
		if wDatas[GetCurrentTarget().networkID] >= mainMenu.qconfig.qstacks:Value() then
			CastSkillShot(0, GetOrigin(myHero))
		end
	end
end

function ComboE()
	if not mainMenu.keyconfig.combo:Value() then return end
	if QCastData.casting then return end
	if isAttacking then return end
	if not CanCast(_E) then return end
	if not mainMenu.econfig.comboe:Value() then return end

	--local EPredData = {delay = skills.E.delay, speed = skills.E.speed, width = skills.E.width, range = skills.E.range, radius = skills.E.radius}
	local predictinfo = GetCircularAOEPrediction(GetCurrentTarget(), skills.E, GetOrigin(myHero))

	local castpos = predictinfo.castPos

	if predictinfo.hitChance >= .7 and ValidTarget(GetCurrentTarget()) and GetGameTimer() - LastComboSpellTime > 2 then
		if wDatas[GetCurrentTarget().networkID] >= mainMenu.econfig.estacks:Value() then
			CastSkillShot(_E, castpos.x, castpos.y, castpos.z)
			LastComboSpellTime = GetGameTimer()
		end
	end
end

function ComboR()
	if not mainMenu.keyconfig.combo:Value() then return end
	if not CanCast(_R) then return end
	if QCastData.casting then return end
	if isAttacking then return end
	if not ValidTarget(GetCurrentTarget()) then return end
	if not ComboWillKill(GetCurrentTarget()) then return end

	local predictinfo = GetPrediction(GetCurrentTarget(), skills.R, GetOrigin(myHero))

	local castpos = predictinfo.castPos

	if predictinfo.hitChance >= .7 and ValidTarget(GetCurrentTarget()) then
		--if wDatas[GetCurrentTarget().networkID] >= mainMenu.econfig.estacks:Value() then
			CastSkillShot(_R, castpos.x, castpos.y, castpos.z)
		--end
	end

end

--																		SCRIPT LOGICS HARASS

function HarassQ()
	if not mainMenu.keyconfig.harass:Value() then return end
	if not CanCast(_Q) then return end
	if isAttacking then return end
	if not mainMenu.qconfig.harassq:Value() then return end

	if QCastData.casting then 
		local timecasting = GetGameTimer() - QCastData.starttime
		
		if timecasting < 1 then return end

		local QPredData = {delay = skills.Q.delay, speed = skills.Q.speed, width = skills.Q.width, range = CalcQRange(timecasting)}
		local predictinfo = GetLinearAOEPrediction(GetCurrentTarget(), QPredData, GetOrigin(myHero))

		local castpos = predictinfo.castPos

		if predictinfo.hitChance >= .7 and ValidTarget(GetCurrentTarget()) then
			CastSkillShot2(0, castpos)
		end
		--print(predictinfo)
	elseif ValidTarget(GetCurrentTarget()) then
		CastSkillShot(0, GetOrigin(myHero))
	end
end

function HarassE()
	if not mainMenu.keyconfig.harass:Value() then return end
	if not CanCast(_E) then return end
	if isAttacking then return end
	if not mainMenu.econfig.harasse:Value() then return end

	local predictinfo = GetCircularAOEPrediction(GetCurrentTarget(), skills.E, GetOrigin(myHero))

	local castpos = predictinfo.castPos

	if predictinfo.hitChance >= .7 and ValidTarget(GetCurrentTarget()) then
		CastSkillShot(_E, castpos.x, castpos.y, castpos.z)
	end
end

--																		SCRIPT LOGICS LANECLEAR

function ClearQ()
	if not mainMenu.qconfig.laneclearQ:Value() then return end
	if mainMenu.keyconfig.clear:Value() then
		if not isAttacking then
			if LaneClearMode == 2 then
				for i, minion in pairs(minionManager.objects) do
					if ValidTarget(minion, skills.Q.range) and mainMenu.qconfig.ShoveQ:Value() then

						local vectorTo = Vector(GetOrigin(minion)) - Vector(GetOrigin(myHero))

						local vectorLeft = vectorTo:perpendicular()
						local vectorRight = vectorTo:perpendicular2()

						local start = Vector(GetOrigin(myHero))

						local minionsinrange = {}
						for i, minion in pairs(minionManager.objects) do
							if ValidTarget(minion, skills.Q.range) then
								table.insert(minionsinrange, minion)
							end
						end

						local timecasting

						if QCastData.starttime then
							timecasting = GetGameTimer() - QCastData.starttime
						
						else
							timecasting = .1
						end
						
						local minionshitbyQ = CountObjectsOnLineSegment(start, start + (vectorTo:normalized() * CalcQRange(timecasting)), skills.Q.width, minionsinrange, nil)
						if minionshitbyQ >= mainMenu.qconfig.QMinionsNumber:Value() then
							if not QCastData.casting then
								CastSkillShot(0, start + (vectorTo:normalized() * skills.Q.range))
							elseif GetGameTimer() - QCastData.starttime > (mainMenu.qconfig.QChargeTime:Value()/1000) then
								CastSkillShot2(0, start + (vectorTo:normalized() * skills.Q.range))
							end
						end
					end
				end
			end
		end
	end
end

function ClearE()
	if not mainMenu.econfig.laneclearE:Value() then return end
	if mainMenu.keyconfig.clear:Value() then
		if QCastData.casting then return end
		if not isAttacking then
			if LaneClearMode == 2 then
				for i, minion in pairs(minionManager.objects) do
					if ValidTarget(minion, skills.E.range) and mainMenu.econfig.ShoveE:Value() then
						if myHero.mana <= (myHero.maxMana /100 * mainMenu.econfig.ClearManaE:Value()) then return end
						local minionsHit = {}
						for i, creep in pairs(minionManager.objects) do
							if ValidTarget(creep) and minion:DistanceTo(creep) <= skills.E.radius then
								table.insert(minionsHit, creep)
							end
						end
						if #minionsHit >= mainMenu.econfig.EMinionsNumber:Value() then
							CastSkillShot(2, GetOrigin(minion))
						end
					end
				end
			end
		end
	end
end

--																		SCRIPT LOGICS KILLSTEAL

function DoKS()
	for _, enemy in pairs(GetEnemyHeroes()) do
		if ValidTarget(enemy) and myHero:DistanceTo(enemy) <= skills.Q.maxRange then
			if CanCast(_Q) and qDmg(enemy) * 1.6 > enemy.health then
				if not QCastData.casting then
					CastSkillShot(0, GetOrigin(myHero))
					IsKSChannel = true
				else
					local timecasting = GetGameTimer() - QCastData.starttime

					local QPredData = {delay = skills.Q.delay, speed = skills.Q.speed, width = skills.Q.width, range = CalcQRange(timecasting)}
					local predictinfo = GetLinearAOEPrediction(enemy, QPredData, GetOrigin(myHero))

					local castpos = predictinfo.castPos

					if predictinfo.hitChance >= .7 and ValidTarget(enemy) and myHero:DistanceTo(enemy) > ((CalcQRange(timecasting) + 200) < skills.Q.maxRange and CalcQRange(timecasting) + 200 or skills.Q.maxRange) then
						CastSkillShot2(0, castpos)
						IsKSChannel = false
					end
				end
			end
		end
	end
end

--																		SCRIPT MISC LOGICS

function CheckRCast(pos)
	local ES = Vector(pos) - Vector(myHero) 
	ES = ES:normalized() * skills.R.range
	pos = myHero.pos + ES
	local predictedPositions = {}
	for i, v in pairs(GetEnemyHeroes()) do
		if ValidTarget(v, skills.R.range) then
			local ppos = GetPrediction(v, skills.R, GetOrigin(myHero))
			table.insert(predictedPositions, ppos)
		end
	end

	if #predictedPositions == 0 then return end

	for i, v in pairs(predictedPositions) do
		local projection, line, isonline = VectorPointProjectionOnLine(Vector(myHero.pos), Vector(pos), Vector(ppos))
		if Vector(projection):dist(Vector(ppos)) > skills.R.width then
			print("ult will miss")
			return false
		end
	end
	return true
end

--																		GOS API CALLBACKS

OnUpdateBuff(function(unit, buff)
	if buff.Name == "VarusQ" and unit.networkID == myHero.networkID then
		QCastData.casting = true
		QCastData.starttime = GetGameTimer()
	elseif buff.Name:lower() == "varuswdebuff" and unit.team ~= myHero.team then
		wDatas[unit.networkID] = buff.Count
	end
end)

OnRemoveBuff(function(unit, buff)
	if buff.Name == "VarusQ" and unit.networkID == myHero.networkID then
		QCastData.casting = false
		IsKSChannel = false
	elseif buff.Name:lower() == "varuswdebuff" and unit.team ~= myHero.team then
		wDatas[unit.networkID] = 0
	end
end)

OnSpellCast(function(spell)
	if spell.spellID == 3 then
		if not CheckRCast(spell.castPos) then
			BlockCast()
		end
	end
end)

OnProcessSpellAttack(function(unit, spell)
	if unit == myHero and spell.name:find("Attack") then
		--print(spell.name)
		isAttacking = true
	end
end)

OnProcessSpellComplete(function(unit, spell)
	if unit == myHero and spell.name:find("Attack") then
		isAttacking = false
	end
end)

OnAttackCancel(function()
	isAttacking = false
end)

OnObjectLoad(function(object)
	if object.type == Obj_AI_Shop and object.team == myHero.team then
		shop = object
	end
end)

OnTick(function()
	ComboQ()
	HarassQ()
	if not IsKSChannel and not QCastData.Casting then
		ComboE()
		ComboR()
		HarassE()
	end
	DoKS()

	ClearQ()
	ClearE()

	if mainMenu.keyconfig.combo:Value() then
		Ghostblade()
	end

	if shop and myHero:DistanceTo(shop) <= 1000 and GetLevel(myHero) >= 9 then
		BuyItem(items.trinket)
	end
end)

OnDraw(function()
	DrawQRange()
	textpos3d = GetOrigin(myHero)
	local datas = WorldToScreen(1, textpos3d)
	if datas.flag == true and mainMenu.keyconfig.clear:Value() then
		if LaneClearMode == 1 then
			DrawText("Laneclear mode: aa clear", 24, datas.x, datas.y, GoS.White)
		else 
			DrawText("Laneclear mode: shove", 24, datas.x, datas.y, GoS.White)
		end
		--DrawText("IsAttacking: " .. tostring(isAttacking), 24, datas.x, datas.y - 20, GoS.White)
	end
	for _, enemy in pairs(GetEnemyHeroes()) do
		DrawDamageHealth(enemy)
		if ComboWillKill(enemy) and IsVisible(enemy) then
			local screenpos = WorldToScreen(0,GetOrigin(enemy).x,GetOrigin(enemy).y,GetOrigin(enemy).z)

			DrawText("COMBO WILL KILL PLAYER", 14, screenpos.x + 20, screenpos.y - 20 , GoS.White)
		end
	end
end)

OnLoad(function()
	vishandle = VisionHandler()
	pred = PredictMain()
	autolevel()
end)

OnWndMsg(function(Msg, Key)
	if Msg == KEY_DOWN then
		if not mainMenu.keyconfig.clear:Value() then return end

		if Key == 38 then
			LaneClearMode = 2
		elseif Key == 40 then
			LaneClearMode = 1
		end
	end
end)