ys = ys or {}

local ys = ys
local ArrowManager = singletonClass("BattleArrowManager")

ys.Battle.BattleArrowManager = ArrowManager
--- 敌方箭头管理器。负责指向屏幕外敌方位置的箭头UI的对象池管理。
--- 当敌方角色在屏幕边缘之外时，箭头会显示在屏幕边缘，指示敌方方向。
--- 使用pg.Pool管理箭头对象池。
ArrowManager.__name = "BattleArrowManager"
--- 箭头容器根节点名称
ArrowManager.ROOT_NAME = "EnemyArrowContainer"
--- 箭头资源名称
ArrowManager.ARROW_NAME = "EnemyArrow"

--- @class BattleArrowManager
--- @return nil
--- 构造函数（空，实际初始化在Init中完成）。
function ArrowManager.Ctor(self)
	return
end

--- 对象池隐藏位置：Y=10000（屏幕外）
local HIDE_POSITION = Vector3(0, 10000, 0)

--- @class BattleArrowManager
--- @param obj GameObject: 箭头GameObject
--- @return nil
--- 对象池回收函数：将未使用的箭头移动到屏幕外隐藏位置。
function ArrowManager.HideBullet(self, obj)
	obj.transform.position = HIDE_POSITION
end

--- @class BattleArrowManager
--- @param arrowRoot Transform: 箭头容器的Transform（EnemyArrowContainer）
--- @return nil
--- 初始化箭头管理器：从场景中查找箭头模板(EnemyArrow)，
--- 创建pg.Pool对象池（预分配5个，容量10）。
--- 回收时自动调用HideBullet。
function ArrowManager.Init(self, arrowRoot)
	local template = arrowRoot:Find(ArrowManager.ARROW_NAME).gameObject

	template.transform.position = HIDE_POSITION

	template:SetActive(true)

	local pool = pg.Pool.New(arrowRoot, template, 5, 10, true, true)

	pool:SetRecycleFuncs(ArrowManager.HideBullet)
	pool:InitSize()

	self._arrowPool = pool
end

--- @class BattleArrowManager
--- @return nil
--- 清理所有箭头：释放箭头对象池。
function ArrowManager.Clear(self)
	self._arrowPool:Dispose()
end

--- @class BattleArrowManager
--- @return GameObject: 箭头GameObject
--- 从对象池获取一个箭头实例。由BattleEnemyCharacterFactory.MakeArrowBar调用。
function ArrowManager.GetArrow(self)
	return (self._arrowPool:GetObject())
end

--- @class BattleArrowManager
--- @param obj GameObject|nil: 要回收的箭头GameObject
--- @return nil
--- 回收一个箭头到对象池中。
function ArrowManager.DestroyObj(self, obj)
	if obj == nil then
		return
	end

	self._arrowPool:Recycle(obj)
end
