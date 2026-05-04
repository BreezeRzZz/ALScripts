ys = ys or {}

local ys = ys

ys.Battle.BossSkillAlert = class("BossSkillAlert")
ys.Battle.BossSkillAlert.__name = "BossSkillAlert"

--- @class BossSkillAlert
--- Boss技能预警提示
--- 在屏幕中央显示Boss即将释放技能的提示，带呼吸式透明闪烁动画
--- 支持自定义缩放和定时自动消失
--- @param alertGO GameObject 预警GameObject
function ys.Battle.BossSkillAlert.Ctor(self, alertGO)
	self._alertGO = alertGO
	self._alertTF = alertGO.transform
	self._alertTF.localPosition = Vector3.zero

	-- 透明呼吸动画：在0.3和原始alpha之间持续切换
	LeanTween.alpha(alertGO, 0.3, 0.1):setDelay(0.1):setLoopPingPong()
end

--- 显示/隐藏预警
--- @param isActive boolean
function ys.Battle.BossSkillAlert.SetActive(self, isActive)
	self._alertGO:SetActive(isActive)
end

--- 获取当前激活状态
--- @return boolean
function ys.Battle.BossSkillAlert.GetActive(self)
	return self._alertGO.activeSelf
end

--- 设置预警缩放
--- @param scale Vector3 缩放值
function ys.Battle.BossSkillAlert.SetScale(self, scale)
	self._alertTF.localScale = scale
end

--- 设置存在时间，到时自动销毁
--- @param duration number 存在时长（秒）
function ys.Battle.BossSkillAlert.SetExistTime(self, duration)
	-- 创建倒计时定时器，到期后自动Dispose
	self._timer = pg.TimeMgr.GetInstance():AddBattleTimer("BossSkillAlert", 0, duration, function()
		if self._alertGO then
			self:Dispose()
		end
	end)
end

--- 销毁预警
function ys.Battle.BossSkillAlert.Dispose(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._timer)
	LeanTween.cancel(self._alertGO)
	Object.Destroy(self._alertGO)

	self._alertGO = nil
end
