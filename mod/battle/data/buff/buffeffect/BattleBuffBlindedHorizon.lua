ys = ys or {}

local ys = ys
local BattleBuffBlindedHorizon = class("BattleBuffBlindedHorizon", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffBlindedHorizon = BattleBuffBlindedHorizon
BattleBuffBlindedHorizon.__name = "BattleBuffBlindedHorizon"

local BattleConst = ys.Battle.BattleConst

-- 致盲BuffEffect: 将视野限制在范围内
function BattleBuffBlindedHorizon.Ctor(self, effectData)
	BattleBuffBlindedHorizon.super.Ctor(self, effectData)
end

function BattleBuffBlindedHorizon.SetArgs(self, owner, buff)
	self._horizonRange = self._tempData.arg_list.range

	local ownerUID = owner:GetUniqueID()

	local function areaCldFunc(cldObjList)
		for _, cldObj in ipairs(cldObjList) do
			if cldObj.Active then
				local targetList = self:getTargetList(owner, {
					"TargetAllHarm"
				})

				for _, target in ipairs(targetList) do
					if target:GetUniqueID() == cldObj.UID then
						-- 致盲
						target:AppendExposed(ownerUID)

						break
					end
				end
			end
		end
	end

	local function exitCldFunc(cldObj)
		if cldObj.Active then
			local targetList = self:getTargetList(owner, {
				"TargetAllHarm"
			})

			for _, target in ipairs(targetList) do
				if target:GetUniqueID() == cldObj.UID then
					target:RemoveExposed(ownerUID)

					break
				end
			end
		end
	end

	local function endFunc(cldObj)
		if cldObj.Active then
			local targetList = self:getTargetList(owner, {
				"TargetAllHarm"
			})

			for _, target in ipairs(targetList) do
				if target:GetUniqueID() == cldObj.UID then
					target:RemoveExposed(ownerUID)

					break
				end
			end
		end
	end
	-- 生成一个AOE，AOE的碰撞函数会调用areaCldFunc来致盲进入范围内的单位，调用exitCldFunc/endFunc来解除致盲效果
	-- 致盲的可见范围是一个圆形，直径为horizonRange(注意是直径)
	self._aura = ys.Battle.BattleDataProxy.GetInstance():SpawnLastingColumnArea(BattleConst.AOEField.SURFACE, owner:GetIFF(), owner:GetPosition(), self._horizonRange, 0, areaCldFunc, exitCldFunc, false, nil, endFunc, true)
	-- 让AOE跟随owner移动
	local mobilizedAOE = ys.Battle.BattleAOEMobilizedComponent.New(self._aura)

	mobilizedAOE:SetReferenceUnit(owner)
	mobilizedAOE:ConfigData(mobilizedAOE.FOLLOW)
end

function BattleBuffBlindedHorizon.onAttach(self, owner, buff)
	-- blindedHorizon是一种属性
	-- 这个属性在BattleInkView使用
	ys.Battle.BattleAttr.FlashByBuff(owner, "blindedHorizon", self._horizonRange)

	local fleetVO = owner:GetFleetVO()
	-- 影响全队的视野范围
	if fleetVO then
		fleetVO:UpdateHorizon()
	end
end

function BattleBuffBlindedHorizon.onRemove(self, owner, buff)
	ys.Battle.BattleAttr.FlashByBuff(owner, "blindedHorizon", 0)
end

function BattleBuffBlindedHorizon.Clear(self)
	self._aura:SetActiveFlag(false)

	self._aura = nil

	BattleBuffBlindedHorizon.super.Clear(self)
end
