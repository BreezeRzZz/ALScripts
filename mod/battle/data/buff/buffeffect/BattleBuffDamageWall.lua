ys = ys or {}

local ys = ys

ys.Battle.BattleBuffDamageWall = class("BattleBuffDamageWall", ys.Battle.BattleBuffShieldWall)
ys.Battle.BattleBuffDamageWall.__name = "BattleBuffDamageWall"

local BattleBuffDamageWall = ys.Battle.BattleBuffDamageWall

-- 此BuffEffect会在单位周围生成一个伤害墙，持续一段时间。单位碰撞到伤害墙时会受到伤害(伤害值和伤害类型由Buff参数指定)，当碰撞次数达到指定数量后，伤害墙会消失(也就是说，是用来打伤害的护盾墙，与BattleBuffShieldWall不同，BattleBuffShieldWall是用来挡子弹的护盾墙)
-- 使用例：μ罗恩的2技能，其中红色护盾碰撞到敌人时会造成伤害，碰撞次数用完后护盾消失
function BattleBuffDamageWall.Ctor(self, effectData)
	BattleBuffDamageWall.super.Ctor(self, effectData)

	self._cldList = {}
end

function BattleBuffDamageWall.SetArgs(self, owner, buff)
	BattleBuffDamageWall.super.SetArgs(self, owner, buff)
	self._wall:SetCldObjType(ys.Battle.BattleWallData.CLD_OBJ_TYPE_SHIP)
	-- 使用拥有者的属性引用
	self._attr = setmetatable({}, {
		__index = owner._attr
	})
	self._atkAttrType = self._tempData.arg_list.attack_attribute
	self._damage = self._tempData.arg_list.damage
	-- 构造forgeWeapon相关数据，用于伤害计算
	self._forgeTmp = {
		random_damage_rate = 0,
		antisub_enhancement = 0,
		ammo_type = 1,
		damage_type = {
			1,
			1,
			1
		},
		DMG_font = {
			{
				2,
				1.2
			},
			{
				2,
				1.2
			},
			{
				2,
				1.2
			}
		},
		hit_type = {}
	}
	self._forgeWeapon = {
		GetConvertedAtkAttr = function()
			return 0.01
		end,
		GetFixAmmo = function()
			return nil
		end
	}
	self._forgeWeaponTmp = {
		attack_attribute = self._atkAttrType
	}
	self._atkAttr = ys.Battle.BattleAttr.GetAtkAttrByType(self._attr, self._atkAttrType)
end

function BattleBuffDamageWall.onWallCld(self, targetList)
	for _, target in ipairs(targetList) do
		if not table.contains(self._cldList, target) then
			self._dataProxy:HandleWallDamage(self, target)
			table.insert(self._cldList, target)

			self._count = self._count - 1

			if self._count <= 0 then
				break
			end
		end
	end

	local cldListLength = #self._cldList

	while cldListLength > 0 do
		local cldUnit = self._cldList[cldListLength]

		if not table.contains(targetList, cldUnit) then
			table.remove(self._cldList, cldListLength)
		end

		cldListLength = cldListLength - 1
	end

	if self._count <= 0 then
		self:Deactive()
	end
end

-- 因为DamageWall会被当成子弹来用，因此需要补充许多子弹相关的接口
function BattleBuffDamageWall.GetDamageEnhance(self)
	return 1
end

function BattleBuffDamageWall.GetHost(self)
	return self._unit
end

function BattleBuffDamageWall.GetWeaponHostAttr(self)
	return ys.Battle.BattleAttr.GetAttr(self)
end

function BattleBuffDamageWall.GetWeapon(self)
	return self._forgeWeapon
end

function BattleBuffDamageWall.GetWeaponTempData(self)
	return self._forgeWeaponTmp
end

function BattleBuffDamageWall.GetWeaponAtkAttr(self)
	return self._atkAttr
end

function BattleBuffDamageWall.GetCorrectedDMG(self)
	return self._damage
end

function BattleBuffDamageWall.GetTemplate(self)
	return self._forgeTmp
end

function BattleBuffDamageWall.Clear(self)
	self._cldList = nil

	BattleBuffDamageWall.super.Clear(self)
end
