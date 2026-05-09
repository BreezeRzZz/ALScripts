ys = ys or {}

local ys = ys
local BattleAttr = ys.Battle.BattleAttr
local BattleTargetChoise = ys.Battle.BattleTargetChoise

ys.Battle.BattleSkillFusion = class("BattleSkillFusion", ys.Battle.BattleSkillEffect)
ys.Battle.BattleSkillFusion.__name = "BattleSkillFusion"

local BattleSkillFusion = ys.Battle.BattleSkillFusion

BattleSkillFusion.FREEZE_POS = {
	Vector3(-10000, 0, 58),
	[-1] = Vector3(10000, 0, 58)
}

-- 此类SkillEffect进行机甲合体
-- 目前只有Skill 108414用到(宝多六花专武)
--- @param tempData table: 技能效果模板数据
--- @param level number: 技能等级
function BattleSkillFusion.Ctor(self, tempData, level)
	BattleSkillFusion.super.Ctor(self, tempData, level)

	self._fusionUnitTempID = self._tempData.arg_list.fusion_id
	self._fusionUnitSkinID = self._tempData.arg_list.ship_skin_id
	self._elementTagList = self._tempData.arg_list.element_tag_list
	self._attrInheritList = self._tempData.arg_list.attr_inherit_list
	self._fusionUnitEquipmentList = {}

	for _, weaponID in ipairs(self._tempData.arg_list.weapon_id_list) do
		table.insert(self._fusionUnitEquipmentList, {
			id = weaponID,
			equipment = {
				weapon_id = {
					weaponID
				}
			}
		})
	end

	self._fusionUnitSkillList = {}

	for _, buffID in ipairs(self._tempData.arg_list.buff_list) do
		table.insert(self._fusionUnitSkillList, {
			id = buffID,
			level = self._level
		})
	end

	self._duration = self._tempData.arg_list.duration
end

--- @param caster BattleUnit: 施法者
--- @param target BattleUnit: 目标
function BattleSkillFusion.DoDataEffect(self, caster, target)
	self:doFusion(caster)
end

--- @param caster BattleUnit: 施法者
--- @param target BattleUnit: 目标
function BattleSkillFusion.DoDataEffectWithoutTarget(self, caster, target)
	self:doFusion(caster)
end

--- 执行融合逻辑
--- @param caster BattleUnit: 施法者
function BattleSkillFusion.doFusion(self, caster)
	local candidateList1 = BattleTargetChoise.TargetAllHelp(caster)
	local candidateList2 = BattleTargetChoise.TargetShipTag(caster, {
		ship_tag_list = self._elementTagList
	}, candidateList1)
	local properties = {}

	for _, property in ipairs(Ship.PROPERTIES) do
		properties[property] = 1
	end

	local battleDataProxy = ys.Battle.BattleDataProxy.GetInstance()
	local unitData = {
		name = "123",
		shipGS = 1,
		id = caster.id,
		tmpID = self._fusionUnitTempID,
		skinId = self._fusionUnitSkinID,
		level = BattleAttr.GetCurrent(caster, "formulaLevel"),
		equipment = self._fusionUnitEquipmentList,
		properties = properties,
		baseProperties = properties,
		proficiency = {
			1,
			1,
			1
		},
		rarity = caster:GetRarity(),
		intimacy = caster:GetIntimacy(),
		skills = self._fusionUnitSkillList,
		baseList = {
			1,
			1,
			1
		},
		preloasList = {
			0,
			0,
			0
		}
	}
	local fusionUnit = battleDataProxy:SpawnFusionUnit(caster, unitData, candidateList2, self._attrInheritList)
	local fusionUnitHP = fusionUnit:GetHP()
	local mainUnitOriginalPos = {}
	-- 在融合期间，如果有主力舰队的单位参与融合，则记录其原始位置以便后续还原
	-- 融合期间其位置被放到一个很远的位置(实现消失的效果)
	-- 所有参与融合的单位都会被冻结
	-- 融合完毕，回到原始位置
	for _, candidate in ipairs(candidateList2) do
		if candidate:IsMainFleetUnit() then
			mainUnitOriginalPos[candidate] = Clone(candidate:GetPosition())
		end

		battleDataProxy:FreezeUnit(candidate)
		candidate:SetPosition(BattleSkillFusion.FREEZE_POS[candidate:GetIFF()])
	end

	if caster:IsMainFleetUnit() then
		mainUnitOriginalPos[caster] = Clone(caster:GetPosition())
	end

	battleDataProxy:FreezeUnit(caster)
	caster:SetPosition(BattleSkillFusion.FREEZE_POS[caster:GetIFF()])

	self._fusionTimer = nil
	-- 融合持续时间结束后的回调
	local function onFusionTimerEnds()
		local fusionCurrentHP, fusionMaxHP = fusionUnit:GetHP()
		local fusionHPLost = fusionMaxHP - fusionCurrentHP
		local fusionPos = fusionUnit:GetPosition()
		local fusionHPProvideRate = fusionUnit:GetAttrByName("hpProvideRate")

		if caster:IsMainFleetUnit() then
			caster:SetPosition(mainUnitOriginalPos[caster])
		else
			caster:SetPosition(Clone(fusionPos))
		end
		-- 对每个参与融合的单位根据其提供的血量比例进行扣血
		local casterHPLost = math.floor(fusionHPLost * fusionHPProvideRate[caster:GetAttrByName("id")])

		battleDataProxy:HandleDirectDamage(caster, casterHPLost)
		battleDataProxy:ActiveFreezeUnit(caster)

		for _, candidate in ipairs(candidateList2) do
			if candidate:IsMainFleetUnit() then
				candidate:SetPosition(mainUnitOriginalPos[candidate])
			else
				candidate:SetPosition(Clone(fusionPos))
			end

			local candidateHPLost = math.floor(fusionHPLost * fusionHPProvideRate[candidate:GetAttrByName("id")])

			battleDataProxy:HandleDirectDamage(candidate, candidateHPLost)
			battleDataProxy:ActiveFreezeUnit(candidate)
		end

		battleDataProxy:DefusionUnit(fusionUnit)
		pg.TimeMgr.GetInstance():RemoveBattleTimer(self._fusionTimer)
	end

	self._fusionTimer = pg.TimeMgr.GetInstance():AddBattleTimer("fusionSkillTimer", 0, self._duration, onFusionTimerEnds, true)
end

--- 清理：移除融合计时器
function BattleSkillFusion.Clear(self)
	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._fusionTimer)
	BattleSkillFusion.super.Clear(self)
end
