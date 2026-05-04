ys = ys or {}

local ys = ys
local BattleEvent = ys.Battle.BattleEvent
local BattleFormulas = ys.Battle.BattleFormulas
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleTeamVO = class("BattleTeamVO")

ys.Battle.BattleTeamVO = BattleTeamVO
BattleTeamVO.__name = "BattleTeamVO"

--- @class BattleTeamVO
--- @param teamID number 队伍ID
--- @return nil
--- 敌方小队VO的构造函数
function BattleTeamVO.Ctor(self, teamID)
	self._teamID = teamID

	self:init()
end

--- @return nil
--- 更新小队整体位置（基于motionReferenceUnit）
function BattleTeamVO.UpdateMotion(self)
	if self._motionReferenceUnit then
		self._motionVO:UpdatePos(self._motionReferenceUnit)
		self._motionVO:UpdateSpeed(self._motionReferenceUnit:GetSpeed())
	end
end

--- @return boolean
--- 小队是否已全灭（存活单位数为0）
function BattleTeamVO.IsFatalDamage(self)
	return self._count == 0
end

--- @param unit BattleUnit 敌方单位
--- @return nil
--- 添加单位到小队，刷新阵型
function BattleTeamVO.AppendUnit(self, unit)
	unit:SetMotion(self._motionVO)

	self._enemyList[#self._enemyList + 1] = unit
	self._count = self._count + 1

	self:refreshTeamFormation()
	unit:SetTeamVO(self)
end

--- @param unit BattleUnit 要移除的单位
--- @return nil
--- 从小队中移除单位，清除其TeamVO引用
function BattleTeamVO.RemoveUnit(self, unit)
	local removeIndex = 0

	for index, enemy in ipairs(self._enemyList) do
		if enemy == unit then
			removeIndex = index

			break
		end
	end

	table.remove(self._enemyList, removeIndex)

	self._count = self._count - 1

	unit:SetTeamVO(nil)
	self:refreshTeamFormation()
end

--- @return nil
--- 初始化小队数据
function BattleTeamVO.init(self)
	self._enemyList = {}
	self._motionVO = ys.Battle.BattleFleetMotionVO.New()
	self._count = 0
end

--- @return nil
--- 刷新小队阵型：根据pos_offset计算每个单位的位置偏移
--- 第一个单位作为motionReferenceUnit，不跟随编队
function BattleTeamVO.refreshTeamFormation(self)
	local posIndex = 1
	local enemyCount = #self._enemyList
	local indexList = {}

	while posIndex <= enemyCount do
		indexList[#indexList + 1] = posIndex
		posIndex = posIndex + 1
	end

	local posOffset = BattleDataFunction.GetFormationTmpDataFromID(BattleConfig.FORMATION_ID).pos_offset

	self._enemyList = BattleDataFunction.SortFleetList(indexList, self._enemyList)

	local bornOffset = BattleConfig.BornOffset

	for index, enemy in ipairs(self._enemyList) do
		if index == 1 then
			self._motionReferenceUnit = enemy

			enemy:CancelFollowTeam()
		else
			local offset = posOffset[index]

			enemy:UpdateFormationOffset(Vector3(offset.x, offset.y, offset.z) + bornOffset * (index - 1))
		end
	end
end

--- @return nil
function BattleTeamVO.Dispose(self)
	self._enemyList = nil
	self._motionReferenceUnit = nil
	self._motionVO = nil
end
