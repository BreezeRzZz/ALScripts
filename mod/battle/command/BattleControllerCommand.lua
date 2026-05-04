ys = ys or {}

-- 战斗控制器Command，处理玩家操控相关的逻辑（加速、减速、时间缩放等）
local ys = ys

ys.Battle.BattleControllerCommand = class("BattleControllerCommand", ys.MVC.Command)
ys.Battle.BattleControllerCommand.__name = "BattleControllerCommand"

--- 构造函数
--- @param self BattleControllerCommand
function ys.Battle.BattleControllerCommand.Ctor(self)
	ys.Battle.BattleControllerCommand.super.Ctor(self)
end

--- 初始化：绑定DataProxy并InitBattleEvent
--- @param self BattleControllerCommand
function ys.Battle.BattleControllerCommand.Initialize(self)
	ys.Battle.BattleControllerCommand.super.Initialize(self)

	self._dataProxy = self._state:GetProxyByName(ys.Battle.BattleDataProxy.__name)

	self:InitBattleEvent()
end

--- 初始化战斗事件（子类覆盖）
--- @param self BattleControllerCommand
function ys.Battle.BattleControllerCommand.InitBattleEvent(self)
	return
end

--- 增加战斗速度（调试/加速功能）
-- 同时修改BASIC_TIME_SCALE，并给敌我双方添加IFF速度因子
--- @param self BattleControllerCommand
--- @param speedFactor number 速度倍率
function ys.Battle.BattleControllerCommand.addSpeed(self, speedFactor)
	ys.Battle.BattleConfig.BASIC_TIME_SCALE = ys.Battle.BattleConfig.BASIC_TIME_SCALE * speedFactor

	ys.Battle.BattleVariable.AppendIFFFactor(ys.Battle.BattleConfig.FOE_CODE, "cheat_speed_up_" .. ys.Battle.BattleConfig.BASIC_TIME_SCALE, speedFactor)
	ys.Battle.BattleVariable.AppendIFFFactor(ys.Battle.BattleConfig.FRIENDLY_CODE, "cheat_speed_up_" .. ys.Battle.BattleConfig.BASIC_TIME_SCALE, speedFactor)
end

--- 移除速度加成（恢复原始速度）
-- 移除IFF速度因子，然后恢复BASIC_TIME_SCALE
--- @param self BattleControllerCommand
--- @param speedFactor number 速度倍率（用于恢复）
function ys.Battle.BattleControllerCommand.removeSpeed(self, speedFactor)
	ys.Battle.BattleVariable.RemoveIFFFactor(ys.Battle.BattleConfig.FOE_CODE, "cheat_speed_up_" .. ys.Battle.BattleConfig.BASIC_TIME_SCALE)
	ys.Battle.BattleVariable.RemoveIFFFactor(ys.Battle.BattleConfig.FRIENDLY_CODE, "cheat_speed_up_" .. ys.Battle.BattleConfig.BASIC_TIME_SCALE)

	ys.Battle.BattleConfig.BASIC_TIME_SCALE = ys.Battle.BattleConfig.BASIC_TIME_SCALE * speedFactor
end

--- 显示时间缩放后的提示（调试UI）
--- @param self BattleControllerCommand
function ys.Battle.BattleControllerCommand.scaleTime(self)
	pg.TipsMgr.GetInstance():ShowTips("┏━━━━━━━━━━━━┓")
	pg.TipsMgr.GetInstance():ShowTips("┃ヽ(•̀ω•́ )ゝ嗑药 X" .. ys.Battle.BattleConfig.BASIC_TIME_SCALE .. " ！(ง •̀_•́)ง┃")
	pg.TipsMgr.GetInstance():ShowTips("┗━━━━━━━━━━━━┛")
	self._state:ScaleTimer()
end
