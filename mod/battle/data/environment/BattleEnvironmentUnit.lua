ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleEnvironmentUnit = class("BattleEnvironmentUnit")

ys.Battle.BattleEnvironmentUnit = BattleEnvironmentUnit
BattleEnvironmentUnit.__name = "BattleEnvironmentUnit"

--- @class BattleEnvironmentUnit 战场环境单元，管理AOE区域和关联的行为组件
--- @field _uid number 环境单元唯一ID
--- @field _template table 环境模板数据
--- @field _aoeData table AOE区域数据
--- @field _expireTimeStamp number 过期时间戳
--- @field _behaviours table 行为组件列表
--- @field _callback function 移除时的回调
function BattleEnvironmentUnit.Ctor(self, uid, _)
	ys.EventDispatcher.AttachEventDispatcher(self)

	self._uid = uid
end

--- 配置回调函数，环境单元移除时触发
--- @param callback function
function BattleEnvironmentUnit.ConfigCallback(self, callback)
	self._callback = callback
end

--- 获取环境单元唯一ID
--- @return number uid
function BattleEnvironmentUnit.GetUniqueID(self)
	return self._uid
end

--- 设置环境模板，并初始化行为组件列表
--- @param template table 环境模板数据
function BattleEnvironmentUnit.SetTemplate(self, template)
	self._template = template

	self:initBehaviours()
end

--- 设置AOE区域数据，同步计算过期时间
--- @param aoeData table AOE区域数据
function BattleEnvironmentUnit.SetAOEData(self, aoeData)
	self._expireTimeStamp = pg.TimeMgr.GetInstance():GetCombatTime() + self._template.life_time
	self._aoeData = aoeData
end

--- 获取AOE区域数据
--- @return table aoeData
function BattleEnvironmentUnit.GetAOEData(self)
	return self._aoeData
end

--- 获取所有行为组件
--- @return table behaviours
function BattleEnvironmentUnit.GetBehaviours(self)
	return self._behaviours
end

--- 获取环境模板
--- @return table template
function BattleEnvironmentUnit.GetTemplate(self)
	return self._template
end

--- 频繁碰撞更新：将碰撞单位列表分发给每个行为组件
function BattleEnvironmentUnit.UpdateFrequentlyCollide(self, cldUnitList)
	for _, behaviour in ipairs(self._behaviours) do
		behaviour:UpdateCollideUnitList(cldUnitList)
	end
end

--- 每帧更新，驱动所有行为组件的OnUpdate
function BattleEnvironmentUnit.Update(self)
	for _, behaviour in ipairs(self._behaviours) do
		behaviour:OnUpdate()
	end
end

--- 检查环境单元是否已过期
--- @param timeStamp number 当前战斗时间戳
--- @return boolean
function BattleEnvironmentUnit.IsExpire(self, timeStamp)
	return timeStamp > self._expireTimeStamp
end

--- 销毁环境单元，触发回调并释放所有行为组件
function BattleEnvironmentUnit.Dispose(self)
	if self._callback then
		self._callback()
	end

	for _, behaviour in ipairs(self._behaviours) do
		behaviour:Dispose()
	end
end

--- 从模板查询行为列表，创建并绑定各行为组件
function BattleEnvironmentUnit.initBehaviours(self)
	self._behaviours = {}

	local behaviourData = BattleDataFunction.GetEnvironmentBehaviour(self._template.behaviours).behaviour_list

	for _, behaviourTmp in ipairs(behaviourData) do
		local behaviour = ys.Battle.BattleEnvironmentBehaviour.CreateBehaviour(behaviourTmp)

		behaviour:SetUnitRef(self)
		behaviour:SetTemplate(behaviourTmp)
		table.insert(self._behaviours, behaviour)
	end
end
