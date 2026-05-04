ys = ys or {}

local ys = ys
--- pg.effect_offset 表，配置特效的偏移量和挂载点索引
--- 结构: { [fxID] = { offset = {x, y, z}, container_index = int, mirror = bool } }
local effectOffset = pg.effect_offset

--- @class BattleFXPool
--- @classdesc 战斗特效对象池（单例）。
--- 负责战斗特效 (FX) GameObjects 的获取与挂载，结合 BattleResourceManager 的底层资源池。
--- 支持通用 FX（直接挂到 fxContainer）和角色 FX（通过 characterFXContainersPool 挂载到角色骨骼节点）。
--- 还管理 characterFXAttachPoint 子池（角色的特效挂载点，用于异步销毁后重用）。
--- @field _fxContainer UnityEngine.GameObject 特效根容器，所有独立特效的父节点
--- @field _fxContainerTf UnityEngine.Transform 特效根容器Transform
--- @field _charAttachPointPool pg.Pool 角色特效挂载点的对象池（用于 Push/Pop 临时挂载点）
local BattleFXPool = singletonClass("BattleFXPool")

ys.Battle.BattleFXPool = BattleFXPool
BattleFXPool.__name = "BattleFXPool"

function BattleFXPool.Ctor(self)
	return
end

--- 初始化特效池
function BattleFXPool.Init(self)
	self._fxContainer = GameObject("fxContainer")
	self._fxContainerTf = self._fxContainer.transform

	-- 创建并预分配角色特效挂载点池（10个初始容量，上限20）
	local attachPointTemplate = GameObject()
	attachPointTemplate.transform:SetParent(self._fxContainerTf, false)
	attachPointTemplate.name = "characterFXAttachPoint"
	self._charAttachPointPool = pg.Pool.New(self._fxContainerTf, attachPointTemplate, 10, 20, false, true):InitSize()
end

--- 清理特效池
function BattleFXPool.Clear(self)
	self._charAttachPointPool:Dispose()
	self._charAttachPointPool = nil

	Object.Destroy(self._fxContainer)
	self._fxContainer = nil
	self._fxContainerTf = nil
end

--- 获取通用FX（非角色挂载），带偏移量
--- @param fxID string 特效资源ID
--- @param parentTF table|nil 可选的父Transform，默认挂载到 _fxContainerTf
--- @return UnityEngine.GameObject go 实例化后的特效GameObject
--- @return Vector3 offset 特效偏移量（从 effect_offset 表读取）
function BattleFXPool.GetFX(self, fxID, parentTF)
	local go = ys.Battle.BattleResourceManager.GetInstance():InstFX(fxID, true)

	-- 设置父节点，未指定则使用特效根容器
	LuaHelper.SetGOParentTF(go, parentTF or self._fxContainerTf, false)

	local offset
	local offsetData = effectOffset[fxID]

	if offsetData ~= nil then
		local offsetArr = offsetData.offset
		offset = Vector3(offsetArr[1], offsetArr[2], offsetArr[3])
	else
		offset = Vector3.zero
	end

	return go, offset
end

--- 获取角色挂载的特效（以角色GameObject或其挂载点为父节点）
--- 会根据 effect_offset 中的 container_index 决定挂载策略：
---   container_index == -1 → 挂载到角色的 GO 根节点
---   container_index >= 0  → 挂载到角色的 AttachPoint（通过 CharacterFXContainersPool）
--- @param fxID string 特效资源ID
--- @param character table 角色场景对象（需要有 GetGO, GetFXOffsets, GetAttachPoint 等方法）
--- @param autoClear boolean 是否自动清除
--- @param autoClearTimer number 自动清除定时器
--- @param additionalParam table 额外参数
--- @return UnityEngine.GameObject 实例化后的特效GameObject
function BattleFXPool.GetCharacterFX(self, fxID, character, autoClear, autoClearTimer, additionalParam)
	if character == nil then
		return self:GetFX(fxID)
	end

	local go = ys.Battle.BattleResourceManager.GetInstance():InstFX(fxID, true)
	local fxScale -- 未使用，保留占位
	local attachOffset -- 特效在父空间的偏移量
	local offsetData = effectOffset[fxID]

	if offsetData ~= nil then
		local containerIndex = offsetData.container_index
		local offsetArr = offsetData.offset

		-- 默认z偏移+0.02，避免z-fighting
		attachOffset = Vector3(offsetArr[1], offsetArr[2], offsetArr[3] + 0.02)

		if containerIndex == -1 then
			-- 挂载到角色GameObject根节点
			LuaHelper.SetGOParentGO(go, character:GetGO(), true)
		else
			-- 挂载到角色的对应container（通过FXContainersPool获取的挂载点）
			attachOffset = attachOffset + character:GetFXOffsets(containerIndex)
			LuaHelper.SetGOParentGO(go, character:GetAttachPoint(), true)
		end

		-- 镜像翻转：当父节点在x轴上有负缩放时，特效也需要镜像
		if offsetData.mirror and go.transform.parent.transform.lossyScale.x < 0 then
			local scale = go.transform.localScale
			go.transform.localScale = Vector3(-1 * scale.x, scale.y, scale.z)
		end
	else
		attachOffset = Vector3(0, 0, 0.02)
		LuaHelper.SetGOParentGO(go, character:GetGO(), true)
	end

	-- 应用角色特定的FX缩放系数
	local specificScale = character:GetSpecificFXScale()
	if specificScale[fxID] then
		local factor = specificScale[fxID]
		local currentScale = go.transform.localScale
		go.transform.localScale = Vector3(currentScale.x * factor, currentScale.y * factor, currentScale.z * factor)
	end

	-- 通过 EffectMgr 播放特效（处理粒子系统启动等）
	pg.EffectMgr.GetInstance():PlayBattleEffect(go, attachOffset, autoClear, autoClearTimer, additionalParam)

	return go
end

--- 从池中获取一个角色特效挂载点
--- @return UnityEngine.GameObject
function BattleFXPool.PopCharacterAttachPoint(self)
	return self._charAttachPointPool:GetObject()
end

--- 将角色特效挂载点归还到池中
--- @param attachPoint UnityEngine.GameObject 要归还的挂载点
function BattleFXPool.PushCharacterAttachPoint(self, attachPoint)
	self._charAttachPointPool:Recycle(attachPoint)
end
