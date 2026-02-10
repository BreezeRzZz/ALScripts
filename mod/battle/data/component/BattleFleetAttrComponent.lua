ys = ys or {}
ys.Battle.BattleFleetAttrComponent = class("BattleFleetAttrComponent")
ys.Battle.BattleFleetAttrComponent.__name = "BattleFleetAttrComponent"

local BattleFleetAttrComponent = ys.Battle.BattleFleetAttrComponent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleEvent = ys.Battle.BattleEvent

function BattleFleetAttrComponent.Ctor(self, client)
	self._client = client

	self:initFleetAttr()
end

function BattleFleetAttrComponent.Dispose(self)
	self._client = nil
end

function BattleFleetAttrComponent.initFleetAttr(self)
	self._fleetAttrList = {}
end

function BattleFleetAttrComponent.GetCurrent(self, fleetAttrName)
	return self._fleetAttrList[fleetAttrName] or 0
end

function BattleFleetAttrComponent.SetCurrent(self, fleetAttrName, fleetAttrValue)
	local currentValue = self:GetCurrent(fleetAttrName)
	-- 上限表
	-- 目前用到舰队属性的其实很少，可以直接列举如下：
	-- shenpanzhijian = 6 -> 布伦努斯的"审判之剑"
	-- yuanchou = 9 -> 怨仇的"怨仇"
	-- Judgement = 12 -> 阿尔萨斯的”裁决之怒“
	-- kuangsanshijian = 50 -> 时崎狂三的"时间"
	-- ReisalinAP = 99 -> 莱莎阵营舰船的"AP"
	-- KansasSP = 3 -> 堪萨斯的"蓄势"
	-- YumiaMANA = 100 -> 优米雅阵营的"环境玛那"
	-- huohun = 5 -> 紫的"祸魂"
	local capValue = BattleConfig.FLEET_ATTR_CAP[fleetAttrName]
	-- 某些舰队属性没有上限
	if capValue then
		fleetAttrValue = Mathf.Clamp(fleetAttrValue, 0, capValue)
	else
		fleetAttrValue = math.max(fleetAttrValue, 0)
	end

	self._fleetAttrList[fleetAttrName] = fleetAttrValue

	if currentValue ~= fleetAttrValue then
		local deltaValue = fleetAttrValue - currentValue

		self._client:FleetBuffTrigger(BattleConst.BuffEffectType.ON_FLEET_ATTR_UPDATE, {
			attr = fleetAttrName,
			value = fleetAttrValue,
			delta = deltaValue
		})
		self._client:DispatchEvent(ys.Event.New(BattleEvent.UPDATE_FLEET_ATTR, {
			attr = fleetAttrName,
			value = fleetAttrValue
		}))
	end
end
