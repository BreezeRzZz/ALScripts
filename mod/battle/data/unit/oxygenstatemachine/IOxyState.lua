ys = ys or {}

local ys = ys

--- @class IOxyState : 氧气状态机接口/基类
--- 潜艇(Walker)氧气状态机的抽象基类，定义了所有氧气状态的统一接口。
--- 子类包括：IdleOxyState(待机), DiveOxyState(下潜), FloatOxyState(上浮),
---   RaidOxyState(攻击), RetreatOxyState(撤退),
---   FreeDiveOxyState(自由下潜), FreeFloatOxyState(自由上浮), FreeBenchOxyState(自由待机),
---   DeepMineOxyState(深潜/深渊潜航)
ys.Battle.IOxyState = class("IOxyState")
ys.Battle.IOxyState.__name = "IOxyState"

local IOxyState = ys.Battle.IOxyState

--- 构造函数（空实现，子类重写）
--- @param self IOxyState
--- @return nil
function IOxyState.Ctor(self)
	return
end

--- 获取当前状态下可使用的武器类型列表
--- 返回一个OXY_STATE枚举值的数组，表示在此状态下哪些潜航状态的武器可以开火
--- 例如 FloatOxyState 返回 {DIVE, FLOAT}，表示潜航和浮航武器均可使用
--- @param self IOxyState
--- @return table|nil: 可用的武器类型列表（OXY_STATE枚举值），nil表示抽象未实现
function IOxyState.GetWeaponUseableList(self)
	return nil
end

--- 更新碰撞数据（Cloud Data）
--- 当状态切换时调用，用于更新单位的碰撞/可见性数据
--- @param self IOxyState: 新状态
--- @param unit BattleWalkUnit: 所属的潜艇单位
--- @param prevState IOxyState: 切换前的上一个状态
--- @return nil
function IOxyState.UpdateCldData(self, unit, prevState)
	return
end

--- 获取当前的潜航状态枚举值
--- @param self IOxyState
--- @return number|nil: OXY_STATE 枚举值（DIVE/FLOAT），nil表示抽象未实现
function IOxyState.GetDiveState(self)
	return nil
end

--- 获取是否产生气泡标记
--- @param self IOxyState
--- @return boolean|nil: true=产生气泡，nil表示抽象未实现
function IOxyState.GetBubbleFlag(self)
	return nil
end

--- 获取单位是否可见（对敌方）
--- @param self IOxyState
--- @return boolean: 默认true（可见）
function IOxyState.IsVisible(self)
	return true
end

--- 执行氧气更新（每帧调用）
--- 消耗或恢复氧气，具体行为由子类实现
--- @param self IOxyState
--- @param oxyState OxyState: 氧气状态管理器
--- @return nil
function IOxyState.DoUpdateOxy(self, oxyState)
	return
end

--- 获取氧气条是否可见
--- @param self IOxyState
--- @return boolean|nil: nil表示抽象未实现
function IOxyState.GetBarVisible(self)
	return nil
end

--- 获取是否处于自由模式（自由潜航）
--- FreeDiveOxyState/FreeFloatOxyState/FreeBenchOxyState返回true
--- @param self IOxyState
--- @return boolean|nil: nil表示抽象未实现
function IOxyState.RunMode(self)
	return nil
end

--- 检查是否需要从可见切换到不可见
--- 返回true时触发SetDiveInvisible(true)潜航动画
--- @param self IOxyState
--- @return boolean|nil: nil表示抽象未实现
function IOxyState.UpdateDive(self)
	return nil
end
