ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEffectArea = class("BattleEffectArea")

ys.Battle.BattleEffectArea = BattleEffectArea
BattleEffectArea.__name = "BattleEffectArea"

--- 顶部覆盖偏移（用于战场表层特效）
local topCoverOffset = Vector3(0, 3.5, -5)

--- @class BattleEffectArea
--- 战场效果区域（AOE范围显示）
--- 负责在场景中可视化AoE效果（如弹幕范围、燃烧区域等）
--- 支持三种区域类型：
---   - CUBE/立方体区域：按width x height缩放
---   - COLUMN/柱形区域：按range等比缩放
---   - 其他：不更新缩放
--- 根据IFF（敌我识别）决定旋转方向
--- @param go GameObject 特效GameObject
--- @param aoeData BattleAOEData AoE数据对象
--- @param topCover boolean 是否为顶部覆盖层（影响位置偏移和旋转朝向）
function BattleEffectArea.Ctor(self, go, aoeData, topCover)
	self._go = go
	self._aoeData = aoeData
	self._topCover = topCover

	self:Init()
end

--- 初始化：设置缩放策略、旋转策略、首次更新
function BattleEffectArea.Init(self)
	self._tf = self._go.transform
	self._areaType = self._aoeData:GetAreaType()

	-- 根据区域类型绑定不同的缩放更新函数
	if self._areaType == BattleConst.AreaType.CUBE or self._areaType == BattleConst.AreaType.ELLIPSE then
		self.UpdateScale = self.updateCubeScale
	elseif self._areaType == BattleConst.AreaType.COLUMN then
		self.UpdateScale = self.updateColumnScale
	end

	-- 根据IFF决定角度计算方式
	-- 敌方：角度反转 + 180度（朝向玩家侧）
	-- 我方：角度仅反转
	if self._aoeData:GetIFF() == BattleConfig.FOE_CODE then
		function self.GetAngle()
			return self._aoeData:GetAngle() * -1 + 180
		end
	else
		function self.GetAngle()
			return self._aoeData:GetAngle() * -1
		end
	end

	self:Update()
end

--- 每帧总更新：缩放 + 位置 + 旋转
function BattleEffectArea.Update(self)
	self:UpdateScale()
	self:UpdatePosition()
	self:UpdateRotation()
end

--- 更新立方体/ELLIPSE区域的缩放
--- 从AoE数据读取width和height动态缩放（非静态特效时）
--- width方向乘以IFF以实现朝向翻转
function BattleEffectArea.updateCubeScale(self)
	local scaleX = 1
	local scaleZ = 1

	if not self._aoeData:GetFXStatic() then
		scaleX = self._aoeData:GetWidth() * self._aoeData:GetIFF()
		scaleZ = self._aoeData:GetHeight()
	end

	-- 仅当尺寸变化时才更新
	if scaleX == self._preWidth and scaleZ == self._preHeight then
		return
	end

	self._tf.localScale = Vector3(scaleX, 1, scaleZ)
	self._preWidth = scaleX
	self._preHeight = scaleZ
end

--- 更新柱形区域的缩放
--- 从AoE数据读取range，等比缩放X和Z
function BattleEffectArea.updateColumnScale(self)
	local range = self._aoeData:GetRange()

	if range == self._preRange then
		return
	end

	self._tf.localScale = Vector3(range, 1, range)
	self._preRange = range
end

--- 更新位置
--- 顶部覆盖层有额外偏移量，普通层直接使用AoE位置
function BattleEffectArea.UpdatePosition(self)
	if self._topCover then
		self._tf.position = self._aoeData:GetPosition() + topCoverOffset
	else
		self._tf.position = self._aoeData:GetPosition()
	end
end

--- 更新旋转角度
--- 通过GetAngle()获取计算后的角度（已在Init中根据IFF绑定）
function BattleEffectArea.UpdateRotation(self)
	local angle = self:GetAngle()

	if self._preAngle == angle then
		return
	end

	self._tf.localEulerAngles = Vector3(0, angle, 0)
	self._preAngle = angle
end

--- 销毁特效区域
function BattleEffectArea.Dispose(self)
	ys.Battle.BattleResourceManager.GetInstance():DestroyOb(self._go)

	self._go = nil
end
