--- 子弹视图基类
--- 负责管理子弹的视觉表现（模型、特效、旋转），将数据层 BattleBulletUnit 的状态同步到 Unity Transform。
--- 子类通过覆写 Update / UpdatePosition / SetSpawn / getHeightAdjust / GetZExtraOffset 实现不同类型子弹的视觉差异。
---
--- 关键设计：
--- - 视图-数据分离：视图层持有 _bulletData 引用，通过数据层位置/速度驱动视觉更新
--- - 对象池支持：通过 _isTempGO 标记临时模型，Dispose 时归还工厂而非销毁
--- - 性能优化：缓存上一帧速度/位置，仅在变化超过阈值时才更新 Transform，减少不必要的 Unity 跨语言调用
--- - 异步加载：先用临时模型 (AddTempModel) 占位，真实模型加载完成后通过 AddModel 替换
--- @class BattleBullet : BattleSceneObject
--- @field _bulletData BattleBulletUnit 关联的数据层子弹
--- @field _factory table 对象池工厂 (BattleBulletFactory)
--- @field _tf UnityEngine.Transform Unity Transform 组件
--- @field _go UnityEngine.GameObject Unity 游戏对象
--- @field _skeleton table Spine SkeletonAnimation 组件（用于 Spine 动画子弹）
--- @field _spineBullet boolean 是否为 Spine 动画子弹
--- @field _cacheSpeed Vector3 缓存的上一帧速度，用于减少不必要的旋转更新
--- @field _calcSpeed Vector3 当前帧计算的合成速度（数据速度 + 垂直速度）
--- @field _cacheTFPos Vector3 缓存的上一帧 Transform 位置，用于减少不必要的位置更新
--- @field _rotateScript table 旋转控制脚本（AutoTimelineScript，使子弹自动朝向运动方向）
--- @field _bulletHitFunc function 子弹命中/爆炸回调
--- @field _bulletMissFunc function 子弹未命中/消失回调
--- @field _isTempGO boolean 是否使用临时模型（等待真实模型异步加载）
--- @field _trackFX UnityEngine.GameObject 拖尾特效对象
--- @field _cfgTpl table 子弹配置模板 (bullet_template)
--- @field _IFF number 阵营标识

ys = ys or {}

local ys = ys
local BattleBulletEvent = ys.Battle.BattleBulletEvent
local BattleConfig = ys.Battle.BattleConfig
local BattleVariable = ys.Battle.BattleVariable

ys.Battle.BattleBullet = class("BattleBullet", ys.Battle.BattleSceneObject)
ys.Battle.BattleBullet.__name = "BattleBullet"

local BattleBullet = ys.Battle.BattleBullet

--- 构造函数
--- 初始化缓存的 Vector3 为零向量，注册事件监听器
function BattleBullet.Ctor(self)
    BattleBullet.super.Ctor(self)
    ys.EventListener.AttachEventListener(self)

    self.resMgr = ys.Battle.BattleResourceManager.GetInstance()
    self._cacheSpeed = Vector3.zero
    self._calcSpeed = Vector3.zero
    self._cacheTFPos = Vector3.zero
end

--- 每帧更新（由 BattleBulletFactory 驱动）
--- 从数据层获取速度，计算合成速度（数据速度 + 垂直速度），
--- 仅在速度或位置变化超过阈值时才同步 Transform，减少不必要的 Unity 调用。
--- @param timeStamp number 当前时间戳
function BattleBullet.Update(self, timeStamp)
    local bulletSpeed = self._bulletData:GetSpeed()

    -- 合成速度 = 数据层速度 + 垂直速度（重力产生的 Y 轴分量）
    self._calcSpeed:Set(bulletSpeed.x, bulletSpeed.y, bulletSpeed.z)

    local verticalSpeed = self._bulletData:GetVerticalSpeed()

    if verticalSpeed ~= 0 then
        self._calcSpeed.y = self._calcSpeed.y + verticalSpeed
    end

    -- 仅当速度发生变化时才更新旋转（避免每帧无意义的旋转更新）
    if self._cacheSpeed ~= self._calcSpeed then
        if self._rotateScript then
            self._rotateScript:SetSpeed(self._calcSpeed)
        end

        self._cacheSpeed:Set(self._calcSpeed.x, self._calcSpeed.y, self._calcSpeed.z)
    end

    -- 仅当速度足够大或位置变化明显时才同步 Transform 位置
    -- 阈值设计：速度快时必定更新（确保高速子弹不跳帧），静止/慢速时仅在位置变化 >0.1 时更新
    if math.abs(self._calcSpeed.x) >= 0.01 or math.abs(self._calcSpeed.z) >= 0.01 or math.abs(self._calcSpeed.y) >= 0.01 then
        self:UpdatePosition()
    else
        local currentPos = self:GetPosition()

        if math.abs(self._cacheTFPos.x - currentPos.x) >= 0.1 or math.abs(self._cacheTFPos.z - currentPos.z) >= 0.1 or math.abs(self._cacheTFPos.y - currentPos.y) >= 0.1 then
            self:UpdatePosition()
        end
    end
end

--- 同步数据层位置到 Unity Transform
--- 将 _bulletData 的位置写入 _tf.localPosition，同时缓存到 _cacheTFPos
function BattleBullet.UpdatePosition(self)
    local position = self:GetPosition()

    self._tf.localPosition = position

    self._cacheTFPos:Set(position.x, position.y, position.z)
end

--- 子弹超出射程时的默认处理：调用 miss 回调
function BattleBullet.DoOutRange(self)
    self._bulletMissFunc(self)
end

--- 绑定数据层子弹
--- 同时设置起始时间戳、配置模板、IFF 阵营，并注册数据层事件监听
--- @param bulletData BattleBulletUnit 数据层子弹对象
function BattleBullet.SetBulletData(self, bulletData)
    self._bulletData = bulletData

    self._bulletData:SetStartTimeStamp(pg.TimeMgr.GetInstance():GetCombatTime())

    self._cfgTpl = bulletData:GetTemplate()
    self._IFF = bulletData:GetIFF()

    self:AddBulletEvent()
end

--- 注册数据层事件监听
--- 监听 HIT（命中）、INTERCEPTED（被拦截）、OUT_RANGE（超出射程）三种事件
function BattleBullet.AddBulletEvent(self)
    self._bulletData:RegisterEventListener(self, BattleBulletEvent.HIT, self.onBulletHit)
    self._bulletData:RegisterEventListener(self, BattleBulletEvent.INTERCEPTED, self.onIntercepted)
    self._bulletData:RegisterEventListener(self, BattleBulletEvent.OUT_RANGE, self.onOutRange)
end

--- 移除数据层事件监听
function BattleBullet.RemoveBulletEvent(self)
    self._bulletData:UnregisterEventListener(self, BattleBulletEvent.HIT)
    self._bulletData:UnregisterEventListener(self, BattleBulletEvent.INTERCEPTED)
    self._bulletData:UnregisterEventListener(self, BattleBulletEvent.OUT_RANGE)
end

--- 子弹命中回调（从数据层 HIT 事件触发）
--- @param event table 命中事件 {Data = {UID = targetUID, type = unitType}}
function BattleBullet.onBulletHit(self, event)
    local eventData = event.Data
    local targetUID = event.Data.UID
    local targetType = event.Data.type

    self._bulletHitFunc(self, targetUID, targetType)
end

--- 子弹被拦截回调（从数据层 INTERCEPTED 事件触发）
--- 播放命中特效（如护盾撞击火花）
function BattleBullet.onIntercepted(self)
    local fx, fxId = ys.Battle.BattleFXPool.GetInstance():GetFX(self:GetBulletData():GetTemplate().hit_fx)

    pg.EffectMgr.GetInstance():PlayBattleEffect(fx, fxId:Add(self:GetPosition()), true)
end

--- 子弹超出射程回调（从数据层 OUT_RANGE 事件触发）
function BattleBullet.onOutRange(self, event)
    self:DoOutRange()
end

--- @return BattleBulletUnit 关联的数据层子弹
function BattleBullet.GetBulletData(self)
    return self._bulletData
end

--- @return Vector3 数据层子弹当前位置
function BattleBullet.GetPosition(self)
    return self._bulletData:GetPosition()
end

--- 清理资源
--- 重置旋转脚本速度，移除事件监听，根据是否为临时模型选择回收或销毁 GameObject，
--- 清理拖尾特效，最终移除事件监听器。
--% 对象池回收逻辑：临时模型归还工厂 RecyleTempModel，正式模型通过资源管理器 DestroyOb 销毁
function BattleBullet.Dispose(self)
    if self._rotateScript then
        self._rotateScript:SetSpeed(Vector3.zero)
    end

    self:RemoveBulletEvent()

    -- 对象池回收：临时模型归还工厂，正式模型通过资源管理器销毁
    if self._isTempGO then
        self._factory:RecyleTempModel(self._go)
    else
        ys.Battle.BattleResourceManager.GetInstance():DestroyOb(self._go)
    end

    if self._trackFX then
        self.resMgr.GetInstance():DestroyOb(self._trackFX)
    end

    self._skeleton = nil
    self._go = nil
    self._tf = nil
    self._trackFX = nil

    ys.EventListener.DetachEventListener(self)
end

--- @return string 模型 ID（考虑镜像皮肤）
function BattleBullet.GetModleID(self)
    return self._bulletData:GetModleID()
end

--- @return string 命中特效 ID
function BattleBullet.GetFXID(self)
    return self._cfgTpl.hit_fx
end

--- @return string 未命中特效 ID
function BattleBullet.GetMissFXID(self)
    return self._cfgTpl.miss_fx
end

--- @return string 拖尾特效 ID
function BattleBullet.GetTrackFXID(self)
    return self._cfgTpl.track_fx
end

--- 添加子弹模型 GameObject（异步加载真实模型后的回调）
--- 处理临时模型替换、旋转脚本、Spine 动画初始化。
--- @param go UnityEngine.GameObject 加载完成的子弹模型
--- @return boolean 是否成功添加（false 表示子弹已被销毁）
function BattleBullet.AddModel(self, go)
    -- 如果在异步加载过程中子弹已被销毁（_go 被置 nil），直接销毁刚加载的模型
    if self._isTempGO and self._go == nil then
        ys.Battle.BattleResourceManager.GetInstance():DestroyOb(go)

        return false
    else
        -- 如果之前有临时模型，先复制 Transform 信息到真实模型，再回收临时模型
        if self._isTempGO then
            LuaHelper.CopyTransformInfoGO(go, self._go)
            self._factory:RecyleTempModel(self._go)

            self._isTempGO = false
        end

        self:SetGO(go)
        self._bulletData:ActiveCldBox()

        if self._bulletData:IsAutoRotate() then
            self:AddRotateScript()
        end

        -- 尝试查找 Spine 骨骼动画节点 "bullet"
        local bulletNode = self._tf:Find("bullet")

        if bulletNode and bulletNode:GetComponent(typeof(SpineAnim)) then
            self._skeleton = bulletNode:GetComponent("SkeletonAnimation")
            self._spineBullet = true

            bulletNode:GetComponent(typeof(SpineAnim)):SetAction("normal", 0, false)
        end

        -- 尝试查找随机 Spine 骨骼动画节点 "bullet_random"（用于有多个变体动画的子弹）
        local bulletRandomNode = self._tf:Find("bullet_random")

        if bulletRandomNode and bulletRandomNode:GetComponent(typeof(SpineAnim)) then
            self._skeleton = bulletRandomNode:GetComponent("SkeletonAnimation")
            self._spineBullet = true

            local spineAnim = bulletRandomNode:GetComponent(typeof(SpineAnim))
            local randomAction = tostring(math.random(3))

            spineAnim:SetAction(randomAction, 0, false)
        end

        return true
    end
end

--- 设置 Spine 骨骼动画播放速度
--- @param speed number 动画播放速度倍率，默认 1
function BattleBullet.SetAnimaSpeed(self, speed)
    if self._skeleton then
        speed = speed or 1
        self._skeleton.timeScale = speed
    end
end

--- 添加旋转控制脚本
--- 使子弹模型自动朝向运动方向旋转
function BattleBullet.AddRotateScript(self)
    self._rotateScript = self.resMgr:GetRotateScript(self._go)
end

--- 添加临时模型（在真实模型异步加载完成前使用，由 BattleBulletFactory.MakeModel 调用）
--- @param go UnityEngine.GameObject 临时 GameObject
function BattleBullet.AddTempModel(self, go)
    self._isTempGO = true

    self:SetGO(go)

    if self._bulletData:IsAutoRotate() then
        self:AddRotateScript()
    end
end

--- 添加拖尾特效
--- @param trackFX UnityEngine.GameObject 拖尾特效对象
function BattleBullet.AddTrack(self, trackFX)
    self._trackFX = trackFX

    LuaHelper.SetGOParentTF(trackFX, self._tf, false)
end

--- 设置子弹出生点（由 BulletFactory.MakeModel 调用）
--- 计算高度调整后的位置，应用 Z 轴偏移（透视效果），
--- 根据目标位置计算初始角度并调用数据层 InitSpeed。
--% 核心流程：getHeightAdjust 计算实际位置 → 设置 Transform → 数据层 SetSpawnPosition → InitSpeed 初始化速度方向
--- @param position Vector3 原始出生坐标
function BattleBullet.SetSpawn(self, position)
    -- getHeightAdjust 返回调整后的位置和 Z 轴偏移量
    local offset, zExtraOffset = self:getHeightAdjust(position)
    local adjustedPos = offset:Clone()

    -- 应用 Z 轴偏移（高度越高偏移越大，形成透视效果）
    adjustedPos.z = adjustedPos.z + zExtraOffset
    self._tf.localPosition = adjustedPos
    -- 同步到数据层 BattleBulletUnit.SetSpawnPosition
    self._bulletData:SetSpawnPosition(adjustedPos)

    local targetPos, _, _ = self._bulletData:GetRotateInfo()

    -- 如果有目标点，计算初始角度并初始化速度
    if targetPos then
        local angle

        -- 偏移优先：以数据层给定的偏移方向为准，不额外计入 Z 偏移的影响
        if self._bulletData:GetOffsetPriority() then
            angle = math.rad2Deg * math.atan2(targetPos.z - offset.z, targetPos.x - adjustedPos.x)
        else
            -- 普通情况：计入 Z 偏移作为目标方向计算
            angle = math.rad2Deg * math.atan2(targetPos.z - offset.z - zExtraOffset, targetPos.x - adjustedPos.x)
        end

        self._bulletData:InitSpeed(angle)
    else
        self._bulletData:InitSpeed(nil)
    end
end

--- 计算高度调整参数
--- 处理三种情况：空投降落子弹、重力子弹、普通子弹。
--% 空投子弹通过重力公式计算降落时间对应的水平偏移，使得落点正好命中目标
--- @param position Vector3 原始出生坐标
--- @return Vector3 offset 调整后的位置
--- @return number zExtraOffset Z 轴额外偏移量
function BattleBullet.getHeightAdjust(self, position)
    local extraParam = self._bulletData:GetTemplate().extra_param

    -- 情况1：空投降落子弹——从空中掉落，需要计算水平提前量使得落点命中目标
    if extraParam.airdrop then
        local explodePosition = self._bulletData:GetExplodePostion()
        local xExtraOffset = 0

        if extraParam.dropOffset then
            -- 根据自由落体公式计算降落时间内的水平偏移
            -- t = sqrt(2*h/g), xExtraOffset = v * t
            -- 提前这个水平距离投放，使 Y 轴降落时间与 XZ 平面移动时间一致
            xExtraOffset = math.sqrt(math.abs(extraParam.offsetY * 2 / self._bulletData._gravity)) * self._bulletData:GetConvertedVelocity()

            -- 方向修正：如果宿主面朝左（Direction < 0），偏移取反
            if self._bulletData:GetHost():GetDirection() < 0 then
                xExtraOffset = xExtraOffset * -1
            end
        end

        return Vector3(explodePosition.x - xExtraOffset, extraParam.offsetY or position.y, explodePosition.z), 0
    else
        -- 情况2/3：普通子弹——应用数据层配置的偏移量 (barrage_template 中的 offset_x, offset_z)
        local offsetX, offsetZ = self._bulletData:GetOffset()
        local positionX = position.x + offsetX
        local positionZ = position.z + offsetZ

        -- 重力子弹不需要额外的 Y 轴调整（Y 轴由物理引擎控制）
        if self._bulletData:IsGravitate() then
            return Vector3(positionX, position.y, positionZ), 0
        else
            local zExtraOffset = 0
            local positionY
            -- BulletHeight = 1，低于 1 时不做高度调整（透视处理）
            local bulletHeight = BattleConfig.BulletHeight

            if bulletHeight >= position.y then
                positionY = position.y
            else
                -- 高于标准高度时，限制 Y 为标准高度，并在 Z 轴作视觉补偿
                positionY = bulletHeight
                zExtraOffset = self.GetZExtraOffset(position.y)
            end

            return Vector3(positionX, positionY, positionZ), zExtraOffset
        end
    end
end

--- 计算 Z 轴额外偏移量（用于高度补偿的透视效果）
--- 使用 `.` 调用（非 `:`），参数直接为 Y 坐标而非 self。
--- 可以被子类覆写（如 BattleTorpedoBullet 覆写为始终返回 0）。
--- @param positionY number 出生点的 Y 坐标
--- @return number Z 轴偏移量
--% HeightOffsetRate = 1.5, BulletHeight = 1, 即 1.5 * (positionY - 1)
function BattleBullet.GetZExtraOffset(positionY)
    return BattleConfig.HeightOffsetRate * (positionY - BattleConfig.BulletHeight)
end

--- @return table 对象池工厂
function BattleBullet.GetFactory(self)
    return self._factory
end

--- 设置对象池工厂
--- @param factory table 工厂对象
function BattleBullet.SetFactory(self, factory)
    self._factory = factory
end

--- 设置命中/未命中回调函数
--- @param hitFunc function 命中时回调
--- @param missFunc function 未命中/消失时回调
function BattleBullet.SetFXFunc(self, hitFunc, missFunc)
    self._bulletHitFunc = hitFunc
    self._bulletMissFunc = missFunc
end

--- 中立化（子弹被抵消时的视觉处理）
--- 调用 miss 回调并隐藏 GameObject（不销毁，留待工厂回收）
function BattleBullet.Neutrailze(self)
    if self._bulletMissFunc then
        self._bulletMissFunc(self)
    end

    SetActive(self._go, false)
end
