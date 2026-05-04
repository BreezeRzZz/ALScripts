ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.CardPuzzleEnergyBar = class("CardPuzzleEnergyBar")

local CardPuzzleEnergyBar = ys.Battle.CardPuzzleEnergyBar

CardPuzzleEnergyBar.__name = "CardPuzzleEnergyBar"

--- 卡牌拼图能量条视图
--- 显示战斗中能量点数的进度条（类似法力水晶），支持恢复动画

function CardPuzzleEnergyBar.Ctor(self, go)
	self._go = go
	self._tf = self._go.transform
	self._currentLabel = self._tf:Find("count_label/count/current")
	self._shadeLabel = self._tf:Find("count_label/count/current")
	self._maxLabel = self._tf:Find("count_label/max")
	self._recoverBlockList = self._tf:Find("block_list")
end

--- 设置关联的卡牌拼图组件，初始化能量块列表
function CardPuzzleEnergyBar.SetCardPuzzleComponent(self, info)
	self._info = info
	self._energyInfo = self._info:GetEnergy()
	self._blockTFList = {}
	self._max = self._energyInfo:GetMaxEnergy()

	-- 动态创建能量块节点引用
	for i = 1, self._max do
		local blockTF = self._recoverBlockList:Find("block_" .. i)
		local fullTF = blockTF:Find("full")
		local recoverTF = blockTF:Find("recover")
		local blockData = {
			full = fullTF,
			recover = recoverTF
		}

		table.insert(self._blockTFList, blockData)
	end

	self._lastPoint = 0

	-- 激活第一个能量块的恢复状态
	local firstBlock = self._blockTFList[self._lastPoint + 1]

	self:activeRecoverBlock(firstBlock)
end

--- 每帧更新
function CardPuzzleEnergyBar.Update(self)
	self:updateEnergyPoint()
	self:updateEnergyProgress()
end

--- 更新能量块进度显示
function CardPuzzleEnergyBar.updateEnergyProgress(self)
	local currentEnergy = self._energyInfo:GetCurrentEnergy()

	if self._lastPoint == currentEnergy then
		-- 能量点数未变化，只需更新当前正在恢复的块
		if currentEnergy >= self._max then
			-- 已满，无操作
		else
			local recoveringBlock = self._blockTFList[currentEnergy + 1]

			self:updateRecoverBlock(recoveringBlock)
		end
	else
		-- 能量点数发生变化，需要刷新所有块的状态
		local maxEnergy = self._max
		local blockTFList = self._blockTFList

		for index, blockData in ipairs(blockTFList) do
			local block = self._blockTFList[index]
			local energyLevel = index - 1

			if energyLevel < currentEnergy then
				self:updateSingleBlock(block, true)
			elseif energyLevel == currentEnergy then
				self:activeRecoverBlock(block)
				self:updateRecoverBlock(block)
			elseif currentEnergy < energyLevel then
				self:updateSingleBlock(block, false)
			end
		end
	end

	self._lastPoint = currentEnergy
end

--- 更新能量数字显示
function CardPuzzleEnergyBar.updateEnergyPoint(self)
	setText(self._currentLabel, self._energyInfo:GetCurrentEnergy())
	setText(self._shadeLabel, self._energyInfo:GetCurrentEnergy())
	setText(self._maxLabel, self._energyInfo:GetMaxEnergy())
end

--- 激活能量块的恢复状态（显示恢复进度条）
function CardPuzzleEnergyBar.activeRecoverBlock(self, blockData)
	setActive(blockData.full, false)
	setActive(blockData.recover, true)
end

--- 更新恢复块进度（根据生成进度填充）
function CardPuzzleEnergyBar.updateRecoverBlock(self, blockData)
	local fullTF = blockData.full

	blockData.recover:GetComponent(typeof(Image)).fillAmount = self._energyInfo:GetGeneratingProcess()
end

--- 更新单个能量块的状态（满/空）
function CardPuzzleEnergyBar.updateSingleBlock(self, blockData, isFull)
	local fullTF = blockData.full
	local recoverTF = blockData.recover

	setActive(fullTF, isFull)
	setActive(recoverTF, false)
end

function CardPuzzleEnergyBar.Dispose(self)
	self._currentLabel = nil
	self._maxLabel = nil
	self._recoverBlockList = nil
end
