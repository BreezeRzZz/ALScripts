ys = ys or {}

local ys = ys
local BattleBuffOrb = class("BattleBuffOrb", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffOrb = BattleBuffOrb
BattleBuffOrb.__name = "BattleBuffOrb"

-- 这类BuffEffect会给子弹添加一个Buff(通过AppendAttachBuff实现)
-- 相当于bullet的attach_buff参数, 子弹在命中时能给敌人添加这个Buff
-- 使用例: U-81的1技能
function BattleBuffOrb.Ctor(self, effectData)
	BattleBuffOrb.super.Ctor(self, effectData)
end

function BattleBuffOrb.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._buffID = arg_list.buff_id
	self._rant = arg_list.rant or 10000
	-- level是group level(默认同ID的算同组，组等级高的优先), buff_level是这个buff的level
	self._level = arg_list.level or 1
	self._buffLevel = arg_list.buff_level or 1
	self._type = arg_list.type
end

function BattleBuffOrb.onTrigger(self, owner, buff, args)
	local bullet = args._bullet

	if self._type and bullet:GetTemplate().type ~= self._type then
		return
	end

	self:attachOrb(bullet)
	BattleBuffOrb.super.onTrigger(self, owner, buff, args)
end

function BattleBuffOrb.attachOrb(self, bullet)
	local attachBuff = {
		buff_id = self._buffID,
		rant = self._rant,
		level = self._level,
		buff_level = self._buffLevel
	}

	bullet:AppendAttachBuff(attachBuff)
end
