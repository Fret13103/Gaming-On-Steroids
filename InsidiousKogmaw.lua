local myHero = GetMyHero()
if myHero.charName ~= "KogMaw" then return end

local Q = {delay = .25, speed=1425, width=70, range=1200}
local E = {delay = .25, speed=1300, width=120, range=1300}
local R = {delay= .7, speed=math.huge, width = 75, radius=150, range= 1200}

local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}
local mainMenu = Menu("kogmaw", "Insidious KogMaw") 

mainMenu:SubMenu("qconfig", "KogMaw: Q")
mainMenu.qconfig:Boolean("drawQrange", "Draw Q range", true)
mainMenu.qconfig:Boolean("ComboQ", "Use Q in combo", true)
mainMenu.qconfig:Boolean("HarassQ", "UseQ in harass", true)
mainMenu.qconfig:Boolean("KillQ", "Use Q to attempt kill steal", true)
mainMenu.qconfig:Slider("HitchanceQ", "Q hitchance", 0, .01, 1, .01)

mainMenu.qconfig:Info("blank", " ")
mainMenu.qconfig:Info("separator", "Laneclear")

mainMenu.qconfig:Boolean("MinionQ", "Use Q lasthit assister", true)
mainMenu.qconfig:Slider("MinionQMana", "Q lasthit min% mana to Q", 70, 1, 100, 1)

mainMenu:SubMenu("wconfig", "KogMaw: W")
mainMenu.wconfig:Boolean("ComboW", "Use W in combo", true)
mainMenu.wconfig:Boolean("drawWrange", "Draw W range", true)

mainMenu:SubMenu("econfig", "KogMaw: E")
mainMenu.econfig:Boolean("ComboE", "Use E in combo", true)
mainMenu.econfig:Boolean("HarassE", "Use E in harass", true)
mainMenu.econfig:Boolean("KillE", "Use E to attempt kill steal", true)
mainMenu.econfig:Slider("HitchanceE", "E hitchance", 0, .01, 1, .01)

mainMenu.econfig:Info("blank", " ")
mainMenu.econfig:Info("separator", "Laneclear")

mainMenu.econfig:Boolean("ShoveE", "Use E to shove", true)
mainMenu.econfig:Slider("EMinionsNumber", "E to hit x minions", 3, 1, 5, 1)

mainMenu:SubMenu("rconfig", "KogMaw: R")
mainMenu.rconfig:Boolean("ComboR", "Use R in combo", true)
mainMenu.rconfig:Slider("ComboManaR", "Combo min% mana to ult", 60, 1, 100, 1)
mainMenu.rconfig:Boolean("HarassR", "Use R in harass", true)
mainMenu.rconfig:Slider("HarassManaR", "Harass min% mana to ult", 60, 1, 100, 1)
mainMenu.rconfig:Slider("HitchanceR", "R hitchance", 0, .01, 1, .01)

mainMenu.rconfig:Info("blank", " ")
mainMenu.rconfig:Info("separator", "Laneclear")

mainMenu.rconfig:Boolean("ShoveR", "Use R to shove", true)
mainMenu.rconfig:Slider("RMinionsNumber", "R to hit x minions", 3, 1, 5, 1)
mainMenu.rconfig:Slider("ClearManaR", "Shove min% mana to ult", 60, 1, 100, 1)

mainMenu:SubMenu("cconfig", "KogMaw: Custom Settings")
mainMenu.cconfig:Boolean("forceweave", "Force spell weaving", false)

mainMenu:SubMenu("autolevel", "KogMaw: Autolevel")
mainMenu.autolevel:Boolean("allowLeveling", "Autolevel skills", true)

mainMenu:SubMenu("keyconfig", "KogMaw: Keys")
mainMenu.keyconfig:Key("combo", "Combo key", string.byte(" "))
mainMenu.keyconfig:Key("harass", "Harass key", string.byte("C"))
mainMenu.keyconfig:Key("clear", "Lane & Jungle clear", string.byte("V"))

local isAttacking = false 
local canAttack = true
local lastAAMinion = nil

local LaneClearMode = 1

function CanCast(champ, slot)
	return IsReady(slot)
end

class "autolevel"

function autolevel:__init() -- I would've done self.SkillOrders but it always returned nil... ?!?
	OnTick(function() autolevel:Tick() end)
end

function autolevel:Tick()
	if GetLevelPoints(myHero) > 0 and mainMenu.autolevel.allowLeveling:Value() then
		if (myHero.level + 1 - GetLevelPoints(myHero)) then
			local skillOrder = {1,0,2,1,1,3,	1,0,1,0,3,	0,0,2,2,3,	2,2}
			LevelSpell(skillOrder[myHero.level + 1 - GetLevelPoints(myHero)])
		end
	end
end

function qDmg(unit, timer)
	local Dmg = {80, 130, 180, 230, 280}
	Dmg = Dmg[GetCastLevel(myHero, 0)] + (GetBonusAP(myHero)/2)


	if not CanCast(myHero, 0) then return 0 end

	return CalcDamage(myHero, unit, 0 , Dmg)
end

function KogmawPredict(unit, slot)
	local skill

	if not ValidTarget(unit) then return 0 end

	if slot == 0 then 
		skill = Q
	elseif slot == 2 then
		skill = E
	elseif slot == 3 then
		skill = R
	end

	if skill == Q or skill == E then
		local pred = GetPrediction(unit, skill)
		return pred
	else
		local pred = GetCircularAOEPrediction(unit, skill)
		return pred
	end
end

function KogMawSkillShot(unit, slot)
	local skill
	local hitchance

	if not ValidTarget(unit) then return false end

	if slot == 0 then
		skill = Q
		hitchance = mainMenu.qconfig.HitchanceQ:Value()
	elseif slot == 2 then
		skill = E
		hitchance = mainMenu.econfig.HitchanceE:Value()
	elseif slot == 3 then
		skill = R
		hitchance = mainMenu.rconfig.HitchanceR:Value()
	end

	if not CanCast(myHero, slot) then return false end

	predict = KogmawPredict(unit, slot)

	if ValidTarget(unit, skill.range) and CanCast(myHero, slot) and predict.hitChance >= hitchance then
		if myHero:DistanceTo(predict.castPos) <= skill.range then
			if skill == Q then
				if not predict:mCollision(1) then
					CastSkillShot(slot, predict.castPos)
					return true
				end
				return false
			else
				CastSkillShot(slot, predict.castPos)
				return true
			end
		end
	end
	return false
end

function KogMawCombo(unit)
	if not ValidTarget(unit) then return end
	if isAttacking then return end

	if GetCastLevel(myHero, 1) > 0 then
		local wgains = {630 , 650 , 670 , 690 , 710}
		if myHero:DistanceTo(unit) <= (wgains[GetCastLevel(myHero, 1)]) then
			CastSpell(1)
		end
	end

	if KogMawSkillShot(unit, 0) then return end
	if KogMawSkillShot(unit, 2) then return end
	if myHero.mana < (myHero.maxMana/100 * mainMenu.rconfig.ComboManaR:Value()) then return end
	if KogMawSkillShot(unit, 3) then return end
end

function KogMawComboForce(unit)
	if not ValidTarget(unit) then return end

	if GetCastLevel(myHero, 1) > 0 and CanCast(myHero, 1) then
		local wgains = {130 , 150 , 170 , 190 , 210}
		if myHero:DistanceTo(unit) <= (GetRange(myHero) + wgains[GetCastLevel(myHero, 1)]) then
			CastSpell(1)
		end
	end

	if myHero.mana > (myHero.maxMana/100 * mainMenu.rconfig.ComboManaR:Value()) then
	if KogMawSkillShot(unit, 3) then return end
end
	if KogMawSkillShot(unit, 0) then return end
	if KogMawSkillShot(unit, 2) then return end
end

function KogMawHarass(unit)
	if not ValidTarget(unit) then return end
	if isAttacking then return end

	if GetCastLevel(myHero, 1) > 0 then
		local wgains = {760 , 790 , 810 , 850 , 890}
		if myHero:DistanceTo(unit) <= (wgains[GetCastLevel(myHero, 1)]) then
			CastSpell(1)
		end
	end

	if KogMawSkillShot(unit, 0) then return end
	if KogMawSkillShot(unit, 2) then return end
	if myHero.mana < (myHero.maxMana/100 * mainMenu.rconfig.HarassManaR:Value()) then return end
	if KogMawSkillShot(unit, 3) then return end
end

local polygons = {}

function KogMawClear()
	if mainMenu.keyconfig.clear:Value() then
		if not canAttack then
			if myHero.mana < (myHero.maxMana * mainMenu.qconfig.MinionQMana:Value() / 100) then return end
			if not mainMenu.qconfig.MinionQ:Value() then return end

			local lowestMinion = nil
			for i, minion in pairs(minionManager.objects) do
				if minion ~= LastAAMinion and ValidTarget(minion, Q.range) then
					if lowestMinion == nil then lowestMinion = minion elseif minion.health < lowestMinion.health then lowestMinion = minion end
				end
			end

			if ValidTarget(lowestMinion) then
				local dmg = qDmg(lowestMinion)
				if dmg > lowestMinion.health then
					KogMawSkillShot(lowestMinion, 0)
					return
				end
			end
		end
		if LaneClearMode == 2 then --shove logics
			for i, minion in pairs(minionManager.objects) do
				if ValidTarget(minion, E.range) and mainMenu.econfig.ShoveE:Value() then

					local vectorTo = Vector(GetOrigin(minion)) - Vector(GetOrigin(myHero))

					local vectorLeft = vectorTo:perpendicular()
					local vectorRight = vectorTo:perpendicular2()

					local start = Vector(GetOrigin(myHero))

					local minionsinrange = {}
					for i, minion in pairs(minionManager.objects) do
						if ValidTarget(minion, E.range) then
							table.insert(minionsinrange, minion)
						end
					end

					local minionshitbyE = CountObjectsOnLineSegment(start, start + (vectorTo:normalized() * E.range), E.width, minionsinrange, nil)
					if minionshitbyE >= mainMenu.econfig.EMinionsNumber:Value() then
						CastSkillShot(2, start + (vectorTo:normalized() * E.range))
					end
				end
				if ValidTarget(minion, R.range) and mainMenu.rconfig.ShoveR:Value() then
					if myHero.mana <= (myHero.maxMana /100 * mainMenu.rconfig.ClearManaR:Value()) then return end
					local minionsHit = {}
					for i, creep in pairs(minionManager.objects) do
						if ValidTarget(creep) and minion:DistanceTo(creep) <= R.radius then
							table.insert(minionsHit, creep)
						end
					end
					if #minionsHit >= mainMenu.rconfig.RMinionsNumber:Value() then
						CastSkillShot(3, GetOrigin(minion))
					end
				end
			end
		end
	end
end

OnLoad(function()
	autolevel()
end)

OnTick(function()
	local target = GetCurrentTarget()

	if mainMenu.keyconfig.combo:Value() then
		KogMawCombo(target)
	elseif mainMenu.keyconfig.harass:Value() then
		KogMawHarass(target)
	elseif mainMenu.keyconfig.clear:Value() then
		KogMawClear()
	end
end)

OnDraw(function()
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
	if GetCastLevel(myHero, 1) > 0 and mainMenu.wconfig.drawWrange:Value() then
		local wgains = {760 , 790 , 810 , 850 , 890}
		range = wgains[GetCastLevel(myHero, 1)]
		DrawCircle(GetOrigin(myHero), range, 1, 10, GoS.White)
	end
	for i, poly in pairs(polygons) do
		poly:draw(GoS.White, 10)
	end
end)

OnProcessSpellAttack(function(unit, spell)
	if unit == myHero and spell.name:find("Attack") then
		--print(spell.name)
		canAttack = false
		lastAAMinion = spell.target
		DelayAction(function() lastAAMinion = nil end, spell.windUpTime + (myHero:DistanceTo(spell.target)/1800))
		DelayAction(function() canAttack = true end, spell.windUpTime + 1/(GetBaseAttackSpeed(myHero) * GetAttackSpeed(myHero)))
		isAttacking = true
	end
end)

OnProcessSpellComplete(function(unit, spell)
	if unit == myHero and spell.name:find("Attack") then
		isAttacking = false

		if not mainMenu.cconfig.forceweave:Value() then return end
		if not mainMenu.keyconfig.combo:Value() then return end

		if spell.target.type == "AIHeroClient" then
			KogMawComboForce(spell.target)
		end
	end
end)

function IsKeyHeld(Key)
	for i, entry in pairs(heldKeys) do
		if entry == Key then
			return true
		end
	end
	return false
end

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
