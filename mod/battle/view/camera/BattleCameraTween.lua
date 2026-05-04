ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleCameraTween = class("BattleCameraTween")
ys.Battle.BattleCameraTween.__name = "BattleCameraTween"

local BattleCameraTween = ys.Battle.BattleCameraTween

--- @class BattleCameraTween
--- 摄像机缓动动画
--- 使用 LeanTween 实现摄像机在两个位置之间的平滑过渡。
--- 支持延迟、缓动函数和完成回调。缓动曲线为 easeOutExpo（指数衰减缓出），
--- 能产生快速开始逐渐减速的自然减速效果。

--- @return nil
--- 构造函数，初始化零向量缓存点
function BattleCameraTween.Ctor(self)
	self._point = Vector3.zero
end

--- @param target GameObject 目标 GameObject（摄像机对象）
--- @param from Vector3 起始位置
--- @param to Vector3 目标位置
--- @param duration number 动画持续时间
--- @param delay number|nil 延迟开始时间（秒）
--- @param ease boolean|nil 是否使用缓动效果
--- @param onComplete function|nil 动画完成时的回调函数
--- @return nil
--- 设置摄像机的起始位置和目标位置并启动缓动动画
--- LeanTween.value 会在 duration 时间内将 from 插值到 to，每帧回调更新 _point
function BattleCameraTween.SetFromTo(self, target, from, to, duration, delay, ease, onComplete)
	-- 初始位置设为起始点
	self._point:Set(from.x, from.y, from.z)

	-- 创建 LeanTween 插值动画，每帧更新 _point 为当前插值结果
	local tween = LeanTween.value(go(target), from, to, duration):setOnUpdateVector3(System.Action_UnityEngine_Vector3(function(tweenValue)
		self._point:Set(tweenValue.x, tweenValue.y, tweenValue.z)
	end))

	-- 如果指定了延迟且不为 0，设置延迟
	if delay and delay ~= 0 then
		tween:setDelay(delay)
	end

	-- 如果启用缓动，使用 easeOutExpo（指数衰减缓出）
	if ease then
		tween:setEase(LeanTweenType.easeOutExpo)
	end

	-- 如果指定了完成回调，绑定到动画结束事件
	if onComplete then
		tween:setOnComplete(System.Action(function()
			onComplete()
		end))
	end
end

--- @return Vector3 当前缓动位置的缓存值
--- 获取摄像机当前的缓动位置
function BattleCameraTween.GetCameraPos(self)
	return self._point
end

--- @return nil
--- 清理函数
function BattleCameraTween.Dispose(self)
	self._point = nil
end
