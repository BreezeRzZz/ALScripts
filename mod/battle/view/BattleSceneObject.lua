ys = ys or {}

local ys = ys

--- @class BattleSceneObject
--- @classdesc 战斗中所有场景对象的基类（角色、子弹、区域特效等现象层对象）。
--- 提供 GameObject/Transform 管理、碰撞体获取（虚方法，子类必须覆写）、
--- 相机正交旋转适配、以及资源销毁的统一接口。
--- @field _go UnityEngine.GameObject 绑定的GameObject
--- @field _tf UnityEngine.Transform GameObject的Transform缓存
local BattleSceneObject = class("BattleSceneObject")

ys.Battle.BattleSceneObject = BattleSceneObject
BattleSceneObject.__name = "BattleSceneObject"

function BattleSceneObject.Ctor(self)
	return
end

--- 获取绑定的GameObject
--- @return UnityEngine.GameObject
function BattleSceneObject.GetGO(self)
	return self._go
end

--- 获取绑定的Transform
--- @return UnityEngine.Transform
function BattleSceneObject.GetTf(self)
	return self._tf
end

--- 设置GameObject并缓存其Transform
--- @param go UnityEngine.GameObject 要绑定的GameObject
function BattleSceneObject.SetGO(self, go)
	self._go = go
	self._tf = go.transform
end

--- 获取碰撞盒尺寸（虚方法，子类必须覆写）
--- @return Vector3 碰撞盒尺寸
function BattleSceneObject.GetCldBoxSize(self)
	assert(false, self.__name .. ".GetCldBoxSize: this function should be override!!!")
end

--- 获取碰撞盒（虚方法，子类必须覆写）
--- @return table 碰撞盒数据
function BattleSceneObject.GetCldBox(self)
	assert(false, self.__name .. ".GetCldBox: this function should be override!!!")
end

--- 获取碰撞数据（虚方法，子类必须覆写）
--- @return table 碰撞数据
function BattleSceneObject.GetCldData(self)
	assert(false, self.__name .. ".GetCldData: this function should be override!!!")
end

--- 获取GameObject的本地位置
--- @return Vector3 localPosition
function BattleSceneObject.GetGOPosition(self)
	return self._tf.localPosition
end

--- 使对象与指定GameObject的旋转正交对齐（用于BulletWorld的Billboard效果）
--- @param target UnityEngine.GameObject 相机或其他参考对象
function BattleSceneObject.CameraOrthogonal(self, target)
	self._tf.localRotation = target.transform.localRotation
end

--- 销毁场景对象：清空引用并通过 BattleResourceManager 回收/销毁 GameObject
function BattleSceneObject.Dispose(self)
	self._tf = nil

	ys.Battle.BattleResourceManager.GetInstance():DestroyOb(self._go)

	self._go = nil
end
