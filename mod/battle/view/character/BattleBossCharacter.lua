ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleBossCharacter = class("BattleBossCharacter", ys.Battle.BattleEnemyCharacter)

ys.Battle.BattleBossCharacter = BattleBossCharacter
BattleBossCharacter.__name = "BattleBossCharacter"

--- 构造函数：调用父类初始化
function BattleBossCharacter.Ctor(self)
	BattleBossCharacter.super.Ctor(self)
end

--- 销毁Boss角色：停止HP条tween，清理施法时钟和瞄准偏斜条
function BattleBossCharacter.Dispose(self)
	if not self._chargeTimer.paused then
		self._chargeTimer:Stop()
	end

	if self._castClock then
		self._castClock:Dispose()

		self._castClock = nil
	end

	if self._aimBiarBar then
		local aimBiasGO = self._aimBiarBar:GetGO()

		self._factory:GetHPBarPool():DestroyObj(aimBiasGO)
		self._aimBiarBar:Dispose()

		self._aimBiarBar = nil
	end

	LeanTween.cancel(self._HPBar)
	BattleBossCharacter.super.Dispose(self)
end

--- 每帧Update：施法时钟、护甲时钟、屏障时钟位置更新
function BattleBossCharacter.Update(self)
	BattleBossCharacter.super.Update(self)
	self:UpdateCastClockPosition()

	if self._armor then
		self:UpdateCastClock()
	end

	self:UpdateBarrierClockPosition()

	if self._barrier then
		self:updateBarrierClock()
	end
end

--- 更新反潜警戒条位置（Boss使用HP条偏移而不是默认的_hpBarPos）
function BattleBossCharacter.UpdateVigilantBarPosition(self)
	local vigilantPos = self._referenceVector + self._hpBarOffset

	self._vigilantBar:UpdateVigilantBarPosition(vigilantPos)
end

--- Boss额外注册武器打断事件
function BattleBossCharacter.RegisterWeaponListener(self, weapon)
	BattleBossCharacter.super.RegisterWeaponListener(self, weapon)
	weapon:RegisterEventListener(self, BattleUnitEvent.WEAPON_INTERRUPT, self.onWeaponInterrupted)
end

--- 取消武器打断事件
function BattleBossCharacter.UnregisterWeaponListener(self, weapon)
	BattleBossCharacter.super.UnregisterWeaponListener(self, weapon)
	weapon:UnregisterEventListener(self, BattleUnitEvent.WEAPON_INTERRUPT)
end

--- 添加Boss专用的多层HP条系统
--- - 显示Boss名称、等级、头像
--- - 初始化护甲条和屏障条
--- - 设置多层HP视觉
--- @param hpBarObj GameObject HP条对象
--- @param activeVernier boolean 是否激活游标
function BattleBossCharacter.AddHPBar(self, hpBarObj, activeVernier)
	self._HPBar = hpBarObj
	self._HPBarTf = hpBarObj.transform

	hpBarObj:SetActive(true)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.OnUpdateHP)

	self._HPBarCountText = self._HPBarTf:Find("HPBarCount"):GetComponent(typeof(Text))
	self._activeVernier = activeVernier

	self:SetTemplateInfo()
	self:initBarComponent()
	self:SetHPBarCountText(self._HPBarTotalCount)

	self._cacheHP = self._unitData:GetMaxHP()

	self:UpdateHpBar()
	self:initBarrierBar()
end

--- 设置Boss HP条的模板信息：名称、等级、类型图标、头像
function BattleBossCharacter.SetTemplateInfo(self)
	local unitTemplate = self._unitData:GetTemplate()
	local bossName = ""

	if unitTemplate then
		bossName = unitTemplate.name
	end

	self._HPBarTf:Find("BossNameBG/BossName"):GetComponent(typeof(Text)).text = bossName
	self._HPBarTf:Find("BossNameBG/BossLv"):GetComponent(typeof(Text)).text = "Lv." .. self._unitData:GetLevel()

	local enemyType = pg.enemy_data_by_type[unitTemplate.type].type
	local typeSprite = GetSpriteFromAtlas("shiptype", shipType2Battleprint(enemyType))

	setImageSprite(self._HPBarTf:Find("BossIcon/typeIcon/icon"), typeSprite, true)

	local bossIcon = ys.Battle.BattleResourceManager.GetInstance():GetCharacterSquareIcon(self._bossIcon)

	setImageSprite(findTF(self._HPBarTf, "BossIcon/icon"), bossIcon)

	-- 护甲条
	self._armorBar = self._HPBarTf:Find("ArmorBar")
	self._armorProgress = self._HPBarTf:Find("ArmorBar/armorProgress"):GetComponent(typeof(Image))

	SetActive(self._armorBar, false)

	-- 屏障条
	self._barrierBar = self._HPBarTf:Find("ShieldBar")
	self._barrierProgress = self._barrierBar:Find("shieldProgress"):GetComponent(typeof(Image))

	SetActive(self._barrierBar, false)
end

--- 设置Boss关卡数据：HP条数量、图标、Boss序号
--- @param bossData table {hpBarNum, hideBarNum, icon, bossCount}
function BattleBossCharacter.SetBossData(self, bossData)
	self._bossBarInfoList = {}
	self._HPBarTotalCount = bossData.hpBarNum or 1
	self._hideBarNum = bossData.hideBarNum
	self._bossIcon = self:GetUnitData():GetTemplate().icon
	self._bossIndex = bossData.bossCount
end

--- @return number Boss序号
function BattleBossCharacter.GetBossIndex(self)
	return self._bossIndex
end

--- 初始化多层HP条组件：创建5个HP条段、游标和循环tween定时器
function BattleBossCharacter.initBarComponent(self)
	self._stepHP = self:GetUnitData():GetMaxHP() / self._HPBarTotalCount

	local barIndex = 1

	self._resTotalCount = 5
	self._bossBarInfoList = {}

	-- 创建5个HP条段（hp_1 ~ hp_5，各有delta）
	while barIndex <= self._resTotalCount do
		local barInfo = {}
		local barPath = "bloodBarContainer/hp_" .. barIndex
		local deltaPath = barPath .. "_delta"
		local barTF = self._HPBarTf:Find(barPath)
		local deltaTF = self._HPBarTf:Find(deltaPath)

		barInfo.progressImage = barTF:GetComponent(typeof(Image))
		barInfo.deltaImage = deltaTF:GetComponent(typeof(Image))
		barInfo.progressTF = barTF.transform
		barInfo.deltaTF = deltaTF.transform
		barInfo.progressImage.fillAmount = 1
		barInfo.deltaImage.fillAmount = 1
		self._bossBarInfoList[barIndex] = barInfo
		barIndex = barIndex + 1
	end

	self._topBarIndex = self._HPBarTf.childCount - 1
	self._currentFmod = math.fmod(self._HPBarTotalCount, self._resTotalCount)

	if self._currentFmod == 0 then
		self._currentFmod = self._resTotalCount
	end

	-- HP条总数少于5时隐藏多余的条
	if self._HPBarTotalCount < 5 then
		local hideIdx = self._resTotalCount

		while hideIdx > self._HPBarTotalCount do
			local barPath = "bloodBarContainer/hp_" .. hideIdx

			SetActive(self._HPBarTf:Find(barPath), false)
			SetActive(self._HPBarTf:Find(barPath .. "_delta"), false)

			hideIdx = hideIdx - 1
		end
	else
		-- 总数>=5时把多余的条沉底（用于循环复用）
		local overflowIdx = self._resTotalCount

		while overflowIdx > self._currentFmod do
			local barPath = "bloodBarContainer/hp_" .. overflowIdx

			self._HPBarTf:Find(barPath).transform:SetSiblingIndex(0)
			self._HPBarTf:Find(barPath .. "_delta").transform:SetSiblingIndex(0)

			overflowIdx = overflowIdx - 1
		end
	end

	if self._activeVernier then
		self._vernier = self._HPBarTf:Find("vernier/tag")

		SetActive(self._HPBarTf:Find("vernier"), self._activeVernier)
	end

	-- HP条delta动画定时器（每秒生成tween）
	self._chargeTimer = Timer.New(function()
		self._currentTween = self:generateTween()
	end, 1)
end

--- 更新Boss HP条：计算当前分条和填充量，播放delta动画
function BattleBossCharacter.UpdateHpBar(self)
	local currentHP = self._unitData:GetCurrentHP()

	if self._cacheHP == currentHP then
		return
	end

	if not self._chargeTimer.paused then
		self._chargeTimer:Stop()
		self._chargeTimer:Stop()
		self._chargeTimer:Reset()
	end

	local currentFmod, fillAmount, currentDivision = self:GetCurrentFmod()

	self:SortBar(currentFmod, currentDivision)

	self._currentFmod = currentFmod
	self._currentDivision = currentDivision

	if currentHP < self._cacheHP then
		if self._currentDivision ~= currentDivision then
			LeanTween.cancel(self._HPBar)
		end

		self._chargeTimer:Start()
	end

	self._bossBarInfoList[currentFmod].progressImage.fillAmount = fillAmount

	if self._activeVernier then
		self._vernier.anchorMin = Vector2(fillAmount, 0.5)
		self._vernier.anchorMax = Vector2(fillAmount, 0.5)
	end

	self:SetHPBarCountText(currentDivision)

	self._cacheHP = currentHP
end

--- 生成HP条delta动画tween（当前段从delta值渐变到progress值）
--- @return LeanTween tween对象
function BattleBossCharacter.generateTween(self)
	local barInfo = self._bossBarInfoList[self._currentFmod]
	local deltaImage = barInfo.deltaImage
	local targetFill = barInfo.progressImage.fillAmount

	duration = duration or 0.7

	return (LeanTween.value(go(self._HPBar), deltaImage.fillAmount, targetFill, 0.7):setOnUpdate(System.Action_float(function(value)
		deltaImage.fillAmount = value
	end)))
end

--- 获取当前HP的分段信息
--- @return number currentFmod 当前段索引 (1-5)
--- @return number fillAmount 当前段填充比例 (0-1)
--- @return number currentDivision 当前是第几管HP
function BattleBossCharacter.GetCurrentFmod(self)
	local currentHP = self._unitData:GetCurrentHP()
	local barIndex, fillAmount = math.modf(currentHP / self._stepHP)
	local currentDivision = barIndex + 1
	local currentFmod = math.fmod(currentDivision, self._resTotalCount)

	if currentFmod == 0 then
		currentFmod = 5
	end

	return currentFmod, fillAmount, currentDivision
end

--- 分段HP条排序：当HP跨段时显示/隐藏对应的条段
--- @param newFmod number 新的当前段索引
--- @param currentDivision number 当前第几管
function BattleBossCharacter.SortBar(self, newFmod, currentDivision)
	if newFmod == self._currentFmod then
		return
	elseif newFmod > self._currentFmod then
		-- HP增加（回血）：从旧段到新段逐段填满并置顶
		local fillIdx = self._currentFmod

		self._bossBarInfoList[fillIdx].progressImage.fillAmount = 1
		self._bossBarInfoList[fillIdx].deltaImage.fillAmount = 1

		while fillIdx < newFmod do
			fillIdx = fillIdx + 1

			local barInfo = self._bossBarInfoList[fillIdx]

			barInfo.deltaTF:SetSiblingIndex(self._topBarIndex)
			barInfo.progressTF:SetSiblingIndex(self._topBarIndex)
			SetActive(barInfo.progressImage, true)
			SetActive(barInfo.deltaImage, true)
		end
	elseif newFmod < self._currentFmod then
		-- HP减少（扣血）：旧段填满并沉底
		local clearIdx = self._currentFmod

		while newFmod < clearIdx do
			local barInfo = self._bossBarInfoList[clearIdx]

			barInfo.progressImage.fillAmount = 1
			barInfo.deltaImage.fillAmount = 1

			barInfo.progressTF:SetSiblingIndex(0)
			barInfo.deltaTF:SetSiblingIndex(0)

			if currentDivision < self._resTotalCount then
				SetActive(barInfo.progressImage, false)
				SetActive(barInfo.deltaImage, false)
			end

			clearIdx = clearIdx - 1
		end
	end
end

--- 设置HP条计数文本（"X N"或"X??"如果隐藏）
--- @param count number 当前HP管序号
function BattleBossCharacter.SetHPBarCountText(self, count)
	if self._hideBarNum then
		self._HPBarCountText.text = "X??"
	else
		self._HPBarCountText.text = "X " .. count
	end
end

--- 更新HP条位置（使用_normalHPTF位置）
function BattleBossCharacter.UpdateHPBarPosition(self)
	if self._normalHPTF and not self._hideHP then
		self._hpBarPos:Copy(self._referenceVector):Add(self._hpBarOffset)

		self._normalHPTF.position = self._hpBarPos
	end
end

--- 武器前摇：初始化护甲条和施法时钟
--- @param event table {Data = {fx, armor, time}}
function BattleBossCharacter.onWeaponPreCast(self, event)
	BattleBossCharacter.super.onWeaponPreCast(self, event)

	local precastData = event.Data
	local armorValue = precastData.armor

	self:initArmorBar(precastData.armor)

	if armorValue and armorValue ~= 0 then
		self:initCastClock(precastData.time, event.Dispatcher)
	end
end

--- 武器前摇结束：清除护甲和施法时钟（护甲被打穿则强制中断）
--- @param event table {Data = {armor}, Dispatcher}
function BattleBossCharacter.onWeaponPrecastFinish(self, event)
	BattleBossCharacter.super.onWeaponPrecastFinish(self, event)

	local armorValue = event.Data.armor
	local weapon = event.Dispatcher

	if self._castClock:GetCastingWeapon() == weapon and armorValue and armorValue ~= 0 then
		if self._armor <= 0 then
			self._castClock:Interrupt(true)
		else
			self._castClock:Interrupt(false)
		end

		self._armor = nil

		SetActive(self._armorBar, false)
	end
end

--- 武器被打断：切换到中断状态
function BattleBossCharacter.onWeaponInterrupted(self, event)
	self._unitData:StateChange(ys.Battle.UnitState.STATE_INTERRUPT)
end

--- 初始化护甲条：设置护甲值和总护甲，显示护甲UI
--- @param armorValue number 护甲值
function BattleBossCharacter.initArmorBar(self, armorValue)
	if armorValue and armorValue ~= 0 then
		self._armor = armorValue
		self._totalArmor = armorValue

		self:updateWeaponArmor()
		SetActive(self._armorBar, true)
	end
end

--- HP更新：处理屏障和护甲的伤害穿透
--- @param event table {Data = {dHP, preShieldHP}}
function BattleBossCharacter.OnUpdateHP(self, event)
	local preShieldHP = event.Data.preShieldHP

	-- 屏障先吸收伤害
	if self._barrier and preShieldHP < 0 then
		self._barrier = self._barrier + preShieldHP

		self:updateBarrierBar()
	end

	BattleBossCharacter.super.OnUpdateHP(self, event)

	local dHP = event.Data.dHP

	-- 护甲承受剩余伤害
	if self._armor and dHP < 0 then
		self._armor = self._armor + dHP

		self:updateWeaponArmor()
	end
end

--- 更新护甲填充量
function BattleBossCharacter.updateWeaponArmor(self)
	self._armorProgress.fillAmount = self._armor / self._totalArmor
end

--- 初始化施法时钟：记录施法结束时间和总时长
--- @param duration number 施法时长
--- @param weapon BattleWeaponUnit 施法武器
function BattleBossCharacter.initCastClock(self, duration, weapon)
	self._castClock:Casting(duration, weapon)

	self._castFinishTime = pg.TimeMgr.GetInstance():GetCombatTime() + duration
	self._castDuration = duration
end

--- 更新施法时钟进度
function BattleBossCharacter.UpdateCastClock(self)
	self._castClock:UpdateCastClock()
end

--- Boss的HP条在潜入时也保持可见
function BattleBossCharacter.updateComponentDiveInvisible(self)
	BattleBossCharacter.super.updateComponentDiveInvisible(self)
	SetActive(self._HPBarTf, true)
end

--- Boss的HP条始终可见
function BattleBossCharacter.updateComponentVisible(self)
	BattleBossCharacter.super.updateComponentVisible(self)
	SetActive(self._HPBarTf, true)
end

--- 初始化屏障条事件监听
function BattleBossCharacter.initBarrierBar(self)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.BARRIER_STATE_CHANGE, self.onBarrierStateChange)
end

--- 屏障状态变化：初始化或移除屏障UI
--- @param event table {Data = {barrierDurability, barrierDuration}}
function BattleBossCharacter.onBarrierStateChange(self, event)
	local barrierDurability = event.Data.barrierDurability
	local barrierDuration = event.Data.barrierDuration

	SetActive(self._barrierBar, barrierDurability > 0)

	if barrierDurability > 0 then
		self._totalBarrier = barrierDurability
		self._barrier = barrierDurability

		self:initBarrierClock(barrierDuration)
		self:updateBarrierBar()
		self:updateBarrierClock()
	else
		self._barrier = nil
		self._totalBarrier = nil

		self._barrierClock:Interrupt()
	end
end

--- 更新屏障填充量
function BattleBossCharacter.updateBarrierBar(self)
	self._barrierProgress.fillAmount = self._barrier / self._totalBarrier
end

--- 更新屏障时钟进度
function BattleBossCharacter.updateBarrierClock(self)
	self._barrierClock:UpdateBarrierClockProgress()
end

--- 初始化屏障时钟
--- @param duration number 屏障持续时间
function BattleBossCharacter.initBarrierClock(self, duration)
	self._barrierClock:Shielding(duration)
end

--- Boss的瞄准偏斜条：在HP条容器内找到biasBar子对象
--- @param aimBiasBarObj GameObject 偏斜条容器
function BattleBossCharacter.AddAimBiasBar(self, aimBiasBarObj)
	self._normalHPTF = aimBiasBarObj
	self._aimBiarBarTF = aimBiasBarObj:Find("biasBar")
	self._aimBiarBar = ys.Battle.BattleAimbiasBar.New(self._aimBiarBarTF)

	self._aimBiarBar:ConfigAimBias(self._unitData:GetAimBias())
	self._aimBiarBar:UpdateAimBiasProgress()
end

--- 添加模型后立即更新位置
function BattleBossCharacter.AddModel(self, modelGO)
	BattleBossCharacter.super.AddModel(self, modelGO)
	self:UpdatePosition()
end
