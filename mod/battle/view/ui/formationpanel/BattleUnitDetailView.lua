ys = ys or {}

local ys = ys
local BattleAttr = ys.Battle.BattleAttr
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local EquipmentType = ys.Battle.BattleConst.EquipmentType
local BattleUnitDetailView = class("BattleUnitDetailView")

ys.Battle.BattleUnitDetailView = BattleUnitDetailView
BattleUnitDetailView.__name = "BattleUnitDetailView"
-- 默认激活的面板
BattleUnitDetailView.DefaultActive = {
	"attr_panels",
	"attr_panels/buff"
}
-- 敌方标记列表
BattleUnitDetailView.EnemyMarkList = {}
-- 高亮Buff列表
BattleUnitDetailView.HIGH_LIGHT_BUFF = {}
-- 基础属性列表（主要面板显示）
BattleUnitDetailView.PrimalAttr = {
	"cannonPower",
	"torpedoPower",
	"airPower",
	"antiAirPower",
	"antiSubPower",
	"loadSpeed",
	"dodgeRate",
	"attackRating",
	"velocity"
}
-- 基础强化属性映射：属性名 -> UI路径
BattleUnitDetailView.BaseEnhancement = {
	damageRatioByCannon = "damage/damageRatioByCannon",
	injureRatioByBulletTorpedo = "injure/injureRatioByBulletTorpedo",
	damageRatioByBulletTorpedo = "damage/damageRatioByBulletTorpedo",
	injureRatioByCannon = "injure/injureRatioByCannon",
	damageRatioBullet = "damage/damageRatioBullet",
	injureRatio = "injure/injureRatio",
	injureRatioByAir = "injure/injureRatioByAir",
	damageRatioByAir = "damage/damageRatioByAir"
}
-- 需要监听的二级属性列表
BattleUnitDetailView.SecondaryAttrListener = {}

--- 战斗单位详情面板视图
--- 显示单位的详细属性（基础属性、强化、Buff、武器、技能等），用于调试/开发

function BattleUnitDetailView.Ctor(self)
	pg.DelegateInfo.New(self)
end

--- 设置要查看的单位
function BattleUnitDetailView.SetUnit(self, unit)
	ys.EventListener.AttachEventListener(self)

	self._unit = unit

	-- 玩家单位：加载立绘Q版头像和星级
	if self._unit:GetUnitType() == BattleConst.UnitType.PLAYER_UNIT then
		local qIcon = ys.Battle.BattleResourceManager.GetInstance():GetCharacterQIcon(self._unit:GetTemplate().painting)

		setImageSprite(self._icon, qIcon)

		for starIndex = 1, self._unit:GetTemplate().star do
			local starClone = cloneTplTo(self._starTpl, self._stars)

			setActive(starClone, true)
		end
	end

	setText(self._templateID, self._unit:GetTemplate().id)
	setText(self._name, self._unit:GetTemplate().name)
	setText(self._lv, self._unit:GetAttrByName("level"))

	self._preAttrList = {}

	-- 初始化基础属性显示
	for _, attrName in ipairs(BattleUnitDetailView.PrimalAttr) do
		local baseValue = BattleAttr.GetBase(self._unit, attrName)

		setText(self._attrView:Find(attrName .. "/base"), baseValue)

		self._preAttrList[attrName] = baseValue
	end

	self._baseEhcList = {}

	-- 初始化基础强化缓存
	for ehcKey, ehcPath in pairs(BattleUnitDetailView.BaseEnhancement) do
		self._baseEhcList[ehcKey] = 0
	end

	self._secondaryAttrList = {}
	self._buffList = {}
	self._aaList = {}
	self._weaponList = {}
	self._skillList = {}

	self:updateWeaponList()
end

--- 每帧更新所有属性面板
function BattleUnitDetailView.Update(self)
	-- 更新基础属性
	for _, attrName in ipairs(BattleUnitDetailView.PrimalAttr) do
		self:updatePrimalAttr(attrName)
	end

	-- 更新基础强化
	for attrName, path in pairs(BattleUnitDetailView.BaseEnhancement) do
		self:updateBaseEnhancement(attrName, path)
	end

	-- 更新二级属性（标签相关）
	local attrDict = self._unit:GetAttr()

	for attrName, attrValue in pairs(attrDict) do
		if string.find(attrName, "DMG_TAG_EHC_") or string.find(attrName, "DMG_FROM_TAG_") or table.contains(BattleUnitDetailView.SecondaryAttrListener, attrName) then
			self:updateSecondaryAttr(attrName, attrValue)
		end
	end

	self:updateHP()
	self:updateBuffList()
	self:updateWeaponProgress()
	self:updateSkillList()
end

--- 配置UI皮肤，初始化所有Transform引用
function BattleUnitDetailView.ConfigSkin(self, go)
	self._go = go

	local tf = go.transform

	self._tf = tf
	self._iconView = tf:Find("icon")
	self._icon = self._iconView:Find("icon")
	self._stars = self._iconView:Find("stars")
	self._starTpl = self._stars:Find("star_tpl")
	self._templateView = tf:Find("template")
	self._templateID = self._templateView:Find("template/text")
	self._name = self._templateView:Find("name/text")
	self._lv = self._templateView:Find("level/text")
	self._totalHP = self._templateView:Find("totalHP/text")
	self._currentHP = self._templateView:Find("currentHP/text")
	self._shield = self._templateView:Find("shield/text")
	self._attrView = tf:Find("attr_panels/primal_attr")
	self._baseEnhanceView = tf:Find("attr_panels/basic_ehc")
	self._secondaryAttrView = tf:Find("attr_panels/tag_ehc")
	self._secondaryAttrContainer = self._secondaryAttrView:Find("tag_container")
	self._secondaryAttrTpl = self._secondaryAttrView:Find("tag_attr_tpl")
	self._buffView = tf:Find("attr_panels/buff")
	self._buffContainer = self._buffView:Find("buff_container")
	self._buffTpl = self._buffView:Find("buff_tpl")
	self._weaponView = tf:Find("panel_container/weapon_panels")
	self._weaponContainer = self._weaponView:Find("weapon_container")
	self._weaponTpl = self._weaponView:Find("weapon_tpl")
	self._skillView = tf:Find("panel_container/skill_panel")
	self._skillContainer = self._skillView:Find("skill_container")
	self._skillTpl = self._skillView:Find("skill_tpl")

	SetActive(self._go, true)

	-- 激活默认面板
	for _, panelPath in ipairs(BattleUnitDetailView.DefaultActive) do
		SetActive(tf:Find(panelPath), true)
	end
end

--- 更新HP和护盾显示
function BattleUnitDetailView.updateHP(self)
	local currentHP, totalHP = self._unit:GetHP()
	local hpRate = self._unit:GetHPRate()

	setText(self._totalHP, totalHP)
	setText(self._currentHP, currentHP)

	-- 遍历所有Buff计算总护盾值
	local buffList = self._unit:GetBuffList()
	local totalShield = 0

	for buffID, buff in pairs(buffList) do
		for _, effect in ipairs(buff:GetEffectList()) do
			if effect.__name == "BattleBuffShield" or effect.__name == "BattleBuffRecordShield" then
				totalShield = totalShield + math.max(0, effect:GetEffectAttachData())
			end
		end
	end

	setText(self._shield, totalShield)
end

--- 更新单个基础属性显示（含变化量）
function BattleUnitDetailView.updatePrimalAttr(self, attrName)
	local currentValue = self._unit:GetAttrByName(attrName)

	setText(self._attrView:Find(attrName .. "/current"), currentValue)

	-- 与上一帧比较，显示变化量
	local deltaChange = currentValue - self._preAttrList[attrName]

	if deltaChange ~= 0 then
		local changeTF = self._attrView:Find(attrName .. "/change")

		BattleUnitDetailView.setDeltaText(changeTF, deltaChange)

		self._preAttrList[attrName] = currentValue
	end

	-- 与基础值比较，显示总增量
	local deltaFromBase = currentValue - BattleAttr.GetBase(self._unit, attrName)

	if deltaFromBase ~= 0 then
		local deltaTF = self._attrView:Find(attrName .. "/delta")

		BattleUnitDetailView.setDeltaText(deltaTF, deltaFromBase)
	end
end

--- 更新单个基础强化属性显示
function BattleUnitDetailView.updateBaseEnhancement(self, attrName, uiPath)
	local ehcTF = self._baseEnhanceView:Find(uiPath)
	local currentValue = self._unit:GetAttrByName(attrName)
	local deltaChange = currentValue - self._baseEhcList[attrName]

	setText(ehcTF:Find("current"), currentValue)

	if deltaChange ~= 0 then
		BattleUnitDetailView.setDeltaText(ehcTF:Find("change"), deltaChange)
	end
end

--- 更新二级属性显示（动态创建TF）
function BattleUnitDetailView.updateSecondaryAttr(self, attrName, attrValue)
	if not self._secondaryAttrList[attrName] then
		local attrTF = cloneTplTo(self._secondaryAttrTpl, self._secondaryAttrContainer)

		Canvas.ForceUpdateCanvases()
		setText(attrTF:Find("tag_name"), attrName)
		setActive(attrTF, true)

		local attrData = {
			value = 0,
			tf = attrTF
		}

		self._secondaryAttrList[attrName] = attrData
	end

	local entryTF = self._secondaryAttrList[attrName].tf
	local currentValue = self._unit:GetAttrByName(attrName)
	local prevValue = self._secondaryAttrList[attrName].value

	if prevValue ~= attrValue then
		setText(entryTF:Find("current"), attrValue)

		local deltaChange = currentValue - prevValue

		BattleUnitDetailView.setDeltaText(entryTF:Find("delta"), deltaChange)
	end
end

--- 更新Buff列表：移除过期Buff，添加新Buff，更新层数
function BattleUnitDetailView.updateBuffList(self)
	local buffList = self._unit:GetBuffList()

	-- 移除已经不存在的Buff UI
	for buffID, buffTF in pairs(self._buffList) do
		if not buffList[buffID] then
			GameObject.Destroy(buffTF.gameObject)

			self._buffList[buffID] = nil
		end
	end

	-- 添加新Buff或更新层数
	for buffID, buff in pairs(buffList) do
		if not self._buffList[buffID] then
			self:addBuff(buffID, buff)
		else
			local buffViewTF = self._buffList[buffID]

			if buff._stack > 1 then
				local stackTF = buffViewTF:Find("buff_stack")

				setActive(stackTF, true)
				setText(stackTF, "x" .. buff._stack)
			end
		end
	end

	-- 检测Buff中的技能施放效果，添加到技能列表
	for _, buff in pairs(buffList) do
		local effectList = buff:GetEffectList()

		for _, effect in ipairs(effectList) do
			if effect.__name == ys.Battle.BattleBuffCastSkill.__name and (not self._skillList[effect._skill_id] or not table.contains(self._skillList[effect._skill_id].effectList, effect)) then
				self:addSkillCaster(effect)
			end
		end
	end
end

--- 更新武器列表显示
function BattleUnitDetailView.updateWeaponList(self)
	-- 空袭辅助武器
	local aaList = self._unit:GetAirAssistList()

	if aaList then
		for _, aaWeapon in ipairs(aaList) do
			local aaWeaponTF = cloneTplTo(self._weaponTpl, self._weaponContainer)

			Canvas.ForceUpdateCanvases()

			local icon = aaWeaponTF:Find("common/icon")

			GetImageSpriteFromAtlasAsync("skillicon/2130", "", icon)
			setText(aaWeaponTF:Find("common/index"), "空袭")
			setText(aaWeaponTF:Find("common/templateID"), aaWeapon:GetStrikeSkillID())

			self._aaList[aaWeapon] = aaWeaponTF
		end
	end

	-- 所有常规武器
	local weaponList = self._unit:GetAllWeapon()

	for _, weapon in ipairs(weaponList) do
		local weaponType = weapon:GetType()

		-- 跳过空袭和舰队防空武器
		if weaponType ~= EquipmentType.STRIKE_AIRCRAFT and weaponType ~= EquipmentType.FLEET_ANTI_AIR then
			local weaponTF = cloneTplTo(self._weaponTpl, self._weaponContainer)

			Canvas.ForceUpdateCanvases()
			setText(weaponTF:Find("common/index"), weapon:GetEquipmentIndex())
			setText(weaponTF:Find("common/templateID"), weapon:GetTemplateData().id)

			local equipmentID = weapon:GetSrcEquipmentID()
			local iconTF = weaponTF:Find("common/icon")

			if equipmentID then
				local iconPath = BattleDataFunction.GetWeaponDataFromID(equipmentID).icon

				GetImageSpriteFromAtlasAsync("equips/" .. iconPath, "", iconTF)
			else
				setActive(iconTF, false)
			end

			self._weaponList[weapon] = {
				tf = weaponTF,
				data = {}
			}

			-- 武器射界开关
			onToggle(self, weaponTF:Find("common/sector"), function(isOn)
				self._unit:ActiveWeaponSectorView(weapon, isOn)
			end)
			self:updateBulletAttrBuff(weapon)
		end
	end

	-- 舰队远程防空武器
	local fleetAA = self._unit:GetFleetRangeAAWeapon()

	if fleetAA then
		local fleetAATF = cloneTplTo(self._weaponTpl, self._weaponContainer)

		Canvas.ForceUpdateCanvases()

		local icon = fleetAATF:Find("common/icon")

		GetImageSpriteFromAtlasAsync("skillicon/2130", "", icon)
		setText(fleetAATF:Find("common/index"), "远程防空")
		setText(fleetAATF:Find("common/templateID"), "N/A")
		onToggle(self, fleetAATF:Find("common/sector"), function(isOn)
			self._unit:ActiveWeaponSectorView(fleetAA, isOn)
		end)
	end
end

--- 更新武器进度显示（装填率、伤害、暴击率、命中率）
function BattleUnitDetailView.updateWeaponProgress(self)
	for weapon, weaponData in pairs(self._weaponList) do
		local weaponTF = weaponData.tf
		local reloadRate = weapon:GetReloadRate()

		BattleUnitDetailView.updateBarProgress(weaponTF, reloadRate)
		setText(weaponTF:Find("sum/damageSum"), weapon:GetDamageSUM())
		setText(weaponTF:Find("sum/CTRate"), string.format("%.2f", weapon:GetCTRate() * 100) .. "%")
		setText(weaponTF:Find("sum/ACCRate"), string.format("%.2f", weapon:GetACCRate() * 100) .. "%")
		self:updateBulletAttrBuff(weapon)
	end

	for aaWeapon, aaTF in pairs(self._aaList) do
		local reloadRate = aaWeapon:GetReloadRate()

		BattleUnitDetailView.updateBarProgress(aaTF, reloadRate)

		local currentDamage, totalDamage = aaWeapon:GetDamageSUM()

		setText(aaTF:Find("sum/damageSum"), currentDamage .. " + " .. totalDamage)
	end
end

--- 更新进度条填充量（装填率）
--- @param weaponTF Transform 武器面板的Transform
--- @param reloadRate number 装填率（0=装填完毕）
function BattleUnitDetailView.updateBarProgress(weaponTF, reloadRate)
	local progressBar = weaponTF:Find("common/reload_progress/blood"):GetComponent(typeof(Image))

	progressBar.fillAmount = 1 - reloadRate

	if reloadRate == 0 then
		progressBar.color = Color.green
	else
		progressBar.color = Color.red
	end
end

--- 更新武器子弹属性Buff显示
function BattleUnitDetailView.updateBulletAttrBuff(self, weapon)
	local weaponData = self._weaponList[weapon]
	local weaponTF = weaponData.tf
	local dataDict = weaponData.data
	local attrTpl = weaponTF:Find("weapon_attr_tpl")
	local attrContainer = weaponTF:Find("weapon_attr_container")
	local expireFlags = {}

	-- 标记所有现有属性为"过期"
	for effectKey, _ in pairs(dataDict) do
		expireFlags[effectKey] = true
	end

	-- 遍历单位Buff列表，查找子弹属性Buff
	for _, buff in pairs(self._unit:GetBuffList()) do
		for _, effect in ipairs(buff:GetEffectList()) do
			if effect.__name == ys.Battle.BattleBuffAddBulletAttr.__name then
				local equipIndex = weapon:GetEquipmentIndex()

				if effect:equipIndexRequire(equipIndex) then
					local attrTF = dataDict[effect]

					if not attrTF then
						attrTF = cloneTplTo(attrTpl, attrContainer)

						setText(attrTF:Find("tag_name"), effect._attr)
						setText(attrTF:Find("src_buff"), buff:GetID())
						Canvas.ForceUpdateCanvases()

						attrTF:Find("src_buff"):GetComponent(typeof(Text)).color = Color.green
						dataDict[effect] = attrTF
					end

					setText(attrTF:Find("current"), effect._number)

					expireFlags[effect] = false
				end
			end
		end
	end

	-- 标记已过期的属性（Buff已失效）
	for effectKey, isExpired in pairs(expireFlags) do
		if isExpired then
			local expiredTF = dataDict[effectKey]

			SetActive(expiredTF:Find("expire"), true)
		end
	end
end

--- 添加Buff UI条目
function BattleUnitDetailView.addBuff(self, buffID, buff)
	local buffTF = cloneTplTo(self._buffTpl, self._buffContainer)

	Canvas.ForceUpdateCanvases()
	setText(buffTF:Find("buff_id"), "buff_" .. buffID)

	-- 高亮Buff特殊标记
	if table.contains(BattleUnitDetailView.HIGH_LIGHT_BUFF, buffID) then
		local highlightTF = buffTF:Find("high_light")

		setActive(highlightTF, true)
	end

	if buff._stack > 1 then
		local stackTF = buffTF:Find("buff_stack")

		setActive(stackTF, true)
		setText(stackTF, "x" .. buff._stack)
	end

	setActive(buffTF, true)

	self._buffList[buffID] = buffTF
end

--- 添加技能施放者记录（用于统计技能伤害和次数）
function BattleUnitDetailView.addSkillCaster(self, effect)
	local skillID = effect._skill_id
	local skillLv = effect._srcBuff:GetLv()

	-- 只统计会实际开火的技能
	if not ys.Battle.BattleSkillUnit.IsFireSkill(skillID, skillLv) then
		return
	end

	local skillData = self._skillList[skillID]

	if not skillData then
		local skillTF = cloneTplTo(self._skillTpl, self._skillContainer)
		local commonTF = skillTF:Find("common")

		setText(commonTF:Find("skillID"), effect._skill_id)

		local iconTF = skillTF:Find("common/icon")
		local iconID = effect._srcBuff._tempData.icon or 10120

		GetImageSpriteFromAtlasAsync("skillicon/" .. iconID, "", iconTF)
		Canvas.ForceUpdateCanvases()

		skillData = {
			tf = skillTF,
			effectList = {}
		}
		self._skillList[skillID] = skillData
	end

	table.insert(skillData.effectList, effect)
	self:updateCastEffectTpl(skillID)
end

--- 更新技能列表所有技能的施放统计
function BattleUnitDetailView.updateSkillList(self)
	for skillID, skillData in pairs(self._skillList) do
		self:updateCastEffectTpl(skillID)
	end
end

--- 更新单个技能的施放统计模板
function BattleUnitDetailView.updateCastEffectTpl(self, skillID)
	local skillData = self._skillList[skillID]
	local skillTF = skillData.tf
	local effectList = skillData.effectList
	local totalCast = 0
	local totalDamage = 0

	for _, effect in ipairs(effectList) do
		totalCast = totalCast + effect:GetCastCount()
		totalDamage = totalDamage + effect:GetSkillFireDamageSum()
	end

	local commonTF = skillTF:Find("common")

	setText(commonTF:Find("count"), totalCast)
	setText(commonTF:Find("damageSum"), totalDamage)
end

function BattleUnitDetailView.Dispose(self)
	pg.DelegateInfo.Dispose(self)

	self._unit = nil
	self._secondaryAttrList = nil
	self._buffList = nil
	self._weaponList = nil

	GameObject.Destroy(self._go)
	ys.EventListener.DetachEventListener(self)
end

--- 设置增量文本（正数绿色、负数红色）
--- @param tf Transform 文本所在的Transform
--- @param value number 增量值
function BattleUnitDetailView.setDeltaText(tf, value)
	setText(tf, value)

	local color = value > 0 and Color.green or Color.red

	tf:GetComponent(typeof(Text)).color = color
end

-- 武器/子弹/弹幕/飞机的 Forger 引用（留空，运行时赋值）
BattleUnitDetailView.WeaponForger = {}
BattleUnitDetailView.BulletForger = {}
BattleUnitDetailView.BarrageForger = {}
BattleUnitDetailView.AircraftForger = {}
