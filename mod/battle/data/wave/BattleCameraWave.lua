ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleCameraWave = class("BattleCameraWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleCameraWave.__name = "BattleCameraWave"

local BattleCameraWave = ys.Battle.BattleCameraWave

--- 波次类型：摄像机控制波
--- 控制战斗场景摄像机的聚焦、缩放、慢动作等特效。
--- 用于 BOSS 登场特写、技能动画镜头等场景。执行后不阻塞，立即通过。
function BattleCameraWave.Ctor(self)
	BattleCameraWave.super.Ctor(self)
end

--- 设置波次数据，从 triggerParams 读取摄像机参数
--- @param waveData table 关卡配置中对应的 wave 数据
function BattleCameraWave.SetWaveData(self, waveData)
	BattleCameraWave.super.SetWaveData(self, waveData)

	self._pause      = self._param.pause              -- 是否暂停
	self._cameraType = self._param.type or 0          -- 摄像机操作类型：0=全景，1=聚焦角色
	self._modelID    = self._param.model or 900006    -- 聚焦目标的模板 ID（type=1 时生效）
	self._duration   = self._param.duration or 1      -- 持续时间（秒）
	self._zoomSize   = self._param.zoomSize           -- 缩放目标大小
	self._zoomBounce = self._param.zoomBounce         -- 是否使用弹跳缩放动画
end

--- 执行波次：根据 cameraType 执行不同的摄像机操作
--- type == 1：聚焦指定 modelID 的角色，可选缩放
--- type == 0：重置摄像机（取消聚焦）
--- 最后开启子弹时间减速特效，然后立即 doPass
function BattleCameraWave.DoWave(self)
	BattleCameraWave.super.DoWave(self)

	local cameraUtil = ys.Battle.BattleCameraUtil.GetInstance()

	if self._cameraType == 1 then
		-- 聚焦指定角色
		local unitList = ys.Battle.BattleDataProxy.GetInstance():GetUnitList()
		local targetUnit

		for _, unit in pairs(unitList) do
			if unit:GetTemplateID() == self._modelID then
				targetUnit = unit

				break
			end
		end

		-- 聚焦到目标单位
		cameraUtil:FocusCharacter(targetUnit, self._duration, 0, true, not self._zoomBounce)

		if self._zoomSize then
			-- 缩放操作（zoomBounce=true 时有弹跳效果：先缩小再放大）
			local halfDuration = self._duration * 0.5

			if self._zoomBounce then
				-- 弹跳缩放：先拉到广角，再缩回目标尺寸
				cameraUtil:ZoomCamara(nil, BattleConfig.CAST_CAM_OVERLOOK_SIZE, halfDuration)
				LeanTween.delayedCall(halfDuration, System.Action(function()
					cameraUtil:ZoomCamara(BattleConfig.CAST_CAM_OVERLOOK_SIZE, self._zoomSize, halfDuration)
				end))
			else
				-- 直接缩放到目标尺寸
				cameraUtil:ZoomCamara(nil, self._zoomSize, self._duration, true)
			end
		end
	elseif self._cameraType == 0 then
		-- 重置摄像机：取消聚焦、取消缩放
		cameraUtil:FocusCharacter(nil, self._duration, 0)
		cameraUtil:ZoomCamara(nil, nil, self._duration)
	end

	-- 开启子弹时间效果（慢动作），增强镜头表现力
	cameraUtil:BulletTime(BattleConfig.SPEED_FACTOR_FOCUS_CHARACTER, nil)
	self:doPass()
end
