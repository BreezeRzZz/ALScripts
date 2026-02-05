ys = ys or {}

local ys = ys

ys.Battle.BattleBuffAddAircraftTag = class("BattleBuffAddAircraftTag", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffAddAircraftTag.__name = "BattleBuffAddAircraftTag"

local BattleBuffAddAircraftTag = ys.Battle.BattleBuffAddAircraftTag

function BattleBuffAddAircraftTag.Ctor(self, effectData)
	BattleBuffAddAircraftTag.super.Ctor(self, effectData)
end

function BattleBuffAddAircraftTag.SetArgs(self, owner, buff)
	self._labelTag = self._tempData.arg_list.tag_list
end

function BattleBuffAddAircraftTag.onAircraftCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	local aircraft = args.aircraft

	for _, tag in ipairs(self._labelTag) do
		if string.find(tag, "^[NT]_%d+$") then
			pg.TipsMgr.GetInstance():ShowTips(">>BattleBuffAddAircraftTag<<不允许使用'N_'或'T_'标签")
		else
			aircraft:AddLabelTag(tag)
		end
	end
end
