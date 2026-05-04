ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviour = class("BattleEnvironmentBehaviour")

ys.Battle.BattleEnvironmentBehaviour = BattleEnvironmentBehaviour
BattleEnvironmentBehaviour.__name = "BattleEnvironmentBehaviour"
BattleEnvironmentBehaviour.STATE_DELAY = "STATE_DELAY"
BattleEnvironmentBehaviour.STATE_READY = "STATE_READY"
BattleEnvironmentBehaviour.STATE_OVERHEAT = "STATE_OVERHEAT"
BattleEnvironmentBehaviour.STATE_EXPIRE = "STATE_EXPIRE"

--- @class BattleEnvironmentBehaviour 战场环境行为基类，管理延迟/冷却/生命周期状态机
--- @field _cldUnitList table 碰撞单位列表
--- @field _unit BattleEnvironmentUnit 关联的环境单元
--- @field _tmpData table 行为模板数据(来自battle_environment_behaviour_template)
--- @field _state string 当前状态(STATE_DELAY/READY/OVERHEAT/EXPIRE)
--- @field _delayStartTime number 延迟开始时间戳
--- @field _liftStartTime number 生命周期开始时间戳
--- @field _CDstartTime number 冷却开始时间戳
--- @field _diveFilter table 潜水状态过滤表
function BattleEnvironmentBehaviour.Ctor(self, _, _)
	self._cldUnitList = {}
end

--- 绑定所属环境单元
--- @param unit BattleEnvironmentUnit
function BattleEnvironmentBehaviour.SetUnitRef(self, unit)
	assert(unit, "Shounld Bind A Unit")

	self._unit = unit
end

--- 设置行为模板，初始化延迟/生命期/潜水过滤
--- @param tmpData table 行为配置数据
function BattleEnvironmentBehaviour.SetTemplate(self, tmpData)
	self._tmpData = tmpData

	if self._tmpData.delay then
		self._delayStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
		self._state = BattleEnvironmentBehaviour.STATE_DELAY
	else
		self._state = BattleEnvironmentBehaviour.STATE_READY
	end

	if self._tmpData.life_time then
		self._liftStartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end

	self._diveFilter = self._tmpData.diveFilter or {}
end

--- 更新碰撞单位列表，按 diveFilter 过滤潜水状态不符的单位
--- @param cldUnitList table 待过滤的碰撞单位列表
function BattleEnvironmentBehaviour.UpdateCollideUnitList(self, cldUnitList)
	if #self._diveFilter ~= 0 then
		local len = #cldUnitList

		while len > 0 do
			local oxyState = cldUnitList[len]:GetCurrentOxyState()

			for _, filterState in ipairs(self._diveFilter) do
				if oxyState == filterState then
					table.remove(cldUnitList, len)

					break
				end
			end

			len = len - 1
		end
	end

	self._cldUnitList = cldUnitList
end

--- 每帧更新：依次处理延迟、冷却、生命周期
function BattleEnvironmentBehaviour.OnUpdate(self)
	self:updateDelay()
	self:updateReload()
	self:updateLifeTime()

	if self._state == BattleEnvironmentBehaviour.STATE_READY then
		self:doBehaviour()
	end
end

--- 释放资源
function BattleEnvironmentBehaviour.Dispose(self)
	self._cldUnitList = nil
	self._tmpData = nil
	self._CDstartTime = nil
end

--- 碰撞回调（子类可重写）
function BattleEnvironmentBehaviour.OnCollide(self, _)
	return
end

--- 获取当前状态
--- @return string state
function BattleEnvironmentBehaviour.GetCurrentState(self)
	return self._state
end

--- 检查延迟是否完成，完成则进入冷却处理
function BattleEnvironmentBehaviour.updateDelay(self)
	if self._delayStartTime and self._tmpData.delay + self._delayStartTime <= pg.TimeMgr.GetInstance():GetCombatTime() then
		self._delayStartTime = nil

		self:handleCoolDown()
	end
end

--- 检查冷却是否完成，完成则恢复就绪
function BattleEnvironmentBehaviour.updateReload(self)
	if self._CDstartTime then
		if self:getReloadFinishTimeStamp() <= pg.TimeMgr.GetInstance():GetCombatTime() then
			self:handleCoolDown()
		else
			return
		end
	end
end

--- 检查生命周期是否已过，是则标记过期并执行doExpire
function BattleEnvironmentBehaviour.updateLifeTime(self)
	if self._liftStartTime and self._liftStartTime + self._tmpData.life_time <= pg.TimeMgr.GetInstance():GetCombatTime() then
		self._state = BattleEnvironmentBehaviour.STATE_EXPIRE

		self:doExpire()
	end
end

--- 计算冷却完成时间戳
--- @return number
function BattleEnvironmentBehaviour.getReloadFinishTimeStamp(self)
	return self._tmpData.reload_time + self._CDstartTime
end

--- 冷却完成，恢复就绪状态
function BattleEnvironmentBehaviour.handleCoolDown(self)
	self._state = BattleEnvironmentBehaviour.STATE_READY
	self._CDstartTime = nil
end

--- 执行行为：若有冷却时间则进入过热状态
function BattleEnvironmentBehaviour.doBehaviour(self)
	if self._tmpData.reload_time then
		self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
		self._state = BattleEnvironmentBehaviour.STATE_OVERHEAT
	end
end

--- 过期处理
function BattleEnvironmentBehaviour.doExpire(self)
	self._state = BattleEnvironmentBehaviour.STATE_EXPIRE
end

--- 行为类型枚举到类名的映射表
BattleEnvironmentBehaviour.BehaviourClassEnum = {
	[BattleConst.EnviroumentBehaviour.PLAY_FX] = "BattleEnvironmentBehaviourPlayFX",
	[BattleConst.EnviroumentBehaviour.DAMAGE] = "BattleEnvironmentBehaviourDamage",
	[BattleConst.EnviroumentBehaviour.BUFF] = "BattleEnvironmentBehaviourBuff",
	[BattleConst.EnviroumentBehaviour.MOVEMENT] = "BattleEnvironmentBehaviourMovement",
	[BattleConst.EnviroumentBehaviour.FORCE] = "BattleEnvironmentBehaviourForce",
	[BattleConst.EnviroumentBehaviour.SPAWN] = "BattleEnvironmentBehaviourSpawn",
	[BattleConst.EnviroumentBehaviour.PLAY_SFX] = "BattleEnvironmentBehaviourPlaySFX",
	[BattleConst.EnviroumentBehaviour.SHAKE_SCREEN] = "BattleEnvironmentBehaviourShakeScreen"
}

--- 工厂方法：根据行为模板type字段创建对应子类实例
--- @param tmpData table 行为模板数据（含type字段）
--- @return BattleEnvironmentBehaviour
function BattleEnvironmentBehaviour.CreateBehaviour(tmpData)
	return ys.Battle[BattleEnvironmentBehaviour.BehaviourClassEnum[tmpData.type]].New()
end
