ys = ys or {}

local ys = ys
local BattleColumnCldComponent = class("BattleColumnCldComponent", ys.Battle.BattleCldComponent)

ys.Battle.BattleColumnCldComponent = BattleColumnCldComponent
BattleColumnCldComponent.__name = "BattleColumnCldComponent"

-- 圆柱碰撞组件，参数为范围和厚度
-- 一般实际不用管厚度
function BattleColumnCldComponent.Ctor(self, range, thickness)
	ys.Battle.BattleColumnCldComponent.super.Ctor(self)
	-- range和tickness都除以2
	-- 所以实际上，原本的box参数是指直径和高度
	self._range = range * 0.5
	self._tickness = thickness * 0.5
	self._box = pg.CldNode.New()
end

function BattleColumnCldComponent.GetCldBox(self, position)
	return self._box:UpdateCylinder(position, self._tickness, self._range)
end

function BattleColumnCldComponent.GetCldBoxSize(self)
	return {
		range = self._range,
		tickness = self._tickness
	}
end
