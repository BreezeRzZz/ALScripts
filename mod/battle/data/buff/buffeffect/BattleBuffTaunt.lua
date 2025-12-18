ys = ys or {}

local ys = ys
local BattleAttr = ys.Battle.BattleAttr
local BattleBuffTaunt = class("BattleBuffTaunt", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffTaunt = BattleBuffTaunt
BattleBuffTaunt.__name = "BattleBuffTaunt"

function BattleBuffTaunt.Ctor(self, effectData)
	BattleBuffTaunt.super.Ctor(self, effectData)

	self._tauntActive = false
end

function BattleBuffTaunt.SetArgs(self, owner, buff)
	self._guardTargetFilter = self._tempData.arg_list.guardTarget
	self._handleCloak = owner:GetCloak() ~= nil
end

function BattleBuffTaunt.onTrigger(self, owner, buff, attach)
	if not self._handleCloak then
		return
	end

	local targetList = self:getTargetList(owner, self._guardTargetFilter, self._tempData.arg_list)
	local isCloak = true

	for _, target in ipairs(targetList) do
		isCloak = isCloak and BattleAttr.IsCloak(target)
	end
	-- 若存在被保护的队友暴露了，则强制自己暴露
	if not isCloak and not self._tauntActive then
		self:forceToExpose(owner)
	elseif isCloak and self._tauntActive then
		self:releaseExpose(owner)
	end
end

function BattleBuffTaunt.onRemove(self, owner, buff, attach)
	self:releaseExpose(owner)
end

function BattleBuffTaunt.forceToExpose(self, owner)
	if not self._handleCloak then
		return
	end

	self._tauntActive = true
	--- @type BattleUnitCloakComponent
	local cloak = owner:GetCloak()

	cloak:ForceToMax()
	cloak:UpdateTauntExpose(true)
end

function BattleBuffTaunt.releaseExpose(self, owner)
	if not self._handleCloak then
		return
	end

	self._tauntActive = false
	--- @type BattleUnitCloakComponent
	local cloak = owner:GetCloak()

	cloak:UpdateTauntExpose(false)
end
