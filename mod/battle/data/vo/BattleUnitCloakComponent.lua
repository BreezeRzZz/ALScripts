ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleAttr = ys.Battle.BattleAttr

ys.Battle.BattleUnitCloakComponent = class("BattleUnitCloakComponent")
ys.Battle.BattleUnitCloakComponent.__name = "BattleUnitCloakComponent"

-- 核心组件之一: 隐匿组件
local BattleUnitCloakComponent = ys.Battle.BattleUnitCloakComponent

BattleUnitCloakComponent.STATE_CLOAK = "STATE_CLOAK"
BattleUnitCloakComponent.STATE_UNCLOAK = "STATE_UNCLOAK"

-- 在BattleUnit.InitCloak调用, 挂载隐匿组件
function BattleUnitCloakComponent.Ctor(self, client)
	-- client指的是主体单位，也就是这个组件是挂在这个单位身上的
	self._client = client

	self:initCloak()
end

function BattleUnitCloakComponent.Update(self, timeStamp)
	self._lastCloakUpdateStamp = self._lastCloakUpdateStamp or timeStamp

	self:updateCloakValue(timeStamp)
	self:UpdateCloakState()

	self._lastCloakUpdateStamp = timeStamp
	-- DOT的暴露值更新在状态更新后, 这有点奇怪
	ys.Battle.BattleBuffDOT.UpdateCloakLock(self._client)
end

function BattleUnitCloakComponent.UpdateCloakConfig(self)
	self._exposeBase = BattleAttr.GetCurrent(self._client, "cloakExposeBase")
	self._exposeExtra = BattleAttr.GetCurrent(self._client, "cloakExposeExtra")
	self._restoreValue = BattleAttr.GetCurrent(self._client, "cloakRestore")
	self._recovery = BattleAttr.GetCurrent(self._client, "cloakRecovery")

	self:adjustCloakAttr()
	self._client:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_CLOAK_CONFIG))
end

function BattleUnitCloakComponent.SetRecoverySpeed(self, recoverySpeed)
	self._fieldRecoveryOverride = recoverySpeed
end

-- 提高暴露值("进度条"增加)
function BattleUnitCloakComponent.AppendExpose(self, exposeValue)
	local currentCloakValue = self._cloakValue + exposeValue
	local cloakBottom = self:GetCloakBottom()

	self._cloakValue = Mathf.Clamp(currentCloakValue, cloakBottom, self._exposeValue)

	self:UpdateCloakState()
end

function BattleUnitCloakComponent.AppendStrikeExpose(self)
	local exposedValue = math.min(self._strikeExposeAdditive * self._strikeCount, self._strikeExposeAdditiveLimit)

	self._strikeCount = self._strikeCount + 1

	self:AppendExpose(exposedValue)
end

function BattleUnitCloakComponent.AppendBombardExpose(self)
	local exposedValue = math.min(self._bombardExposeAdditive * self._bombardCount, self._bombardExposeAdditiveLimit)

	self._bombardCount = self._bombardCount + 1

	self:AppendExpose(exposedValue)
end

function BattleUnitCloakComponent.AppendExposeSpeed(self, exposeSpeed)
	self._exposeSpeed = exposeSpeed
end

-- 强制破隐
function BattleUnitCloakComponent.ForceToMax(self)
	self:ForceToRate(1)
end

function BattleUnitCloakComponent.ForceToRate(self, rate)
	self._cloakValue = math.floor(rate * self._exposeValue)

	self:UpdateCloakState()
end

-- 处理DOT类BuffEffect传来的暴露值更新请求
-- 被BattleUnit.CloakOnFire调用
-- DOT类的特点是会锁定隐匿下限. 在DOT存在期间, cloakValue不能落到此线之下
function BattleUnitCloakComponent.UpdateDotExpose(self, exposedValue)
	if exposedValue ~= self._cloakBottom then
		self._cloakBottom = exposedValue

		self._client:DispatchEvent(ys.Event.New(BattleUnitEvent.UPDATE_CLOAK_LOCK))
	end
end

-- 被BattleBuffTaunt用到. 用于强制暴露(设置暴露值下限).
function BattleUnitCloakComponent.UpdateTauntExpose(self, tauntExpose)
	if tauntExpose then
		self._tauntCloakBottom = self._restoreValue
	else
		self._tauntCloakBottom = nil
	end
end

function BattleUnitCloakComponent.UpdateCloakState(self)
	local currentState
	-- 大于隐匿上限, 破隐
	if self._cloakValue >= self._exposeValue then
		currentState = BattleUnitCloakComponent.STATE_UNCLOAK
	-- 小于隐匿回复线, 重新隐匿
	elseif self._cloakValue < self._restoreValue then
		currentState = BattleUnitCloakComponent.STATE_CLOAK
	end
	-- 状态发生了切换时, 相应修改属性并触发事件
	if currentState and currentState ~= self._currentState then
		self._currentState = currentState

		if self._currentState == BattleUnitCloakComponent.STATE_UNCLOAK then
			BattleAttr.Uncloak(self._client)
			self:triggerBuff()
		elseif self._currentState == BattleUnitCloakComponent.STATE_CLOAK then
			BattleAttr.Cloak(self._client)
			self:triggerBuff()
		end
	end
end

function BattleUnitCloakComponent.GetCloakValue(self)
	return self._cloakValue
end

function BattleUnitCloakComponent.GetCloakMax(self)
	return self._exposeValue
end

function BattleUnitCloakComponent.GetCloakLockMin(self)
	return self._fireLockValue
end

function BattleUnitCloakComponent.GetCloakRestoreValue(self)
	return self._restoreValue
end

function BattleUnitCloakComponent.GetCloakBottom(self)
	-- 强制暴露: 设置暴露值下限
	if self._tauntCloakBottom then
		return math.max(self._tauntCloakBottom, self._cloakBottom)
	else
		return self._cloakBottom
	end
end

function BattleUnitCloakComponent.GetCurrentState(self)
	return self._currentState
end

function BattleUnitCloakComponent.GetExposeSpeed(self)
	return self._exposeSpeed
end

function BattleUnitCloakComponent.updateCloakValue(self, timeStamp)
	local elapsedTime = timeStamp - self._lastCloakUpdateStamp
	local recovery = self._fieldRecoveryOverride or self._recovery
	local exposedValue = (self._exposeSpeed - recovery) * elapsedTime

	self:AppendExpose(exposedValue)
end

function BattleUnitCloakComponent.initCloak(self)
	-- 先明确定义: 
	-- 隐匿系统的核心属性是暴露值cloakValue. 暴露值有各种增加方式(如舰载机撞线、DOT等)
	--- (虽然理论上应该叫exposeValue, 但代码就这么写的. 注意区分cloakValue是那个"进度条", exposeValue是那个"上限", 这命名我也是醉了)
	-- 暴露值达到隐匿上限后，破隐(切换cloakState = 0).
	-- 只有当破隐者回落到隐匿回复线以下时，才能重新隐匿(切换cloakState = 1)
	-- 暴露值如何降低: 依靠隐匿回复速度，随着时间流逝自动降低
	-- (因此可以认为, "隐匿"和"暴露”是两个相对的概念，暴露值越高，隐匿状态越差)

	-- exposeBase: 隐匿基础上限
	-- 在BattleAttr.SetPlayerAttrFromOutBattle中, 设置为机动+50
	self._exposeBase = BattleAttr.GetCurrent(self._client, "cloakExposeBase")
	-- exposeExtra: 隐匿额外上限. 一般靠特定技能提供, 否则是0
	self._exposeExtra = BattleAttr.GetCurrent(self._client, "cloakExposeExtra")
	-- restoreValue: 隐匿回复线. 如果破隐, 需要到此值之下才能重新隐匿
	-- 为上述两者之和(即总上限)减去一个固定值(60)
	self._restoreValue = BattleAttr.GetCurrent(self._client, "cloakRestore")
	-- fireLockValue: 这没用过, 应该废弃了
	self._fireLockValue = BattleAttr.GetCurrent(self._client, "cloakFireLock")
	self._cloakValue = 0
	self._exposeSpeed = 0
	self._cloakBottom = 0

	self:adjustCloakAttr()
	-- recovery: 隐匿回复速度. 默认为5/s
	self._recovery = BattleAttr.GetCurrent(self._client, "cloakRecovery")
	-- strikeExposeAdditive: 每次空袭额外增加的暴露值. 默认6
	self._strikeExposeAdditive = BattleAttr.GetCurrent(self._client, "cloakStrikeAdditive")
	-- bombardExposeAdditive: 每次跨射额外增加的暴露值. 默认6
	self._bombardExposeAdditive = BattleAttr.GetCurrent(self._client, "cloakBombardAdditive")
	self._strikeCount = 0
	self._bombardCount = 0
	-- 额外上限均为60
	self._strikeExposeAdditiveLimit = BattleConfig.CLOAK_STRIKE_ADDITIVE_LIMIT
	self._bombardExposeAdditiveLimit = BattleConfig.CLOAK_STRIKE_ADDITIVE_LIMIT
	self._exposeDotList = {}
	-- 初始默认是隐匿状态
	self._currentState = BattleUnitCloakComponent.STATE_CLOAK
	-- 设置隐匿属性, 才能用这个属性
	BattleAttr.Cloak(self._client)
	self:triggerBuff()
end

function BattleUnitCloakComponent.triggerBuff(self)
	local isCloak = BattleAttr.GetCurrent(self._client, "isCloak")

	self._client:DispatchCloakStateUpdate()
end

function BattleUnitCloakComponent.adjustCloakAttr(self)
	-- CLOAK_EXPOSE_BASE_MIN = 100
	-- base最小是100
	self._exposeBase = math.max(self._exposeBase, BattleConfig.CLOAK_EXPOSE_BASE_MIN)
	-- CLOAK_EXPOSE_SKILL_MIN = 60
	-- exposeValue这里指的是隐匿上限(超过即破隐)
	self._exposeValue = math.max(self._exposeBase + self._exposeExtra, BattleConfig.CLOAK_EXPOSE_SKILL_MIN)
	-- CLOAK_BASE_RESTORE_DELTA = -60
	self._restoreValue = math.max(self._exposeValue + BattleConfig.CLOAK_BASE_RESTORE_DELTA, 0)
	self._cloakValue = Mathf.Clamp(self._cloakValue, 0, self._exposeValue)

	BattleAttr.SetCurrent(self._client, "cloakExposeBase", self._exposeBase)
	BattleAttr.SetCurrent(self._client, "cloakRestore", self._restoreValue)
	self:UpdateCloakState()
end
