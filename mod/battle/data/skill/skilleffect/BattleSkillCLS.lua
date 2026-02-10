ys = ys or {}

local ys = ys
local BattleSkillCLS = class("BattleSkillCLS", ys.Battle.BattleSkillEffect)

ys.Battle.BattleSkillCLS = BattleSkillCLS
BattleSkillCLS.__name = "BattleSkillCLS"
BattleSkillCLS.TYPE_BULLET = 1
BattleSkillCLS.TYPE_AIRCRAFT = 2
BattleSkillCLS.TYPE_MINION = 3
BattleSkillCLS.TYPE_AOE = 4

-- 此类SkillEffect清除场上施法者敌对的子弹/舰载机/小怪/AOE
-- 与CLSArea不同的是，CLSArea只能清除特定范围内的对象，而CLS则是全屏清除
-- 使用例: 航母的空袭消弹
function BattleSkillCLS.Ctor(self, tempData, level)
	BattleSkillCLS.super.Ctor(self, tempData, level)

	self._clsTypeList = self._tempData.arg_list.typeList or {}
end

function BattleSkillCLS.DoDataEffect(self, caster)
	self:doCls(caster)
end

function BattleSkillCLS.DoDataEffectWithoutTarget(self, caster)
	self:doCls(caster)
end

function BattleSkillCLS.doCls(self, caster)
	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local casterOpponentIFF = caster:GetIFF() * -1

	for _, clsType in ipairs(self._clsTypeList) do
		if clsType == BattleSkillCLS.TYPE_BULLET then
			battleDataProxy:CLSBullet(casterOpponentIFF)
		elseif clsType == BattleSkillCLS.TYPE_AIRCRAFT then
			battleDataProxy:CLSAircraft(casterOpponentIFF)
		elseif clsType == BattleSkillCLS.TYPE_MINION then
			battleDataProxy:CLSMinion()
		elseif clsType == BattleSkillCLS.TYPE_AOE then
			battleDataProxy:CLSAOE()
		end
	end
end
