ys = ys or {}

local ys = ys
local BattleBuffEvent = ys.Battle.BattleBuffEvent
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleResourceManager = ys.Battle.BattleResourceManager
local BattleDataFunction = ys.Battle.BattleDataFunction

ys.Battle.BattleEffectComponent = class("BattleEffectComponent")

local BattleEffectComponent = ys.Battle.BattleEffectComponent

BattleEffectComponent.__name = "BattleEffectComponent"

--- 构造函数：初始化效果组件
--- - _owner: 所属的 BattleCharacter 实例
--- - _blinkIDList: buff_id -> blinkID 映射
--- - _buffLastEffects: buff_id -> {effectObj, ...} 最后持续特效列表
--- - _effectList: index -> {effect_go, posFun, rotationFun, fillFunc, ...} 动态特效列表
--- @param owner BattleCharacter 所属角色
function BattleEffectComponent.Ctor(self, owner)
	ys.EventListener.AttachEventListener(self)

	self._owner = owner
	self._blinkIDList = {}
	self._buffLastEffects = {}
	self._currentLastFXID = nil
	self._effectIndex = 0
	self._effectList = {}
end

--- 切换所有者（换肤时使用）：重新映射blinkID
--- @param newOwner BattleCharacter 新的所有者
--- @param blinkIdMapping table 旧blinkID -> 新blinkID的映射
function BattleEffectComponent.SwitchOwner(self, newOwner, blinkIdMapping)
	self._owner = newOwner

	for oldBlinkId, newBlinkId in pairs(self._blinkIDList) do
		if blinkIdMapping[newBlinkId] then
			self._blinkIDList[oldBlinkId] = blinkIdMapping[newBlinkId]
		end
	end
end

--- 清除所有buff效果（胜利时调用）
function BattleEffectComponent.ClearEffect(self)
	for _, blinkId in pairs(self._blinkIDList) do
		self._owner:RemoveBlink(blinkId)
	end

	self._blinkIDList = {}
end

--- 销毁：移除所有闪烁和特效
function BattleEffectComponent.Dispose(self)
	for _, blinkId in pairs(self._blinkIDList) do
		self._owner:RemoveBlink(blinkId)
	end

	self._effectList = nil
	self._buffLastEffects = nil

	ys.EventListener.DetachEventListener(self)
end

--- @return BattleFXPool FX池实例
function BattleEffectComponent.GetFXPool(self)
	return ys.Battle.BattleFXPool.GetInstance()
end

--- 注册UnitData的Buff和Effect事件监听
--- @param unitData BattleUnitData 单位数据
function BattleEffectComponent.SetUnitDataEvent(self, unitData)
	unitData:RegisterEventListener(self, BattleBuffEvent.BUFF_CAST, self.onBuffCast)
	unitData:RegisterEventListener(self, BattleBuffEvent.BUFF_ATTACH, self.onBuffAdd)
	unitData:RegisterEventListener(self, BattleBuffEvent.BUFF_STACK, self.onBuffStack)
	unitData:RegisterEventListener(self, BattleBuffEvent.BUFF_REMOVE, self.onBuffRemove)
	unitData:RegisterEventListener(self, BattleUnitEvent.ADD_EFFECT, self.onAddEffect)
	unitData:RegisterEventListener(self, BattleUnitEvent.CANCEL_EFFECT, self.onCancelEffect)
	unitData:RegisterEventListener(self, BattleUnitEvent.DEACTIVE_EFFECT, self.onDeactiveEffect)
end

--- 移除所有事件监听
--- @param unitData BattleUnitData
function BattleEffectComponent.RemoveUnitEvent(self, unitData)
	unitData:UnregisterEventListener(self, BattleBuffEvent.BUFF_ATTACH)
	unitData:UnregisterEventListener(self, BattleBuffEvent.BUFF_CAST)
	unitData:UnregisterEventListener(self, BattleBuffEvent.BUFF_STACK)
	unitData:UnregisterEventListener(self, BattleBuffEvent.BUFF_REMOVE)
	unitData:UnregisterEventListener(self, BattleUnitEvent.ADD_EFFECT)
	unitData:UnregisterEventListener(self, BattleUnitEvent.CANCEL_EFFECT)
	unitData:UnregisterEventListener(self, BattleUnitEvent.DEACTIVE_EFFECT)
end

--- 每帧Update：获取角色朝向，更新所有动态特效的位置/旋转/填充
--- @param combatTime number 战斗时间戳
function BattleEffectComponent.Update(self, combatTime)
	self._dir = self._owner:GetUnitData():GetDirection()

	for _, effectData in pairs(self._effectList) do
		effectData.currentTime = combatTime - effectData.startTime

		self:updateEffect(effectData)
	end
end

--- 添加动态特效事件入口
--- @param event table {Data = {index, ...}}
function BattleEffectComponent.onAddEffect(self, event)
	local effectConfig = event.Data

	self:addEffect(effectConfig)
end

--- 取消动态特效事件入口
--- @param event table {Data = {index}}
function BattleEffectComponent.onCancelEffect(self, event)
	local cancelData = event.Data

	self:cancelEffect(cancelData)
end

--- 停用动态特效事件入口
--- @param event table {Data = {index}}
function BattleEffectComponent.onDeactiveEffect(self, event)
	local deactiveData = event.Data

	self:deactiveEffect(deactiveData)
end

--- Buff添加事件处理
--- @param event table {Data = {buff_id, buff_level}}
function BattleEffectComponent.onBuffAdd(self, event)
	self:DoWhenAddBuff(event)
end

--- Buff施放事件：添加闪烁
--- @param event table {Data = {buff_id}}
function BattleEffectComponent.onBuffCast(self, event)
	local buffID = event.Data.buff_id

	self:addBlink(buffID)
end

--- Buff添加时的处理：播放初始特效和持续特效
--- @param event table {Data = {buff_id, buff_level}}
function BattleEffectComponent.DoWhenAddBuff(self, event)
	local buffID = event.Data.buff_id
	local buffLevel = event.Data.buff_level

	self:addInitFX(buffID)
	self:addLastFX(buffID)
end

--- Buff堆叠事件处理
--- @param event table {Data = {buff_id, stack_count}}
function BattleEffectComponent.onBuffStack(self, event)
	self:DoWhenStackBuff(event)
end

--- Buff堆叠逻辑：
--- - 播放初始特效
--- - 如果存在last_effect_stack_list，根据堆叠数切换特效
--- - 如果last_effect支持堆叠显示多个，根据堆叠数增减特效数量
--- @param event table {Data = {buff_id, stack_count}}
function BattleEffectComponent.DoWhenStackBuff(self, event)
	local buffID = event.Data.buff_id

	self:addInitFX(buffID)

	local stackCount = event.Data.stack_count
	local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID)

	-- 堆叠切换特效（如不同堆叠数显示不同光效）
	if buffTemplate.last_effect_stack_list and self:checkLastFXID(buffID, stackCount) ~= self._currentLastFXID then
		self:switchLastFX(buffID, stackCount)
	end

	-- 堆叠数增减特效
	if buffTemplate.last_effect ~= "" and buffTemplate.last_effect_stack then
		local currentEffectCount = #self._buffLastEffects[buffID]

		if currentEffectCount < stackCount then
			self:addLastFX(buffID)
		elseif stackCount < currentEffectCount then
			local removeCount = currentEffectCount - stackCount

			while removeCount > 0 do
				self:removeLastFX(buffID)

				removeCount = removeCount - 1
			end
		end
	end
end

--- Buff移除事件：清理所有持续特效和闪烁
--- @param event table {Data = {buff_id}}
function BattleEffectComponent.onBuffRemove(self, event)
	local buffID = event.Data.buff_id

	if self._buffLastEffects[buffID] then
		local effectCount = #self._buffLastEffects[buffID]

		while effectCount > 0 do
			self:removeLastFX(buffID)

			effectCount = effectCount - 1
		end
	end

	local blinkId = self._blinkIDList[buffID]

	if blinkId then
		self._owner:RemoveBlink(blinkId)

		self._blinkIDList[buffID] = nil
	end
end

--- 播放Buff初始特效（init_effect）
--- 支持skin_adapt：根据皮肤ID自适应特效
--- @param buffID number Buff ID
function BattleEffectComponent.addInitFX(self, buffID)
	local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID)

	if buffTemplate.init_effect and buffTemplate.init_effect ~= "" then
		local fxID = buffTemplate.init_effect

		if buffTemplate.skin_adapt then
			fxID = BattleDataFunction.SkinAdaptFXID(fxID, self._owner:GetUnitData():GetSkinID())
		end

		self._owner:AddFX(fxID)
	end
end

--- 移除最后一个持续特效
--- @param buffID number Buff ID
function BattleEffectComponent.removeLastFX(self, buffID)
	local effectList = self._buffLastEffects[buffID]

	if effectList ~= nil and #effectList > 0 then
		local removedEffect = table.remove(effectList)

		self._owner:RemoveFX(removedEffect)
	end
end

--- 切换持续特效（堆叠数变化时）
--- - 先移除当前持续特效
--- - 根据新堆叠数从last_effect_stack_list中找到对应特效并生成
--- @param buffID number Buff ID
--- @param stackCount number 当前堆叠数
function BattleEffectComponent.switchLastFX(self, buffID, stackCount)
	local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID)
	local targetFxID = self:checkLastFXID(buffID, stackCount)

	if self._currentLastFXID then
		self:removeLastFX(buffID)
	end

	if targetFxID then
		local newEffect = self:generateLastFX(buffTemplate, targetFxID)
		local effectList = self._buffLastEffects[buffID] or {}

		table.insert(effectList, newEffect)

		self._buffLastEffects[buffID] = effectList
	end
end

--- 根据堆叠数从last_effect_stack_list中查找对应的特效ID
--- @param buffID number Buff ID
--- @param stackCount number 当前堆叠数
--- @return string|nil 特效ID
function BattleEffectComponent.checkLastFXID(self, buffID, stackCount)
	local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID)
	local matchedFxID

	for stackThreshold, fxID in pairs(buffTemplate.last_effect_stack_list) do
		if stackThreshold <= stackCount then
			matchedFxID = fxID
		end
	end

	return matchedFxID
end

--- 添加Buff持续特效（last_effect）
--- @param buffID number Buff ID
function BattleEffectComponent.addLastFX(self, buffID)
	local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID)

	if buffTemplate.last_effect ~= nil and buffTemplate.last_effect ~= "" then
		local newEffect = self:generateLastFX(buffTemplate, buffTemplate.last_effect)
		local effectList = self._buffLastEffects[buffID] or {}

		table.insert(effectList, newEffect)

		self._buffLastEffects[buffID] = effectList
	end
end

--- 生成持续特效并处理缩放/角度/骨骼绑定
---
--- 支持以下buffTemplate配置：
--- - last_effect_cld_scale: 根据碰撞数据缩放特效
--- - last_effect_cld_angle: 根据碰撞数据设置扇形角度
--- - last_effect_bound_bone: 将特效绑定到指定骨骼位置
--- @param buffTemplate table Buff模板数据
--- @param fxID string 特效资源ID
--- @return GameObject 特效对象
function BattleEffectComponent.generateLastFX(self, buffTemplate, fxID)
	self._currentLastFXID = fxID

	local effectObj = self._owner:AddFX(fxID)

	if buffTemplate.last_effect_cld_scale or buffTemplate.last_effect_cld_angle then
		local cldEffect
		local effectList = buffTemplate[buffLv] or buffTemplate.effect_list

		for _, effectConfig in ipairs(effectList) do
			if effectConfig.arg_list.cld_data then
				cldEffect = effectConfig

				break
			end
		end

		if cldEffect then
			-- 根据碰撞盒数据缩放特效
			if buffTemplate.last_effect_cld_scale then
				local cldBox = cldEffect.arg_list.cld_data.box
				local effectScale = effectObj.transform.localScale

				if cldBox.range then
					effectScale.x = effectScale.x * cldBox.range
					effectScale.y = effectScale.y * cldBox.range
					effectScale.z = effectScale.z * cldBox.range
				else
					effectScale.x = effectScale.x * cldBox[1]
					effectScale.y = effectScale.y * cldBox[2]
					effectScale.z = effectScale.z * cldBox[3]
				end

				effectObj.transform.localScale = effectScale
			end

			-- 根据碰撞盒角度设置扇形Shader参数
			if buffTemplate.last_effect_cld_angle then
				local cldAngle = cldEffect.arg_list.cld_data.angle
				local sectorMaterial = effectObj.transform:Find("scale/sector"):GetComponent(typeof(Renderer)).material
				local angleValue = (360 - cldAngle) * 0.5 - 5

				sectorMaterial:SetInt("_AngleControl", angleValue)
			end

			-- 将特效绑定到指定骨骼位置
			if buffTemplate.last_effect_bound_bone then
				local bonePositions = self._owner:GetBoneList()[buffTemplate.last_effect_bound_bone]

				if bonePositions then
					effectObj.transform.localPosition = bonePositions[1]
				end
			end
		end
	end

	effectObj:SetActive(true)

	return effectObj
end

--- 添加Buff闪烁效果
--- - 从buff模板读取blink配置 [r, g, b, period, duration]
--- - 存储blinkID到_buffIDList用于后续移除
--- @param buffID number Buff ID
function BattleEffectComponent.addBlink(self, buffID)
	local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID)

	if buffTemplate.blink then
		local blinkConfig = buffTemplate.blink
		local blinkId = self._owner:AddBlink(blinkConfig[1], blinkConfig[2], blinkConfig[3], blinkConfig[4], blinkConfig[5])

		self._blinkIDList[buffID] = blinkId
	end
end

--- 添加动态特效（支持位置/旋转/填充函数）
---
--- 特效配置包含：
--- - index: 特效槽索引（用于复用）
--- - effect: 特效资源名
--- - posFun(time): 返回位置的函数
--- - rotationFun(time): 返回旋转角度的函数
--- - fillFunc(): 返回 (position, scaleX, scaleZ) 的函数
--- @param effectConfig table 特效配置
function BattleEffectComponent.addEffect(self, effectConfig)
	local effectIndex = effectConfig.index or self:getIndex()
	local existingEffect = self._effectList[effectIndex]

	if existingEffect then
		-- 复用已存在的特效槽
		local savedScale = existingEffect.effect_tf.localScale

		existingEffect.effect_go:SetActive(true)

		existingEffect.effect_tf.localScale = savedScale
	else
		local effectObj = self._owner:AddFX(effectConfig.effect)

		if not effectObj then
			return
		end

		local effectData = {
			currentTime = 0,
			effect_go = effectObj,
			effect_tf = effectObj.transform,
			posFun = effectConfig.posFun,
			rotationFun = effectConfig.rotationFun,
			startTime = pg.TimeMgr.GetInstance():GetCombatTime(),
			fillFunc = effectConfig.fillFunc
		}

		self._effectList[effectIndex] = effectData

		self:updateEffect(effectData)
		pg.EffectMgr.GetInstance():PlayBattleEffect(effectObj, effectObj.transform.localPosition, false, function(effectName)
			self._owner:RemoveFX(effectObj)

			self._effectList[effectIndex] = nil
		end)
	end
end

--- 取消动态特效
--- @param cancelData table {index}
function BattleEffectComponent.cancelEffect(self, cancelData)
	local effectIndex = cancelData.index
	local effectData = self._effectList[effectIndex]

	if effectData then
		self._owner:RemoveFX(effectData.effect_go)

		self._effectList[effectIndex] = nil
	end
end

--- 停用动态特效（隐藏但不销毁）
--- @param deactiveData table {index}
function BattleEffectComponent.deactiveEffect(self, deactiveData)
	local effectIndex = deactiveData.index
	local effectData = self._effectList[effectIndex]

	if effectData then
		effectData.effect_go:SetActive(false)
	end
end

--- 获取下一个特效索引（自增）
--- @return number 特效索引
function BattleEffectComponent.getIndex(self)
	self._effectIndex = self._effectIndex + 1

	return self._effectIndex
end

--- 更新单个动态特效的位置、旋转和填充
---
--- 支持三种更新函数：
--- - posFun(time) -> localPosition
--- - rotationFun(time) -> localEulerAngles（注意朝向翻转处理）
--- - fillFunc() -> (position, scaleX, scaleZ)（填充函數类）
--- @param effectData table 特效数据 {effect_tf, posFun, rotationFun, fillFunc, currentTime}
function BattleEffectComponent.updateEffect(self, effectData)
	if effectData.posFun then
		local newPos = effectData.posFun(effectData.currentTime)

		effectData.effect_tf.localPosition = newPos
	end

	if effectData.rotationFun then
		local newRotation = effectData.rotationFun(effectData.currentTime)

		-- 角色朝左时旋转补偿180度
		if self._dir == ys.Battle.BattleConst.UnitDir.LEFT then
			newRotation.y = newRotation.y - 180
		end

		effectData.effect_tf.localEulerAngles = newRotation
	end

	if effectData.fillFunc then
		self._characterScaleX = self._characterScaleX or self._owner:GetTf().localScale.x
		self._characterScaleZ = self._characterScaleZ or self._owner:GetTf().localScale.z

		local worldPos, scaleX, scaleZ = effectData.fillFunc()

		effectData.effect_tf.position = worldPos
		effectData.effect_tf.localScale = Vector3(scaleX / self._characterScaleX, 0, scaleZ / self._characterScaleZ)
	end
end
