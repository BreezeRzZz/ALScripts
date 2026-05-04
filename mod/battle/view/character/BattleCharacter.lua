ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local BattleResourceManager = ys.Battle.BattleResourceManager
local BattleFormulas = ys.Battle.BattleFormulas
local BattleCharacter = class("BattleCharacter", ys.Battle.BattleSceneObject)

ys.Battle.BattleCharacter = BattleCharacter
BattleCharacter.__name = "BattleCharacter"

--- 屏幕外箭头隐藏时的锚点位置（远离屏幕）
local OFF_SCREEN_POS = Vector2(-1200, -1200)
--- 聊天气泡在屏幕外时的偏移量
local CHAT_OFFSCREEN_OFFSET = Vector3.New(0.3, -1.8, 0)

BattleCharacter.AIM_OFFSET = Vector3.New(0, -3.5, 0)

--- 箭头朝向左侧时的缩放
local ARROW_SCALE_LEFT = Vector3(-1, 1, 1)
--- 箭头朝向右侧时的缩放
local ARROW_SCALE_RIGHT = Vector3(1, 1, 1)

--- 构造函数，初始化所有内部状态
function BattleCharacter.Ctor(self)
	BattleCharacter.super.Ctor(self)
	self:Init()
end

--- 初始化内部状态：事件监听、子弹工厂、特效视图、各种缓存列表
function BattleCharacter.Init(self)
	ys.EventListener.AttachEventListener(self)
	self:InitBulletFactory()
	self:InitEffectView()

	self._tagFXList = {}
	self._cacheFXList = {}
	self._allFX = {}
	self._bulletCache = {}
	self._weaponRegisterList = {}
	self._characterPos = Vector3.zero
	self._orbitCount = 0
	self._orbitList = {}
	self._orbitSpineOrderOffset = 0
	self._orbitActionCacheList = {}
	self._orbitSpeedUpdateList = {}
	self._orbitActionUpdateList = {}
	self._inViewArea = false
	self._alwaysHideArrow = false
	self._hideHP = false
	self._referenceVector = Vector3.zero
	self._referenceVectorCache = Vector3.zero
	self._referenceVectorTemp = Vector3.zero
	self._referenceUpdateFlag = false
	self._referenceVectorBorn = nil
	self._hpBarPos = Vector3.zero
	self._arrowVector = Vector3.zero
	self._arrowAngleVector = Vector3.zero
	self._blinkDict = {}
	self._coverSpineHPBarOffset = 0
	self._shaderType = nil
	self._color = nil
	self._actionIndex = nil
end

--- 获取子弹工厂列表
function BattleCharacter.InitBulletFactory(self)
	self._bulletFactoryList = ys.Battle.BattleBulletFactory.GetFactoryList()
end

--- 设置关联的UnitData，并注册单位事件监听
--- @param unitData BattleUnitData 战斗单位数据
function BattleCharacter.SetUnitData(self, unitData)
	self._unitData = unitData

	self:AddUnitEvent()
end

--- 初始化骨骼绑定列表，从模板的 bound_bone 和通用骨骼配置读取
function BattleCharacter.SetBoneList(self)
	self._boneList = {}
	self._remoteBoneTable = {}
	self._bonePosTable = nil
	self._posMatrix = nil

	local initScale = self:GetInitScale()

	for boneName, boneData in pairs(self._unitData:GetTemplate().bound_bone) do
		if boneName ~= "remote" then
			self:insertBondList(boneName, boneData)
		end
	end

	for boneName, boneData in pairs(BattleConfig.CommonBone) do
		self:insertBondList(boneName, boneData)
	end
end

--- 插入单个骨骼绑定到 _boneList
--- @param boneName string 骨骼名称
--- @param bonePositions table 骨骼位置数据列表
function BattleCharacter.insertBondList(self, boneName, bonePositions)
	for _, posEntry in ipairs(bonePositions) do
		if type(posEntry) == "table" then
			local bonePosArray = {}

			bonePosArray[#bonePosArray + 1] = Vector3(posEntry[1], posEntry[2], posEntry[3])
			self._boneList[boneName] = bonePosArray
		end
	end
end

--- 根据子弹模板在指定骨骼位置生成子弹
--- @param bulletTmp BattleBulletTemplate 子弹模板
--- @param spawnBone string 生成骨骼名
--- @param fireFxID string|nil 开火特效ID
--- @param spawnPos Vector3|nil 指定生成位置（可选）
function BattleCharacter.SpawnBullet(self, bulletTmp, spawnBone, fireFxID, spawnPos)
	local bulletFactory = self._bulletFactoryList[bulletTmp:GetTemplate().type]
	local remoteBonePos = self._unitData:GetRemoteBoundBone(spawnBone)
	local finalPos = spawnPos or remoteBonePos or self:GetBonePos(spawnBone)

	bulletFactory:CreateBullet(self._tf, bulletTmp, finalPos, fireFxID, self._unitData:GetDirection())
end

--- 获取指定骨骼的世界坐标位置
--- 使用 localToWorldMatrix 缓存加速，每帧重置一次
--- @param boneName string 骨骼名
--- @return Vector3 骨骼的世界坐标
function BattleCharacter.GetBonePos(self, boneName)
	local bonePosArray = self._boneList[boneName]

	-- 如果指定骨骼不存在，则使用任意第一个骨骼
	if bonePosArray == nil or #bonePosArray == 0 then
		for _, positions in pairs(self._boneList) do
			bonePosArray = positions

			break
		end
	end

	local matrix

	if not self._posMatrix then
		matrix = self._tf.localToWorldMatrix
		self._posMatrix = matrix
		self._bonePosTable = {}
	else
		matrix = self._posMatrix
	end

	local cachedPositions = self._bonePosTable[boneName]

	if cachedPositions == nil then
		cachedPositions = {}

		for _, localPos in ipairs(bonePosArray) do
			cachedPositions[#cachedPositions + 1] = matrix:MultiplyPoint3x4(localPos)
		end

		self._bonePosTable[boneName] = cachedPositions
	end

	-- 如果只有一个位置直接返回，否则随机选择（用于多骨骼位置随机发射）
	if #cachedPositions == 1 then
		return cachedPositions[1]
	else
		return cachedPositions[math.floor(math.Random(0, #cachedPositions)) + 1]
	end
end

--- @return table 骨骼列表
function BattleCharacter.GetBoneList(self)
	return self._boneList
end

--- 存储特效挂载点和偏移表
function BattleCharacter.AddFXOffsets(self, attachPoint, fxOffsets)
	self._FXAttachPoint = attachPoint
	self._FXOffset = fxOffsets
end

--- 获取指定特效容器的偏移位置
--- @param fxIndex number|nil 特效容器索引，默认为1
function BattleCharacter.GetFXOffsets(self, fxIndex)
	fxIndex = fxIndex or 1

	return self._FXOffset[fxIndex]
end

--- @return Transform 特效挂载点
function BattleCharacter.GetAttachPoint(self)
	return self._FXAttachPoint
end

--- 获取特定FX缩放（子类可重写）
--- @return table 缩放表
function BattleCharacter.GetSpecificFXScale(self)
	return {}
end

--- 在角色位置直接播放特效（不跟随角色）
--- @param fxName string 特效名称
function BattleCharacter.PlayFX(self, fxName)
	local fx = self:GetFactory():GetFXPool():GetFX(fxName)

	pg.EffectMgr.GetInstance():PlayBattleEffect(fx, self:GetPosition(), true)
end

--- 给角色添加跟随特效
--- @param fxName string 特效名称
--- @param useCache boolean|nil 是否缓存以便批量移除
--- @param timeScale number|nil 时间缩放
--- @param callback function|nil 播放完成回调
--- @return GameObject 特效对象
function BattleCharacter.AddFX(self, fxName, useCache, timeScale, callback)
	local fxObj = self:GetFactory():GetFXPool():GetCharacterFX(fxName, self, not useCache, function(fx)
		if callback then
			callback()
		end

		self._allFX[fx] = nil
	end, timeScale)

	if useCache then
		local cacheList = self._cacheFXList[fxName] or {}

		table.insert(cacheList, fxObj)

		self._cacheFXList[fxName] = cacheList
	end

	self._allFX[fxObj] = true

	return fxObj
end

--- 移除指定特效
--- @param fxObj GameObject 特效对象
function BattleCharacter.RemoveFX(self, fxObj)
	if self._allFX and self._allFX[fxObj] then
		self._allFX[fxObj] = nil

		BattleResourceManager.GetInstance():DestroyOb(fxObj)
	end
end

--- 通过名称从缓存中移除最后一个该类型特效
--- @param fxName string 特效名称
function BattleCharacter.RemoveCacheFX(self, fxName)
	local cacheList = self._cacheFXList[fxName]

	if cacheList ~= nil and #cacheList > 0 then
		local removedFx = table.remove(cacheList)

		self._allFX[removedFx] = nil

		BattleResourceManager.GetInstance():DestroyOb(removedFx)
	end
end

--- 添加移动浪花特效
function BattleCharacter.AddWaveFX(self, fxName)
	self._waveFX = self:AddFX(fxName)
end

--- 移除移动浪花特效
function BattleCharacter.RemoveWaveFX(self)
	if not self._waveFX then
		return
	end

	self:RemoveFX(self._waveFX)
end

--- Buff计时器更新回调
--- @param event table 事件数据 {Data = {isActive, ...}}
function BattleCharacter.onAddBuffClock(self, event)
	local eventData = event.Data

	if eventData.isActive then
		if not self._buffClock then
			self._factory:MakeBuffClock(self)
		end

		self._buffClock:Casting(eventData)
	else
		self._buffClock:Interrupt(eventData)
	end
end

--- 给Spine角色添加闪烁效果
--- @param r number 红色分量
--- @param g number 绿色分量
--- @param b number 蓝色分量
--- @param period number|nil 闪烁周期，默认0.1
--- @param duration number|nil 闪烁持续时间，默认0.1
--- @param keepForever boolean|nil 是否永久，默认false
--- @param alpha number|nil 透明度，默认0.18
--- @return number|nil 闪烁ID（用于移除）
function BattleCharacter.AddBlink(self, r, g, b, period, duration, keepForever, alpha)
	-- 下潜隐身时不允许闪烁
	if self._unitData:GetDiveInvisible() then
		return nil
	end

	-- 盲烟暴露检查
	if not self._unitData:GetExposed() then
		return nil
	end

	period = period or 0.1
	duration = duration or 0.1
	keepForever = keepForever or false
	alpha = alpha or 0.18

	local blinkID = SpineAnim.CharBlink(self._go, r, g, b, alpha, period, duration, keepForever)

	if not keepForever then
		self._blinkDict[blinkID] = {
			r = r,
			g = g,
			b = b,
			a = alpha,
			peroid = period,
			duration = duration
		}
	end

	return blinkID
end

--- 移除闪烁效果
--- @param blinkID number 闪烁ID
function BattleCharacter.RemoveBlink(self, blinkID)
	self._blinkDict[blinkID] = nil

	SpineAnim.RemoveBlink(self._go, blinkID)
end

--- 给角色添加Shader着色
--- @param color Color|nil 着色颜色，默认透明黑
function BattleCharacter.AddShaderColor(self, color)
	if not self._unitData:GetExposed() then
		return
	end

	color = color or Color.New(0, 0, 0, 0)

	SpineAnim.AddShaderColor(self._go, color)
end

--- @return Vector3 角色当前世界坐标
function BattleCharacter.GetPosition(self)
	return self._characterPos
end

--- @return BattleUnitData 关联的单位数据
function BattleCharacter.GetUnitData(self)
	return self._unitData
end

--- 获取死亡爆炸特效ID
--- @return string|nil 爆炸特效ID
function BattleCharacter.GetDestroyFXID(self)
	return self:GetUnitData():GetTemplate().bomb_fx
end

--- 获取prefab位置偏移（用于编辑器中的站位调整）
--- @return Vector3 偏移量
function BattleCharacter.GetOffsetPos(self)
	return (BuildVector3(self._unitData:GetTemplate().position_offset))
end

--- 获取参考坐标（用于UI定位）。如果传入对比坐标则计算相对差值
--- @param comparePos Vector3|nil 用于比较的坐标
--- @return Vector3 参考坐标
function BattleCharacter.GetReferenceVector(self, comparePos)
	if comparePos == nil then
		return self._referenceVector
	else
		self._referenceVectorTemp:Set(self._characterPos.x, self._characterPos.y, self._characterPos.z)
		self._referenceVectorTemp:Sub(comparePos)
		ys.Battle.BattleVariable.CameraPosToUICameraByRef(self._referenceVectorTemp)

		self._referenceVectorTemp.z = 2

		return self._referenceVectorTemp
	end
end

--- 获取初始模型缩放
--- @return number 缩放值
function BattleCharacter.GetInitScale(self)
	return self._unitData:GetAttrByName("modelScale")
end

--- 注册所有单位事件监听（子弹、武器、特效、buff等）
function BattleCharacter.AddUnitEvent(self)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.SPAWN_CACHE_BULLET, self.onSpawnCacheBullet)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.CREATE_TEMPORARY_WEAPON, self.onNewWeapon)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.POP_UP, self.onPopup)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.VOICE, self.onVoice)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.PLAY_FX, self.onPlayFX)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.REMOVE_WEAPON, self.onRemoveWeapon)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.ADD_BLINK, self.onBlink)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.SUBMARINE_VISIBLE, self.onUpdateDiveInvisible)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.SUBMARINE_DETECTED, self.onDetected)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.SUBMARINE_FORCE_DETECTED, self.onForceDetected)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.BLIND_VISIBLE, self.onUpdateBlindInvisible)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.BLIND_EXPOSE, self.onBlindExposed)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.INIT_ANIT_SUB_VIGILANCE, self.onInitVigilantState)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.INIT_CLOAK, self.onInitCloak)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_CONFIG, self.onUpdateCloakConfig)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_LOCK, self.onUpdateCloakLock)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.INIT_AIMBIAS, self.onInitAimBias)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_AIMBIAS_LOCK, self.onUpdateAimBiasLock)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.HOST_AIMBIAS, self.onHostAimBias)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.REMOVE_AIMBIAS, self.onRemoveAimBias)
	self._unitData:RegisterEventListener(self, ys.Battle.BattleBuffEvent.BUFF_EFFECT_CHNAGE_SIZE, self.onChangeSize)
	self._unitData:RegisterEventListener(self, ys.Battle.BattleBuffEvent.BUFF_EFFECT_NEW_WEAPON, self.onNewWeapon)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.HIDE_WAVE_FX, self.RemoveWaveFX)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.ADD_BUFF_CLOCK, self.onAddBuffClock)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.SWITCH_SPINE, self.onSwitchSpine)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.SWITCH_SHADER, self.onSwitchShader)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_SCORE, self.onUpdateScore)

	local autoWeapons = self._unitData:GetAutoWeapons()

	for _, weapon in ipairs(autoWeapons) do
		self:RegisterWeaponListener(weapon)
	end

	self._effectOb:SetUnitDataEvent(self._unitData)
end

--- 移除所有单位事件监听
function BattleCharacter.RemoveUnitEvent(self)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.UPDATE_HP)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.CREATE_TEMPORARY_WEAPON)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.CHANGE_ACTION)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.SPAWN_CACHE_BULLET)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.POP_UP)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.VOICE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.PLAY_FX)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.REMOVE_WEAPON)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.ADD_BLINK)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.SUBMARINE_VISIBLE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.SUBMARINE_DETECTED)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.SUBMARINE_FORCE_DETECTED)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.BLIND_VISIBLE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.BLIND_EXPOSE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.UPDATE_SCORE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.CHANGE_ANTI_SUB_VIGILANCE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.INIT_ANIT_SUB_VIGILANCE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.ANTI_SUB_VIGILANCE_SONAR_CHECK)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_CONFIG)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.UPDATE_CLOAK_LOCK)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.INIT_CLOAK)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.HOST_AIMBIAS)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.UPDATE_AIMBIAS_LOCK)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.INIT_AIMBIAS)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.REMOVE_AIMBIAS)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.ADD_BUFF_CLOCK)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.SWITCH_SPINE)
	self._unitData:UnregisterEventListener(self, BattleUnitEvent.SWITCH_SHADER)
	self._unitData:UnregisterEventListener(self, ys.Battle.BattleBuffEvent.BUFF_EFFECT_CHNAGE_SIZE)
	self._unitData:UnregisterEventListener(self, ys.Battle.BattleBuffEvent.BUFF_EFFECT_NEW_WEAPON)

	for weaponUnit, _ in pairs(self._weaponRegisterList) do
		self:UnregisterWeaponListener(weaponUnit)
	end
end

--- 每帧Update：更新UI组件、HP弹出、动画特效、标签特效
--- 如果参考坐标有变化，则更新HP条和弹出容器位置
function BattleCharacter.Update(self)
	local combatTime = pg.TimeMgr.GetInstance():GetCombatTime()

	self._bonePosSet = nil

	self:UpdateUIComponentPosition()
	self:UpdateHPPop()
	self:UpdateAniEffect(combatTime)
	self:UpdateTagEffect(combatTime)

	if self._referenceUpdateFlag then
		self:UpdateHPBarPosition()
		self:UpdateHPPopContainerPosition()
	end

	self:UpdateChatPosition()
	self:UpdateHpBar()
	self:updateSomkeFX()
	self:UpdateAimBiasBar()
	self:UpdateBuffClock()
	self:UpdateOrbit()
end

--- 给武器注册子弹创建和开火事件监听
--- @param weapon BattleWeaponUnit 武器实例
function BattleCharacter.RegisterWeaponListener(self, weapon)
	if self._weaponRegisterList[weapon] then
		return
	end

	weapon:RegisterEventListener(self, BattleUnitEvent.CREATE_BULLET, self.onCreateBullet)
	weapon:RegisterEventListener(self, BattleUnitEvent.FIRE, self.onCannonFire)

	self._weaponRegisterList[weapon] = true
end

--- 取消武器的事件监听
--- @param weapon BattleWeaponUnit 武器实例
function BattleCharacter.UnregisterWeaponListener(self, weapon)
	self._weaponRegisterList[weapon] = nil

	weapon:UnregisterEventListener(self, BattleUnitEvent.CREATE_BULLET)
	weapon:UnregisterEventListener(self, BattleUnitEvent.FIRE)
end

--- 子弹创建事件处理：从武器事件数据中提取子弹模板和生成参数
--- @param event table 武器发射事件
function BattleCharacter.onCreateBullet(self, event)
	local bulletTmp = event.Data.bullet
	local spawnBone = event.Data.spawnBound
	local fireFxID = event.Data.fireFxID
	local spawnPos = event.Data.position

	self:SpawnBullet(bulletTmp, spawnBone, fireFxID, spawnPos)
end

--- 武器开火事件处理：支持武器缓存机制
--- @param event table 武器开火事件 {Dispatcher, Data = {target, actionIndex}}
function BattleCharacter.onCannonFire(self, event)
	local weapon = event.Dispatcher
	local target = event.Data.target
	local actionIndex = event.Data.actionIndex or "attack"
	local needWeaponCache = self._unitData:NeedWeaponCache()
	local shouldCache

	if not needWeaponCache then
		if self._cacheWeapon == nil then
			shouldCache = false
		else
			shouldCache = true
		end
	else
		self._cacheWeapon = {}
		shouldCache = true

		self._unitData:StateChange(ys.Battle.UnitState.STATE_ATTACK, actionIndex)
	end

	if shouldCache == true then
		local cacheEntry = {
			weapon = weapon,
			target = target,
		}

		self._cacheWeapon[#self._cacheWeapon + 1] = cacheEntry
	else
		weapon:DoAttack(target)
	end
end

--- 缓存子弹全部生成：在动画帧中批量释放所有缓存的武器攻击
function BattleCharacter.onSpawnCacheBullet(self)
	if self._cacheWeapon then
		for _, cacheEntry in ipairs(self._cacheWeapon) do
			cacheEntry.weapon:DoAttack(cacheEntry.target)

			if not self._unitData:IsAlive() then
				break
			end
		end

		self._cacheWeapon = nil
	end
end

--- 动态添加新武器的事件注册
--- @param event table 新武器事件 {Data = {weapon}}
function BattleCharacter.onNewWeapon(self, event)
	local weapon = event.Data.weapon

	self:RegisterWeaponListener(weapon)
end

--- 弹出气泡文字事件处理
--- @param event table {Data = {content, duration, key}}
function BattleCharacter.onPopup(self, event)
	local eventData = event.Data
	local content = eventData.content
	local duration = eventData.duration
	local key = eventData.key

	self:SetPopup(content, duration, key)
end

--- 语音播放事件处理
--- @param event table {Data = {content, key}}
function BattleCharacter.onVoice(self, event)
	local eventData = event.Data
	local voiceContent = eventData.content
	local voiceKey = eventData.key

	self:Voice(voiceContent, voiceKey)
end

--- 播放特效事件处理
--- @param event table {Data = {fxName, notAttach}}
function BattleCharacter.onPlayFX(self, event)
	local fxName = event.Data.fxName

	if event.Data.notAttach then
		self:PlayFX(fxName)
	else
		self:AddFX(fxName)
	end
end

--- 移除武器事件处理：清理缓存中的武器引用并取消注册
--- @param event table {Data = {weapon}}
function BattleCharacter.onRemoveWeapon(self, event)
	local weapon = event.Data.weapon

	if self._cacheWeapon then
		for idx, cacheEntry in ipairs(self._cacheWeapon) do
			if cacheEntry.weapon == weapon then
				table.remove(self._cacheWeapon, idx)

				break
			end
		end
	end

	self:UnregisterWeaponListener(weapon)
end

--- 闪烁事件处理
--- @param event table {Data = {blink = {red, green, blue, alpha, peroid, duration}}}
function BattleCharacter.onBlink(self, event)
	local blinkData = event.Data.blink
	local r = blinkData.red
	local g = blinkData.green
	local b = blinkData.blue
	local a = blinkData.alpha
	local period = blinkData.peroid
	local duration = blinkData.duration

	self:AddBlink(r, g, b, period, duration, true, a)
end

--- 下潜隐身状态变化事件
function BattleCharacter.onUpdateDiveInvisible(self, event)
	self:UpdateDiveInvisible()
end

--- 更新下潜隐身视觉效果
--- - 我方潜艇：半透明shader
--- - 敌方潜艇：水下滤镜颜色 + 渐变透明
--- @param isDiveStart boolean|nil 是否是下潜开始时
function BattleCharacter.UpdateDiveInvisible(self, isDiveStart)
	if not self._go then
		return
	end

	local isDiveInvisible = not self._unitData:GetForceExpose() and self._unitData:GetDiveInvisible()
	local isFoe = self._unitData:GetIFF() == BattleConfig.FOE_CODE

	if isDiveInvisible then
		local filterColor = self:GetFactory():GetDivingFilterColor()

		self:updateInvisible(isDiveInvisible, isFoe and "GRID_TRANSPARENT" or "SEMI_TRANSPARENT", filterColor)

		if not isDiveStart and isFoe then
			self:spineSemiTransparentFade(0, 0.7, 0)
		end
	else
		self:updateInvisible(isDiveInvisible)

		if not isFoe then
			self:AddShaderColor()
		end
	end

	if isFoe then
		self:updateComponentVisible()
	end
end

--- 盲烟隐身状态变化事件
function BattleCharacter.onUpdateBlindInvisible(self, event)
	self:UpdateBlindInvisible()
end

--- 更新盲烟隐身：根据暴露状态控制Renderer和UI组件可见性
function BattleCharacter.UpdateBlindInvisible(self)
	local exposed = self._unitData:GetExposed()

	self:GetTf():GetComponent(typeof(Renderer)).enabled = exposed

	self:updateComponentVisible()
end

--- 更新角色透明/显形状态
--- @param isInvisible boolean 是否隐身
--- @param shaderType string|nil 着色器类型（隐身时使用）
--- @param color Color|nil 着色颜色
function BattleCharacter.updateInvisible(self, isInvisible, shaderType, color)
	if isInvisible then
		self:SwitchShader(shaderType, color)
		self._animator:ChangeRenderQueue(2999)
	else
		self:SwitchShader("COLORED_ALPHA")
		self._animator:ChangeRenderQueue(3000)
	end

	-- 隐身时隐藏浪花特效
	if self._waveFX then
		SetActive(self._waveFX.transform, not isInvisible)
	end
end

--- 反潜探测事件处理：被发现时显示"shock"特效
function BattleCharacter.onDetected(self, event)
	if not self._go then
		return
	end

	if self._unitData:GetDiveDetected() and self._unitData:GetIFF() == BattleConfig.FOE_CODE then
		self._shockFX = self:AddFX("shock", true, true)
	else
		self:RemoveCacheFX("shock")
	end

	if self._unitData:GetIFF() == BattleConfig.FOE_CODE then
		self:UpdateCharacterDetected()
	end

	self:updateComponentVisible()
end

--- 更新角色被探测时的透明度渐变
--- - 友方或被探测到：渐显（fade in）
--- - 未被探测到的敌方：渐隐（fade out）
function BattleCharacter.UpdateCharacterDetected(self)
	if self._unitData:GetIFF() == BattleConfig.FRIENDLY_CODE or self._unitData:GetDiveDetected() then
		self:spineSemiTransparentFade(0, 0.7, BattleConfig.SUB_FADE_IN_DURATION)
	else
		self:spineSemiTransparentFade(0.7, 0, BattleConfig.SUB_FADE_OUT_DURATION)
	end
end

--- 强制暴露事件处理
function BattleCharacter.onForceDetected(self, event)
	self:UpdateCharacterForceDetected()
end

--- 敌人强制暴露时的视觉效果：直接渐显
function BattleCharacter.UpdateCharacterForceDetected(self)
	if self._unitData:GetIFF() == BattleConfig.FOE_CODE and self._unitData:GetForceExpose() then
		self:spineSemiTransparentFade(0, 0.7, BattleConfig.SUB_FADE_IN_DURATION)
		self:updateComponentVisible()
	end
end

--- 盲烟暴露事件处理
function BattleCharacter.onBlindExposed(self, event)
	local exposed = self._unitData:GetExposed()

	self:GetTf():GetComponent(typeof(Renderer)).enabled = exposed

	self:updateComponentVisible()
end

--- 更新所有UI组件的可见性
--- - 友方单位：检查是否不是隐身
--- - 敌方单位：检查暴露状态、下潜检测状态、强制暴露等
function BattleCharacter.updateComponentVisible(self)
	local isVisible

	if self._unitData:GetIFF() ~= BattleConfig.FOE_CODE then
		isVisible = self._unitData:GetAttrByName(ys.Battle.BattleBuffSetBattleUnitType.ATTR_KEY) > BattleConfig.FUSION_ELEMENT_UNIT_TYPE
	else
		local exposed = self._unitData:GetExposed()
		local diveDetected = self._unitData:GetDiveDetected()
		local diveInvisible = self._unitData:GetDiveInvisible()

		isVisible = self._unitData:GetForceExpose() or exposed and (not diveInvisible or not not diveDetected)
	end

	SetActive(self._arrowBarTf, isVisible)
	SetActive(self._HPBarTf, isVisible)
	SetActive(self._FXAttachPoint, isVisible)
	SetActive(self._hpPopContainerTF, isVisible)

	if self._hpCloakBar then
		self._hpCloakBar:SetActive(isVisible)
	end

	if self._cloakBar then
		self._cloakBar:SetActive(isVisible)
	end

	if self._aimBiarBar then
		self._aimBiarBar:SetActive(isVisible)
	end
end

--- 更新潜入隐身时的UI组件可见性（仅控制HP条和特效挂载点）
function BattleCharacter.updateComponentDiveInvisible(self)
	local isDetected = self._unitData:GetDiveDetected() and self._unitData:GetIFF() == BattleConfig.FOE_CODE
	local isDiveInvisible = self._unitData:GetDiveInvisible()
	local isVisible = (isDetected or not isDiveInvisible) and true or false

	SetActive(self._arrowBarTf, isVisible)
	SetActive(self._HPBarTf, isVisible)
	SetActive(self._FXAttachPoint, isVisible)
end

--- 更新盲烟隐身时组件可见性
function BattleCharacter.updateComponentBlindInvisible(self)
	local exposed = self._unitData:GetExposed()

	self:GetTf():GetComponent(typeof(Renderer)).enabled = exposed

	SetActive(self._arrowBarTf, exposed)
	SetActive(self._HPBarTf, exposed)
	SetActive(self._FXAttachPoint, exposed)
end

--- Spine角色半透明渐变
--- @param fromAlpha number 起始透明度
--- @param toAlpha number 目标透明度
--- @param duration number 渐变时间
function BattleCharacter.spineSemiTransparentFade(self, fromAlpha, toAlpha, duration)
	LeanTween.cancel(self._go)
	onDelayTick(function()
		if not self._go then
			return
		end

		duration = duration or 0

		SpineAnim.ShaderTransparentFade(self._go, toAlpha, fromAlpha, duration, "_Invisible")
	end, 0.06)
end

--- 初始化反潜警戒状态：创建警戒条和声纳范围特效
--- @param event table {Data = {sonarRange}}
function BattleCharacter.onInitVigilantState(self, event)
	self._factory:MakeVigilantBar(self)

	range = event.Data.sonarRange * 0.5

	local antiSubAreaFX = self:AddFX("AntiSubArea", true).transform

	antiSubAreaFX.localScale = Vector3(range, 0, range)

	-- 声纳检测动画回调
	local function playSonarAnim()
		local animator = antiSubAreaFX:Find("Quad"):GetComponent(typeof(Animator))

		animator.enabled = true

		animator:Play("antiSubZoom", -1, 0)
	end

	self._unitData:RegisterEventListener(self, BattleUnitEvent.CHANGE_ANTI_SUB_VIGILANCE, self.onVigilantStateChange)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.ANTI_SUB_VIGILANCE_SONAR_CHECK, playSonarAnim)
end

--- 反潜警戒状态变化
function BattleCharacter.onVigilantStateChange(self, event)
	self:updateVigilantMark()
end

--- 更新反潜警戒标记
function BattleCharacter.updateVigilantMark(self)
	if self._vigilantBar then
		self._vigilantBar:UpdateVigilantMark()
	end
end

--- 动作切换事件回调
--- @param event table {Data = {actionType}}
function BattleCharacter.OnActionChange(self, event)
	local actionType = event.Data.actionType

	self:PlayAction(actionType)
end

--- 播放角色动作动画
--- - 处理Spine动画左右翻转（根据模型Scale符号）
--- - 处理轨道(Orbit)附属品的动作切换条件
--- - 胜利动作时清除Effect组件的效果
--- @param actionType string 动作类型名
function BattleCharacter.PlayAction(self, actionType)
	local finalAction = actionType
	local needFlip = false

	-- 根据模型朝向决定是否需要翻转动画
	if self._skeleton then
		finalAction, needFlip = SpineAnimUtil.GetCharAnimDirect(self._skeleton, math.sign(self._modelScale.x), finalAction)
	end

	if needFlip then
		local flippedScale = Vector3(math.abs(self._modelScale.x), self._modelScale.y, self._modelScale.z)

		self:setLocalScale(flippedScale, true)
	end

	self._animator:SetAction(finalAction, 0, BattleConst.ActionLoop[actionType])

	self._actionIndex = actionType

	-- 胜利动作时清除所有buff特效
	if actionType == BattleConst.ActionName.VICTORY or actionType == BattleConst.ActionName.VICTORY_SWIM then
		self._effectOb:ClearEffect()
	end

	-- 检查轨道附属品的动作变化条件（condition.type == 2）
	if #self._orbitActionUpdateList > 0 then
		for _, orbitEntry in ipairs(self._orbitActionUpdateList) do
			local orbitObj = orbitEntry.orbit
			local changeConfig = orbitEntry.change
			local actionParams = changeConfig.condition.param
			local matched = false

			for _, actionPattern in ipairs(actionParams) do
				if string.find(actionType, actionPattern) then
					matched = true

					break
				end
			end

			if matched then
				self:changeOrbitAction(orbitObj, changeConfig)

				break
			end
		end
	end
end

--- 设置动画播放速度
--- @param timeScale number|nil 时间缩放，默认1
function BattleCharacter.SetAnimaSpeed(self, timeScale)
	self._skeleton = self._skeleton or self:GetTf():GetComponent("SkeletonAnimation")
	timeScale = timeScale or 1
	self._skeleton.timeScale = timeScale
end

--- 更新角色Transform位置到UnitData的坐标
function BattleCharacter.UpdatePosition(self)
	if not self._go then
		return
	end

	local unitPos = self._unitData:GetPosition()

	-- 位置没变则跳过
	if self._unitData:GetSpeed() == Vector3.zero and self._characterPos == unitPos then
		return
	end

	self._characterPos = unitPos
	self._tf.localPosition = self:getCharacterPos()
end

--- @return Vector3 角色当前位置
function BattleCharacter.getCharacterPos(self)
	return self._characterPos
end

--- 清理骨骼位置缓存矩阵（每帧重置）
function BattleCharacter.UpdateMatrix(self)
	self._bonePosTable = nil
	self._posMatrix = nil
end

--- 更新UI组件参考坐标：将世界坐标转换到UI相机空间
function BattleCharacter.UpdateUIComponentPosition(self)
	local unitPos = self._unitData:GetPosition()

	self._referenceVector:Set(unitPos.x, unitPos.y, unitPos.z)
	ys.Battle.BattleVariable.CameraPosToUICameraByRef(self._referenceVector)

	self._referenceVector.z = 10
	self._referenceUpdateFlag = not self._referenceVector:Equals(self._referenceVectorCache)

	if self._referenceUpdateFlag then
		self._referenceVectorCache:Copy(self._referenceVector)
	end
end

--- 更新HP弹出文字容器的位置
function BattleCharacter.UpdateHPPopContainerPosition(self)
	self._hpPopContainerTF.position = self._referenceVector
end

--- 更新HP条位置（基于参考坐标+偏移）
function BattleCharacter.UpdateHPBarPosition(self)
	if not self._hideHP then
		self._hpBarPos:Copy(self._referenceVector):Add(self._hpBarOffset)

		self._HPBarTf.position = self._hpBarPos
	end
end

--- 设置HP条和箭头的隐藏状态
--- @param hideArrow boolean 是否永久隐藏箭头
--- @param hideHP boolean 是否隐藏HP条
function BattleCharacter.SetBarHidden(self, hideArrow, hideHP)
	self._alwaysHideArrow = hideArrow
	self._hideHP = hideHP

	if self._arrowBar then
		if self._alwaysHideArrow then
			self._arrowBarTf.anchoredPosition = OFF_SCREEN_POS
		else
			self._arrowBarTf.position = self._arrowVector
		end
	end
end

--- 更新施法时钟位置
function BattleCharacter.UpdateCastClockPosition(self)
	self._castClock:UpdateCastClockPosition(self._referenceVector)
end

--- 更新屏障时钟位置
function BattleCharacter.UpdateBarrierClockPosition(self)
	self._barrierClock:UpdateBarrierClockPosition(self._referenceVector)
end

--- 初始化箭头指向系统的参考点
function BattleCharacter.SetArrowPoint(self)
	self._arrowVector:Set()

	self._cameraUtil = ys.Battle.BattleCameraUtil.GetInstance()
	self._arrowCenterPos = self._cameraUtil:GetArrowCenterPos()
end

--- 更新屏幕外指示箭头的位置和朝向
--- - 如果在视野内：箭头移出屏幕
--- - 如果离开出生点太远：使用出生点作为箭头参考
function BattleCharacter.UpdateArrowBarPosition(self)
	local arrowPos = self._cameraUtil:GetCharacterArrowBarPosition(self._referenceVector, self._arrowVector)

	if not arrowPos then
		if not self._inViewArea then
			self._inViewArea = true
			self._arrowBarTf.anchoredPosition = OFF_SCREEN_POS
		end
	else
		local bornPos = self._unitData:GetBornPosition()

		if bornPos and bornPos ~= self._unitData:GetPosition() then
			arrowPos = self._cameraUtil:GetCharacterArrowBarPosition(self._referenceVectorBorn, self._arrowVector)
		end

		self._arrowVector = arrowPos
		self._inViewArea = false

		if not self._alwaysHideArrow then
			self._arrowBarTf.position = self._arrowVector

			-- 根据箭头在屏幕左右的朝向翻转
			if self._arrowVector.x > 0 then
				self._arrowBarTf.localScale = ARROW_SCALE_LEFT
			else
				self._arrowBarTf.localScale = ARROW_SCALE_RIGHT
			end
		end
	end
end

--- 更新屏幕外箭头的旋转角度（指向目标方向）
function BattleCharacter.UpdateArrowBarRotation(self)
	if self._inViewArea then
		return
	end

	local arrowX = self._arrowVector.x
	local arrowY = self._arrowVector.y
	local angle = math.rad2Deg * math.atan2(arrowY - self._arrowCenterPos.y, arrowX - self._arrowCenterPos.x)

	self._arrowAngleVector.z = angle
	self._arrowBarTf.eulerAngles = self._arrowAngleVector
end

--- 更新聊天气泡位置：视野内跟随角色，视野外跟随箭头
function BattleCharacter.UpdateChatPosition(self)
	if not self._popGO then
		return
	end

	if self._inViewArea then
		self._popTF.position = self:GetReferenceVector()
	else
		self._popTF.position = self._arrowVector + CHAT_OFFSCREEN_OFFSET
	end
end

--- 销毁角色：清理特效、轨道、HP条、箭头、动画等所有资源
function BattleCharacter.Dispose(self)
	if self._popGO then
		LeanTween.cancel(self._popGO)
	end

	if self._popNumBundle then
		self._hpPopContainerTF = nil

		self._popNumBundle:Clear()

		self._popNumBundle = nil
	end

	self._popNumPool = nil

	Object.Destroy(self._popGO)

	if self._voicePlaybackInfo then
		self._voicePlaybackInfo:PlaybackStop()
	end

	if self._cloakBar then
		self._cloakBar:Dispose()

		self._cloakBar = nil
		self._cloakBarTf = nil
	end

	if self._aimBiarBar then
		self._aimBiarBar:Dispose()

		self._aimBiarBar = nil
	end

	if self._buffClock then
		self._buffClock:Dispose()

		self._buffClock = nil
	end

	self._voicePlaybackInfo = nil
	self._popGO = nil
	self._popTF = nil
	self._cacheWeapon = nil

	for fxObj, _ in pairs(self._allFX) do
		BattleResourceManager.GetInstance():DestroyOb(fxObj)
	end

	for orbitObj, _ in pairs(self._orbitList) do
		BattleResourceManager.GetInstance():DestroyOb(orbitObj)
	end

	self._orbitList = nil
	self._orbitActionCacheList = nil
	self._orbitSpeedUpdateList = nil
	self._orbitActionUpdateList = nil

	pg.TimeMgr.GetInstance():RemoveBattleTimer(self._voiceTimer)

	self._voiceTimer = nil

	self._effectOb:RemoveUnitEvent(self._unitData)
	self._effectOb:Dispose()

	self._HPProgressBar = nil
	self._HPProgress = nil

	self._factory:GetHPBarPool():DestroyObj(self._HPBar)

	self._HPBar = nil
	self._HPBarTf = nil
	self._arrowBar = nil
	self._arrowBarTf = nil

	if self._animator then
		self._animator:ClearOverrideMaterial()

		self._animator = nil
	end

	self._skeleton = nil
	self._posMatrix = nil
	self._shockFX = nil
	self._waveFX = nil

	self:RemoveUnitEvent()
	ys.EventListener.DetachEventListener(self)

	self._bulletFactoryList = nil

	for _, tagFX in pairs(self._tagFXList) do
		tagFX:Dispose()
	end

	self._tagFXList = nil
	self._weaponRegisterList = nil

	BattleCharacter.super.Dispose(self)
end

--- 将模型GameObject绑定到角色：设置Spine动画、骨骼、初始动作
--- @param modelGO GameObject 角色模型GameObject
function BattleCharacter.AddModel(self, modelGO)
	self:SetGO(modelGO)

	self._hpBarOffset = Vector3(0, self._unitData:GetBoxSize().y, 0)
	self._animator = self:GetTf():GetComponent(typeof(SpineAnim))
	self._skeleton = self:GetTf():GetComponent("SkeletonAnimation")

	if self._animator then
		self._animator:Start()
	end

	self:SetBoneList()
	self:UpdateMatrix()
	self._unitData:ActiveCldBox()

	local initScale = self:GetInitScale()

	self:setLocalScale(Vector3(initScale * self._unitData:GetDirection(), initScale, initScale))

	-- 根据氧气状态播放对应初始动作（下潜/正常移动）
	local oxyState = self._unitData:GetOxyState()

	if oxyState and oxyState:GetCurrentDiveState() == ys.Battle.BattleConst.OXY_STATE.DIVE then
		self:PlayAction(ys.Battle.BattleConst.ActionName.DIVE)
	else
		self:PlayAction(ys.Battle.BattleConst.ActionName.MOVE)
	end

	-- 设置动画回调：finish/action/skin_on/skin_off 四种事件
	self._animator:SetActionCallBack(function(eventType)
		if eventType == "finish" then
			self:OnAnimatorEnd()
		elseif eventType == "action" then
			self:OnAnimatorTrigger()
		else
			self:changeOrbitListVisible(eventType)
		end
	end)
	self._unitData:RegisterEventListener(self, BattleUnitEvent.CHANGE_ACTION, self.OnActionChange)
end

--- 根据skin_on/skin_off事件控制轨道附属品的显隐
--- @param visibilityEvent string "skin_on" 或 "skin_off"
function BattleCharacter.changeOrbitListVisible(self, visibilityEvent)
	local isVisible

	if visibilityEvent == "skin_on" then
		isVisible = true
	elseif visibilityEvent == "skin_off" then
		isVisible = false
	else
		return
	end

	if self._orbitList then
		for orbitObj, _ in pairs(self._orbitList) do
			SetActive(orbitObj, isVisible)
		end
	end
end

--- 切换角色模型（换装/皮肤切换时调用）
--- - 保留现有的Blink字典
--- - 重新绑定轨道附属品
--- - 重新挂载特效挂载点
--- @param newModelGO GameObject 新模型
--- @param skinID number|nil 皮肤ID
function BattleCharacter.SwitchModel(self, newModelGO, skinID)
	local oldGO = self._go

	self:SetGO(newModelGO)

	self._animator = self:GetTf():GetComponent(typeof(SpineAnim))
	self._skeleton = self:GetTf():GetComponent("SkeletonAnimation")

	if self._animator then
		self._animator:Start()
	end

	self:SetBoneList()

	self._tf.position = self._unitData:GetPosition()

	self:UpdateMatrix()

	self._hpBarOffset.y = self._hpBarOffset.y + self._coverSpineHPBarOffset

	self:UpdateHPBarPosition()

	local initScale = self:GetInitScale()

	self:setLocalScale(Vector3(initScale * self._unitData:GetDirection(), initScale, initScale))
	self._animator:SetActionCallBack(function(eventType)
		if eventType == "finish" then
			self:OnAnimatorEnd()
		elseif eventType == "action" then
			self:OnAnimatorTrigger()
		else
			self:changeOrbitListVisible(eventType)
		end
	end)
	self:SwitchShader(self._shaderType, self._color)

	-- 重新创建所有闪烁效果
	local newBlinkDict = {}
	local blinkIdMapping = {}

	for oldBlinkId, blinkData in pairs(self._blinkDict) do
		local newBlinkId = SpineAnim.CharBlink(self._go, blinkData.r, blinkData.g, blinkData.b, blinkData.a, blinkData.peroid, blinkData.duration, false)

		newBlinkDict[newBlinkId] = blinkData
		blinkIdMapping[oldBlinkId] = newBlinkId
	end

	self._blinkDict = newBlinkDict

	self:PlayAction(self._actionIndex)

	-- 如果不是换肤（无skinID），需要重新绑定轨道BoneFollower
	if not skinID then
		for orbitObj, orbitData in pairs(self._orbitList) do
			SpineAnim.AddFollower(orbitData.boundBone, self._tf, orbitObj.transform):GetComponent("Spine.Unity.BoneFollower").followBoneRotation = false
		end
	end

	self._effectOb:SwitchOwner(self, blinkIdMapping)
	self._FXAttachPoint.transform:SetParent(self:GetTf(), false)
	BattleResourceManager.GetInstance():DestroyOb(oldGO)
end

--- 添加轨道附属品（皮肤装饰物，如光环、浮游炮等）
--- @param orbitGO GameObject 轨道对象
--- @param equipSkinData table 装备皮肤数据
--- @param charBonePrefix string|nil 双角色时的骨骼前缀（如"char1"/"char2"）
function BattleCharacter.AddOrbit(self, orbitGO, equipSkinData, charBonePrefix)
	local boundBoneName = equipSkinData.orbit_combat_bound[1]

	if charBonePrefix then
		boundBoneName = charBonePrefix .. "_" .. boundBoneName
	end

	local boundOffset = equipSkinData.orbit_combat_bound[2]
	local hiddenAction = equipSkinData.orbit_hidden_action

	orbitGO.transform.localPosition = Vector3(boundOffset[1], boundOffset[2], boundOffset[3])

	local boneFollower = SpineAnim.AddFollower(boundBoneName, self._tf, orbitGO.transform):GetComponent("Spine.Unity.BoneFollower")

	if equipSkinData.orbit_rotate then
		boneFollower.followBoneRotation = true

		local euler = orbitGO.transform.localEulerAngles

		orbitGO.transform.localEulerAngles = Vector3(euler.x, euler.y, euler.z - 90)
	else
		boneFollower.followBoneRotation = false
	end

	self._orbitList[orbitGO] = {
		hiddenAction = hiddenAction,
		boundBone = boundBoneName,
		offset = self._orbitSpineOrderOffset
	}

	-- 处理轨道的动画切换条件
	local defaultChange = equipSkinData.orbit_combat_anima_change.default

	if defaultChange then
		self:changeOrbitAction(orbitGO, defaultChange)

		for _, changeConfig in ipairs(equipSkinData.orbit_combat_anima_change.change) do
			if changeConfig.condition.type == 1 then
				-- 速度条件：添加到速度更新列表
				table.insert(self._orbitSpeedUpdateList, {
					orbit = orbitGO,
					change = Clone(changeConfig)
				})
			elseif changeConfig.condition.type == 2 then
				-- 动作条件：添加到动作更新列表
				table.insert(self._orbitActionUpdateList, {
					orbit = orbitGO,
					change = Clone(changeConfig)
				})
			end
		end
	end

	self._orbitSpineOrderOffset = self._orbitSpineOrderOffset + BattleCharacter.getMaxZSort(orbitGO)

	self:sortOrbitZOrder()
end

--- 对所有轨道附属品的MeshRenderer排序层级进行重新排序
function BattleCharacter.sortOrbitZOrder(self)
	for orbitObj, orbitData in pairs(self._orbitList) do
		local maxZ = BattleCharacter.getMaxZSort(orbitObj)

		eachChild(orbitObj, function(child)
			if child and child:GetComponent("MeshRenderer") then
				local childOrder = child:GetComponent("MeshRenderer").sortingOrder

				if childOrder > 0 then
					child:GetComponent("MeshRenderer").sortingOrder = self._orbitSpineOrderOffset - orbitData.offset - maxZ + childOrder
				end
			end
		end)
	end
end

--- 获取GameObject及其子对象的最大sortingOrder（用于Z轴排序）
--- @param go GameObject 目标对象
--- @return number 最大sortingOrder
function BattleCharacter.getMaxZSort(go)
	local maxOrder = 0

	eachChild(go, function(child)
		if child and child:GetComponent("MeshRenderer") then
			local order = child:GetComponent("MeshRenderer").sortingOrder

			maxOrder = math.max(maxOrder, order)
		end
	end)

	return maxOrder
end

--- 切换轨道附属品的动画状态（激活/停用节点）
--- @param orbitGO GameObject 轨道对象
--- @param changeConfigs table 变化配置列表 [{node, active, activate}]
function BattleCharacter.changeOrbitAction(self, orbitGO, changeConfigs)
	for _, config in ipairs(changeConfigs) do
		local node = orbitGO.transform:Find(config.node)

		if node then
			SetActive(node, config.active)

			if config.active and self._orbitActionCacheList[node] ~= config.activate then
				local activateValue = config.activate

				node:GetComponent(typeof(Animator)):SetBool("activate", activateValue)

				self._orbitActionCacheList[node] = config.activate
			end
		end
	end
end

--- 每帧更新轨道附属品（基于速度条件的动画切换）
function BattleCharacter.UpdateOrbit(self)
	if #self._orbitSpeedUpdateList <= 0 then
		return
	end

	local currentSpeed = self._unitData:GetSpeed():Magnitude()

	for _, orbitEntry in pairs(self._orbitSpeedUpdateList) do
		local orbitObj = orbitEntry.orbit
		local changeConfig = orbitEntry.change
		local speedConditions = changeConfig.condition.param
		local allConditionsMet = true

		for _, condition in ipairs(speedConditions) do
			allConditionsMet = BattleFormulas.simpleCompare(condition, currentSpeed) and allConditionsMet
		end

		if allConditionsMet then
			self:changeOrbitAction(orbitObj, changeConfig)
		end
	end
end

--- 添加烟雾特效配置表
--- @param smokeConfigs table 烟雾配置 [{rate, smokes}]
function BattleCharacter.AddSmokeFXs(self, smokeConfigs)
	self._smokeList = smokeConfigs

	self:updateSomkeFX()
end

--- 添加阴影引用
--- @param shadowObj GameObject 阴影对象
function BattleCharacter.AddShadow(self, shadowObj)
	self._shadow = shadowObj
end

--- 添加HP条并注册HP更新事件
--- @param hpBarObj GameObject HP条对象
function BattleCharacter.AddHPBar(self, hpBarObj)
	self._HPBar = hpBarObj
	self._HPBarTf = hpBarObj.transform
	self._HPProgressBar = self._HPBarTf:Find("blood")
	self._HPProgress = self._HPProgressBar:GetComponent(typeof(Image))

	self._unitData:RegisterEventListener(self, BattleUnitEvent.UPDATE_HP, self.OnUpdateHP)

	self._HPBarTf.position = self._referenceVector + self._hpBarOffset
end

--- UI组件容器的占位方法（子类重写）
--- @param container Transform
function BattleCharacter.AddUIComponentContainer(self, container)
	self:UpdateUIComponentPosition()
end

--- 添加弹出数字池（伤害/治疗数字）
--- @param popNumPool BattlePopNumPool 弹出数字池
function BattleCharacter.AddPopNumPool(self, popNumPool)
	self._popNumPool = popNumPool
	self._hpPopIndex_put = 1
	self._hpPopIndex_get = 1
	self._hpPopCount = 0
	self._hpPopCatch = {}
	self._popNumBundle = self._popNumPool:GetBundle(self._unitData:GetUnitType())
	self._hpPopContainerTF = self._popNumBundle:GetContainer().transform
end

--- 添加屏幕外指示箭头
--- @param arrowBarObj GameObject 箭头对象
function BattleCharacter.AddArrowBar(self, arrowBarObj)
	self._arrowBar = arrowBarObj
	self._arrowBarTf = arrowBarObj.transform

	self:SetArrowPoint()
end

--- 添加施法时钟（Boss蓄力倒计时）
--- @param castClockObj GameObject 施法时钟GameObject
function BattleCharacter.AddCastClock(self, castClockObj)
	local clockTf = castClockObj.transform

	SetActive(clockTf, false)

	self._castClock = ys.Battle.BattleCastBar.New(clockTf)

	self:UpdateCastClockPosition()
end

--- 添加Buff时钟
--- @param buffClockObj GameObject Buff时钟GameObject
function BattleCharacter.AddBuffClock(self, buffClockObj)
	local buffClockTf = buffClockObj.transform

	SetActive(buffClockTf, false)

	self._buffClock = ys.Battle.BattleBuffClock.New(buffClockTf)
end

--- 添加屏障时钟
--- @param barrierClockObj GameObject 屏障时钟GameObject
function BattleCharacter.AddBarrierClock(self, barrierClockObj)
	local barrierTf = barrierClockObj.transform

	SetActive(barrierTf, false)

	self._barrierClock = ys.Battle.BattleBarrierBar.New(barrierTf)

	self:UpdateBarrierClockPosition()
end

--- 添加反潜警戒条
--- @param vigilantBarObj GameObject 警戒条GameObject
function BattleCharacter.AddVigilantBar(self, vigilantBarObj)
	self._vigilantBar = ys.Battle.BattleVigilantBar.New(vigilantBarObj.transform)

	self._vigilantBar:ConfigVigilant(self._unitData:GetAntiSubState())
	self._vigilantBar:UpdateVigilantProgress()
	self:updateVigilantMark()
end

--- 更新反潜警戒条位置
function BattleCharacter.UpdateVigilantBarPosition(self)
	self._vigilantBar:UpdateVigilantBarPosition(self._hpBarPos)
end

--- 添加隐藏槽（cloak bar）
--- @param cloakBarObj GameObject 隐藏槽GameObject
function BattleCharacter.AddCloakBar(self, cloakBarObj)
	self._cloakBarTf = cloakBarObj.transform
	self._cloakBar = ys.Battle.BattleCloakBar.New(self._cloakBarTf)

	self._cloakBar:ConfigCloak(self._unitData:GetCloak())
	self._cloakBar:UpdateCloakProgress()
end

--- 更新隐藏槽位置：视野外跟随箭头，视野内隐藏
function BattleCharacter.UpdateCloakBarPosition(self)
	if self._inViewArea then
		self._cloakBarTf.anchoredPosition = OFF_SCREEN_POS
	else
		self._cloakBar:UpdateCloarBarPosition(self._arrowVector)
	end
end

--- 初始化隐藏状态
function BattleCharacter.onInitCloak(self, event)
	self._factory:MakeCloakBar(self)
end

--- 隐藏配置更新
function BattleCharacter.onUpdateCloakConfig(self, event)
	self._cloakBar:UpdateCloakConfig()
end

--- 隐藏锁定状态更新
function BattleCharacter.onUpdateCloakLock(self, event)
	self._cloakBar:UpdateCloakLock()
end

--- 添加瞄准偏斜条（Aim Bias Bar）
--- @param aimBiasBarObj Transform 瞄准偏斜条Transform
function BattleCharacter.AddAimBiasBar(self, aimBiasBarObj)
	self._aimBiarBarTF = aimBiasBarObj
	self._aimBiarBar = ys.Battle.BattleAimbiasBar.New(aimBiasBarObj)

	self._aimBiarBar:ConfigAimBias(self._unitData:GetAimBias())
	self._aimBiarBar:UpdateAimBiasProgress()
end

--- 检测是否为双角色Spine（通过骨骼名称判断）
--- @return boolean 是否为双角色
function BattleCharacter.IsDoubleChar(self)
	if self._skeleton then
		local char1FaceIdx = self._skeleton.skeleton:FindBoneIndex("char1_face")
		local char2FaceIdx = self._skeleton.skeleton:FindBoneIndex("char2_face")

		if char1FaceIdx >= 0 and char2FaceIdx >= 0 then
			return true
		end
	end

	return false
end

--- 更新瞄准偏斜条进度
function BattleCharacter.UpdateAimBiasBar(self)
	if self._aimBiarBar then
		self._aimBiarBar:UpdateAimBiasProgress()
	end
end

--- 更新Buff时钟
function BattleCharacter.UpdateBuffClock(self)
	if self._buffClock and self._buffClock:IsActive() then
		self._buffClock:UpdateCastClockPosition(self._referenceVector)
		self._buffClock:UpdateCastClock()
	end
end

--- 瞄准偏斜锁定状态更新
function BattleCharacter.onUpdateAimBiasLock(self, event)
	self._aimBiarBar:UpdateLockStateView()
end

--- 初始化瞄准偏斜：如果是宿主则创建条
function BattleCharacter.onInitAimBias(self, event)
	if self._unitData:GetAimBias():GetHost() == self._unitData then
		self._factory:MakeAimBiasBar(self)
	end
end

--- 成为瞄准偏斜宿主
function BattleCharacter.onHostAimBias(self, event)
	self._factory:MakeAimBiasBar(self)
end

--- 移除瞄准偏斜条
function BattleCharacter.onRemoveAimBias(self, event)
	self._aimBiarBar:SetActive(false)
	self._aimBiarBar:Dispose()

	self._aimBiarBar = nil
	self._aimBiarBarTF = nil
end

--- 添加瞄准偏斜迷雾特效（fog effect on aim bias）
function BattleCharacter.AddAimBiasFogFX(self)
	local fogFxID = self._unitData:GetTemplate().fog_fx

	if fogFxID and fogFxID ~= "" then
		self._fogFx = self:AddFX(fogFxID)
	end
end

--- HP更新事件入口
--- @param event table {Data = {dHP, isCri, isMiss, isHeal, posOffset, font}}
function BattleCharacter.OnUpdateHP(self, event)
	self:_DealHPPop(event.Data)
end

--- 处理HP弹出数字的队列管理
--- - 如果队列为空则立即播放
--- - 如果单位存活则加入队列
--- - 如果单位已死亡则立即播放
function BattleCharacter._DealHPPop(self, hpPopData)
	if self._hpPopIndex_put == self._hpPopIndex_get and self._hpPopCount == 0 then
		self:_PlayHPPop(hpPopData)

		self._hpPopCount = 1
	elseif self._unitData:IsAlive() then
		self._hpPopCatch[self._hpPopIndex_put] = hpPopData
		self._hpPopIndex_put = self._hpPopIndex_put + 1
	else
		self:_PlayHPPop(hpPopData)
	end
end

--- 每帧更新HP弹出队列：按计数器节流弹出
function BattleCharacter.UpdateHPPop(self)
	if self._hpPopIndex_put == self._hpPopIndex_get then
		return
	else
		self._hpPopCount = self._hpPopCount + 1

		if self:_CalcHPPopCount() <= self._hpPopCount then
			self:_PlayHPPop(self._hpPopCatch[self._hpPopIndex_get])

			self._hpPopCatch[self._hpPopIndex_get] = nil
			self._hpPopIndex_get = self._hpPopIndex_get + 1
			self._hpPopCount = 0
		end
	end
end

--- 播放HP弹出数字
--- @param hpPopData table {dHP, isCri, isMiss, isHeal, posOffset, font}
function BattleCharacter._PlayHPPop(self, hpPopData)
	if self._popNumBundle:IsScorePop() then
		return
	end

	local dHP = hpPopData.dHP
	local isCrit = hpPopData.isCri
	local isMiss = hpPopData.isMiss
	local isHeal = hpPopData.isHeal
	local posOffset = hpPopData.posOffset or Vector3.zero
	local font = hpPopData.font
	local pop = self._popNumBundle:GetPop(isHeal, isCrit, isMiss, dHP, font)

	pop:SetReferenceCharacter(self, posOffset)
	pop:Play()
end

--- 计算HP弹出节流计数器（积压太多时加速弹出）
--- @return number 弹出节流值
function BattleCharacter._CalcHPPopCount(self)
	if self._hpPopIndex_put - self._hpPopIndex_get > 5 then
		return 1
	else
		return 5
	end
end

--- 分数更新事件：弹出分数数字
function BattleCharacter.onUpdateScore(self, event)
	local score = event.Data.score
	local scorePop = self._popNumBundle:GetScorePop(score)

	scorePop:SetReferenceCharacter(self, Vector3.zero)
	scorePop:Play()
end

--- 更新HP条的填充量显示
function BattleCharacter.UpdateHpBar(self)
	local currentHP = self._unitData:GetCurrentHP()

	if self._HPProgress and self._cacheHP ~= currentHP then
		local hpRate = self._unitData:GetHPRate()

		self._HPProgress.fillAmount = hpRate
		self._cacheHP = currentHP
	end
end

--- Buff尺寸变化事件处理
function BattleCharacter.onChangeSize(self, event)
	self:doChangeSize(event)
end

--- 根据HP比例更新烟雾特效的激活/停用
--- smokeConfig: {rate = HP阈值, active = 是否激活, smokes = {[fxData] = fxObj}}
function BattleCharacter.updateSomkeFX(self)
	local hpRate = self._unitData:GetHPRate()

	for _, smokeConfig in ipairs(self._smokeList) do
		if hpRate < smokeConfig.rate then
			if smokeConfig.active == false then
				smokeConfig.active = true

				local smokes = smokeConfig.smokes

				for fxData, fxObj in pairs(smokes) do
					if fxData.unInitialize then
						local newFx = self:AddFX(fxData.resID)

						newFx.transform.localPosition = fxData.pos
						smokes[fxData] = newFx

						SetActive(newFx, true)

						fxData.unInitialize = false
					else
						SetActive(fxObj, true)
					end
				end
			end
		elseif smokeConfig.active == true then
			smokeConfig.active = false

			local smokes = smokeConfig.smokes

			for fxData, fxObj in pairs(smokes) do
				if fxData.unInitialize then
					-- 尚未初始化的跳过
				else
					SetActive(fxObj, false)
				end
			end
		end
	end
end

--- 根据modelScale属性改变角色尺寸
function BattleCharacter.doChangeSize(self, event)
	local modelScale = self._unitData:GetAttrByName("modelScale")

	self:setLocalScale(Vector3(modelScale * self._unitData:GetDirection(), modelScale, modelScale))
end

--- 初始化特效视图组件
function BattleCharacter.InitEffectView(self)
	self._effectOb = ys.Battle.BattleEffectComponent.New(self)
end

--- 更新动画特效
--- @param combatTime number 战斗时间戳
function BattleCharacter.UpdateAniEffect(self, combatTime)
	self._effectOb:Update(combatTime)
end

--- 更新标签特效位置（锁定标记等）
--- @param combatTime number 战斗时间戳
function BattleCharacter.UpdateTagEffect(self, combatTime)
	local halfBoxY = self._unitData:GetBoxSize().y * 0.5

	for _, tagFX in pairs(self._tagFXList) do
		tagFX:Update(combatTime)
		tagFX:SetPosition(self._referenceVector + Vector3(0, halfBoxY, 0))
	end
end

--- 设置聊天气泡弹窗
--- @param content string 气泡文字内容
--- @param duration number 持续时间
--- @param key string 气泡key（用于去重）
function BattleCharacter.SetPopup(self, content, duration, key)
	if self._voiceTimer then
		if self._voiceKey == key then
			self._voiceKey = nil
		else
			return
		end
	end

	if self._popGO then
		LeanTween.cancel(self._popGO)

		local anim = self._popGO.transform:GetComponent(typeof(Animation))

		if anim then
			anim:Play("popup_out")
			self._popGO:GetComponent("DftAniEvent"):SetEndEvent(function()
				self.ChatPopAnimation(self._popGO, duration)
			end)
		else
			LeanTween.cancel(self._popGO)
			LeanTween.scale(rtf(self._popGO.gameObject), Vector3.New(0, 0, 1), 0.1):setEase(LeanTweenType.easeInBack):setOnComplete(System.Action(function()
				self.ChatPop(self._popGO, duration)
			end))
		end
	else
		self._popGO = self._factory:MakePopup()
		self._popTF = self._popGO.transform

		if self._popGO.transform:GetComponent(typeof(Animation)) then
			self.ChatPopAnimation(self._popGO, duration)
		else
			self._popTF.localScale = Vector3(0, 0, 0)

			self.ChatPop(self._popGO, duration)
		end
	end

	BattleCharacter.setChatText(self._popGO, content)
	SetActive(self._popGO, true)
end

--- 通过Animation组件播放聊天气泡动画
--- @param popGO GameObject 气泡GameObject
--- @param duration number 持续时间
function BattleCharacter.ChatPopAnimation(self, popGO, duration)
	local anim = popGO.transform:GetComponent(typeof(Animation))

	anim:Play("popup_in")
	LeanTween.delayedCall(popGO.gameObject, duration, System.Action(function()
		anim:Play("popup_out")
		popGO:GetComponent("DftAniEvent"):SetEndEvent(function()
			SetActive(popGO, false)
		end)
	end))
end

--- 通过LeanTween播放聊天气泡弹出/缩回动画
--- @param popGO GameObject 气泡GameObject
--- @param duration number|nil 显示持续时间，默认2.5秒
function BattleCharacter.ChatPop(self, popGO, duration)
	duration = duration or 2.5

	LeanTween.scale(rtf(popGO.gameObject), Vector3.New(1, 1, 1), 0.3):setEase(LeanTweenType.easeOutBack):setOnComplete(System.Action(function()
		LeanTween.scale(rtf(popGO.gameObject), Vector3.New(0, 0, 1), 0.3):setEase(LeanTweenType.easeInBack):setDelay(duration):setOnComplete(System.Action(function()
			SetActive(popGO, false)
		end))
	end))
end

--- 设置聊天气泡文字内容和对齐方式
--- @param popGO GameObject 气泡GameObject
--- @param text string 文字内容
function BattleCharacter.setChatText(self, popGO, text)
	local textComp = findTF(popGO, "Text"):GetComponent(typeof(Text))

	textComp.text = text

	if #textComp.text > CHAT_POP_STR_LEN then
		textComp.alignment = TextAnchor.MiddleLeft
	else
		textComp.alignment = TextAnchor.MiddleCenter
	end
end

--- 播放角色语音
--- @param voiceCue string CRI音频cue名
--- @param voiceKey string 语音去重key
function BattleCharacter.Voice(self, voiceCue, voiceKey)
	if self._voiceTimer then
		return
	end

	pg.CriMgr.GetInstance():PlayMultipleSound_V3(voiceCue, function(playbackInfo)
		if playbackInfo then
			self._voiceKey = voiceKey
			self._voicePlaybackInfo = playbackInfo
			self._voiceTimer = pg.TimeMgr.GetInstance():AddBattleTimer("", 0, self._voicePlaybackInfo:GetLength() * 0.001, function()
				pg.TimeMgr.GetInstance():RemoveBattleTimer(self._voiceTimer)

				self._voiceTimer = nil
				self._voiceKey = nil
				self._voicePlaybackInfo = nil
			end)
		end
	end)
end

--- 设置本地缩放（保留原始modelScale用于后续计算）
--- @param scale Vector3 缩放值
--- @param isTemp boolean|nil 是否是临时翻转（不更新_modelScale）
function BattleCharacter.setLocalScale(self, scale, isTemp)
	self._tf.localScale = scale

	if not isTemp then
		self._modelScale = scale
	end
end

--- 声纳激活（子类重写）
function BattleCharacter.SonarAcitve(self, isActive)
	return
end

--- 切换角色Shader
--- @param shaderType string|nil Shader类型名
--- @param color Color|nil 着色颜色
--- @param shaderArgs table|nil Shader额外参数 {invisible}
function BattleCharacter.SwitchShader(self, shaderType, color, shaderArgs)
	LeanTween.cancel(self._go)

	color = color or Color.New(0, 0, 0, 0)

	if shaderType then
		local shader = BattleResourceManager.GetInstance():GetShader(shaderType)

		self._animator:ShiftShader(shader, color)

		if shaderArgs then
			self:spineSemiTransparentFade(0, shaderArgs.invisible, 0)
		end
	end

	self._shaderType = shaderType
	self._color = color
end

--- 暂停/恢复动作动画
--- @param pause boolean true暂停, false恢复
function BattleCharacter.PauseActionAnimation(self, pause)
	local timeScale = pause and 0 or 1

	self._animator:GetAnimationState().TimeScale = timeScale
end

--- @return BattleCharacterFactory 关联的工厂
function BattleCharacter.GetFactory(self)
	return self._factory
end

--- 设置关联的工厂
--- @param factory BattleCharacterFactory 工厂实例
function BattleCharacter.SetFactory(self, factory)
	self._factory = factory
end

--- 切换Spine事件处理（换装）
--- @param event table {Data = {skin, HPBarOffset}}
function BattleCharacter.onSwitchSpine(self, event)
	local switchData = event.Data
	local skinID = switchData.skin

	self._coverSpineHPBarOffset = switchData.HPBarOffset or 0

	self:SwitchSpine(skinID)
end

--- 切换Spine模型：清除旧闪烁效果然后委托工厂创建新模型
--- @param skinID number 皮肤ID
function BattleCharacter.SwitchSpine(self, skinID)
	for blinkId, _ in pairs(self._blinkDict) do
		SpineAnim.RemoveBlink(self._go, blinkId)
	end

	self._factory:SwitchCharacterSpine(self, skinID)
end

--- Shader切换事件处理
--- @param event table {Data = {shader, color, args}}
function BattleCharacter.onSwitchShader(self, event)
	local data = event.Data
	local shaderType = data.shader
	local color = data.color
	local shaderArgs = data.args

	self:SwitchShader(shaderType, color, shaderArgs)
end
