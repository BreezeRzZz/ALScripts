ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleFormulas = ys.Battle.BattleFormulas
local vector3Up = Vector3.up
local BattleVariable = ys.Battle.BattleVariable
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleScaleBulletUnit = class("BattleScaleBulletUnit", ys.Battle.BattleBulletUnit)
ys.Battle.BattleScaleBulletUnit.__name = "BattleScaleBulletUnit"

local BattleScaleBulletUnit = ys.Battle.BattleScaleBulletUnit

--- @class BattleScaleBulletUnit : BattleBulletUnit
--- @param UID number 子弹唯一ID
--- @param IFF number 敌我识别码
--- 可缩放碰撞体的子弹：继承自BattleBulletUnit，碰撞体随时间逐渐变大(scaleX递增)，
--- 达到上限后不再缩放，开始沿速度方向移动
function BattleScaleBulletUnit.Ctor(self, UID, IFF)
	BattleScaleBulletUnit.super.Ctor(self, UID, IFF)

	self._scaleX = 0
end

--- @param timeStamp number 时间戳
--- 碰撞体未达上限时继续缩放，否则按速度移动
function BattleScaleBulletUnit.Update(self, timeStamp)
	local cldBox = self._tempData.cld_box

	if self._scaleX + cldBox[1] > self._scaleLimit then
		self:calcSpeed()
	else
		self:UpdateCLDBox()
	end

	BattleScaleBulletUnit.super.Update(self, timeStamp)
end

--- @param tempData table 子弹模板数据
function BattleScaleBulletUnit.SetTemplateData(self, tempData)
	BattleScaleBulletUnit.super.SetTemplateData(self, tempData)

	self._scaleSpeed = self._tempData.extra_param.scaleSpeed
	self._scaleLimit = self._tempData.extra_param.cldMax
end

--- @param angle number 发射角度
function BattleScaleBulletUnit.InitSpeed(self, angle)
	BattleScaleBulletUnit.super.InitSpeed(self, angle)
	self:calcScaleSpeed()
end

--- 缩放阶段的速度分量：速度大小 = 缩放速度 / 2
function BattleScaleBulletUnit.calcScaleSpeed(self)
	local halfScaleSpeed = self._scaleSpeed * 0.5
	local yAngleRad = math.deg2Rad * self._yAngle

	self._speed = Vector3(halfScaleSpeed * math.cos(yAngleRad), 0, halfScaleSpeed * math.sin(yAngleRad))
end

--- 更新碰撞体X轴尺寸
function BattleScaleBulletUnit.UpdateCLDBox(self)
	local cldBox = self._tempData.cld_box

	self._scaleX = self._scaleX + self._scaleSpeed

	self._cldComponent:ResetSize(cldBox[1] + self._scaleX, cldBox[2], cldBox[3])
end

--- @return number radian 弧度
--- @return number cos 余弦值（缓存）
--- @return number sin 正弦值（缓存）
function BattleScaleBulletUnit.GetRadian(self)
	local radian = self._radCache or self:GetYAngle() * math.deg2Rad
	local cosVal = self._cosCache or math.cos(radian)
	local sinVal = self._sinCache or math.sin(radian)

	return radian, cosVal, sinVal
end
