ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleLaserEffect = class("BattleLaserEffect", ys.Battle.BattleEffectArea)

ys.Battle.BattleLaserEffect = BattleLaserEffect
BattleLaserEffect.__name = "BattleLaserEffect"

--- @class BattleLaserEffect : BattleEffectArea
--- 激光特效渲染器（继承自BattleEffectArea）
--- 使用LaserScript组件控制LineRenderer绘制激光束
--- 每帧更新激光宽度、长度和角度，带波浪动画效果
--- @param go GameObject 激光特效GameObject（挂载LaserScript组件）
--- @param aoeData BattleAOEData AoE数据对象
function BattleLaserEffect.Ctor(self, go, aoeData)
	BattleLaserEffect.super.Ctor(self, go, aoeData)
end

--- 设置为静态（激光不支持静态，空实现）
function BattleLaserEffect.SetStatic(self)
	return
end

--- 初始化：获取LaserScript组件，初始化波次计数
function BattleLaserEffect.Init(self)
	self._tf = self._go.transform
	self._laserScript = GetComponent(self._go, "LaserScript")
	self._waveCount = 0

	self:Update()
end

--- 每帧更新：先更新LineRenderer参数，再更新位置
function BattleLaserEffect.Update(self)
	self:updateLineRenderer()
	self:UpdatePosition()
end

--- 更新LineRenderer的宽度、长度和角度
--- 宽度 = height + cos(波次 * 3°)，产生周期性波浪效果
--- 长度 = AoE width（沿激光方向的长度）
--- 角度根据IFF处理：敌方旋转180度
function BattleLaserEffect.updateLineRenderer(self)
	local lineWidth = self._aoeData:GetHeight()

	-- 宽度 = 基础宽度 + 余弦波浪效果（waveCount控制波浪频率）
	self._laserScript.width = lineWidth + math.cos(self._waveCount * math.deg2Rad * 3)
	self._waveCount = self._waveCount + 1
	self._laserScript.length = self._aoeData:GetWidth()

	-- 角度处理：IFF为敌方(-1)时旋转180度
	local lineAngle = self._aoeData:GetAngle() * math.deg2Rad

	if self._aoeData:GetIFF() == -1 then
		lineAngle = lineAngle + math.pi
	end

	self._laserScript.angle = lineAngle
end
