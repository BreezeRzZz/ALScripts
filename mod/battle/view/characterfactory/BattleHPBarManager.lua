ys = ys or {}

local ys = ys
local HPBarManager = singletonClass("BattleHPBarManager")

ys.Battle.BattleHPBarManager = HPBarManager
--- HP条管理器。负责友方和敌方两类HP条的创建、对象池管理、回收。
--- 使用pg.Pool实现对象池，预创建一定数量的HP条以减少运行时GC。
HPBarManager.__name = "BattleHPBarManager"
--- HP条容器根节点名称（场景Hierarchy中的父节点）
HPBarManager.ROOT_NAME = "HPBarContainer"
--- 友方HP条资源名（蓝色/绿色血条）
HPBarManager.HP_BAR_FRIENDLY = "heroBlood"
--- 敌方HP条资源名（红色血条）
HPBarManager.HP_BAR_FOE = "enemyBlood"
--- 各类型HP条的原始背景宽度
HPBarManager.ORIGIN_BAR_WIDTH = {
	heroBlood = 70,
	enemyBlood = 154
}
--- 各类型HP条的原始血条进度宽度（fill区域）
HPBarManager.ORIGIN_PROGRESS_WIDTH = {
	heroBlood = 66,
	enemyBlood = 153
}

--- @class BattleHPBarManager
--- @return nil
--- 构造函数（空，实际初始化在Init中完成）。
function HPBarManager.Ctor(self)
	return
end

--- @class BattleHPBarManager
--- @param sceneRoot Transform: 场景根Transform（HP条模板的父节点）
--- @param poolRoot Transform: 对象池父节点（运行时池中对象挂载点）
--- @return nil
--- 初始化HP条管理器：创建两类HP条的对象池。
---   - 友方(heroBlood): 预分配3个，容量10
---   - 敌方(enemyBlood): 预分配8个，容量10
--- _ob2Pool: GameObject->Pool 反向映射表，用于回收时找到对应池。
function HPBarManager.Init(self, sceneRoot, poolRoot)
	self._allPool = {}
	self._ob2Pool = {}
	self._allPool[HPBarManager.HP_BAR_FRIENDLY] = HPBarManager.generateTempPool(HPBarManager.HP_BAR_FRIENDLY, poolRoot, sceneRoot, 3, 10)
	self._allPool[HPBarManager.HP_BAR_FOE] = HPBarManager.generateTempPool(HPBarManager.HP_BAR_FOE, poolRoot, sceneRoot, 8, 10)
end

--- @class BattleHPBarManager
--- @param canvasRoot Transform: Canvas根节点（UGUI Canvas的Transform）
--- @return nil
--- 在Canvas创建后重新绑定对象池的父节点（动态Canvas场景时使用）。
function HPBarManager.InitialPoolRoot(self, canvasRoot)
	self._allPool[HPBarManager.HP_BAR_FRIENDLY]:ResetParent(canvasRoot)
	self._allPool[HPBarManager.HP_BAR_FOE]:ResetParent(canvasRoot)
end

--- @class BattleHPBarManager
--- @return nil
--- 清理所有HP条：释放所有对象池，清空反向映射。
function HPBarManager.Clear(self)
	for _, pool in pairs(self._allPool) do
		pool:Dispose()
	end

	self._ob2Pool = {}
	self._allPool = {}
end

--- @class BattleHPBarManager
--- @param barType string: HP条类型（HP_BAR_FRIENDLY / HP_BAR_FOE）
--- @return GameObject: 初始化好的HP条GameObject
--- 从对象池获取一个HP条。获得后做以下初始化：
---   1) 记录ob2Pool反向映射（回收时需要）
---   2) 重置血条fillAmount为1（满血）
---   3) 隐藏type（船型图标）节点
---   4) 隐藏torpedoIcons（鱼雷图标）节点
---   5) 隐藏biasBar（瞄准偏差条）节点
--- 子节点由各Factory在MakeBloodBar中按需激活。
function HPBarManager.GetHPBar(self, barType)
	local pool = self._allPool[barType]
	local hpBar = pool:GetObject()

	-- 记录反向映射，回收时用
	self._ob2Pool[hpBar] = pool

	local hpBarTf = hpBar.transform

	-- 重置血条为满血
	hpBarTf:Find("blood"):GetComponent(typeof(Image)).fillAmount = 1

	-- 默认隐藏船型图标（敌方Factory中按icon_type决定是否显示）
	local typeTf = hpBarTf:Find("type")

	if typeTf then
		SetActive(typeTf, false)
	end

	-- 默认隐藏鱼雷图标（玩家Factory中激活）
	local torpedoIcons = hpBarTf:Find("torpedoIcons")

	if torpedoIcons then
		SetActive(torpedoIcons, false)
	end

	-- 默认隐藏瞄准偏差条（有AimBias的Factory中激活）
	local biasBar = hpBarTf:Find("biasBar")

	if biasBar then
		SetActive(biasBar, false)
	end

	return hpBar
end

--- @class BattleHPBarManager
--- @param obj GameObject|nil: 要回收的HP条GameObject
--- @return nil
--- 回收/销毁一个HP条。如果ob2Pool中有映射则回收到对应池中，
--- 否则直接Object.Destroy（如被错误传递的外部对象）。
function HPBarManager.DestroyObj(self, obj)
	if obj == nil then
		return
	end

	local pool = self._ob2Pool[obj]

	if pool then
		pool:Recycle(obj)
	else
		Object.Destroy(obj)
	end
end

--- 对象池隐藏位置：将未使用的HP条移动到屏幕外的Y=10000位置
local HIDE_POSITION = Vector3(0, 10000, 0)

--- @class BattleHPBarManager
--- @param obj GameObject: HP条GameObject
--- @return nil
--- 对象池回收函数：将HP条移动到屏幕外隐藏位置。
function HPBarManager.HideBullet(self, obj)
	obj.transform.position = HIDE_POSITION
end

--- @class BattleHPBarManager
--- @param barName string: HP条资源名称（如"heroBlood"、"enemyBlood"）
--- @param poolRoot Transform: 对象池父节点
--- @param sceneRoot Transform: 场景模板根节点
--- @param initSize number: 预分配数量
--- @param capacity number: 池容量上限
--- @return pg.Pool: 创建好的对象池
--- 内部方法：从场景中查找HP条模板，创建pg.Pool对象池。
--- 先取出模板GameObject，隐藏到HIDE_POSITION后创建池。
--- 池的回收函数设置为HideBullet（移动到屏幕外）。
function HPBarManager.generateTempPool(barName, poolRoot, sceneRoot, initSize, capacity)
	local template = sceneRoot.transform:Find(barName).gameObject

	template.transform.position = HIDE_POSITION

	template:SetActive(true)

	local pool = pg.Pool.New(poolRoot, template, initSize, capacity, true, true)

	pool:SetRecycleFuncs(HPBarManager.HideBullet)
	pool:InitSize()

	return pool
end
