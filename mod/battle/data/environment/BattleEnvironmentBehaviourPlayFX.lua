ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEnvironmentBehaviourPlayFX = class("BattleEnvironmentBehaviourPlayFX", ys.Battle.BattleEnvironmentBehaviour)

ys.Battle.BattleEnvironmentBehaviourPlayFX = BattleEnvironmentBehaviourPlayFX
BattleEnvironmentBehaviourPlayFX.__name = "BattleEnvironmentBehaviourPlayFX"

--- @class BattleEnvironmentBehaviourPlayFX : BattleEnvironmentBehaviour
--- 环境特效行为：在AOE区域位置播放视觉特效，支持缩放
function BattleEnvironmentBehaviourPlayFX.Ctor(self)
	BattleEnvironmentBehaviourPlayFX.super.Ctor(self)
end

--- 读取FX_ID和位置偏移
--- @param tmpData table
function BattleEnvironmentBehaviourPlayFX.SetTemplate(self, tmpData)
	BattleEnvironmentBehaviourPlayFX.super.SetTemplate(self, tmpData)

	self._FXID = self._tmpData.FX_ID
	self._offset = self._tmpData.offset and Vector3(unpack(self._tmpData.offset)) or Vector3.zero
end

--- 根据AOE区域类型（CUBE取宽度/COLUMN取半径）计算缩放，生成特效
function BattleEnvironmentBehaviourPlayFX.doBehaviour(self)
	local scale = 1

	if self._tmpData.scaleRate then
		local aoeData = self._unit:GetAOEData()
		local areaType = aoeData:GetAreaType()
		local size

		if areaType == BattleConst.AreaType.CUBE then
			size = aoeData:GetWidth()
		elseif areaType == BattleConst.AreaType.COLUMN then
			size = aoeData:GetRange()
		end

		scale = self._tmpData.scaleRate * size
	elseif self._tmpData.scale then
		scale = self._tmpData.scale
	end

	local pos = self._unit:GetAOEData():GetPosition() + self._offset

	ys.Battle.BattleDataProxy.GetInstance():SpawnEffect(self._FXID, pos, scale)
	BattleEnvironmentBehaviourPlayFX.super.doBehaviour(self)
end
