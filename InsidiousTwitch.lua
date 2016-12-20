local myHero = GetMyHero()

if GetObjectName(myHero) ~= "Twitch" then return end

local LocalVersion = 1

local UpdateURL = ""

AutoUpdater(LocalVersion, 
 true, 
 raw.githubusercontent.com, 
 "/Fret13103/Gaming-On-Steroids/master/InsidiousTwitch.ver.lua", 
 "/Fret13103/Gaming-On-Steroids/master/InsidiousTwitch.lua", 
 SCRIPT_PATH .. "InsidiousTwitch.lua", 
 function() print("UPDATE!") return end, 
 function() print("NO UPDATE!") return end, 
 function() print("THERE IS A NEW VERSION!") return end, 
 function() print("FAILED UPDATE!") return end)

if not pcall( require, "OpenPredict" ) then PrintChat("Please install OpenPredict!") return end

local buffunits = {} --{unit, stacks}

local skills = {
	W = { delay = 0.1, speed = 1400, width = 55, range = 950, radius = 275 },
	E = {	range = 1200}
}

local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}

local items = {trinket = 3363, bork = 3153, cutlass = 3144, youmuus = 3142}
local storepos = Vector(400, 182, 400)

local mainMenu = Menu("twitch", "Insidious Twitch")
mainMenu:SubMenu("econfig", "Twitch: E")
mainMenu.econfig:Boolean("KillE", "Use E to kill champions", true)
mainMenu.econfig:Boolean("StacksE", "Use E at 6 stacks", true)

mainMenu.econfig:Info("blank", " ")
mainMenu.econfig:Info("separator", "Laneclear")

mainMenu.econfig:Boolean("MinionE", "Use E to kill minions", true)
mainMenu.econfig:Slider("KillMinionsNumber", "E to kill x minions", 3, 1, 5, 1)

mainMenu:SubMenu("wconfig", "Twitch: W")
mainMenu.wconfig:Boolean("ComboW", "Use W in combo", true)
mainMenu.wconfig:Boolean("GapcloseW", "Antigapclose W", true)
mainMenu.wconfig:Slider("HitchanceW", "W hitchance", 0, .01, 1, .01)

mainMenu.wconfig:Info("blank", " ")
mainMenu.wconfig:Info("separator", "Laneclear") --SEPARATOR 

mainMenu.wconfig:Boolean("laneclearW", "Use W in laneclear", true)
mainMenu.wconfig:Slider("SplashMinionsNumber", "W to poison x minions", 4, 1, 7, 1)


mainMenu:SubMenu("keyconfig", "Twitch: Keys")
mainMenu.keyconfig:Key("combo", "Combo key", string.byte(" "))
mainMenu.keyconfig:Key("clear", "Lane & Jungle clear", string.byte("V"))

local shop = nil
--IsChatOpen? IsChatOpened?

--BuyItem(ID)


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
				if numhit >= minhit and CanUseSpell(myHero, 1) then
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
		if CanUseSpell(myHero, 1) and WCanHit(GetCurrentTarget()) and mainMenu.keyconfig.combo:Value() then
			CastSkillShot(1, WCanHit(GetCurrentTarget()))
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
		if numkill > minkill and CanUseSpell(myHero, 2) then
			CastSpell(2)
		end
	end
end

function ExpungeOnStacked()
	for i, enemy in pairs(GetEnemyHeroes()) do
		local buffedUnit = findBuffUnit(enemy)
		if buffedUnit and buffedUnit[2] == 6 and CanUseSpell(myHero, 2) and ValidTarget(enemy, skills.E.range) and mainMenu.keyconfig.combo and mainMenu.econfig.StacksE:Value() then
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
				if dmg and enemy.health and dmg > enemy.health and CanUseSpell(myHero, 2) and mainMenu.econfig.KillE:Value() then
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
	PrintChat("<font color=\"#00f0ff\"><b>Insidious Twitch:</b></font><font color=\"#ffffff\"> loaded!</font>")
end)

OnUpdateBuff(function(unit, buff)
	if ValidTarget(unit, 1000) then
		if buff.Name == "TwitchDeadlyVenom" then
			buffedUnit = findBuffUnit(unit)
			if buffedUnit then
				buffedUnit[2] = buffedUnit[2] < 6 and buffedUnit[2] + 1 or 6
			else
				local newBuffedUnit = {unit, 1}
				table.insert(buffunits, newBuffedUnit)
			end
		end
	end
end)

OnRemoveBuff(function(unit, buff)
	if buff.Name == "TwitchDeadlyVenom" then
		buffedUnitIndex = findBuffUnitIndex(unit)
		if buffedUnitIndex then
			table.remove(buffunits, buffedUnitIndex)
		end
	end
end)

OnWndMsg(function(Msg, Key)
	if Key == string.byte("B") and Msg == 256 and not IsChatOpened() then
		if CanUseSpell(myHero, 0) then
			CastSpell(0)
		end
	elseif Key == string.byte("I") and Msg == 256 then
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
	if shop and myHero:DistanceTo(shop) <= 800 and GetLevel(myHero) >= 9 then
		BuyItem(items.trinket)
	end
	--killsteal functions
	ExpungeToKill()

	--combo functions
	if mainMenu.keyconfig.combo:Value() then
		ExpungeOnStacked()
		TryW()
	end

	if mainMenu.keyconfig.clear:Value() then
		WClearMinions()
		EKillMinions()
	end
	--end))
end)

OnDraw(function()
	for i, enemy in pairs(GetEnemyHeroes()) do
		if ValidTarget(enemy) and CanUseSpell(myHero, 2) and findBuffUnit(enemy) then

			local eDmg = CalcExpungeDamage(findBuffUnit(enemy)) 

			if not eDmg then eDmg = 0 end

			DrawDmgOverHpBar(enemy, enemy.health, 100, 0, GoS.Red)
		end
	end
end)
