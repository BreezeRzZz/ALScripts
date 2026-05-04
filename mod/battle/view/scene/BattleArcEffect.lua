ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleArcEffect = class("BattleArcEffect")

ys.Battle.BattleArcEffect = BattleArcEffect
BattleArcEffect.__name = "BattleArcEffect"

--- @class BattleArcEffect
--- 电弧/连接线特效（两个单位之间的可视化连线）
--- 通过shader的_PosBegin和_PosEnd参数在两个单位之间绘制连接特效
--- 单位A绑定到角色的骨骼节点，单位B绑定到世界坐标
--- @param go GameObject 特效GameObject（挂载Renderer）
--- @param characterA BattleCharacter 宿主角色（A端）
--- @param unitB BattleUnit 目标单位数据（B端）
--- @param boundBone string 绑定的骨骼名称
function BattleArcEffect.Ctor(self, go, characterA, unitB, boundBone)
	self._go = go
	self._characterA = characterA
	self._unitA = characterA:GetUnitData()
	self._unitB = unitB
	self._boundBone = boundBone
	self._material = self._go.transform:GetComponent(typeof(Renderer)).material

	-- 初始化A端（角色骨骼位置）和B端（单位世界位置）
	local bonePos = self._characterA:GetBonePos(self._boundBone)
	local unitBPos = self._unitB:GetPosition()

	self._vectorA = Vector4.New(bonePos.x, 5, bonePos.z, 1)
	self._vectorB = Vector4.New(unitBPos.x, 5, unitBPos.z, 1)

	self._material:SetVector("_PosBegin", self._vectorA)
	self._material:SetVector("_PosEnd", self._vectorB)
end

--- 每帧更新连线端点
--- 如果A端或B端死亡，触发callback销毁
function BattleArcEffect.Update(self)
	if self._unitA:IsAlive() and self._unitB:IsAlive() then
		local bonePos = self._characterA:GetBonePos(self._boundBone)
		local unitBPos = self._unitB:GetPosition()

		self._vectorA.x = bonePos.x
		self._vectorA.z = bonePos.z
		self._vectorB.x = unitBPos.x
		self._vectorB.z = unitBPos.z

		self._material:SetVector("_PosBegin", self._vectorA)
		self._material:SetVector("_PosEnd", self._vectorB)

		-- 特效跟随A端位置
		self._go.transform.position = self._vectorA
	else
		-- 任一端已死亡，触发回调
		self._callback()
	end
end

--- 配置销毁回调，并注册播放战场特效
--- @param callback function 特效结束时的回调（用于回收）
function BattleArcEffect.ConfigCallback(self, callback)
	self._callback = callback

	-- 注册为战场特效播放
	pg.EffectMgr.GetInstance():PlayBattleEffect(self._go, Vector3.zero, true, self._callback)
end

--- 销毁电弧特效，清空所有引用
function BattleArcEffect.Dispose(self)
	self._callback = nil
	self._material = nil
	self._go = nil
	self._unitA = nil
	self._unitB = nil
	self._vectorA = nil
	self._vectorB = nil
end
