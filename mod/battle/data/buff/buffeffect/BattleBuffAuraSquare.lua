ys = ys or {}

local ys = ys
local BattleBuffAuraSquare = class("BattleBuffAuraSquare", ys.Battle.BattleBuffAura)

ys.Battle.BattleBuffAuraSquare = BattleBuffAuraSquare
BattleBuffAuraSquare.__name = "BattleBuffAuraSquare"

local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig

function BattleBuffAuraSquare.Ctor(self, effectData)
	BattleBuffAuraSquare.super.Ctor(self, effectData)
end

function BattleBuffAuraSquare.SetArgs(self, owner, buff)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local totalUpperBound, totalLowerBound, totalLeftBound, totalRightBound = battleDataProxy:GetTotalBounds()
	local auraWidth = totalRightBound - totalLeftBound
	local auraHeight = totalUpperBound - totalLowerBound
	local auraCenterZ = totalLowerBound + auraHeight * 0.5
	local auraCenterX = totalLeftBound + auraWidth * 0.5

	self._unit = owner
	self._buffLevel = buff:GetLv()

	local arg_list = self._tempData.arg_list
	-- 优先使用传入参数的宽高, 没有的话使用默认的全场宽高
	self._arraWidth = arg_list.cld_data.box.width or auraWidth
	self._auraHeight = arg_list.cld_data.box.height or auraHeight
	self._buffID = arg_list.buff_id
	-- 默认是对敌方生效的
	self._friendly = arg_list.friendly_fire or false
	self._frontOffset = arg_list.cld_data.box.front_offset or 0

	local areaCldFunc, exitCldFunc, endFunc = self:getAreaCldFunc(owner)
	local ownerIFF = owner:GetIFF()

	self._aura = battleDataProxy:SpawnLastingCubeArea(BattleConst.AOEField.SURFACE, ownerIFF, owner:GetPosition(), self._arraWidth, self._auraHeight, 0, areaCldFunc, exitCldFunc, self._friendly, nil, endFunc, false)

	local scaleableAOE = ys.Battle.BattleAOEScaleableComponent.New(self._aura)

	scaleableAOE:SetReferenceUnit(owner)
	-- 后边界，根据是否友方确定
	local rearBound = ownerIFF == BattleConfig.FRIENDLY_CODE and totalLeftBound or totalRightBound
	local boundData = {
		upperBound = totalUpperBound,
		lowerBound = totalLowerBound,
		rearBound = rearBound,
		frontOffset = self._frontOffset
	}

	scaleableAOE:ConfigData(scaleableAOE.FILL, boundData)

	local function fillFunc(arg_3_0)
		local auraPos = self._aura:GetPosition()
		local auraWidth = self._aura:GetWidth()
		local auraHeight = self._aura:GetHeight()

		return auraPos, auraWidth, auraHeight
	end

	self._effectIndex = "BattleBuffAuraSquare" .. self._buffID

	local addEffectArgs = {
		index = self._effectIndex,
		effect = arg_list.effect,
		fillFunc = fillFunc
	}

	owner:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.ADD_EFFECT, addEffectArgs))
end

function BattleBuffAuraSquare.Clear(self)
	self._unit:DispatchEvent(ys.Event.New(ys.Battle.BattleUnitEvent.CANCEL_EFFECT, {
		index = self._effectIndex
	}))
	BattleBuffAuraSquare.super.Clear(self)
end
