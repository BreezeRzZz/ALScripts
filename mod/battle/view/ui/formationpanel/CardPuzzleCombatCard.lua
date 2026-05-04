ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig

ys.Battle.CardPuzzleCombatCard = class("CardPuzzleCombatCard", CardPuzzleCardView)

local CardPuzzleCombatCard = ys.Battle.CardPuzzleCombatCard

CardPuzzleCombatCard.__name = "CardPuzzleCombatCard"
-- 卡牌各状态下的缩放值
CardPuzzleCombatCard.CARD_SCALE = Vector3(0.57, 0.57, 0)
CardPuzzleCombatCard.DRAG_SCALE = Vector3(0.65, 0.65, 0)
CardPuzzleCombatCard.DRAW_SCALE = Vector3(0.2, 0.2, 0)
CardPuzzleCombatCard.SHUFFLE_SCALE = Vector3(0.1, 0.1, 0)
-- 回收位置（移出屏幕）
CardPuzzleCombatCard.RECYLE_POS = Vector3(10000, 10000, 0)
-- 卡牌状态枚举
CardPuzzleCombatCard.STATE_LOCK = "STATE_LOCK"
CardPuzzleCombatCard.STATE_FREE = "STATE_FREE"
CardPuzzleCombatCard.STATE_DRAG = "STATE_DRAG"
CardPuzzleCombatCard.STATE_LONG_PRESS = "STATE_LONG_PRESS"
-- 默认移动插值系数
CardPuzzleCombatCard.BASE_LERP = 0.2

--- 卡牌拼图中的战斗卡牌视图
--- 继承自 CardPuzzleCardView，管理卡牌在战斗中的显示、拖拽、状态转换等

function CardPuzzleCombatCard.Ctor(self, tf)
	CardPuzzleCombatCard.super.Ctor(self, tf)

	self._go = tf.gameObject
	tf.localScale = CardPuzzleCombatCard.CARD_SCALE
	self._moveLerp = 0.2
	self._pos = Vector3.zero
end

--- 根据稀有度获取背景图名称
function CardPuzzleCombatCard.GetRarityBG(self, rarity)
	return "battle_card_bg_" .. rarity
end

--- 获取卡牌总费用
function CardPuzzleCombatCard.GetCardCost(self)
	return self.data:GetTotalCost()
end

--- 更新视图，初始化UI元素引用
function CardPuzzleCombatCard.UpdateView(self)
	CardPuzzleCombatCard.super.UpdateView(self)

	self._coolDown = self._tf:Find("cooldown")
	self._coolDownProgress = self._coolDown:GetComponent(typeof(Image))
	self._canvaGroup = self._tf:GetComponent(typeof(CanvasGroup))
	self._boostHint = self._tf:Find("boost_hint")

	self:UpdateTotalCost()
	self:UpdateBoostHint()
end

--- 每帧更新
function CardPuzzleCombatCard.Update(self)
	self:updateCoolDown()
	self:MoveToRefPos()
end

--- 设置灰色遮罩
function CardPuzzleCombatCard.ShowGray(self, isGray)
	setGray(self._tf, isGray, true)
end

--- 设置卡牌信息数据
function CardPuzzleCombatCard.SetCardInfo(self, cardInfo)
	self._cardInfo = cardInfo

	self:SetData(self._cardInfo)
end

--- 获取卡牌信息数据
function CardPuzzleCombatCard.GetCardInfo(self)
	return self._cardInfo
end

--- 抽卡动画：缩放入场
function CardPuzzleCombatCard.DrawAnima(self, targetPos)
	self:drawAlphaAndScale()

	self._tf.localPosition = targetPos
end

--- 获取UI位置（用于详情弹窗定位）
function CardPuzzleCombatCard.GetUIPos(self)
	return self._tf.anchoredPosition
end

--- 设置同级渲染顺序
function CardPuzzleCombatCard.SetSibling(self, index)
	self._tf:SetSiblingIndex(index)
end

--- 设置目标参考位置（MoveToRefPos的移动目标）
function CardPuzzleCombatCard.SetReferencePos(self, refPos)
	self._refPos = refPos
end

--- 设置移动插值系数
function CardPuzzleCombatCard.SetMoveLerp(self, lerp)
	self._moveLerp = lerp or CardPuzzleCombatCard.BASE_LERP
end

--- 平滑移动到参考位置
function CardPuzzleCombatCard.MoveToRefPos(self)
	if self._tf.localPosition:Equals(self._refPos) then
		if self._moveToPointCallback then
			self:_moveToPointCallback()

			self._moveToPointCallback = nil
		end

		return
	end

	if self._moveLerp == 1 then
		self._pos:Copy(self._refPos)
	else
		local currentPos = self._tf.localPosition
		local lerpedPos = Vector2.Lerp(currentPos, self._refPos, self._moveLerp)

		self._pos:Copy(lerpedPos)
	end

	self._tf.localPosition = self._pos
end

--- 将卡牌移到对象池回收位置（移出屏幕）
function CardPuzzleCombatCard.SetToObjPoolRecylePos(self)
	self._tf.localPosition = CardPuzzleCombatCard.RECYLE_POS
end

--- 移动回牌组
function CardPuzzleCombatCard.MoveToDeck(self, callback, deckPos)
	self:shuffleBackAlphaAndScale()
	self:SetMoveLerp(0.8)

	self._refPos = deckPos
	self._moveToPointCallback = callback
end

--- 获取当前状态
function CardPuzzleCombatCard.GetState(self)
	return self._state
end

--- 切换状态
function CardPuzzleCombatCard.ChangeState(self, state)
	self._state = state
end

--- 配置操作回调（拖拽、长按等交互）
--- @param dragStartFunc function 拖拽开始回调
--- @param dragFunc function 拖拽中回调
--- @param dragEndFunc function 拖拽结束回调
--- @param longPressFunc function 长按回调
--- @param clickFunc function 点击回调
function CardPuzzleCombatCard.ConfigOP(self, dragStartFunc, dragFunc, dragEndFunc, longPressFunc, clickFunc)
	self._dragDelegate = GetOrAddComponent(self._go, "EventTriggerListener")

	-- 配置点击回调
	self._dragDelegate:AddPointUpFunc(function(eventData, eventGO)
		clickFunc()
	end)
	-- 配置拖拽开始回调
	self._dragDelegate:AddBeginDragFunc(function(eventData, eventGO)
		self:dragAlphaAndScale()
		dragStartFunc(self._cardInfo)
	end)
	-- 配置拖拽中回调
	self._dragDelegate:AddDragFunc(function(eventData, eventGO)
		dragFunc(eventData.position)
	end)
	-- 配置拖拽结束回调
	self._dragDelegate:AddDragEndFunc(function(eventData, eventGO)
		self:resetAll()
		dragEndFunc()
	end)

	-- 配置长按
	self._longPressDelegate = GetOrAddComponent(self._go, "UILongPressTrigger")
	self._longPressDelegate.longPressThreshold = 0.5

	self._longPressDelegate.onLongPressed:AddListener(function()
		longPressFunc()
	end)
end

--- 更新冷却进度显示
function CardPuzzleCombatCard.updateCoolDown(self)
	if self._cardInfo:GetCastRemainRate() > 0 then
		setActive(self._coolDown, true)

		self._coolDownProgress.fillAmount = self._cardInfo:GetCastRemainRate()
	else
		setActive(self._coolDown, false)
	end
end

--- 将屏幕坐标转换为父容器本地坐标
function CardPuzzleCombatCard.change2ScrPos(self, screenPos)
	local overlayCamera = pg.UIMgr.GetInstance().overlayCameraComp

	return (LuaHelper.ScreenToLocal(self, screenPos, overlayCamera))
end

--- 更新拖拽位置
--- @param screenPosition Vector3 屏幕坐标
function CardPuzzleCombatCard.UpdateDragPosition(self, screenPosition)
	local localPos = self.change2ScrPos(self._tf.parent, screenPosition)

	self:SetReferencePos(localPos)
end

--- 设置射线阻挡（拖拽时关闭，防止遮挡下方卡牌）
function CardPuzzleCombatCard.BlockRayCast(self, blocksRaycasts)
	self._canvaGroup.blocksRaycasts = blocksRaycasts
end

--- 更新费用文本显示
function CardPuzzleCombatCard.UpdateTotalCost(self)
	if self._cardInfo then
		setText(self.costTF, self.data:GetTotalCost())
	end
end

--- 更新增益提示显示
function CardPuzzleCombatCard.UpdateBoostHint(self)
	if self._cardInfo then
		setActive(self._boostHint, self._cardInfo:IsBoost())
	end
end

--- 拖拽时的缩放和透明度动画
function CardPuzzleCombatCard.dragAlphaAndScale(self)
	LeanTween.cancel(self._go)
	LeanTween.scale(self._go, CardPuzzleCombatCard.DRAG_SCALE, 0.1)
	LeanTween.alphaCanvas(self._canvaGroup, 0.7, 0.1)
end

--- 抽卡出场时的缩放和透明度动画
function CardPuzzleCombatCard.drawAlphaAndScale(self)
	LeanTween.cancel(self._go)

	self._tf.localScale = CardPuzzleCombatCard.DRAW_SCALE
	self._canvaGroup.alpha = 0.2

	LeanTween.scale(self._go, CardPuzzleCombatCard.CARD_SCALE, 0.2)
	LeanTween.alphaCanvas(self._canvaGroup, 1, 0.2)
end

--- 洗牌回收时的缩放和透明度动画
function CardPuzzleCombatCard.shuffleBackAlphaAndScale(self)
	self:resetAll()
	LeanTween.scale(self._go, CardPuzzleCombatCard.SHUFFLE_SCALE, 0.2)
	LeanTween.alphaCanvas(self._canvaGroup, 0, 0.2)
end

--- 重置所有动画效果
function CardPuzzleCombatCard.resetAll(self)
	LeanTween.cancel(self._go)

	self._tf.localScale = CardPuzzleCombatCard.CARD_SCALE
	self._canvaGroup.alpha = 1
end
