ys = ys or {}

local ys = ys

--- @class IAntiSubState
--- 反潜警戒状态机 — 状态接口基类
--- 定义了水面舰船对敌方潜艇的探测与反应行为的状态接口。
--- 所有具体状态 (Calm / Suspicious / Vigilant / Engage) 都继承自此接口。
---
--- 状态机概览:
---   CALM      (平静)    — 未发现潜艇，无任何警觉
---   SUSPICIOUS (可疑)   — 探测到潜艇活动的间接迹象（水雷爆炸、潜艇上浮等）
---   VIGILANT  (警戒)    — 声纳探测到潜艇信号，准备交战
---   ENGAGE    (交战)    — 锁定目标，可以使用深水炸弹等反潜武器
---
--- 警戒值 (VigilantValue) 机制:
---   - 每个状态有 meterSpeed（计量表速度），决定警戒值的增减速率
---   - 警戒值达到 100 时强制进入 ENGAGE 状态
---   - 当输入信号消失后，经过 decayDuration 秒衰减期，触发 ToPreLevel 降级
ys.Battle.IAntiSubState = class("IAntiSubState")
ys.Battle.IAntiSubState.__name = "IAntiSubState"

local IAntiSubState = ys.Battle.IAntiSubState

--- 构造函数（基类空实现）
function IAntiSubState.Ctor(self)
	return
end

--- 警戒区域交战回调
--- 当单位进入声纳/警戒范围时由 AntiSubState 控制器调用
--- @param ctrl AntiSubState 控制器实例
function IAntiSubState.OnVigilantEngage(self, ctrl)
	return
end

--- 水雷爆炸回调
--- 当友方水雷在附近爆炸时触发，暗示附近可能有潜艇
--- @param ctrl AntiSubState 控制器实例
function IAntiSubState.OnMineExplode(self, ctrl)
	return
end

--- 潜艇上浮回调
--- 当敌方潜艇被迫上浮/进入可观测状态时触发
--- @param ctrl AntiSubState 控制器实例
function IAntiSubState.OnSubmarinFloat(self, ctrl)
	return
end

--- 声纳探测回调
--- 当声纳系统返回探测结果时调用（由 BattleIndieSonar 等触发）
--- @param ctrl AntiSubState 控制器实例
function IAntiSubState.OnSonarDetect(self, ctrl)
	return
end

--- 降级到前一个状态
--- 在警觉值衰减 (decay) 触发后调用，将状态降到更低一级
--- 各状态实现不同的降级目标:
---   SUSPICIOUS → CALM
---   VIGILANT   → SUSPICIOUS
---   ENGAGE     → VIGILANT
--- @param ctrl AntiSubState 控制器实例
function IAntiSubState.ToPreLevel(self, ctrl)
	return
end

--- 仇恨链回调
--- 当有其他单位（如旗舰）通过 HATE_CHAIN 事件共享仇恨时触发
--- 用于编队内反潜信息的共享传递
--- @param ctrl AntiSubState 控制器实例
function IAntiSubState.OnHateChain(self, ctrl)
	return
end

--- 当前状态是否允许警觉值衰减
--- CALM 状态下不会衰减（因为没有警觉值可供衰减）
--- @return boolean|nil
function IAntiSubState.CanDecay(self)
	return nil
end

--- 获取当前状态下可以使用的武器氧气状态列表
--- 返回值决定了反潜武器（深水炸弹等）在什么潜艇氧气状态下可以使用
--- 空表 {} 表示所有武器均不可用
--- @return table|nil 允许的 OXY_STATE 列表，如 { OXY_STATE.FLOAT }
function IAntiSubState.GetWeaponUseable(self)
	return nil
end

--- 获取当前状态的警告等级标记
--- 用于 UI 显示，0=无警告, 1=可疑, 2=警戒, 3=交战
--- @return number|nil
function IAntiSubState.GetWarnMark(self)
	return nil
end

--- 获取当前状态的计量表速度
--- 正值增加警戒值，负值减少警戒值
--- @return number|nil
function IAntiSubState.GetMeterSpeed(self)
	return nil
end

--- 获取当前状态的衰减持续时间（秒）
--- 当无输入信号持续此时间后，触发 ToPreLevel 降级
--- @return number|nil
function IAntiSubState.DecayDuration(self)
	return nil
end
