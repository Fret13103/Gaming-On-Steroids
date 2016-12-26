
class "EnemyData"

require "MapPositionGOS"

function EnemyData:__init(char, lastseen, lastpos)
	return {Hero = char, LastSeen = lastseen, LastPos = lastpos}
end


class "VisionHandler"

function VisionHandler:__init()
	self.VisibleEnemies = {}
	self.EnemyDatas = {}
	self.BlueTrinketID = 3363
	self.DefaultTrinketID = 3340

	for i, unit in pairs(GetEnemyHeroes())
		table.insert(self.EnemyDatas, EnemyData(unit, GetGameTimer(), Vector3(0,0,0)))
	end
end

function VisionHandler:GetVisibleEnemies()
	local visibles = {}
	for i, unit in pairs(GetEnemyHeroes())
		if unit.visible then
			table.insert(visibles, unit)
		end
	end
	return visibles
end

function VisionHandler:Tick()
	self.VisibleEnemies = VisionHandler:GetVisibleEnemies()
	for _, enemy in pairs(self.VisibleEnemies) do
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
end

function VisionHandler:LastSeenTime(unit)
	for _, enemydata in pairs(self.EnemyDatas) do
		if enemydata.Hero.networkID == unit.networkID then
			return MapPositionGos:inBush(enemydata.LastSeen)
		end
	end
end

function VisionHandler:UseTrinket(pos)
	local itemconstants = {ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}

	for _, item in pairs(itemconstants) do
		if GetItemID(myHero, item) == self.DefaultTrinketID then
			if myHero:DistanceTo(pos) <= 900 then
				CastSpell(item, pos)
			end
		elseif GetItemID(myHero, item) == self.BlueTrinketID then
			if myHero:DistanceTo(pos) <= GetRange(myHero) then
				CastSpell(item, pos)
			end
		end
	end
end
