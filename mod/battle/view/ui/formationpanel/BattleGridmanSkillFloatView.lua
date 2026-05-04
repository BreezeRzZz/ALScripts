ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.BattleGridmanSkillFloatView = class("BattleGridmanSkillFloatView")
ys.Battle.BattleGridmanSkillFloatView.__name = "BattleGridmanSkillFloatView"

local BattleGridmanSkillFloatView = ys.Battle.BattleGridmanSkillFloatView

--- Gridman联动活动中的技能浮动图标视图
--- 显示技能释放和融合的浮动特效图标
--- @param go GameObject 浮动图标UI的GameObject
function BattleGridmanSkillFloatView.Ctor(self, go)
	self._go = go
	self._tf = tf(go)

	self:init()
end

--- 初始化技能图标列表和融合图标
function BattleGridmanSkillFloatView.init(self)
	self._fusion = {}
	-- 双方各有一个融合图标位置（FRIENDLY_CODE=1, FOE_CODE=-1）
	self._fusion[BattleConfig.FRIENDLY_CODE] = self._tf:Find("fusion_1")
	self._fusion[BattleConfig.FOE_CODE] = self._tf:Find("fusion_-1")
	self._skillList = {}

	-- 为指定阵营初始化3个技能图标槽位
	local function initSkillSlots(iffCode)
		self._skillList[iffCode] = {}

		for slotIndex = 1, 3 do
			local slotKey = slotIndex * iffCode
			local slotTF = self._tf:Find("skill_" .. slotKey)

			table.insert(self._skillList[iffCode], {
				idle = true,
				tf = slotTF
			})
		end
	end

	initSkillSlots(BattleConfig.FRIENDLY_CODE)
	initSkillSlots(BattleConfig.FOE_CODE)

	self._resource = self._tf:Find("res")
end

--- 显示技能释放浮动效果
--- 在空闲的槽位上播放对应资源的图标动画
--- @param skillIconName string 资源名称（用于查找sprite）
--- @param iffCode number 阵营代码
function BattleGridmanSkillFloatView.DoSkillFloat(self, skillIconName, iffCode)
	local slot
	local slotList = self._skillList[iffCode]

	-- 找到第一个空闲槽位
	for i = 1, 3 do
		if slotList[i].idle then
			slot = slotList[i]

			break
		end
	end

	if not slot then
		return
	end

	slot.idle = false

	local slotTF = slot.tf
	local animaTF = slotTF:Find("anima")
	local iconSprite = self._resource:Find(skillIconName):GetComponent(typeof(Image)).sprite

	setImageSprite(animaTF, iconSprite, true)
	setActive(slotTF, true)
	-- 动画结束后标记为空闲
	animaTF:GetComponent(typeof(DftAniEvent)):SetEndEvent(function(_)
		slot.idle = true

		setActive(slotTF, false)
	end)
end

--- 显示融合技能浮动效果
--- @param iffCode number 阵营代码
function BattleGridmanSkillFloatView.DoFusionFloat(self, iffCode)
	local fusionTF = self._fusion[iffCode]

	setActive(fusionTF, true)
	fusionTF:Find("anima"):GetComponent(typeof(DftAniEvent)):SetEndEvent(function(_)
		setActive(fusionTF, false)
	end)
end

--- 此视图没有需要清理的资源
function BattleGridmanSkillFloatView.Dispose(self)
	return
end
