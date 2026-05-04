ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent

ys.Battle.BattleNPCCharacter = class("BattleNPCCharacter", ys.Battle.BattleEnemyCharacter)
ys.Battle.BattleNPCCharacter.__name = "BattleNPCCharacter"

local BattleNPCCharacter = ys.Battle.BattleNPCCharacter

--- 构造函数：初始化前摇绑定标志
function BattleNPCCharacter.Ctor(self)
	BattleNPCCharacter.super.Ctor(self)

	self._preCastBound = false
end

--- 设置HP条颜色
--- @param color Color HP颜色
function BattleNPCCharacter.SetHPColor(self, color)
	self._HPColor = color
end

--- @return Color|nil HP颜色
function BattleNPCCharacter.GetHPColor(self)
	return self._HPColor
end

--- 设置自定义prefab（覆盖模板默认值）
--- @param prefabName string Prefab名称
function BattleNPCCharacter.SetModleID(self, prefabName)
	self._prefab = prefabName
end

--- 获取模型ID：优先使用自定义prefab
--- @return string Prefab名称
function BattleNPCCharacter.GetModleID(self)
	if self._prefab then
		return self._prefab
	else
		return self._unitData:GetTemplate().prefab
	end
end

--- 标记为不可见（将在MakeVisible时隐藏）
function BattleNPCCharacter.SetUnvisible(self)
	self._isUnvisible = true
end

--- 应用不可见标记：隐藏模型、HP条、Buff条
function BattleNPCCharacter.MakeVisible(self)
	if self._isUnvisible then
		self._go:SetActive(false)
		self._HPBar:SetActive(false)
		self._buffBar:SetActive(false)
	end
end
