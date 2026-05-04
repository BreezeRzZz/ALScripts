--- 加农炮弹视图
--- 最简单的子弹子类，直接继承 BattleBullet 的全部行为，无额外覆写。
--- 加农炮弹的特点是由常规火炮发射，直线飞行，视觉上仅需要基础的模型旋转跟随速度方向。
--- @class BattleCannonBullet : BattleBullet

ys = ys or {}

local ys = ys
local BattleResourceManager = ys.Battle.BattleResourceManager

ys.Battle.BattleCannonBullet = class("BattleCannonBullet", ys.Battle.BattleBullet)
ys.Battle.BattleCannonBullet.__name = "BattleCannonBullet"

--- 构造函数
--- 直接调用父类 Ctor，无额外初始化
--- @param ... 透传给 BattleBullet.Ctor
function ys.Battle.BattleCannonBullet.Ctor(self, ...)
    ys.Battle.BattleCannonBullet.super.Ctor(self, ...)
end
