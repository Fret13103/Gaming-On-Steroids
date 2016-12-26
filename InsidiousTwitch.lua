local myHero = GetMyHero()

if GetObjectName(myHero) ~= "Twitch" then return end

local LocalVersion = 1.7

local UpdateURL = ""

function TwitchMessage(msg)
	print("<font color=\"#00f0ff\"><b>Insidious Twitch:</b></font><font color=\"#ffffff\"> "..msg.."</font>")
end

AutoUpdater(LocalVersion, 
 true, 
 "raw.githubusercontent.com", 
 "/Fret13103/Gaming-On-Steroids/master/InsidiousTwitch.ver.lua", 
 "/Fret13103/Gaming-On-Steroids/master/InsidiousTwitch.lua".. "?no-cache=".. math.random(9999, 1001020201), 
 SCRIPT_PATH .. "InsidiousTwitch.lua", 
 function() TwitchMessage("Update completed successfully!") return end, 
 function() TwitchMessage("You are up to date!") return end, 
 function() TwitchMessage("Update found - starting update!") return end, 
 function() TwitchMessage("Failed to update!") return end)

if not pcall( require, "OpenPredict" ) then PrintChat("Please install OpenPredict!") return end

local buffunits = {} --{unit, stacks}

local skills = {
	W = { delay = 0.1, speed = 1400, width = 55, range = 950, radius = 275},
	E = { range = 1200 }
}

local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}

local items = {trinket = 3363, bork = 3153, cutlass = 3144, youmuus = 3142}
local storepos = Vector(400, 182, 400)

local mainMenu = Menu("twitch", "Insidious Twitch")

local orbwalker = "Disabled"

mainMenu:SubMenu("qconfig", "Twitch: Q")
mainMenu.qconfig:Boolean("Youmuus", "Youmuus in combat after stealth", true)
mainMenu.qconfig:Boolean("drawQrange", "Draw Q range", true)
mainMenu.qconfig:Boolean("drawQmap", "Draw Q on map", true)

mainMenu:SubMenu("econfig", "Twitch: E")
mainMenu.econfig:Boolean("KillE", "Use E to kill champions", true)
mainMenu.econfig:Boolean("StacksE", "Use E at 6 stacks", true)

mainMenu.econfig:Info("blank", " ")
mainMenu.econfig:Info("separator", "Laneclear")

mainMenu.econfig:Boolean("MinionE", "Use E to kill minions", true)
mainMenu.econfig:Slider("KillMinionsNumber", "E to kill x minions", 3, 1, 5, 1)

mainMenu:SubMenu("wconfig", "Twitch: W")
mainMenu.wconfig:Boolean("ComboW", "Use W in combo", true)
mainMenu.wconfig:Boolean("BlockW", "Block W use while ulting", false)
mainMenu.wconfig:Boolean("GapcloseW", "Antigapclose W", true)
mainMenu.wconfig:Slider("HitchanceW", "W hitchance", 0, .01, 1, .01)

mainMenu.wconfig:Info("blank", " ")
mainMenu.wconfig:Info("separator", "Laneclear") --SEPARATOR 

mainMenu.wconfig:Boolean("laneclearW", "Use W in laneclear", true)
mainMenu.wconfig:Slider("SplashMinionsNumber", "W to poison x minions", 4, 1, 7, 1)

mainMenu:SubMenu("autolevel", "Twitch: Autolevel")
mainMenu.autolevel:Boolean("allowLeveling", "Autolevel skills", true)
mainMenu.autolevel:Slider("skillOrder", "Skill order priority", 2, 1, 2, 1)
mainMenu.autolevel:Info("displayOrder", "Skill order is: E")


mainMenu:SubMenu("keyconfig", "Twitch: Keys")
mainMenu.keyconfig:Key("combo", "Combo key", string.byte(" "))
mainMenu.keyconfig:Key("clear", "Lane & Jungle clear", string.byte("V"))
mainMenu.keyconfig:Key("recall", "Please set this to your recall key", string.byte("B"))

local shop = nil
--IsChatOpen? IsChatOpened?

--BuyItem(ID)

local isAttacking = false

local SkillOrders = {
	{_E,_W,_Q, _E, _E, _R,_E,_Q,_E,_Q,_R,_Q,_Q,_W,_W,_R,_W,_W},
	{_E,_W,_Q, _E, _E, _R,_E,_W,_E,_W,_R,_W,_W,_Q,_Q,_R,_Q,_Q}
	}

function CanCast(char, slot)
	return CanUseSpell(char, slot) == 0
end

function EnemyData(char, lastseen, lastpos)
	return {Hero = char, LastSeen = lastseen, LastPos = lastpos}
end

local vishandle

class "VisionHandler"

function VisionHandler:__init()
	self.VisibleEnemies = {}
	self.EnemyDatas = {}
	self.BlueTrinketID = 3363
	self.DefaultTrinketID = 3340


	for i, unit in pairs(GetEnemyHeroes()) do
		table.insert(self.EnemyDatas, EnemyData(unit, GetGameTimer(), Vector(0,0,0)))
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
			end
		end
		if contains == false then
			table.insert(self.EnemyDatas, EnemyData(unit, GetGameTimer(), GetOrigin(enemy)))
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
		if not IsVisible(enemydata.Hero) and GetGameTimer() - self:LastSeenTime(enemydata.Hero) <= 1 then
			table.insert(missings, enemydata)
		end
	end
	return missings
end

function VisionHandler:UseTrinket(pos)
	local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}

	if myHero:DistanceTo(pos) <= skills.W.range and CanCast(myHero, 1) then
		CastSkillShot(1, pos)
		return
	end

	for _, item in pairs(itemconstants) do
		if GetItemID(myHero, item) == self.DefaultTrinketID then
			if myHero:DistanceTo(pos) <= 900 then
				CastSkillShot(item, pos)
			end
		elseif GetItemID(myHero, item) == self.BlueTrinketID then
			if myHero:DistanceTo(pos) <= GetRange(myHero)*2 then
				CastSkillShot(item, pos)
			end
		end
	end
end

function VisionHandler:WardMissing()
	local missings = self:GetMissing()

	for i, enemydata in pairs(missings) do
		self:UseTrinket(GetOrigin(enemydata.Hero))
	end
end

class "autolevel"

function autolevel:__init() -- I would've done self.SkillOrders but it always returned nil... ?!?
	OnTick(function() autolevel:Tick() end)
end

function autolevel:displayPriority()
	if mainMenu.autolevel.skillOrder:Value() == 1 then
		mainMenu.autolevel.displayOrder.name = "Skill order is: ".. "EQW"
	elseif mainMenu.autolevel.skillOrder:Value() == 2 then
		mainMenu.autolevel.displayOrder.name = "Skill order is: ".. "EWQ"
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

function DrawCircleMinimap(origin, radius, color)
  local MapData = {
    [SUMMONERS_RIFT] = {min = {x = -120, z = -120}, max = {x = 14870, z = 14980}},
    [TWISTED_TREELINE] = {min = {x = 0, z = 0}, max = {x = 15398, z = 15398}},
    [CRYSTAL_SCAR] = {min = {x = 0, z = 0}, max = {x = 13987, z = 13987}},
    [HOWLING_ABYSS] = {min = {x = -28, z = -19}, max = {x = 12849, z = 12858}},
  }
  local p1 = WorldToMinimap(origin.x + radius, origin.y, origin.z)
  local step = math.pi / (radius * 0.05)
  local bF = false
 
  for theta = 0, 2 * math.pi + step, step do
    local x, y = origin.x + math.cos(theta) * radius, origin.z - math.sin(theta) * radius
 
    if x > MapData[GetMapID()].min.x and y > MapData[GetMapID()].min.z and x < MapData[GetMapID()].max.x and y < MapData[GetMapID()].max.z then
      local p2 = WorldToMinimap(x, 0, y)
 
      if not bF then
        DrawLine(p1.x, p1.y, p2.x, p2.y, 1, color)
      end
      p1, bF = p2, false
    else
      bF = true
    end
  end
end

function IsAutoAttacking()

end

function findBuffUnit(unit)
	for i, buffunit in pairs(buffunits) do
		if buffunit[1] == unit then
			return buffunit
		end
	end
	return nil
end

function findBuffUnitIndex(unit)
	for i, buffunit in pairs(buffunits) do
		if buffunit[1] == unit then
			return i
		end
	end
	return nil
end

local qduration = {10,11,12,13,14}
local lastQCastTime = GetGameTimer()
local hasQBuff = false

function DrawQDistanceAvailable()
	if GetCastLevel(myHero, 0) == 0 then return end
	if not mainMenu.qconfig.drawQrange:Value() then return end
	if not hasQBuff then
		lastQCastTime = GetGameTimer()
	end

	local qtimeleft = --[[qduration[GetCastLevel(myHero, 0)] - (qduration[GetCastLevel(myHero, 0)] -]] qduration[GetCastLevel(myHero, 0)] - (GetGameTimer() - lastQCastTime)
	local distleft = qtimeleft * GetMoveSpeed(myHero)

	DrawCircle(GetOrigin(myHero), distleft, 1, 10, GoS.White)
	--DrawCircleMinimap(GetOrigin(myHero), distleft, GoS.Red)
	--local time = GetBuffExpireTime - GetBuffStartTime
end

function DrawQDistanceMinimap()
	if GetCastLevel(myHero, 0) == 0 then return end
	if not mainMenu.qconfig.drawQmap:Value() then return end
	if not hasQBuff then
		lastQCastTime = GetGameTimer()
	end
	if not hasQBuff then
		lastQCastTime = GetGameTimer()
	end
	local qtimeleft = --[[qduration[GetCastLevel(myHero, 0)] - (qduration[GetCastLevel(myHero, 0)] -]] qduration[GetCastLevel(myHero, 0)] - (GetGameTimer() - lastQCastTime)
	local distleft = qtimeleft * GetMoveSpeed(myHero)

	DrawCircleMinimap(GetOrigin(myHero), distleft, GoS.White)
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
			if CanCast(myHero, item) == 0 and ValidTarget(GetCurrentTarget()) then
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

function WClearMinions()
	if not mainMenu.wconfig.laneclearW:Value() then return end
	local minhit = mainMenu.wconfig.SplashMinionsNumber:Value()

	for i, minion in pairs(minionManager.objects) do
		if ValidTarget(minion, skills.W.range) then
			local nearbyminions = {}

			for _, otherminion in pairs(minionManager.objects) do
				if minion:DistanceTo(otherminion) <= 300 and ValidTarget(otherminion) then
					table.insert(nearbyminions, otherminion)
				end
			end

			local addvalue = Vector(0,0,0)

			for _, v in pairs(nearbyminions) do
				addvalue = addvalue + GetOrigin(v)
			end

			addvalue = addvalue / #nearbyminions
			local numhit = 1
			for _, v in pairs(nearbyminions) do
				if v:DistanceTo(addvalue) < skills.W.radius then
					numhit = numhit + 1
				end 
				if numhit >= minhit and CanCast(myHero, 1) then
					CastSkillShot(1, addvalue)
				end
			end
		end
	end
end

function WCanHit(unit)
	if unit and ValidTarget(unit, skills.W.range) then
		local WPred=GetCircularAOEPrediction(unit, skills.W)
		if WPred and WPred.hitChance > (mainMenu.wconfig.HitchanceW:Value()) then
			return WPred.castPos
		end
		return nil
	end
end

function TryW()
	if ValidTarget(GetCurrentTarget()) then
		if not isulting then
			if CanCast(myHero, 1) and WCanHit(GetCurrentTarget()) and mainMenu.keyconfig.combo:Value() then
				CastSkillShot(1, WCanHit(GetCurrentTarget()))
			end
		elseif mainMenu.wconfig.BlockW:Value() == false then
			if CanCast(myHero, 1) and WCanHit(GetCurrentTarget()) and mainMenu.keyconfig.combo:Value() then
				CastSkillShot(1, WCanHit(GetCurrentTarget()))
			end
		end
	end
end

function EKillMinions()
	if mainMenu.econfig.MinionE:Value() then
		local minkill = mainMenu.econfig.KillMinionsNumber:Value() 
		local numkill = 0
		for i, v in pairs(minionManager.objects) do
			if ValidTarget(v, 1200) and v.isMinion then
				local buffobj = findBuffUnit(v)
				if buffobj ~= nil then
					local edmg = CalcExpungeDamage(buffobj)
					if edmg > v.health then
						numkill = numkill + 1
					end
				end
			end
		end
		if numkill > minkill and CanCast(myHero, 2) then
			CastSpell(2)
		end
	end
end

function ExpungeOnStacked()
	for i, enemy in pairs(GetEnemyHeroes()) do
		local buffedUnit = findBuffUnit(enemy)
		if buffedUnit and buffedUnit[2] == 6 and CanCast(myHero, 2) and ValidTarget(enemy, skills.E.range) and mainMenu.keyconfig.combo and mainMenu.econfig.StacksE:Value() then
			CastSpell(2)
		end
	end
end

function ExpungeToKill()
	for i, enemy in pairs(GetEnemyHeroes()) do
		if ValidTarget(enemy, 1200) then
			local buffedunit = findBuffUnit(enemy)
			if buffedunit then
				local dmg = CalcExpungeDamage(buffedunit)
				if dmg and enemy.health and dmg > enemy.health + enemy.shieldAD and CanCast(myHero, 2) and mainMenu.econfig.KillE:Value() then
					CastSpell(2)
				end
			end
		end
	end
end

function CalcExpungeDamage(buffedunit)
	local BaseDamage = {20, 35, 50, 65, 80}
	local PerStackDamage = {15, 20, 25, 30, 35}
	local PerStackADMod = .25

	local dmg = ((BaseDamage[GetCastLevel(myHero, 2)] + (PerStackDamage[GetCastLevel(myHero, 2)] * buffedunit[2])) + GetBonusDmg(myHero) * .25 * buffedunit[2]) * 1.05 - CalcArmor(buffedunit[1])
	return dmg
end

function CalcArmor(target)
	local arpflat = GetArmorPenFlat(myHero)
	local arpcent = GetArmorPenPercent(myHero)
	local targetarmor = GetArmor(target)
	targetarmor = targetarmor / 100 * (100 - arpcent)
	targetarmor = targetarmor - arpcent
	return targetarmor
end

OnLoad(function()
	TwitchMessage("loaded!")
	vishandle = VisionHandler()
	print(vishandle)
	autolevel()
	local orbwalker =  {"Disabled", "IOW", "DAC", "Platywalk", "GoSWalk"}
	orbwalker = orbwalker[mc_cfg_orb.orb:Value()]
end)

OnUpdateBuff(function(unit, buff)
	if buff.Name == "TwitchDeadlyVenom" and unit.team ~= myHero.team then
		buffedUnit = findBuffUnit(unit)
		if buffedUnit then
			buffedUnit[2] = buffedUnit[2] < 6 and buffedUnit[2] + 1 or 6
		else
			local newBuffedUnit = {unit, 1}
			table.insert(buffunits, newBuffedUnit)
		end
	elseif buff.Name == "TwitchHideInShadows" and unit.networkID == myHero.networkID then
		lastQCastTime = GetGameTimer()
		hasQBuff = true
	elseif buff.Name == "TwitchFullAutomatic" and unit.networkID == myHero.networkID then
		isulting = true

	--[[elseif buff.Name == "recall" and unit.networkID == myHero.networkID then
		if CanCast(myHero, 0) then
			CastSpell(0)
		end]]
	end
end)

--[[OnAnimation(function(unit, animation)
	if unit.networkID ~= myHero.networkID then return end


	if animation:lower():find("recall") and CanCast(myHero, 0) or animation == "Recall" and CanCast(myHero, 0) then
		DelayAction(function() CastTargetSpell(myHero, 0) print("lol") end, .5)
	end
end) You can't cast using OnAnimation, it refuses to cast abilities]]

OnSpellCast(function(spell)
	if spell.spellID == 13 and spell.targetID == myHero.networkID then
		CastSpell(0)
	end
end)

OnRemoveBuff(function(unit, buff)
	if buff.Name == "TwitchDeadlyVenom" then
		buffedUnitIndex = findBuffUnitIndex(unit)
		if buffedUnitIndex then
			table.remove(buffunits, buffedUnitIndex)
		end
	elseif buff.Name == "TwitchHideInShadows" then
		hasQBuff = false
	elseif buff.Name == "TwitchFullAutomatic" then
		isulting = false
	end
end)

OnWndMsg(function(Msg, Key)
	if IsChatOpened() then return end 

	--[[if Key == string.byte("B") and Msg == 256 then
		if CanCast(myHero, 0) then
			--CastSpell(0)
		end
		--This is THE ONLY method of stealth before recall outside of blocking recall packet, sending q cast then sending recall packet.
	else]]if Key == string.byte("I") and Msg == 256 then
		PrintItems()
	end
end)

OnObjectLoad(function(object)
	if object.type == Obj_AI_Shop and object.team == myHero.team then
		shop = object
	end
end)

OnTick(function()
	--coroutine.resume(coroutine.create(function()  attempt to index global 'coroutine' a nil value?!

	if shop and myHero:DistanceTo(shop) <= 1000 and GetLevel(myHero) >= 9 then
		BuyItem(items.trinket)
	end
	--[[if mainMenu.keyconfig.recall:Value() and CanCast(myHero, 0) then
		CastSpell(0)
		this is also too slow
	end]]
	--killsteal functions
	ExpungeToKill()

	--combo functions
	if mainMenu.keyconfig.combo:Value() then
		ExpungeOnStacked()
		if not isAttacking and not hasQBuff and myHero:DistanceTo(GetCurrentTarget()) >= GetRange(myHero) then
			TryW()
		end
		Ghostblade()
	end

	if mainMenu.keyconfig.clear:Value() then
		WClearMinions()
		EKillMinions()
	end
	--end))
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
		if mainMenu.keyconfig.combo:Value() then
			TryW()
		end
	end
end)

OnDraw(function()
	DrawQDistanceAvailable()
	for i, enemy in pairs(GetEnemyHeroes()) do
		if ValidTarget(enemy) and CanCast(myHero, 2) and findBuffUnit(enemy) then

			local eDmg = CalcExpungeDamage(findBuffUnit(enemy)) 

			if not eDmg then eDmg = 0 end

			DrawDmgOverHpBar(enemy, enemy.health, 100, 0, GoS.Blue)
		end
	end
end)

OnDrawMinimap(function()
DrawQDistanceMinimap()
end)
