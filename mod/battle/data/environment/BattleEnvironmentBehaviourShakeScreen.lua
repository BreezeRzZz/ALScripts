ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourShakeScreen = class("BattleEnvironmentBehaviourShakeScreen", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourShakeScreen = BattleEnvironmentBehaviourShakeScreen
BattleEnvironmentBehaviourShakeScreen.__name = "BattleEnvironmentBehaviourShakeScreen"

--- @class BattleEnvironmentBehaviourShakeScreen : BattleEnvironmentBehaviour
--- 环境震屏行为：触发屏幕震动效果
function BattleEnvironmentBehaviourShakeScreen.Ctor(self)
	BattleEnvironmentBehaviourShakeScreen.super.Ctor(self)
end

--- 读取shake_ID
--- @param tmpData table
function BattleEnvironmentBehaviourShakeScreen.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourShakeScreen.super.SetTemplate(self, tmpData)

	self._shakeID = self._tmpData.shake_ID
end

--- 根据震动模板启动震屏；进入过热状态等待冷却
function BattleEnvironmentBehaviourShakeScreen.doBehaviour(self)
	ys.Battle.BattleCameraUtil.GetInstance():StartShake(pg.shake_template[self._shakeID])

	self._state = BattleEnvironmentBehaviourShakeScreen.STATE_OVERHEAT

	if self._tmpData.reload_time then
		self._CDstartTime = pg.TimeMgr.GetInstance():GetCombatTime()
	end
end
