ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleShrapnelBullet = class("BattleShrapnelBullet", ys.Battle.BattleBullet)

ys.Battle.BattleShrapnelBullet = BattleShrapnelBullet
BattleShrapnelBullet.__name = "BattleShrapnelBullet"

--- @class BattleShrapnelBullet
--- @return nil
--- 构造函数
--- - 原本提供了另外2个参数，但基类构造函数只有一个参数，因此去除
function BattleShrapnelBullet.Ctor(self)
	BattleShrapnelBullet.super.Ctor(self)
end

--- @class BattleShrapnelBullet
--- @return nil
--- 添加子弹事件
--- - 基础类会监听：HIT、INTERCEPTED、OUT_RANGE
--- - 这里增加监听：SPLIT，即母弹分裂事件
function BattleShrapnelBullet.AddBulletEvent(self)
	BattleShrapnelBullet.super.AddBulletEvent(self)
	self._bulletData:RegisterEventListener(self, BattleBulletEvent.SPLIT, self.onBulletSplit)
end

--- @class BattleShrapnelBullet
--- @return nil
--- 移除子弹事件
--- - 移除所有监听
function BattleShrapnelBullet.RemoveBulletEvent(self)
	BattleShrapnelBullet.super.RemoveBulletEvent(self)
	self._bulletData:UnregisterEventListener(self, BattleBulletEvent.SPLIT)
end

--- @class BattleShrapnelBullet
--- @return nil
--- 母弹分裂时的回调
--- - 本来还有一个参数，但未使用，因此去除
--- - _bulletHitFunc在基类中由SetFxFunc设置，而这个函数在对应的工厂类中调用
function BattleShrapnelBullet.onBulletSplit(self)
	self._bulletHitFunc(self)
end
