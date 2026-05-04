ys = ys or {}

local ys = ys
local BattleResourceManager = ys.Battle.BattleResourceManager

--- @class BattleCharacterFXContainersPool
--- @classdesc 角色特效挂载容器池（单例）。
--- 每个角色身上的特效需要挂载到特定的容器节点上（由 BattleConst.FXContainerIndex 定义，
--- 如 body/head/hand 等骨骼挂点）。本池管理这些容器节点组的复用。
---
--- 工作流程：
---   Pop(characterTF, offsetList) → 从池中取出一组容器节点（4个），挂载到 characterTF 下
---   Push(containerList)          → 清空容器下的子对象，归还到池中待下次复用
---
--- 池中缓存的是整组4个GameObject，避免每帧创建/销毁。
--- @field _pool table[] 池中缓存的容器组列表（每组是4个GameObject的table）
--- @field _templateContainer UnityEngine.GameObject 池模板的根容器（放在屏幕外 -10000,-10000,0）
--- @field _templateContainerTf UnityEngine.Transform 模板容器的Transform
local BattleCharacterFXContainersPool = singletonClass("BattleCharacterFXContainersPool")
ys.Battle.BattleCharacterFXContainersPool = BattleCharacterFXContainersPool
BattleCharacterFXContainersPool.__name = "BattleCharacterFXContainersPool"

local CharacterFXContainersPool = ys.Battle.BattleCharacterFXContainersPool

function CharacterFXContainersPool.Ctor(self)
	return
end

--- 初始化容器池
function CharacterFXContainersPool.Init(self)
	self._pool = {}
	self._templateContainer = GameObject("characterFXContainerPoolParent")
	self._templateContainerTf = self._templateContainer.transform
	-- 放在屏幕外不可见
	self._templateContainerTf.position = Vector3(-10000, -10000, 0)
end

--- 从池中取出一组特效挂载容器，挂载到指定父节点下
--- @param parentTF UnityEngine.Transform 角色的Transform，容器将挂载为其子节点
--- @param offsetList table 4个容器的位置偏移列表，格式: { {x,y,z}, {x,y,z}, {x,y,z}, {x,y,z} }
--- @return table containerGroup 4个GameObject组成的table，key为 FXContainerIndex 的索引
function CharacterFXContainersPool.Pop(self, parentTF, offsetList)
	local parentRotation = parentTF.localEulerAngles

	-- 默认偏移量：四个零点
	offsetList = offsetList or {
		{ 0, 0, 0 },
		{ 0, 0, 0 },
		{ 0, 0, 0 },
		{ 0, 0, 0 },
	}

	local containerGroup

	if #self._pool == 0 then
		-- 池为空，新建一组4个GameObject（每个对应一个 FXContainerIndex 槽位）
		containerGroup = {}

		for index, containerName in ipairs(ys.Battle.BattleConst.FXContainerIndex) do
			local containerObj = GameObject()
			local containerTf = containerObj.transform
			local offset = offsetList[index]

			containerTf:SetParent(parentTF, false)

			-- 设置本地位置和朝向（x旋转需要反向，补偿角色朝向）
			containerTf.localPosition = Vector3(offset[1], offset[2], offset[3])
			containerTf.localEulerAngles = Vector3(parentRotation.x * -1, parentRotation.y, parentRotation.z)
			containerObj.name = "fxContainer_" .. containerName
			containerGroup[index] = containerObj
		end
	else
		-- 从池中复用最后一组
		containerGroup = self._pool[#self._pool]
		self._pool[#self._pool] = nil

		for index, containerObj in ipairs(containerGroup) do
			local offset = offsetList[index]
			local containerTf = containerObj.transform

			containerTf:SetParent(parentTF, false)

			containerTf.localPosition = Vector3(offset[1], offset[2], offset[3])
			containerTf.localEulerAngles = Vector3(parentRotation.x * -1, parentRotation.y, parentRotation.z)
		end
	end

	return containerGroup
end

--- 归还容器组到池（先销毁容器下所有子特效，再放回池）
--- @param containerGroup table 要归还的4个GameObject容器组
function CharacterFXContainersPool.Push(self, containerGroup)
	for _, containerObj in ipairs(containerGroup) do
		local containerTf = containerObj.transform

		-- 卸载父节点，挂回模板容器下
		containerTf:SetParent(self._templateContainerTf, false)

		-- 销毁容器下的所有子对象（即之前挂载的特效GO）
		for childIndex = containerTf.childCount - 1, 0, -1 do
			BattleResourceManager.GetInstance():DestroyOb(containerTf:GetChild(childIndex).gameObject)
		end
	end

	-- 放回池尾部
	self._pool[#self._pool + 1] = containerGroup
end

--- 清理整个容器池（战斗结束时调用）
function CharacterFXContainersPool.Clear(self)
	for _, containerGroup in ipairs(self._pool) do
		for _, containerObj in ipairs(containerGroup) do
			Object.Destroy(containerObj)
		end
	end

	self._pool = nil

	Object.Destroy(self._templateContainer)
	self._templateContainer = nil
	self._templateContainerTf = nil
end
