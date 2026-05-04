ys = ys or {}

local ys = ys

ys.Battle.BattleAlert = class("BattleAlert")
ys.Battle.BattleAlert.__name = "BattleAlert"

--- @class BattleAlert
--- 通用战斗警报区域指示器
--- 用于显示范围预警（如炸弹、弹幕预警），通过缩放圆盘表示危险进度
--- @param alertGO GameObject 警报GameObject（带Disk子节点的预制体）
function ys.Battle.BattleAlert.Ctor(self, alertGO)
	self._alertGO = alertGO
	self._alertTf = alertGO.transform
	self._diskTf = self._alertGO.transform:Find("Disk")

	-- 初始化为0进度
	self:UpdateRate(0)
	self._alertGO:SetActive(true)
end

--- 设置警报位置
--- @param pos Vector3 世界坐标（只用x,z分量）
function ys.Battle.BattleAlert.SetPosition(self, pos)
	self._alertTf.localPosition = Vector3(pos.x, 0, pos.z)
end

--- 缩放整个警报区域
--- @param scale number 缩放倍率
function ys.Battle.BattleAlert.Zoom(self, scale)
	self._alertTf.localScale = Vector3(scale * 2, scale * 2, 1)
end

--- 更新警报进度（通过缩放内圈盘片表示剩余时间比例）
--- @param rate number 0~1，0=初始/无进度，1=完全填充（即将触发）
function ys.Battle.BattleAlert.UpdateRate(self, rate)
	self._diskTf.localScale = Vector3(rate, rate, 1)
end

--- 销毁警报GameObject
function ys.Battle.BattleAlert.Dispose(self)
	Object.Destroy(self._alertGO)
end
