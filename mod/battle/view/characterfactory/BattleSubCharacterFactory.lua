ys = ys or {}

local ys = ys
local SubCharacterFactory = singletonClass("BattleSubCharacterFactory", ys.Battle.BattlePlayerCharacterFactory)

ys.Battle.BattleSubCharacterFactory = SubCharacterFactory
--- 潜艇角色工厂。继承自BattlePlayerCharacterFactory（潜艇属于玩家编队）。
--- 与父类的区别：箭头使用SubArrow（副箭头，指向反潜目标），
--- 其余组件（HP条、鱼雷轨道等）完全继承父类。
SubCharacterFactory.__name = "BattleSubCharacterFactory"

--- @class BattleSubCharacterFactory
--- @return nil
--- 构造函数：覆盖ARROW_BAR_NAME为SubArrow（副箭头），
--- 用于指示反潜/水下目标方向。
function SubCharacterFactory.Ctor(self)
	SubCharacterFactory.super.Ctor(self)

	self.ARROW_BAR_NAME = "EnemyArrowContainer/SubArrow"
end

--- @class BattleSubCharacterFactory
--- @return BattleSubCharacter: 潜艇角色视觉对象
--- 创建BattleSubCharacter实例。
function SubCharacterFactory.MakeCharacter(self)
	return ys.Battle.BattleSubCharacter.New()
end
