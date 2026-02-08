ys = ys or {}

local ys = ys

ys.Battle.BattleBuffOverrideBullet = class("BattleBuffOverrideBullet", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffOverrideBullet.__name = "BattleBuffOverrideBullet"

local BattleBuffOverrideBullet = ys.Battle.BattleBuffOverrideBullet

-- 此类BuffEffect的作用是覆盖(指定类型)子弹的某些属性，目前只包含：水上/水下过滤、无视护盾(可能后续游戏开发者会添加更多属性)
-- 使用例: 鲁梅2技能
function BattleBuffOverrideBullet.Ctor(self, effectData)
	BattleBuffOverrideBullet.super.Ctor(self, effectData)
end

function BattleBuffOverrideBullet.SetArgs(self, owner, buff)
	self._bulletType = self._tempData.arg_list.bullet_type
	self._override = self._tempData.arg_list.override
end

function BattleBuffOverrideBullet.onBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	local bullet = args._bullet

	if bullet:GetType() == self._bulletType then
		self:overrideBullet(bullet)
	end
end

function BattleBuffOverrideBullet.overrideBullet(self, bullet)
	for paramName, paramValue in pairs(self._override) do
		if paramName == "diverFilter" then
			bullet:SetDiverFilter(paramValue)
			bullet:ResetCldSurface()
		elseif paramName == "ignoreShield" then
			bullet:SetIgnoreShield(paramValue)
		end
	end
end
