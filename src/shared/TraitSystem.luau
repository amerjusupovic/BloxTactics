--[[
	TraitSystem.luau
	Shared trait computation and application logic.
	Server uses this for battle prep; client can use exported metadata for UI.
]]

local Constants = require(script.Parent.Constants)
local DataStructures = require(script.Parent.DataStructures)
local BoardState = DataStructures.BoardState
local Unit = DataStructures.Unit

local TraitSystem = {}

-- Returns mapping traitId -> {count:number, active:boolean, units:{Unit}}
function TraitSystem.computeBoardTraits(boardState: BoardState): {[string]: any}
	local result = {}
	if not boardState or not boardState.grid then return result end
	for pos, unit in pairs(boardState.grid) do
		if unit and unit.traits then
			for _, trait in ipairs(unit.traits) do
				local entry = result[trait]
				if not entry then
					entry = {count = 0, active = false, units = {}}
					result[trait] = entry
				end
				entry.count += 1
				table.insert(entry.units, unit)
			end
		end
	end
	-- Mark active
	for trait, data in pairs(result) do
		local def = Constants.TRAITS[trait]
		if def and data.count >= def.requirement then
			data.active = true
		end
	end
	return result
end

-- Battle prep: apply pre-battle bonuses (shields, juggernaut DR) to a list of battle units
-- battleUnits: { { unit=Unit, model=Model, originalHexName=string, maxHealth:number, ... } }
function TraitSystem.applyPreBattleBonuses(battleUnits)
	-- Build counts and index by trait
	local counts = {}
	for _, bu in ipairs(battleUnits) do
		local unit = bu.unit
		if unit and unit.traits then
			for _, trait in ipairs(unit.traits) do
				counts[trait] = (counts[trait] or 0) + 1
			end
		end
	end

	local function hasActive(trait)
		local def = Constants.TRAITS[trait]
		return def and counts[trait] and counts[trait] >= def.requirement
	end

	-- Pre-calc coordinate map from hex name (Hex_row_col)
	local coordMap = {}
	for _, bu in ipairs(battleUnits) do
		if bu.originalHexName then
			local row,col = string.match(bu.originalHexName, "Hex_(%d+)_(%d+)")
			if row and col then
				coordMap[bu] = {row = tonumber(row), col = tonumber(col)}
			end
		end
	end

	-- Medieval: apply 20% max health shield to adjacent allies to any Medieval unit
	if hasActive("Medieval") then
		for _, bu in ipairs(battleUnits) do
			local unit = bu.unit
			if unit and unit.traits then
				local isMedieval = table.find(unit.traits, "Medieval") ~= nil
				if isMedieval then
					local c = coordMap[bu]
					if c then
						for other, oc in pairs(coordMap) do
							if other ~= bu then
								if math.abs(oc.row - c.row) <= 1 and math.abs(oc.col - c.col) <= 1 then
									-- Grant shield once; use attribute shield on battleUnit
									if not other.shield or other.shield < 0 then other.shield = 0 end
									other.shield += math.floor(0.2 * (other.maxHealth or 0))
									if other.model then
										other.model:SetAttribute("Shield", other.shield)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- Juggernaut: 15% damage reduction to Juggernaut units while active
	if hasActive("Juggernaut") then
		for _, bu in ipairs(battleUnits) do
			local unit = bu.unit
			if unit and unit.traits and table.find(unit.traits, "Juggernaut") then
				bu.damageReduction = 0.15
				if bu.model then bu.model:SetAttribute("DamageReduction", bu.damageReduction) end
			end
		end
	end

	-- Ranger stacks start at zero; just mark if active
	local rangerActive = hasActive("Ranger")
	if rangerActive then
		for _, bu in ipairs(battleUnits) do
			if bu.unit.traits and table.find(bu.unit.traits, "Ranger") then
				bu.rangerStacks = 0
			end
		end
	end

	-- Mystic / Artillerist have purely runtime effects handled during attacks; we just mark active flags for team
	return {
		active = counts,
		isActive = function(trait) return hasActive(trait) end
	}
end

return TraitSystem
