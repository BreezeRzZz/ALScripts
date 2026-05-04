ys = ys or {}

local ys = ys

ys.Battle.TorAlert = class("TorAlert")
ys.Battle.TorAlert.__name = "TorAlert"

--- @class TorAlert
--- 鱼雷警报指示器
--- 在屏幕上显示鱼雷来袭方向和预警区域，通过LeanTween实现渐隐动画
--- @param alertGO GameObject 警报GameObject预制体
function ys.Battle.TorAlert.Ctor(self, alertGO)
	self._alertGO = alertGO
	self._alertTF = alertGO.transform
	-- 初始大范围展示（宽高比 20:5）
	self._alertTF.localScale = Vector3(20, 5, 1)

	-- Y轴缩放动画：0.5秒内从当前缩放到0，制造消失效果
	LeanTween.scaleY(alertGO, 0, 0.5):setDelay(0.1)
end

--- 设置鱼雷警报位置和方向
--- @param worldPos Vector3 世界坐标位置
--- @param angle number 角度（度），鱼雷来袭方向，180度反转
function ys.Battle.TorAlert.SetPosition(self, worldPos, angle)
	-- 播放战场特效
	pg.EffectMgr.GetInstance():PlayBattleEffect(self._alertGO, worldPos)

	-- 设置朝向：angle为0时指向右侧
	self._alertTF.eulerAngles = Vector3(0, 180 - angle, 0)
end

--- 销毁鱼雷警报
function ys.Battle.TorAlert.Dispose(self)
	LeanTween.cancel(self._alertGO)
	ys.Battle.BattleResourceManager.GetInstance():DestroyOb(self._alertGO)
end
