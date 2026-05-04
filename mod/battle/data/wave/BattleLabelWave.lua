ys = ys or {}

local ys = ys

ys.Battle.BattleLabelWave = class("BattleLabelWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleLabelWave.__name = "BattleLabelWave"

local BattleLabelWave = ys.Battle.BattleLabelWave

--- 波次类型：标签/文本显示波
--- 在战斗中显示自定义标签（如剧情对话气泡、提示文字、BOSS 名称等）。
--- 不阻塞战斗，发送标签数据后立即通过。
function BattleLabelWave.Ctor(self)
	BattleLabelWave.super.Ctor(self)
end

--- 设置波次数据，构建传递给 UI 层的标签数据表
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleLabelWave.SetWaveData(self, waveData)
	BattleLabelWave.super.SetWaveData(self, waveData)

	-- 构建标签数据表，通过 DispatchCustomWarning 发送到 UI
	self._labelData = {
		op       = self._param.op,       -- 操作类型：显示/隐藏/更新
		key      = self._param.key,      -- 标签唯一标识，用于区分多个标签
		x        = self._param.x,        -- 屏幕 X 坐标
		y        = self._param.y,        -- 屏幕 Y 坐标
		dialogue = self._param.dialogue, -- 对话/文字内容
		duration = self._param.duration, -- 显示时长（秒）
	}
end

--- 执行波次：DispatchCustomWarning -> 立即 doPass
function BattleLabelWave.DoWave(self)
	BattleLabelWave.super.DoWave(self)
	ys.Battle.BattleState.GetInstance():GetProxyByName(ys.Battle.BattleDataProxy.__name):DispatchCustomWarning(self._labelData)
	self:doPass()
end
