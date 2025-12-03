ys = ys or {}

local ys = ys

ys.Battle.BattleBuffCastSkill = class("BattleBuffCastSkill", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffCastSkill.__name = "BattleBuffCastSkill"

local BattleBuffCastSkill = ys.Battle.BattleBuffCastSkill

BattleBuffCastSkill.FX_TYPE = ys.Battle.BattleBuffEffect.FX_TYPE_CASTER

function BattleBuffCastSkill.Ctor(self, effectData)
	BattleBuffCastSkill.super.Ctor(self, effectData)

	self._castCount = 0
	self._fireSkillDMGSum = 0
end

function BattleBuffCastSkill.GetEffectType(self)
	return BattleBuffCastSkill.FX_TYPE
end

function BattleBuffCastSkill.GetGroupData(self)
	return self._group
end

function BattleBuffCastSkill.SetArgs(self, owner, buff)
	self._level = buff:GetLv()

	local arg_list = self._tempData.arg_list

	-- 对应的skill ID
	self._skill_id = arg_list.skill_id
	self._target = arg_list.target or "TargetSelf"
	self._check_target = arg_list.check_target
	self._check_weapon = arg_list.check_weapon
	self._check_spweapon = arg_list.check_spweapon
	self._check_target_gap = arg_list.check_target_gap
	self._time = arg_list.time or 0

	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()

	-- initialCD表示无开局CD，否则按time计算首次生效时间
	if arg_list.initialCD then
		self._nextEffectTime = currentTime
	else
		self._nextEffectTime = currentTime + self._time
	end

	self._minTargetNumber = arg_list.minTargetNumber or 0
	self._maxTargetNumber = arg_list.maxTargetNumber or 10000
	self._minWeaponNumber = arg_list.minWeaponNumber or 0
	self._maxWeaponNumber = arg_list.maxWeaponNumber or 10000
	self._rant = arg_list.rant or 10000
	self._streak = arg_list.streakRange
	self._dungeonTypeList = arg_list.dungeonTypeList
	self._effectAttachData = arg_list.effectAttachData
	self._repeatCount = arg_list.repeat_count or 1
	self._attrConsumeRepeat = arg_list.fleetAttrConsume
	self._group = arg_list.group
	self._srcBuff = buff
end

function BattleBuffCastSkill.onBulletCreate(self, owner, buff, args)
	-- 检查equipIndex是否在effect的index列表中
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end
	--- @type BattleBulletUnit
	local bullet = args._bullet
	--- trigger即effectType
	--- @type string
	local bulletTrigger = self._tempData.arg_list.bulletTrigger

	local function triggerFunction(host, _args)
		if host and host:IsAlive() then
			self:castSkill(host, _args)
		end
	end
	-- 把这个函数加到该子弹的对应Trigger(effectType)的函数列表里
	bullet:SetBuffFun(bulletTrigger, triggerFunction)
end

function BattleBuffCastSkill.onTrigger(self, owner, buff, args)
	return (self:castSkill(owner, args, buff))
end

function BattleBuffCastSkill.castSkill(self, owner, args, buff)
	local currentTime = pg.TimeMgr.GetInstance():GetCombatTime()
	-- 未达到nextEffectTime，冷却中
	if self:IsInCD(currentTime) then
		return "overheat"
	end
	-- 概率判定
	if not ys.Battle.BattleFormulas.IsHappen(self._rant) then
		return "chance"
	end
	-- 检查要求的目标数量
	-- 要求的目标类型需要全部满足
	if self._check_target then
		local targetList = self:getTargetList(owner, self._check_target, self._tempData.arg_list)

		if not targetList then
			return "check target none"
		end

		local targetNum = #targetList
		-- 需要在[minTargetNumber, maxTargetNumber]范围内
		if targetNum < self._minTargetNumber then
			return "check target min"
		end

		if targetNum > self._maxTargetNumber then
			return "check target max"
		end
	end

	if self._check_target_gap then
		-- 计算两个目标列表的数量差值
		-- 例如限界挑战天秤座的砝码计算Buff，用到了这个逻辑
		local attachedBuffList = self:getTargetList(owner, self._check_target_gap[1].target, self._check_target_gap[1].arg)
		local effectGroupData = self:getTargetList(owner, self._check_target_gap[2].target, self._check_target_gap[2].arg)
		local targetNumGap = math.abs(#attachedBuffList - #effectGroupData)

		-- 要求两个目标列表数量差值在[minTargetNumber, maxTargetNumber]范围内
		if targetNumGap < self._minTargetNumber then
			return "check target gap min"
		end

		if targetNumGap > self._maxTargetNumber then
			return "check target gap max"
		end
	end

	if self._check_weapon then
		local validEquipmentNum = #BattleBuffCastSkill.GetEquipmentList(owner, self._tempData.arg_list)
		-- 这里的min/maxWeaponNumber应为equipment，属程序员混淆概念了
		if validEquipmentNum < self._minWeaponNumber then
			return "check weapon min"
		end

		if validEquipmentNum > self._maxWeaponNumber then
			return "check weapon max"
		end
	end

	if self._check_spweapon and not BattleBuffCastSkill.FilterSpWeapon(owner, self._tempData.arg_list) then
		return "check spweapon"
	end

	if self._hpUpperBound or self._hpLowerBound then
		local hpRate
		-- 如果args中指定了unit，则以指定的单位的生命比例为准
		-- 否则以owner为准
		if not args or not args.unit then
			hpRate = owner:GetHPRate()
		else
			hpRate = args.unit:GetHPRate()
		end
		-- 一般要求[hpLowerBound, hpUpperBound]
		-- 但如果有hpOutInterval，则要求 <= hpLowerBound或 >= hpUpperBound
		if not self:hpIntervalRequire(hpRate) then
			return "check hp"
		end
	end
	-- attrInterval本身是一个属性(字符串)
	if self._attrInterval then
		local attrIntervalValue = ys.Battle.BattleAttr.GetBase(owner, self._attrInterval)
		-- 需要在(attrLowerBound, attrUpperBound)范围内
		-- 这个是开区间，有点奇怪
		if not self:attrIntervalRequire(attrIntervalValue) then
			return "check interval"
		end
	end
	-- 需要在[streak[1],streak[2])范围内，左闭右开
	-- 主要用于实现各种"在前xx场战斗..."的效果.
	if self._streak and not BattleBuffCastSkill.GetWinningStreak(self._streak) then
		return "check winning streak"
	end
	-- 要求当前副本类型在dungeonTypeList中
	-- 可到sharecfgdata/expedition_data_template查看副本类型对应关系
	if self._dungeonTypeList and not BattleBuffCastSkill.GetDungeonType(self._dungeonTypeList) then
		return "check dungeon"
	end
	-- 一类十分复杂的检查条件，通过指定一个表达式，检查其他BuffEffect的状态来判定是否满足条件
	-- 目前只有检查护盾抵挡次数的例子
	if self._effectAttachData and not self:BuffAttachDataCondition(buff) then
		return "check attach data"
	end
	-- 这也是通过指定表达式来检查是否满足条件，不过比较的对象是舰队属性(全体)
	-- 举例：怨仇技能需要检查我方单位附加的"怨仇"层数来决定使用不同的技能
	if self._fleetAttrRequire and args and not self:fleetAttrRequire(owner, args.attr) then
		return "check fleet attr"
	end

	if self._fleetAttrRequire then
		if args then
			if not self:fleetAttrRequire(owner, args.attr) then
				return
			end
		elseif not self:fleetAttrRequire(owner) then
			return "check fleet attr"
		end
	end
	-- 舰队属性变化值的检查
	if self._fleetAttrDeltaRequire and args and not self:fleetAttrDelatRequire(args.delta) then
		return "check fleet attr delta"
	end
	-- 检查Buff的层数是否满足要求
	if not self:stackRequire(buff) then
		return "check buff stack"
	end

	local targetList = self:getTargetList(owner, self._target, self._tempData.arg_list)
	
	BattleBuffCastSkill.super.onTrigger(self, owner)

	for _, target in ipairs(targetList) do
		local highestLevel = true

		if self._group then
			-- 目标身上已附着的Buff列表
			local attachedBuffList = target:GetBuffList()

			for _, attachedBuff in pairs(attachedBuffList) do
				for _, effect in ipairs(attachedBuff._effectList) do
					if effect:GetEffectType() == BattleBuffCastSkill.FX_TYPE and effect:GetGroupData() then
						-- 一般group会包含id和level两个字段
						local effectGroupData = effect:GetGroupData()
						-- 意思就是同组只取最高级的效果
						if effectGroupData.id == self._group.id and effectGroupData.level > self._group.level then
							highestLevel = false

							break
						end
					end
				end
			end
		end

		if highestLevel then
			local spellCounts
			-- 需要消耗某种舰队属性
			if self._attrConsumeRepeat then
				-- 计算根据目前的舰队属性，能触发的次数
				-- 如果有repeatCeil，表示每次只能触发至多repeatCeil次
				-- 目前，只有狂三的时间属性消耗是这个逻辑
				spellCounts = self:fleetAttrRepeatConsume(self._attrConsumeRepeat)
			else
				-- 这个逻辑目前没有使用(对于CastSkill)
				spellCounts = self:repeatCountParse(self._repeatCount)
			end

			if spellCounts == -1 then
				spellCounts = srcBuff:GetStack()
			end
			-- 连续施法spellCounts次
			for _ = 1, spellCounts do
				self:spell(target, args)
			end
		end
	end

	self:enterCoolDown(currentTime)
end

function BattleBuffCastSkill.IsInCD(self, timeStamp)
	return timeStamp < self._nextEffectTime
end

function BattleBuffCastSkill.spell(self, target, args)
	-- attData不知道是哪个变量
	--- @type BattleSkillUnit
	self._skill = self._skill or ys.Battle.BattleSkillUnit.GenerateSpell(self._skill_id, self._level, target, attData)

	if args and args.target then
		self._skill:SetTarget({
			args.target
		})
	end

	self._skill:Cast(target, self._commander)

	self._castCount = self._castCount + 1
end

function BattleBuffCastSkill.enterCoolDown(self, timeStamp)
	if self._time and self._time > 0 then
		self._nextEffectTime = timeStamp + self._time
	end
end

function BattleBuffCastSkill.Interrupt(self)
	BattleBuffCastSkill.super.Interrupt(self)

	if self._skill then
		self._skill:Interrupt()
	end
end

function BattleBuffCastSkill.Clear(self)
	BattleBuffCastSkill.super.Clear(self)

	if self._skill then
		self._skill:Clear()

		self._skill = nil
	end
end

function BattleBuffCastSkill.BuffAttachDataCondition(self, buff)
	local satisfied = true
	local effectList = buff:GetEffectList()

	for _, effect in ipairs(effectList) do
		for _, attachString in ipairs(self._effectAttachData) do
			-- 这类检查很复杂，举个详细例子说明
			-- 例如Buff 13302，我们看两个effect:
				-- 第一个是BattleBuffShield，触发时机onStack/onTakeDamage，参数casterMaxHPRatio=0.04
				-- 第二个是BattleBuffCastSkill，触发时机onRemove，参数skill_id=13302，effectAttachData={"BattleBuffShield<=0"}
			-- 考虑onRemove触发时发生了什么:
				-- 1. effectAttachData是table<string>，里面的每一项都是一个条件表达式, 例如"BattleBuffShield<=0"
				-- 2. 当我们把这个字符串传入，该函数会自动拆解为:
					-- effectName = "BattleBuffShield"
					-- compareOp = "<="
					-- value = 0
				-- 3. 然后该函数会调用传入effect.GetEffectAttachData, 只有BattleBuffRecordShield和BattleBuffShield实现了这个函数
				-- 4. 返回的都是这个ShieldEffect的shield值，表示还有几次盾
				-- 5. 最后把shield值和要求的value进行比较，判断条件是否成立, 例如这里是要求第一个effect的shield值 <= 0(没有盾了)
			-- 6. 如果有多个条件表达式，则要求全部成立
			-- 说白了，这类检查就是通过查看其他BuffEffect的状态来决定是否满足条件，来CastSkill
			-- 目前只有检查护盾抵挡次数的例子
			local attachSatisfied = ys.Battle.BattleFormulas.parseCompareBuffAttachData(attachString, effect)

			satisfied = satisfied and attachSatisfied
		end
	end

	return satisfied
end

function BattleBuffCastSkill.GetWinningStreak(streak)
	-- 获取本编队的连胜场数(代表已经击败了几个敌人)，对应目前应为第 streak + 1 场战斗
	-- 按照这个逻辑推测，如果战斗失败再次进入，应属于同一场战斗(可能需测试)
	-- 连胜场数不会清0
	local winningStreak = ys.Battle.BattleDataProxy.GetInstance():GetWinningStreak()
	local streakMin = streak[1]
	local streakMax = streak[2]
	-- 要求在[streakMin, streakMax)范围内
	return streakMin <= winningStreak and winningStreak < streakMax
end

function BattleBuffCastSkill.GetDungeonType(dungeonTypeList)
	local stageTemplateId = ys.Battle.BattleDataProxy.GetInstance():GetInitData().StageTmpId
	-- sharcfgdata/expedition_data_template
	local dungeonType = pg.expedition_data_template[stageTemplateId].type

	return table.contains(dungeonTypeList, dungeonType)
end

--- @class BattleBuffCastSkill
--- @param owner BattleUnit
--- @param arg_list table
--- @return table<number, table<string, any>>
--- 获取符合条件的装备列表
function BattleBuffCastSkill.GetEquipmentList(owner, arg_list)
	local equipmentList = owner:GetEquipment()
	local validEquipmentList = {}

	for index, equipment in ipairs(equipmentList) do
		validEquipmentList[index] = equipment
	end

	local equipmentNum = #validEquipmentList

	while equipmentNum > 0 do
		local equipment = validEquipmentList[equipmentNum].equipment
		local satisfied = true

		if not equipment then
			satisfied = false
		else
			-- 从equip_data_template表获取
			local equipmentTemplate = ys.Battle.BattleDataFunction.GetEquipDataTemplate(equipment.id)
			-- 装备的group应在要求的weapon_group列表中
			if arg_list.weapon_group and not table.contains(arg_list.weapon_group, equipmentTemplate.group) then
				satisfied = false
			end
			-- 装备的index应在要求的index列表中
			if arg_list.index and not table.contains(arg_list.index, equipmentNum) then
				satisfied = false
			end
			-- 装备的type应在要求的type列表中
			if arg_list.type and not table.contains(arg_list.type, equipmentTemplate.type) then
				satisfied = false
			end

			if arg_list.label then
				-- 从equip_data_statistics表获取label
				local equipmentLabels = ys.Battle.BattleDataFunction.GetWeaponDataFromID(equipment.id).label
				-- 要求的所有label都应在装备的label中
				for _, labelItem in ipairs(arg_list.label) do
					if not table.contains(equipmentLabels, labelItem) then
						satisfied = false

						break
					end
				end
			end
		end

		if not satisfied then
			table.remove(validEquipmentList, equipmentNum)
		end

		equipmentNum = equipmentNum - 1
	end

	return validEquipmentList
end

function BattleBuffCastSkill.FilterSpWeapon(owner, arg_list)
	local spWeapon = owner:GetSpWeapon()
	local satisfied = true

	;(function()
		if not spWeapon then
			satisfied = false

			return
		end
		-- spweapon_data_statistics
		local spWeaponData = ys.Battle.BattleDataFunction.GetSpWeaponDataFromID(spWeapon:GetConfigID())
		-- 兵装的type应在要求的type列表中
		if arg_list.type and not table.contains(arg_list.type, spWeaponData.type) then
			satisfied = false
		end
		-- 要求的所有label都应在兵装的label中
		if arg_list.label then
			for _, labelItem in ipairs(arg_list.label) do
				if not table.contains(spWeaponData.label, labelItem) then
					satisfied = false

					return
				end
			end
		end
	end)()

	return satisfied and spWeapon or nil
end

function BattleBuffCastSkill.GetCastCount(self)
	return self._castCount
end

function BattleBuffCastSkill.GetSkillFireDamageSum(self)
	self._fireSkillDMGSum = math.max(self._skill and self._skill:GetDamageSum() or 0, self._fireSkillDMGSum)

	return self._fireSkillDMGSum
end
