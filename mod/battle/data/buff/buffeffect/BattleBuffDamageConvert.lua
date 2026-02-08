ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleAttr = ys.Battle.BattleAttr
local BattleConst = ys.Battle.BattleConst
local BattleBuffDamageConvert = class("BattleBuffDamageConvert", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffDamageConvert = BattleBuffDamageConvert
BattleBuffDamageConvert.__name = "BattleBuffDamageConvert"
BattleBuffDamageConvert.ATTR_PRE = {
	[BattleConst.WeaponDamageAttr.CANNON] = "injureRatioByCannon",
	[BattleConst.WeaponDamageAttr.TORPEDO] = "injureRatioByBulletTorpedo",
	[BattleConst.WeaponDamageAttr.AIR] = "injureRatioByAir"
}

-- 此BuffEffect会在Buff持续期间内记录受到的伤害(按属性分类)，Buff结束时，选择造成伤害最多的属性，并根据给定的参数，生成一个Buff(代码形式)来减少受到对应属性伤害的Buff
-- 这看起来像是BattleBuffSkillDamageCount的早期设计。目前这类BuffEffect没有被使用过，不需要管。
function BattleBuffDamageConvert.Ctor(self, effectData)
	BattleBuffDamageConvert.super.Ctor(self, effectData)
end

function BattleBuffDamageConvert.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._convert = arg_list.convert_rate
	self._duration = arg_list.duration
	self._buffSkinID = arg_list.buff_skin_id
	self._attrTable = {}
end

function BattleBuffDamageConvert.onTakeDamage(self, owner, buff, args)
	local damageAttr = args.damageAttr

	if damageAttr then
		local totalDamage = (self._attrTable[damageAttr] or 0) + args.damage

		self._attrTable[damageAttr] = totalDamage
	end
end

function BattleBuffDamageConvert.onRemove(self, owner, buff)
	local maxAttrDamage = 0
	local maxAttrType

	for attrType, attrTotalDamage in pairs(self._attrTable) do
		if maxAttrDamage <= attrTotalDamage then
			maxAttrDamage = attrTotalDamage
			maxAttrType = attrType
		end
	end

	if not maxAttrType then
		return
	end

	local injureRatioByAttr = BattleBuffDamageConvert.ATTR_PRE[maxAttrType]
	local convertedBuff = BattleBuffDamageConvert.generateBuff(self._buffSkinID, self._duration, injureRatioByAttr, maxAttrDamage * self._convert)
	local convertedBuffUnit = ys.Battle.BattleBuffSelfModifyUnit.New(convertedBuff.id, 1, owner, convertedBuff)

	owner:AddBuff(convertedBuffUnit)
end

function BattleBuffDamageConvert.generateBuff(buffSkinID, duration, injureRatioByAttr, number)
	return {
		id = buffSkinID,
		icon = buffSkinID,
		time = duration,
		blink = {
			0,
			0.7,
			1,
			0.3,
			0.3
		},
		effect_list = {
			{
				type = "BattleBuffAddAttr",
				trigger = {
					"onAttach",
					"onRemove"
				},
				arg_list = {
					attr = injureRatioByAttr,
					number = number,
					group = buffSkinID
				}
			}
		},
		{
			time = duration
		},
		name = "代码生成buff",
		init_effect = "jinengchufablue",
		stack = 1,
		picture = "",
		last_effect = "",
		desc = "代码生成buff-指定属性减伤"
	}
end
