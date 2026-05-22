ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleFormulas = ys.Battle.BattleFormulas
local BattleBuffAddBuff = class("BattleBuffAddBuff", ys.Battle.BattleBuffEffect)

ys.Battle.BattleBuffAddBuff = BattleBuffAddBuff
BattleBuffAddBuff.__name = "BattleBuffAddBuff"

function BattleBuffAddBuff.Ctor(self, effectData)
	ys.Battle.BattleBuffAddBuff.super.Ctor(self, effectData)
end

function BattleBuffAddBuff.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._buff_id = arg_list.buff_id
	self._level = arg_list.buff_level or buff:GetLv()
	self._target = arg_list.target or "TargetSelf"
	self._time = arg_list.time or 0
	self._rant = arg_list.rant or 10000
	self._nextEffectTime = pg.TimeMgr.GetInstance():GetCombatTime() + self._time
	self._check_target = arg_list.check_target
	self._minTargetNumber = arg_list.minTargetNumber or 0
	self._maxTargetNumber = arg_list.maxTargetNumber or 10000
	self._isBuffStackByCheckTarget = arg_list.isBuffStackByCheckTarget
	self._countType = arg_list.countType
	self._weaponType = self._tempData.arg_list.weaponType
	self._repeatCount = arg_list.repeat_count or 1
	self._attrConsumeRepeat = arg_list.fleetAttrConsume
end

function BattleBuffAddBuff.onUpdate(self, owner, buff, args)
	local currrentTime = args.timeStamp

	if currrentTime >= self._nextEffectTime then
		self:AddBuff(owner, args, buff)
		-- 每隔time秒，添加Buff
		self._nextEffectTime = currrentTime + self._time
	end
end

function BattleBuffAddBuff.onBulletHit(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	local target = args.target

	if (not self._weaponType or args.weaponType == self._weaponType) and target:IsAlive() then
		self:attachBuff(self._buff_id, self._level, target, buff)
	end
end

function BattleBuffAddBuff.onBulletCreate(self, owner, buff, args)
	if not self:equipIndexRequire(args.equipIndex) then
		return
	end

	local bullet = args._bullet
	local buffId = self._buff_id
	local effectLevel = self._level
	local bulletTrigger = self._tempData.arg_list.bulletTrigger

	local function triggerFunction(host, _args)
		self:attachBuff(buffId, effectLevel, host, buff)
	end

	bullet:SetBuffFun(bulletTrigger, triggerFunction)
end

function BattleBuffAddBuff.onTrigger(self, owner, buff, args)
	-- quota - 1
	BattleBuffAddBuff.super.onTrigger(self, owner, buff, args)
	self:AddBuff(owner, args, buff)
end

function BattleBuffAddBuff.AddBuff(self, owner, buff, args)
	-- 目前只有指挥喵的火和山会用到这个检查
	if not self:commanderRequire(owner, self._tempData.arg_list) then
		return
	end
	-- 久远的"四神变幻"需要检查弹药类型
	if not self:ammoRequire(owner) then
		return
	end

	if self._check_target then
		local checkTargetNum = #self:getTargetList(owner, self._check_target, self._tempData.arg_list, buff)

		if checkTargetNum >= self._minTargetNumber and checkTargetNum <= self._maxTargetNumber then
			-- 注意check_target是用来判定条件的，而target是要添加Buff的目标
			local targetList = self:getTargetList(owner, self._target, self._tempData.arg_list, buff)

			for _, target in ipairs(targetList) do
				-- 根据满足check_target的目标数量设置Buff层数
				-- 如"狼群战术"
				if self._isBuffStackByCheckTarget then
					target:SetBuffStack(self._buff_id, self._level, checkTargetNum)
				else
					self:attachBuff(self._buff_id, self._level, target, args)
				end
			end
		end
	else
		local targetList = self:getTargetList(owner, self._target, self._tempData.arg_list, buff)

		for _, target in ipairs(targetList) do
			self:attachBuff(self._buff_id, self._level, target, args)
		end
	end
end

function BattleBuffAddBuff.attachBuff(self, buffId, buffLevel, target, args)
	-- 相对来说，attachBuff只负责添加Buff的逻辑
	-- 而addBuff负责判定条件和筛选目标
	local effect_list = BattleDataFunction.GetBuffTemplate(buffId).effect_list
	local buff
	-- 这里隐性要求了DOT只有一个effect
	-- 但从实际来看，大多数DOT有很多effect，应该是下面的逻辑
	-- 所以不知道这里为什么要特判
	if #effect_list == 1 and effect_list[1].type == "BattleBuffDOT" then
		if BattleFormulas.CaclulateDOTPlace(self._rant, effect_list[1], self._caster, target) then
			buff = ys.Battle.BattleBuffUnit.New(buffId, nil, self._caster)

			buff:SetOrb(self._caster, 1)
		end
	elseif BattleFormulas.IsHappen(self._rant) then
		buff = ys.Battle.BattleBuffUnit.New(buffId, buffLevel, self._caster)
	end

	if buff then
		buff:SetCommander(self._commander)

		local spellCount

		if self._attrConsumeRepeat then
			spellCount = self:fleetAttrRepeatConsume(self._attrConsumeRepeat)
		else
			spellCount = self:repeatCountParse(self._repeatCount)
		end

		if spellCount == -1 then
			spellCount = args:GetStack()
		end

		for _ = 1, spellCount do
			target:AddBuff(buff)
		end
	end
end

function BattleBuffAddBuff.Dispose(self)
	ys.Battle.BattleBuffAddBuff.super:Dispose()
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._timer)

	self._timer = nil
end
