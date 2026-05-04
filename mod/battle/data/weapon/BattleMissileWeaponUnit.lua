ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleDataFunction = ys.Battle.BattleDataFunction

local BattleMissileWeaponUnit = class("BattleMissileWeaponUnit", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleMissileWeaponUnit = BattleMissileWeaponUnit
BattleMissileWeaponUnit.__name = "BattleMissileWeaponUnit"

--- @class BattleMissileWeaponUnit : BattleWeaponUnit
--- @param self BattleMissileWeaponUnit
--- @param bullet BattleBulletUnit 子弹实例
--- @return Vector3 固定爆炸位置
--- 计算固定爆炸位置：根据宿主朝向和子弹射程确定X偏移
function BattleMissileWeaponUnit.CalculateFixedExplodePosition(self, bullet)
	local range = bullet._range
	local offsetX = (self._host:GetDirection() == BattleConst.UnitDir.RIGHT and 1 or -1) * range
	local hostPos = self._host:GetPosition()

	return Vector3(hostPos.x + offsetX, 0, 0)
end

--- 计算带随机散布的目标位置（受精度属性影响）
--- @param self BattleMissileWeaponUnit
--- @param weapon BattleWeaponUnit 武器实例（提供extra_param）
--- @param target BattleUnit 目标单位
--- @return Vector3 随机化后的实际目标位置
function BattleMissileWeaponUnit.CalculateRandTargetPosition(self, weapon, target)
	-- 获取目标碰撞体中心位置
	local targetPos = target:GetCLDZCenterPosition()
	local extraParam = weapon:GetTemplate().extra_param
	local accuracyAttr = extraParam.accuracy
	local accuracy = 0

	-- 如果有精度属性则读取其值
	if accuracyAttr then
		accuracy = weapon:GetAttrByName(accuracyAttr)
	end

	-- 精度可减少随机偏移量（精度越高散布越小）
	local randomOffsetX = extraParam.randomOffsetX or 0
	local randomOffsetZ = extraParam.randomOffsetZ or 0
	local adjustedRandomX = math.max(0, randomOffsetX - accuracy)
	local adjustedRandomZ = math.max(0, randomOffsetZ - accuracy)
	local offsetX = extraParam.offsetX or 0
	local offsetZ = extraParam.offsetZ or 0

	-- X轴随机散布
	if adjustedRandomX ~= 0 then
		adjustedRandomX = adjustedRandomX * (math.random() - 0.5) + offsetX
	end

	-- Z轴随机散布
	if adjustedRandomZ ~= 0 then
		adjustedRandomZ = adjustedRandomZ * (math.random() - 0.5) + offsetZ
	end

	-- 固定目标偏移量
	local targetOffsetX = extraParam.targetOffsetX or 0
	local targetOffsetZ = extraParam.targetOffsetZ or 0

	return Vector3(targetPos.x + adjustedRandomX + targetOffsetX, 0, targetPos.z + adjustedRandomZ + targetOffsetZ)
end

--- 创建主发射器（导弹武器专用）
--- @param self BattleMissileWeaponUnit
--- @param barrageID number 弹幕ID
--- @param index number 发射器序号
--- @param offsetPriority number 偏移优先级
--- @param target BattleUnit 目标单位
--- @param type string 发射器类型
--- @return BattleBulletEmitter 创建的发射器
function BattleMissileWeaponUnit.createMajorEmitter(self, barrageID, index, offsetPriority, target, type)
	--- 子弹生成回调：生成导弹子弹并设置偏移、旋转与空中回调
	local function spawnFunc(offsetX, offsetZ, angle, offsetPriority, target)
		local bulletID = self._emitBulletIDList[index]
		local bullet = self:Spawn(bulletID, target, BattleMissileWeaponUnit.INTERNAL)

		bullet:SetOffsetPriority(offsetPriority)
		bullet:SetShiftInfo(offsetX, offsetZ)
		bullet:SetRotateInfo(nil, self:GetBaseAngle(), angle)
		-- 注册空中回调：计算爆炸位置并创建预警圈
		bullet:RegisterOnTheAir(self:ChoiceOntheAir(bullet))
		self:DispatchBulletEvent(bullet)
	end

	return BattleMissileWeaponUnit.super.createMajorEmitter(self, barrageID, index, offsetPriority, spawnFunc, nil)
end

--- 返回子弹升空时的回调闭包：计算爆炸位置并创建预警圈
--- @param self BattleMissileWeaponUnit
--- @param bullet BattleBulletUnit 子弹实例
--- @return function 空中回调函数
function BattleMissileWeaponUnit.ChoiceOntheAir(self, bullet)
	return function()
		-- 获取导弹目标位置
		local targetPos = bullet:GetMissileTargetPosition()
		-- 获取旋转信息：shiftX, shiftZ, angle
		local shiftX, shiftZ, angle = bullet:GetRotateInfo()
		-- 获取偏移
		local offsetX, offsetZ = bullet:GetOffset()

		-- 将偏移加至目标位置
		targetPos:Add(Vector3(offsetX, 0, offsetZ))

		-- 计算从生成位置到目标位置的旋转方向
		local rotation = Quaternion.Euler(0, angle, 0)
		local direction = pg.Tool.FilterY(targetPos - bullet:GetSpawnPosition())
		-- 新爆炸位置 = 生成位置 + 旋转后的方向向量
		local explodePos = bullet:GetSpawnPosition() + rotation * direction

		bullet:SetExplodePosition(explodePos)
		-- 创建预警圈（红圈）
		ys.Battle.BattleMissileFactory.CreateBulletAlert(bullet)
	end
end
