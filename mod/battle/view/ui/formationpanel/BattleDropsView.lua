ys = ys or {}

local ys = ys
local BattleConfig = ys.Battle.BattleConfig
local BattleDropsView = class("BattleDropsView")

ys.Battle.BattleDropsView = BattleDropsView
BattleDropsView.__name = "BattleDropsView"
-- 掉落物飘向图标的动画持续时间
BattleDropsView.FLOAT_DURATION = 0.4

--- 战斗掉落物飘动动画视图
--- 当敌舰掉落资源时，在3D场景位置生成金币图标，飘向UI资源计数位置
--- @param go GameObject 掉落视图的GameObject
--- @param container Transform 用于容纳飘动物体的容器
function BattleDropsView.Ctor(self, go, container)
	self._go = go
	self._tf = go.transform
	self._container = container
	self._containerTF = self._container.transform

	self:init()
end

--- 显示/隐藏掉落视图
--- @param isActive boolean
function BattleDropsView.SetActive(self, isActive)
	setActive(self._go, isActive)
end

--- 添加相机引用，用于3D坐标到UI坐标的转换
--- @param camera Camera 3D场景相机
--- @param uiCamera Camera UI相机
function BattleDropsView.AddCamera(self, camera, uiCamera)
	self._camera = camera
	self._uiCamera = uiCamera
	self._cameraTF = self._camera.transform

	local cameraPos = self._cameraTF.localPosition

	-- 记录相机初始位置，用于追踪相机移动
	self._cameraSrcX = cameraPos.x
	self._cameraSrcZ = cameraPos.z
	self._cameraXRotate = self._cameraTF.localEulerAngles.x
end

--- 刷新屏幕缩放比例
function BattleDropsView.RefreshScaleRate(self)
	local screenWidth = UnityEngine.Screen.width
	local screenHeight = UnityEngine.Screen.height
	local worldPoint = self._camera:ScreenToWorldPoint(Vector3(screenWidth, screenHeight, 0))

	self._xScale = screenWidth / worldPoint.x
	self._yScale = screenHeight / worldPoint.y
end

--- 更新容器位置以跟随相机移动
function BattleDropsView.Update(self)
	if #self._resourceList == #self._resourcePool then
		return
	end

	self:updateContainerPosition()
end

--- 初始化掉落视图的各项引用和对象池
function BattleDropsView.init(self)
	self._resourceIcon = self._tf:Find("resourceIcon")
	self._resourceText = self._tf:Find("resourceText"):GetComponent(typeof(Text))
	self._resourceGO = self._containerTF:Find("spin_gold")

	-- 计算图标中心位置
	local halfWidth = self._tf.rect.width / 2
	local halfHeight = self._tf.rect.height / 2

	self._resourceIconX = self._resourceIcon.transform.anchoredPosition.x + halfWidth
	self._resourceIconY = self._resourceIcon.transform.anchoredPosition.y + halfHeight
	self._itemPool = {}
	self._resourcePool = {}
	self._resourceList = {}
	self._itemCount = 0
	self._resourceCount = 0

	self:updateCountText(self._resourceText)

	self._timerList = {}

	-- 预热对象池：pop再push 5个资源图标
	local tempList = {}

	for i = 1, 5 do
		table.insert(tempList, self:pop(self._resourcePool))
	end

	for i = 1, 5 do
		self:push(tempList[i], self._resourcePool)
	end

	local _ = nil -- 未使用的变量（用于保持某些引用）
end

--- 从对象池中取出一个GameObject（池为空则Instantiate新的）
--- @param pool table 对象池列表
--- @return GameObject
function BattleDropsView.pop(self, pool)
	local obj

	if #pool == 0 then
		if pool == self._resourcePool then
			obj = Object.Instantiate(self._resourceGO, Vector3.zero, Quaternion.identity)
			self._resourceList[#self._resourceList + 1] = obj
		end

		obj.transform:SetParent(self._go, false)
	else
		obj = pool[#pool]
		pool[#pool] = nil
	end

	return obj
end

--- 将GameObject归还到对象池
--- @param obj GameObject 要归还的对象
--- @param pool table 目标对象池
function BattleDropsView.push(self, obj, pool)
	obj.transform.localScale = Vector3(0.35, 0.35, 0.35)
	obj:GetComponent(typeof(Animator)).enabled = false

	SetActive(obj, false)

	pool[#pool + 1] = obj
end

--- 更新计数文本（支持k格式缩写）
--- @param textComp Text 文本组件
function BattleDropsView.updateCountText(self, textComp)
	local count

	if textComp == self._resourceText then
		count = self._resourceCount
	end

	if count > 999 then
		textComp.text = string.format("%s%.1f%s", "x", count / 1000, "k")
	else
		textComp.text = string.format("%s%d", "x", count)
	end
end

--- 显示掉落物动画
--- 从3D场景位置生成飘动物体，飞向UI图标位置
--- @param dropData table 掉落数据，含scenePos（场景坐标）和drops.resourceCount
function BattleDropsView.ShowDrop(self, dropData)
	if #self._resourceList == #self._resourcePool then
		self:updateContainerPosition()
	end

	-- 将3D场景坐标转换为UI坐标
	local uiPos = ys.Battle.BattleVariable.CameraPosToUICamera(dropData.scenePos:Clone())
	local startPos = Vector3(uiPos.x, uiPos.y, 2)
	local resourceAmount = dropData.drops.resourceCount
	-- 按RESOURCE_STEP拆分，整数部分一次一个完整step，余数单独处理
	local fullSteps, remainder = math.modf(resourceAmount / BattleConfig.RESOURCE_STEP)

	if remainder > 0 then
		self:makeFloatAnima(startPos, self._resourcePool, self._resourceIconX, self._resourceIconY, self._resourceIcon, "_resourceCount", remainder * BattleConfig.RESOURCE_STEP, self._resourceText, 0)
	end

	while fullSteps > 0 do
		self:makeFloatAnima(startPos, self._resourcePool, self._resourceIconX, self._resourceIconY, self._resourceIcon, "_resourceCount", BattleConfig.RESOURCE_STEP, self._resourceText, fullSteps)

		fullSteps = fullSteps - 1
	end
end

--- 更新容器位置（跟随相机移动做偏移）
function BattleDropsView.updateContainerPosition(self)
	local cameraPos = self._cameraTF.localPosition

	self._containerTF.localPosition = Vector3(self._xScale * (self._cameraSrcX - cameraPos.x), self._yScale * (self._cameraSrcZ - cameraPos.z), 0)
end

--- 创建一个掉落物的飘动动画
--- 1. 从场景位置出现并横向随机偏移 -> 2. 缩小并飞向图标 -> 3. 更新计数
--- @param startPos Vector3 起始位置（UI坐标）
--- @param pool table 对象池
--- @param targetIconX number 图标X坐标
--- @param targetIconY number 图标Y坐标
--- @param iconTF Transform 资源图标Transform
--- @param countField string 计数字段名（如"_resourceCount"）
--- @param amount number 本次增加的数量
--- @param textComp Text 计数文本组件
--- @param stepIndex number 步进索引（控制动画顺序延迟）
function BattleDropsView.makeFloatAnima(self, startPos, pool, targetIconX, targetIconY, iconTF, countField, amount, textComp, stepIndex)
	local floatObj = self:pop(pool)
	local floatTF = floatObj.transform

	SetActive(floatObj, true)

	floatTF.position = startPos
	floatTF.localPosition = floatTF.localPosition - self._containerTF.localPosition

	self:Update()
	floatTF:SetParent(self._container, false)

	-- 随机水平偏移
	local randomX = math.random() * 200 - 100
	local randomY = math.random() * 200

	-- 第一阶段：水平随机飘移
	LeanTween.moveX(rtf(floatObj), floatTF.anchoredPosition.x + randomX, BattleConfig.RESOURCE_STAY_DURATION + stepIndex * 0.05):setOnComplete(System.Action(function()
		LeanTween.scale(go(floatObj), Vector3(0.2, 0.2, 1), BattleDropsView.FLOAT_DURATION)

		-- 计算飞向目标的偏移向量
		local targetOffset = Vector3(targetIconX - floatTF.position.x, targetIconY - floatTF.position.y, 0)

		floatTF.localPosition = floatTF.localPosition + self._containerTF.localPosition

		floatTF:SetParent(self._go, false)
		-- 飞向图标
		LeanTween.move(rtf(floatObj), targetOffset, BattleDropsView.FLOAT_DURATION):setOnComplete(System.Action(function()
			self:push(floatObj, pool)

			iconTF.transform.localScale = Vector3(0.35, 0.35, 0.35)
			self[countField] = self[countField] + amount

			self:updateCountText(textComp)
			-- 图标弹跳效果
			LeanTween.scale(go(iconTF), Vector3(0.5, 0.5, 0.5), 0.12):setEase(LeanTweenType.easeOutExpo):setOnComplete(System.Action(function()
				LeanTween.scale(go(iconTF), Vector3(0.35, 0.35, 0.35), 0.3)
			end))
		end))
	end))

	-- 垂直弹跳动画
	local bounceRatio = randomY / 200

	LeanTween.moveY(rtf(floatObj), floatTF.anchoredPosition.y + randomY, 0.5 * bounceRatio):setOnComplete(System.Action(function()
		floatObj:GetComponent("Animator").enabled = true

		LeanTween.moveY(rtf(floatObj), floatTF.anchoredPosition.y - randomY, 1.5 * bounceRatio):setEase(LeanTweenType.easeOutBounce)
	end))
end

--- 清理所有定时器和缓动动画
function BattleDropsView.Dispose(self)
	for timerID, _ in pairs(self._timerList) do
		if _ then
			pg.TimeMgr.GetInstance():RemoveBattleTimer(timerID)
		end
	end

	for _, obj in ipairs(self._resourceList) do
		LeanTween.cancel(go(obj))
	end

	self._timerList = nil
	self._go = nil
	self._resourceIcon = nil
	self._resourceText = nil
	self._itemIcon = nil
	self._itemText = nil
	self._camera = nil
	self._uiCamera = nil
end
