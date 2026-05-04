ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleMainFleetCharacter = class("BattleMainFleetCharacter", ys.Battle.BattlePlayerCharacter)

ys.Battle.BattleMainFleetCharacter = BattleMainFleetCharacter
BattleMainFleetCharacter.__name = "BattleMainFleetCharacter"

--- 构造函数：调用父类初始化
function BattleMainFleetCharacter.Ctor(self)
	BattleMainFleetCharacter.super.Ctor(self)
end

--- 每帧Update：额外调用箭头位置更新（主舰队始终需要）
function BattleMainFleetCharacter.Update(self)
	BattleMainFleetCharacter.super.Update(self)
	self:UpdateArrowBarPosition()
end

--- 添加箭头条：主舰队使用独立的Q版图标加载方式（qicon/素材名）
--- 与PlayerCharacter的箭头不同，不使用BattleResourceManager
function BattleMainFleetCharacter.AddArrowBar(self, arrowBarObj)
	BattleMainFleetCharacter.super.AddArrowBar(self, arrowBarObj)

	local qIcon = LoadSprite("qicon/" .. self._unitData:GetTemplate().painting) or LoadSprite("heroicon/unknown")

	setImageSprite(findTF(self._arrowBar, "icon"), qIcon)
end

--- 更新HP条位置：视野外跳过（主舰队不在画面内时不显示HP条）
function BattleMainFleetCharacter.UpdateHPBarPosition(self)
	if not self._inViewArea then
		BattleMainFleetCharacter.super.UpdateHPBarPosition(self)
	end
end

--- 获取参考坐标：视野外使用父类方法，视野内返回箭头位置（反转逻辑）
--- 主舰队不在画面可见区域内，所以需要反转
--- @param comparePos Vector3|nil 比较坐标
--- @return Vector3 参考坐标
function BattleMainFleetCharacter.GetReferenceVector(self, comparePos)
	if not self._inViewArea then
		return BattleMainFleetCharacter.super.GetReferenceVector(self, comparePos)
	else
		return self._arrowVector
	end
end
