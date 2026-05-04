ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleFormulas = ys.Battle.BattleFormulas
local BattleAttr = ys.Battle.BattleAttr
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleNPCUnit = class("BattleNPCUnit", ys.Battle.BattleEnemyUnit)

local BattleNPCUnit = ys.Battle.BattleNPCUnit

--- @class BattleNPCUnit
--- @param templateID number: 模板ID
--- @param extraData table: 额外数据(可包含template和attr)
--- @return nil
--- 设置模板：以MonsterTmpData为基础，支持通过extraData.template覆盖字段，通过extraData.attr设置属性
function BattleNPCUnit.SetTemplate(self, templateID, extraData)
	BattleNPCUnit.super.SetTemplate(self, templateID)

	-- 创建以MonsterTmpData为后备的元表代理，支持extraData.template覆盖
	self._tmpData = setmetatable({}, {
		__index = ys.Battle.BattleDataFunction.GetMonsterTmpDataFromID(self._tmpID)
	})

	if extraData.template then
		for iter_1_0, iter_1_1 in pairs(extraData.template) do
			self._tmpData[iter_1_0] = iter_1_1
		end

		self._tmpData.id = templateID
	end

	-- 设置属性：优先使用extraData.attr，否则使用默认SetAttr
	if extraData.attr then
		BattleAttr.SetAttr(self, extraData.attr)
	else
		self:SetAttr()
	end

	local currentHPValue = extraData.currentHP or self:GetMaxHP()

	self:SetCurrentHP(currentHPValue)
	self:InitCldComponent()
end
