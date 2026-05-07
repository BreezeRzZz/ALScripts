ys = ys or {}

local ys = ys
local BattleDataFunction = ys.Battle.BattleDataFunction
local BattleConst = ys.Battle.BattleConst
local BattleConfig = ys.Battle.BattleConfig
local PoolUtil = require("Mgr/Pool/PoolUtil")

--- @class BattleResourceManager
--- @classdesc 战斗资源管理器（单例）。
--- 负责战斗内所有资源的加载、缓存、池化与生命周期管理。
--- 覆盖的资源类型包括：角色Spine动画、飞机模型、子弹prefab、特效FX、轨道orbit、UI组件、立绘painting、地图、图标等。
---
--- 核心架构：
---   1. _preloadList: 预加载清单，StartPreload 时逐项异步加载
---   2. _resCacheList: 已加载的原始资源缓存（在 InitPool 之前暂存）
---   3. _allPool: 各类资源对应的 pg.Pool 对象池
---   4. _ob2Pool: 已借出的 GameObject → Pool 的反向映射（用于 DestroyOb 回收）
---
--- 资源路径约定：
---   Item/     → 子弹
---   Char/     → 角色Spine
---   chargo/   → 飞机模型
---   Effect/   → 特效
---   orbit/    → 装备环绕轨道
---   painting/ → 角色立绘
---   Map/      → 战斗背景地图
---   UI/       → UI组件
---   herohrzicon/, squareicon/, qicon/ → 角色头像图标
---   commanderhrz/, commandericon/ → 指挥喵图标
---   shiptype/ → 舰种图标
---   AircraftIcon/ → 飞机图标
local BattleResourceManager = singletonClass("BattleResourceManager")

ys.Battle.BattleResourceManager = BattleResourceManager
BattleResourceManager.__name = "BattleResourceManager"

function BattleResourceManager.Ctor(self)
	-- 子弹旋转脚本缓存，使用弱引用kv表避免阻止GC
	self.rotateScriptMap = setmetatable({}, {
		__mode = "kv"
	})
end

--- 初始化资源管理器
function BattleResourceManager.Init(self)
	self._preloadList = {}
	self._resCacheList = {}
	self._allPool = {}
	self._ob2Pool = {}

	-- 资源池根节点（放在屏幕外）
	local poolRootObj = GameObject()
	poolRootObj:SetActive(false)
	poolRootObj.name = "PoolRoot"
	poolRootObj.transform.position = Vector3(-10000, -10000, 0)
	self._poolRoot = poolRootObj

	self._bulletContainer = GameObject("BulletContainer")
	self._battleCVList = {}
end

--- 清理所有资源（战斗结束时调用）
function BattleResourceManager.Clear(self)
	-- 清空所有对象池
	for _, pool in pairs(self._allPool) do
		pool:Dispose()
	end

	-- 清空资源缓存，根据资源类型使用不同的清理方法
	for path, obj in pairs(self._resCacheList) do
		if string.find(path, "Char/") then
			BattleResourceManager.ClearCharRes(path, obj)
		elseif string.find(path, "painting/") then
			BattleResourceManager.ClearPaintingRes(path, obj)
		else
			PoolUtil.Destroy(obj)
		end
	end

	self._resCacheList = {}
	self._ob2Pool = {}
	self._allPool = {}

	Object.Destroy(self._poolRoot)
	self._poolRoot = nil

	Object.Destroy(self._bulletContainer)
	self._bulletContainer = nil

	self.rotateScriptMap = setmetatable({}, {
		__mode = "kv"
	})

	-- 卸载所有战斗语音
	for _, cvBank in pairs(self._battleCVList) do
		pg.CriMgr.UnloadCVBank(cvBank)
	end
	self._battleCVList = {}

	ys.Battle.BattleDataFunction.ClearConvertedBarrage()
end

-- ============================================================
-- 资源路径工具函数
-- ============================================================

--- 获取子弹资源路径: "Item/xxx"
function BattleResourceManager.GetBulletPath(resName)
	return "Item/" .. resName
end

--- 获取轨道资源路径: "orbit/xxx"
function BattleResourceManager.GetOrbitPath(resName)
	return "orbit/" .. resName
end

--- 获取角色Spine资源路径: "Char/xxx"
function BattleResourceManager.GetCharacterPath(resName)
	return "Char/" .. resName
end

--- 获取飞机模型资源路径: "chargo/xxx"
function BattleResourceManager.GetCharacterGoPath(resName)
	return "chargo/" .. resName
end

--- 获取飞机图标路径: "AircraftIcon/xxx"
function BattleResourceManager.GetAircraftIconPath(resName)
	return "AircraftIcon/" .. resName
end

--- 获取特效资源路径: "Effect/xxx"
function BattleResourceManager.GetFXPath(resName)
	return "Effect/" .. resName
end

--- 获取立绘资源路径: "painting/xxx"
function BattleResourceManager.GetPaintingPath(resName)
	return "painting/" .. resName
end

--- 获取横版头像路径: "herohrzicon/xxx"
function BattleResourceManager.GetHrzIcon(resName)
	return "herohrzicon/" .. resName
end

--- 获取方形头像路径: "squareicon/xxx"
function BattleResourceManager.GetSquareIcon(resName)
	return "squareicon/" .. resName
end

--- 获取Q版头像路径: "qicon/xxx"
function BattleResourceManager.GetQIcon(resName)
	return "qicon/" .. resName
end

--- 获取指挥喵横版头像路径: "commanderhrz/xxx"
function BattleResourceManager.GetCommanderHrzIconPath(resName)
	return "commanderhrz/" .. resName
end

--- 获取指挥喵图标路径: "commandericon/xxx"
function BattleResourceManager.GetCommanderIconPath(resName)
	return "commandericon/" .. resName
end

--- 获取舰种图标路径: "shiptype/xxx"
function BattleResourceManager.GetShipTypeIconPath(resName)
	return "shiptype/" .. resName
end

--- 获取地图资源路径: "Map/xxx"
function BattleResourceManager.GetMapPath(resName)
	return "Map/" .. resName
end

--- 获取UI资源路径: "UI/xxx"
function BattleResourceManager.GetUIPath(resName)
	return "UI/" .. resName
end

--- 从完整路径中提取纯资源名（去掉所有 "/" 前缀路径）
--- 例如 "Char/jh01" → "jh01"
function BattleResourceManager.GetResName(fullPath)
	local name = fullPath
	local slashIdx = string.find(name, "%/")

	while slashIdx do
		name = string.sub(name, slashIdx + 1)
		slashIdx = string.find(name, "%/")
	end

	return name
end

--- 清理角色Spine资源（如果未被池管理器缓存则清理共享材质后再销毁）
--- @param path string 资源完整路径
--- @param obj GameObject 资源实例
function BattleResourceManager.ClearCharRes(path, obj)
	local resName = BattleResourceManager.GetResName(path)
	local skelDataAsset = obj:GetComponent("SkeletonRenderer").skeletonDataAsset

	if not PoolMgr.GetInstance():IsSpineSkelCached(resName) then
		UIUtil.ClearSharedMaterial(obj)
	end

	PoolUtil.Destroy(obj)
end

--- 清理立绘资源（归还到PoolMgr）
--- @param path string 资源完整路径
--- @param obj GameObject 资源实例
function BattleResourceManager.ClearPaintingRes(path, obj)
	local resName = BattleResourceManager.GetResName(path)
	PoolMgr.GetInstance():ReturnPainting(BattleResourceManager.GetPaintingName(resName), obj)
end

--- 销毁/回收对象——优先通过 _ob2Pool 反向查找其所属的 Pool 进行回收
--- @param obj GameObject 要销毁的对象
function BattleResourceManager.DestroyOb(self, obj)
	local pool = self._ob2Pool[obj]

	if pool then
		pool:Recycle(obj)
	else
		PoolUtil.Destroy(obj)
	end
end

--- 从池中弹出一个对象，记录 ob→pool 的映射
--- @param pool pg.Pool 对象池
--- @param keepParent boolean 是否保持父节点（false则清除parent）
--- @return GameObject
function BattleResourceManager.popPool(self, pool, keepParent)
	local obj = pool:GetObject()

	if not keepParent then
		obj.transform.parent = nil
	end

	self._ob2Pool[obj] = pool

	return obj
end

-- ============================================================
-- 资源实例化（Instantiate）函数——三级缓存策略
--   1. 池命中 → 从 _allPool 弹出
--   2. 缓存命中 → 先用缓存资源初始化池，再弹出
--   3. 缓存未命中 → 异步加载，完成后初始化池再弹出
-- ============================================================

--- 实例化角色Spine角色（异步加载策略）
--- @param resName string 资源名（不含Char/前缀）
--- @param callback function 完成回调，参数为实例化后的GameObject
function BattleResourceManager.InstCharacter(self, resName, callback)
	local fullPath = self.GetCharacterPath(resName)
	local pool = self._allPool[fullPath]

	if pool then
		-- 池命中：直接弹出
		local obj = self:popPool(pool)
		callback(obj)
	elseif self._resCacheList[fullPath] ~= nil then
		-- 缓存命中：先用缓存的资源初始化池
		self:InitPool(fullPath, self._resCacheList[fullPath])
		pool = self._allPool[fullPath]
		local obj = self:popPool(pool)
		callback(obj)
	else
		-- 异步加载Spine资源
		self:LoadSpineAsset(resName, function(asset)
			if not self._poolRoot then
				BattleResourceManager.ClearCharRes(fullPath, asset)
				return
			end

			assert(asset, "角色资源加载失败：" .. resName)

			local charGo = SpineAnim.AnimChar(resName, asset)
			charGo:SetActive(false)
			self:InitPool(fullPath, charGo)

			pool = self._allPool[fullPath]
			local obj = self:popPool(pool)
			callback(obj)
		end)
	end
end

--- 加载Spine骨骼资源（检查PoolMgr缓存状态后决定是同步还是异步加载）
--- @param resName string 资源名（不含路径前缀）
--- @param callback function 完成回调，参数为加载的SkeletonDataAsset
function BattleResourceManager.LoadSpineAsset(self, resName, callback)
	local fullPath = self.GetCharacterPath(resName)

	if not PoolMgr.GetInstance():IsSpineSkelCached(resName) then
		ResourceMgr.Inst:getAssetAsync(fullPath, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
			callback(asset)
		end), true, true)
	else
		PoolMgr.GetInstance():GetSpineSkel(resName, true, callback)
	end
end

--- 实例化飞机模型角色（chargo/ 路径）
--- @param resName string 资源名（不含chargo/前缀）
--- @param callback function 完成回调
function BattleResourceManager.InstAirCharacter(self, resName, callback)
	local fullPath = self.GetCharacterGoPath(resName)
	local pool = self._allPool[fullPath]

	if pool then
		local obj = self:popPool(pool)
		callback(obj)
	elseif self._resCacheList[fullPath] ~= nil then
		self:InitPool(fullPath, self._resCacheList[fullPath])
		pool = self._allPool[fullPath]
		local obj = self:popPool(pool)
		callback(obj)
	else
		ResourceMgr.Inst:getAssetAsync(fullPath, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
			if not self._poolRoot then
				PoolUtil.Destroy(asset)
				return
			else
				assert(asset, "飞机资源加载失败：" .. resName)
				self:InitPool(fullPath, asset)
				pool = self._allPool[fullPath]
				local obj = self:popPool(pool)
				callback(obj)
			end
		end), true, true)
	end
end

--- 实例化子弹资源
--- @param resName string 资源名（不含Item/前缀）
--- @param callback function 完成回调，参数为实例化后的GameObject
--- @return boolean 是否同步完成（true=已缓存，false=异步加载中）
function BattleResourceManager.InstBullet(self, resName, callback)
	local fullPath = self.GetBulletPath(resName)
	local pool = self._allPool[fullPath]

	if pool then
		local obj = self:popPool(pool, true)

		-- 如果子弹有拖尾效果，清除旧的拖尾数据
		if string.find(resName, "_trail") then
			local trail = obj:GetComponentInChildren(typeof(UnityEngine.TrailRenderer))
			if trail then
				trail:Clear()
			end
		end

		callback(obj)
		return true -- 同步完成
	elseif self._resCacheList[fullPath] ~= nil then
		self:InitPool(fullPath, self._resCacheList[fullPath])
		pool = self._allPool[fullPath]
		local obj = self:popPool(pool, true)

		if string.find(resName, "_trail") then
			local trail = obj:GetComponentInChildren(typeof(UnityEngine.TrailRenderer))
			if trail then
				trail:Clear()
			end
		end

		callback(obj)
		return true -- 同步完成
	else
		ResourceMgr.Inst:getAssetAsync(fullPath, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
			if not self._poolRoot then
				PoolUtil.Destroy(asset)
				return
			else
				assert(asset, "子弹资源加载失败：" .. resName)
				self:InitPool(fullPath, asset)
				pool = self._allPool[fullPath]
				local obj = self:popPool(pool, true)
				callback(obj)
			end
		end), true, true)

		return false -- 异步加载中
	end
end

--- 实例化特效资源
--- @param fxID string 特效ID
--- @param keepParent boolean 是否保持父节点
--- @return GameObject
function BattleResourceManager.InstFX(self, fxID, keepParent)
	local fullPath = self.GetFXPath(fxID)
	local go
	local pool = self._allPool[fullPath]

	if pool then
		go = self:popPool(pool, keepParent)
	elseif self._resCacheList[fullPath] ~= nil then
		self:InitPool(fullPath, self._resCacheList[fullPath])
		local popPool = self._allPool[fullPath]
		go = self:popPool(popPool, keepParent)
	else
		-- 异步加载资源，同时创建一个占位假对象避免后续重复触发加载
		ResourceMgr.Inst:getAssetAsync(fullPath, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
			if not self._poolRoot then
				PoolUtil.Destroy(asset)
				return
			else
				assert(asset, "特效资源加载失败：" .. fxID)
				self:InitPool(fullPath, asset)
			end
		end), true, true)

		go = GameObject(fxID .. "临时假obj")
		go:SetActive(false)
		self._resCacheList[fullPath] = go
	end

	-- 如果特效子节点包含SpineAnim组件，初始化其为normal动作
	local bulletChild = tf(go):Find("bullet")
	if bulletChild and bulletChild:GetComponent(typeof(SpineAnim)) then
		local spineAnim = bulletChild:GetComponent(typeof(SpineAnim))
		local skeletonAnim = bulletChild:GetComponent("SkeletonAnimation")
		local animName = "normal"

		if skeletonAnim then
			animName = SpineAnimUtil.GetCharAnimDirect(skeletonAnim, math.sign(bulletChild.localScale.x), "normal")
		end

		spineAnim:SetAction(animName, 0, false)
	end

	return go
end

--- 实例化轨道资源（orbit/）
--- @param orbitName string 轨道资源名
--- @return GameObject
function BattleResourceManager.InstOrbit(self, orbitName)
	local fullPath = self.GetOrbitPath(orbitName)
	local go
	local pool = self._allPool[fullPath]

	if pool then
		go = self:popPool(pool)
	elseif self._resCacheList[fullPath] ~= nil then
		self:InitPool(fullPath, self._resCacheList[fullPath])
		local popPool = self._allPool[fullPath]
		go = self:popPool(popPool)
	else
		ResourceMgr.Inst:getAssetAsync(fullPath, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
			if not self._poolRoot then
				PoolUtil.Destroy(asset)
				return
			else
				assert(asset, "特效资源加载失败：" .. orbitName)
				self:InitPool(fullPath, asset)
			end
		end), true, true)

		go = GameObject(orbitName .. "临时假obj")
		go:SetActive(false)
		self._resCacheList[fullPath] = go
	end

	return go
end

-- ============================================================
-- UI组件实例化（这些有固定路径不需要异步，在StartPreload阶段已保证资源就绪）
-- ============================================================

--- 实例化技能立绘UI (UI/SkillPainting)
function BattleResourceManager.InstSkillPaintingUI(self)
	local pool = self._allPool["UI/SkillPainting"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

--- 实例化大凤技能立绘UI (UI/SkillPaintingDAL)
function BattleResourceManager.InstSkillPaintingDALUI(self)
	local pool = self._allPool["UI/SkillPaintingDAL"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

--- 实例化Boss登场警告UI (UI/MonsterAppearUI)
function BattleResourceManager.InstBossWarningUI(self)
	local pool = self._allPool["UI/MonsterAppearUI"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

--- 实例化古利特技能浮窗UI (UI/combatgridmanskillfloat)
function BattleResourceManager.InstGridmanSkillUI(self)
	local pool = self._allPool["UI/combatgridmanskillfloat"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

--- 实例化莱莎AP UI (UI/combatreisalinapui)
function BattleResourceManager.InstReisalinAPUI(self)
	local pool = self._allPool["UI/combatreisalinapui"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

--- 实例化尤米亚法力UI (UI/combatyumiamanaui)
function BattleResourceManager.InstYumiaManaUI(self)
	local pool = self._allPool["UI/combatyumiamanaui"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

--- 实例化立绘
--- @param paintingName string 立绘资源名
--- @return GameObject
function BattleResourceManager.InstPainting(self, paintingName)
	local fullPath = self.GetPaintingPath(paintingName)
	local obj
	local pool = self._allPool[fullPath]

	if pool then
		obj = pool:GetObject()
		self._ob2Pool[obj] = pool
	elseif self._resCacheList[fullPath] ~= nil then
		obj = Object.Instantiate(self._resCacheList[fullPath])
		obj:SetActive(true)
	end

	return obj
end

--- 实例化地图（必须已预加载）
--- @param mapName string 地图资源名
--- @return GameObject
function BattleResourceManager.InstMap(self, mapName)
	local fullPath = self.GetMapPath(mapName)
	local obj
	local pool = self._allPool[fullPath]

	if pool then
		obj = pool:GetObject()
		self._ob2Pool[obj] = pool
	elseif self._resCacheList[fullPath] ~= nil then
		obj = Object.Instantiate(self._resCacheList[fullPath])
	else
		assert(false, "地图资源没有预加载：" .. mapName)
	end

	obj:SetActive(true)

	return obj
end

--- 实例化卡牌塔罗牌UI (UI/CardTowerCardCombat)
function BattleResourceManager.InstCardPuzzleCard(self)
	local pool = self._allPool["UI/CardTowerCardCombat"]
	local obj = pool:GetObject()
	self._ob2Pool[obj] = pool
	return obj
end

-- ============================================================
-- 图标获取（从 _resCacheList 中取预加载的 Sprite）
-- ============================================================

function BattleResourceManager.GetCharacterIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetHrzIcon(id)]
end

function BattleResourceManager.GetCharacterSquareIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetSquareIcon(id)]
end

function BattleResourceManager.GetCharacterQIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetQIcon(id)]
end

function BattleResourceManager.GetAircraftIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetAircraftIconPath(id)]
end

function BattleResourceManager.GetShipTypeIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetShipTypeIconPath(id)]
end

function BattleResourceManager.GetCommanderHrzIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetCommanderHrzIconPath(id)]
end

function BattleResourceManager.GetCommanderIcon(self, id)
	return self._resCacheList[BattleResourceManager.GetCommanderIconPath(id)]
end

--- 获取战斗着色器（通过ShaderMgr，使用BATTLE_SHADER配置）
function BattleResourceManager.GetShader(self, shaderName)
	return (pg.ShaderMgr.GetInstance():GetShader(BattleConfig.BATTLE_SHADER[shaderName]))
end

-- ============================================================
-- 预加载系统
-- ============================================================

--- 添加预加载资源路径
--- @param path string|table 单个路径字符串或路径表
function BattleResourceManager.AddPreloadResource(self, path)
	if type(path) == "string" then
		self._preloadList[path] = false
	elseif type(path) == "table" then
		for _, p in ipairs(path) do
			self._preloadList[p] = false
		end
	end
end

--- 添加预加载语音
--- @param skinID number 皮肤ID（用于获取对应CV）
function BattleResourceManager.AddPreloadCV(self, skinID)
	local cvKey = ShipWordHelper.RawGetCVKey(skinID)

	if cvKey > 0 then
		self._battleCVList[cvKey] = pg.CriMgr.GetBattleCVBankName(cvKey)
	end
end

--- 开始预加载所有资源
--- @param onProgress function|nil 进度回调，参数为已加载数量
--- @param onComplete function 完成回调
--- @return number totalCount 总预加载数量
function BattleResourceManager.StartPreload(self, onProgress, onComplete)
	local loadedCount = 0
	local totalCount = 0

	for _ in pairs(self._preloadList) do
		totalCount = totalCount + 1
	end

	for _ in pairs(self._battleCVList) do
		totalCount = totalCount + 1
	end

	--- 单个资源加载完成或跳过的统一回调
	--- 用于推进进度并在全部完成时调用 onComplete
	local function onOneLoaded()
		if not self._poolRoot then
			return
		end

		loadedCount = loadedCount + 1

		if loadedCount > totalCount then
			return
		end

		if onProgress then
			onProgress(loadedCount)
		end

		-- 全部加载完成
		if loadedCount == totalCount then
			self._preloadList = nil
			onComplete()
		end
	end

	-- 先加载所有语音
	for cvKey, _ in pairs(self._battleCVList) do
		pg.CriMgr.GetInstance():LoadBattleCV(cvKey, onOneLoaded)
	end

	-- 加载所有预加载资源
	for path, _ in pairs(self._preloadList) do
		local resName = self.GetResName(path)

		if resName == "" or self._resCacheList[path] ~= nil then
			-- 路径为空或已缓存，跳过
			onOneLoaded()
		elseif string.find(path, "herohrzicon/") or string.find(path, "qicon/") or string.find(path, "squareicon/") or string.find(path, "commanderhrz/") or string.find(path, "commandericon/") or string.find(path, "AircraftIcon/") then
			-- 图标类资源：需要处理大/R/小版本路径适配（HXSet）
			local actualPath, pureName = HXSet.autoHxShiftPath(path, resName)

			ResourceMgr.Inst:getAssetAsync(actualPath, "", typeof(Sprite), UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
				if asset == nil then
					originalPrint("资源预加载失败，检查以下目录：>>" .. path .. "<<")
				else
					if not self._poolRoot then
						PoolUtil.Destroy(asset)
						return
					end

					if self._resCacheList then
						self._resCacheList[path] = asset
					end
				end

				onOneLoaded()
			end), true, true)
		elseif string.find(path, "shiptype/") then
			-- 舰种图标：从shiptype图集中异步加载
			local spriteName = string.split(path, "/")[2]

			GetSpriteFromAtlasAsync("shiptype", spriteName, function(asset)
				if asset == nil then
					originalPrint("资源预加载失败，检查以下目录：>>" .. path .. "<<")
				else
					if not self._poolRoot then
						PoolUtil.Destroy(asset)
						return
					end

					if self._resCacheList then
						self._resCacheList[path] = asset
					end
				end

				onOneLoaded()
			end)
		elseif string.find(path, "painting/") then
			-- 立绘资源：通过 PoolMgr 获取立绘
			PoolMgr.GetInstance():GetPainting(BattleResourceManager.GetPaintingName(resName), true, function(asset)
				if asset == nil then
					originalPrint("资源预加载失败，检查以下目录：>>" .. path .. "<<")
				else
					if not self._poolRoot then
						BattleResourceManager.ClearPaintingRes(path, asset)
						return
					end

					ShipExpressionHelper.SetExpression(asset, resName)
					asset:SetActive(false)

					if self._resCacheList then
						self._resCacheList[path] = asset
					end
				end

				onOneLoaded()
			end)
		elseif string.find(path, "Char/") then
			-- 角色Spine资源
			self:LoadSpineAsset(resName, function(asset)
				if asset == nil then
					originalPrint("资源预加载失败，检查以下目录：>>" .. path .. "<<")
				else
					asset = SpineAnim.AnimChar(resName, asset)

					if not self._poolRoot then
						BattleResourceManager.ClearCharRes(path, asset)
						return
					end

					asset:SetActive(false)

					if self._resCacheList then
						self._resCacheList[path] = asset
					end
				end

				self:InitPool(path, asset)
				onOneLoaded()
			end)
		elseif string.find(path, "UI/") then
			-- UI资源
			LoadAndInstantiateAsync("UI", resName, function(asset)
				if asset == nil then
					originalPrint("资源预加载失败，检查以下目录：>>" .. path .. "<<")
				else
					if not self._poolRoot then
						PoolUtil.Destroy(asset)
						return
					end

					asset:SetActive(false)

					if self._resCacheList then
						self._resCacheList[path] = asset
					end
				end

				self:InitPool(path, asset)
				onOneLoaded()
			end, true, true)
		else
			-- 其他通用资源（Item/Effect/Map/chargo/orbit 等）
			ResourceMgr.Inst:getAssetAsync(path, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
				if asset == nil then
					originalPrint("资源预加载失败，检查以下目录：>>" .. path .. "<<")
				else
					if not self._poolRoot then
						PoolUtil.Destroy(asset)
						return
					end

					if self._resCacheList then
						self._resCacheList[path] = asset
					end
				end

				self:InitPool(path, asset)
				onOneLoaded()
			end), true, true)
		end
	end

	return totalCount
end

--- 获取立绘资源名（考虑"隐藏其他对象"和"战斗隐藏背景"设置，可能追加 "_n" 后缀）
--- @param paintingName string 原始立绘名
--- @return string 实际立绘名
function BattleResourceManager.GetPaintingName(paintingName)
	local useNaked = false

	if PlayerPrefs.GetInt(BATTLE_HIDE_BG, 1) > 0 then
		useNaked = checkABExist("painting/" .. paintingName .. "_n")
	else
		useNaked = PlayerPrefs.GetInt("paint_hide_other_obj_" .. paintingName, 0) ~= 0 and checkABExist("painting/" .. paintingName .. "_n")
	end

	return paintingName .. (useNaked and "_n" or "")
end

-- ============================================================
-- 池管理与辅助函数
-- ============================================================

--- 隐藏子弹的固定位置（屏幕外 Y=10000）
local hidePos = Vector3(0, 10000, 0)

--- 子弹回池时移动到屏幕外
--- @param bulletObj GameObject
function BattleResourceManager.HideBullet(bulletObj)
	bulletObj.transform.position = hidePos
end

--- 特效入池后的初始化回调：注册粒子系统事件
--- @param effectObj GameObject
function BattleResourceManager.InitParticleSystemCB(effectObj)
	pg.EffectMgr.GetInstance():CommonEffectEvent(effectObj)
end

--- 为指定资源路径和模板对象初始化对象池
--- 根据资源类型（Item/Effect/Char/chargo/orbit/UI）使用不同的池配置策略
--- @param path string 资源完整路径
--- @param templateObj GameObject 模板对象
function BattleResourceManager.InitPool(self, path, templateObj)
	local poolRootTf = self._poolRoot.transform

	if string.find(path, "Item/") then
		-- 子弹资源
		if templateObj:GetComponentInChildren(typeof(UnityEngine.TrailRenderer)) ~= nil or templateObj:GetComponentInChildren(typeof(ParticleSystem)) ~= nil then
			-- 有拖尾或粒子的子弹：15初始/20上限，自动释放
			self._allPool[path] = pg.Pool.New(self._bulletContainer.transform, templateObj, 15, 20, true, false):InitSize()
		else
			-- 普通子弹：20初始/20上限，回收时调用 HideBullet 移到屏幕外
			local bulletPool = pg.Pool.New(self._bulletContainer.transform, templateObj, 20, 20, true, true)
			bulletPool:SetRecycleFuncs(BattleResourceManager.HideBullet)
			bulletPool:InitSize()
			self._allPool[path] = bulletPool
		end
	elseif string.find(path, "Effect/") then
		-- 特效资源
		if templateObj:GetComponent(typeof(UnityEngine.ParticleSystem)) then
			-- 有粒子系统组件的：基准5个，smoke特殊处理30个，feijiyingzi 1个
			local initSize = 5

			if string.find(path, "smoke") and not string.find(path, "smokeboom") then
				initSize = 30
			elseif string.find(path, "feijiyingzi") then
				initSize = 1
			end

			local fxPool = pg.Pool.New(poolRootTf, templateObj, initSize, 20, false, false)
			fxPool:SetInitFuncs(BattleResourceManager.InitParticleSystemCB)
			fxPool:InitSize()
			self._allPool[path] = fxPool
		else
			-- 无粒子系统组件的特效（如AntiAirArea等）
			local initSize = 8

			if string.find(path, "AntiAirArea") or string.find(path, "AntiSubArea") then
				initSize = 1
			end

			GetOrAddComponent(templateObj, typeof(ParticleSystemEvent))

			local fxPool = pg.Pool.New(poolRootTf, templateObj, initSize, 20, false, false)
			fxPool:InitSize()
			self._allPool[path] = fxPool
		end
	elseif string.find(path, "Char/") then
		-- 角色Spine资源：通常1个，danchuan（单船/自爆船）3个
		local initSize = 1

		if string.find(path, "danchuan") then
			initSize = 3
		end

		local charPool = pg.Pool.New(poolRootTf, templateObj, initSize, 20, false, false):InitSize()
		charPool:SetRecycleFuncs(BattleResourceManager.ResetSpineAction)
		self._allPool[path] = charPool
	elseif string.find(path, "chargo/") then
		-- 飞机模型：3个
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 3, 20, false, false):InitSize()
	elseif string.find(path, "orbit/") then
		-- 轨道：2个
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 2, 20, false, false):InitSize()
	elseif path == "UI/SkillPainting" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 1, 20, false, false):InitSize()
	elseif path == "UI/SkillPaintingDAL" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 1, 20, false, false):InitSize()
	elseif path == "UI/MonsterAppearUI" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 1, 20, false, false):InitSize()
	elseif path == "UI/CardTowerCardCombat" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 7, 20, false, false):InitSize()
	elseif path == "UI/combatgridmanskillfloat" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 1, 20, false, false):InitSize()
	elseif path == "UI/combatreisalinapui" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 1, 20, false, false):InitSize()
	elseif path == "UI/combatyumiamanaui" then
		self._allPool[path] = pg.Pool.New(poolRootTf, templateObj, 1, 20, false, false):InitSize()
	elseif path == "UI/CombatHPBar" .. ys.Battle.BattleState.GetCombatSkinKey() then
		-- HP条：交给 BattleHPBarManager 管理
		ys.Battle.BattleHPBarManager.GetInstance():Init(templateObj, poolRootTf)
	elseif string.find(path, "UI/CombatHPPop") then
		-- HP弹出数字：交给 BattlePopNumManager 管理
		ys.Battle.BattlePopNumManager.GetInstance():Init(templateObj, poolRootTf)
	end
end

--- 获取或添加子弹旋转脚本组件（有缓存避免重复 GetOrAddComponent）
--- @param go GameObject
--- @param bulletName string 子弹名（用于缓存key）
--- @return Component
function BattleResourceManager.GetRotateScript(self, go, bulletName)
	local cache = self.rotateScriptMap

	if cache[go] then
		return cache[go]
	end

	local script = GetOrAddComponent(go, "BulletRotation")
	cache[go] = script

	return script
end

-- ============================================================
-- 资源清单收集函数（用于在战斗前构建预加载列表）
-- ============================================================

--- 获取通用战斗资源清单
--- 包括地图（visionLine, exposeLine）、通用特效（水波纹、炸弹、警报区域等）、UI组件（HP条等）
function BattleResourceManager.GetCommonResource()
	return {
		BattleResourceManager.GetMapPath("visionLine"),
		BattleResourceManager.GetMapPath("exposeLine"),
		BattleResourceManager.GetFXPath(ys.Battle.BattleCharacterFactory.MOVE_WAVE_FX_NAME),
		BattleResourceManager.GetFXPath(ys.Battle.BattleCharacterFactory.BOMB_FX_NAME),
		BattleResourceManager.GetFXPath(ys.Battle.BattleBossCharacterFactory.BOMB_FX_NAME),
		BattleResourceManager.GetFXPath(ys.Battle.BattleAircraftCharacterFactory.BOMB_FX_NAME),
		BattleResourceManager.GetFXPath("AlertArea"),
		BattleResourceManager.GetFXPath("TorAlert"),
		BattleResourceManager.GetFXPath("SquareAlert"),
		BattleResourceManager.GetFXPath("AntiAirArea"),
		BattleResourceManager.GetFXPath("AntiSubArea"),
		BattleResourceManager.GetFXPath("AimBiasArea"),
		BattleResourceManager.GetFXPath("shock"),
		BattleResourceManager.GetFXPath("qianting_chushui"),
		BattleResourceManager.GetFXPath(BattleConfig.PLAYER_SUB_BUBBLE_FX),
		BattleResourceManager.GetFXPath("weaponrange"),
		BattleResourceManager.GetUIPath("SkillPainting"),
		BattleResourceManager.GetUIPath("MonsterAppearUI"),
		BattleResourceManager.GetUIPath("combatreisalinapui"),
		BattleResourceManager.GetUIPath("combatyumiamanaui"),
		BattleResourceManager.GetUIPath("CombatHPBar" .. ys.Battle.BattleState.GetCombatSkinKey()),
		BattleResourceManager.GetUIPath("CombatHPPop" .. ys.Battle.BattleState.GetCombatSkinKey()),
	}
end

--- 获取展示用通用资源（比 GetCommonResource 少一些，用于预览/展示场景）
function BattleResourceManager.GetDisplayCommonResource()
	return {
		BattleResourceManager.GetFXPath(ys.Battle.BattleCharacterFactory.MOVE_WAVE_FX_NAME),
		BattleResourceManager.GetFXPath(ys.Battle.BattleCharacterFactory.BOMB_FX_NAME),
		BattleResourceManager.GetFXPath(ys.Battle.BattleCharacterFactory.DANCHUAN_MOVE_WAVE_FX_NAME),
	}
end

--- 获取地图资源清单（根据地图ID逐层收集）
--- @param mapID number 地图ID
--- @return table 地图资源路径列表
function BattleResourceManager.GetMapResource(mapID)
	local resList = {}
	local BattleMap = ys.Battle.BattleMap

	for _, layer in ipairs(BattleMap.LAYERS) do
		local layerResNames = BattleMap.GetMapResNames(mapID, layer)
		for _, resName in ipairs(layerResNames) do
			resList[#resList + 1] = BattleResourceManager.GetMapPath(resName)
		end
	end

	return resList
end

--- 获取Buff特效资源清单（从 buffFXPreloadList 配置）
function BattleResourceManager.GetBuffResource()
	local resList = {}
	local buffFXList = require("buffFXPreloadList")

	for _, fxName in ipairs(buffFXList) do
		resList[#resList + 1] = BattleResourceManager.GetFXPath(fxName)
	end

	return resList
end

--- 获取单艘舰船的资源清单
--- @param shipTmpID number 舰船模板ID
--- @param skinID number|nil 皮肤ID
--- @param isMainUnit boolean 是否主力单位（主力额外需要立绘）
--- @return table 资源路径列表
function BattleResourceManager.GetShipResource(shipTmpID, skinID, isMainUnit)
	local resList = {}
	local shipTmpData = BattleDataFunction.GetPlayerShipTmpDataFromID(shipTmpID)

	if skinID == nil or skinID == 0 then
		skinID = shipTmpData.skin_id
	end

	local skinData = BattleDataFunction.GetPlayerShipSkinDataFromID(skinID)

	-- 角色Spine + 头像图标
	resList[#resList + 1] = BattleResourceManager.GetCharacterPath(skinData.prefab)
	resList[#resList + 1] = BattleResourceManager.GetHrzIcon(skinData.painting)
	resList[#resList + 1] = BattleResourceManager.GetQIcon(skinData.painting)

	-- 镜像Q版头像（如某些联动角色需要）
	if table.contains(BattleConfig.MIRROR_QICON_SHIP_GROUP, skinData.ship_group) then
		resList[#resList + 1] = BattleResourceManager.GetQIcon(skinData.painting .. BattleConfig.MIRROR_QICON_KEY)
	end

	resList[#resList + 1] = BattleResourceManager.GetSquareIcon(skinData.painting)

	-- 主力单位额外需要立绘
	if isMainUnit and BattleDataFunction.GetShipTypeTmp(shipTmpData.type).team_type == TeamType.Main then
		resList[#resList + 1] = BattleResourceManager.GetPaintingPath(skinData.painting)
	end

	return resList
end

--- 获取玩家舰船（含装备、技能、指挥喵）的完整资源清单
--- @param shipVOList table 舰船VO列表（Ship类型）
--- @param battleType number 战斗类型
--- @return table resList 资源路径列表
--- @return table skinIDList 皮肤ID列表
function BattleResourceManager.GetPlayerShipResource(shipVOList, battleType)
	local resList = {}
	local skinIDList = {}

	for _, shipVO in ipairs(shipVOList) do
		local configId = shipVO.configId

		table.insert(skinIDList, shipVO.skinId)

		-- 舰船本体资源
		local shipRes = BattleResourceManager.GetShipResource(configId, shipVO.skinId, true)
		for _, res in pairs(shipRes) do
			table.insert(resList, res)
		end

		local shipTmpData = BattleDataFunction.GetPlayerShipTmpDataFromID(configId)

		-- 装备资源（5个装备槽位）
		for equipIndex, equipItem in ipairs(shipVO:getActiveEquipments()) do
			local equipId
			local equipSkinId = 0

			if not equipItem then
				equipId = shipTmpData.default_equip_list[equipIndex]
			else
				equipId = equipItem.configId
				equipSkinId = equipItem.skinId
			end

			if equipId then
				local weaponIds = BattleDataFunction.GetWeaponDataFromID(equipId).weapon_id

				if #weaponIds > 0 then
					-- 直接有武器ID列表的（如普通装备）
					for _, weaponId in ipairs(weaponIds) do
						local weaponRes = BattleResourceManager.GetWeaponResource(weaponId, equipSkinId)
						for _, res in pairs(weaponRes) do
							table.insert(resList, res)
						end
					end
				else
					-- 没有武器ID的（如特殊装备，需要通过GetEquipResource处理）
					local equipRes = BattleResourceManager.GetEquipResource(equipId, equipSkinId, battleType)
					for _, res in pairs(equipRes) do
						table.insert(resList, res)
					end
				end
			end
		end

		-- 固定装备（depth_charge_list + fix_equip_list）的武器资源
		local fixedWeaponIds = {}

		for _, equipId in ipairs(shipTmpData.depth_charge_list) do
			local weaponIds = BattleDataFunction.GetWeaponDataFromID(equipId).weapon_id
			for _, weaponId in ipairs(weaponIds) do
				table.insert(fixedWeaponIds, weaponId)
			end
		end

		for _, equipId in ipairs(shipTmpData.fix_equip_list) do
			local weaponIds = BattleDataFunction.GetWeaponDataFromID(equipId).weapon_id
			for _, weaponId in ipairs(weaponIds) do
				table.insert(fixedWeaponIds, weaponId)
			end
		end

		for _, weaponId in ipairs(fixedWeaponIds) do
			local weaponRes = BattleResourceManager.GetWeaponResource(weaponId)
			for _, res in pairs(weaponRes) do
				table.insert(resList, res)
			end
		end

		-- 专武（SpWeapon）资源
		local spWeapon = shipVO.GetSpWeapon and shipVO:GetSpWeapon()
		if spWeapon then
			local spWeaponRes = BattleResourceManager.GetSpWeaponResource(spWeapon:GetConfigID(), battleType)
			for _, res in pairs(spWeaponRes) do
				table.insert(resList, res)
			end
		end

		-- 技能Buff对应的子弹/特效资源
		local skillResList = BattleDataFunction.GetBuffBulletRes(configId, shipVO.skills, battleType, shipVO.skinId, spWeapon)
		for _, res in pairs(skillResList) do
			table.insert(resList, res)
		end

		-- Buff本身对应的资源
		if shipVO.buffs then
			local buffRes = BattleDataFunction.GetBuffListRes(shipVO.buffs, battleType, shipVO.skinId)
			for _, res in pairs(buffRes) do
				table.insert(resList, res)
			end
		end
	end

	return resList, skinIDList
end

--- 获取敌方单位资源清单
--- @param spawnData table 生成数据（含 monsterTemplateID, bossData, buffList, phase 等）
--- @return table 资源路径列表
function BattleResourceManager.GetEnemyResource(spawnData)
	local resList = {}
	local monsterID = spawnData.monsterTemplateID
	local isBoss = spawnData.bossData ~= nil
	local buffList = spawnData.buffList or {}
	local phaseList = spawnData.phase or {}
	local monsterTmp = BattleDataFunction.GetMonsterTmpDataFromID(monsterID)

	-- 基本角色资源
	resList[#resList + 1] = BattleResourceManager.GetCharacterPath(monsterTmp.prefab)
	resList[#resList + 1] = BattleResourceManager.GetFXPath(monsterTmp.wave_fx)

	if monsterTmp.fog_fx then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(monsterTmp.fog_fx)
	end

	-- 登场特效
	for _, appearFX in ipairs(monsterTmp.appear_fx) do
		resList[#resList + 1] = BattleResourceManager.GetFXPath(appearFX)
	end

	-- 烟雾特效
	for _, smokeData in ipairs(monsterTmp.smoke) do
		local smokeFXs = smokeData[2]
		for _, fx in ipairs(smokeFXs) do
			resList[#resList + 1] = BattleResourceManager.GetFXPath(fx[1])
		end
	end

	-- 自定义死亡特效
	if spawnData.deadFX then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(spawnData.deadFX)
	end

	-- 潜艇气泡特效
	if type(monsterTmp.bubble_fx) == "table" then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(monsterTmp.bubble_fx[1])
	end

	--- 递归查询Buff是否需要技能立绘（painting）并加入资源清单
	--- @param buffID number Buff ID
	local function collectBuffSkillPainting(buffID)
		local buffTemplate = ys.Battle.BattleDataFunction.GetBuffTemplate(buffID, 1)

		for _, effectItem in pairs(buffTemplate.effect_list) do
			local skillId = effectItem.arg_list.skill_id

			if skillId then
				local painting = ys.Battle.BattleDataFunction.GetSkillTemplate(skillId).painting

				if painting == 1 then
					resList[#resList + 1] = BattleResourceManager.GetHrzIcon(monsterTmp.icon)
					resList[#resList + 1] = BattleResourceManager.GetSquareIcon(monsterTmp.icon)
				elseif type(painting) == "string" then
					resList[#resList + 1] = BattleResourceManager.GetHrzIcon(painting)
					resList[#resList + 1] = BattleResourceManager.GetSquareIcon(painting)
				end
			end

			-- 递归处理子Buff
			local subBuffId = effectItem.arg_list.buff_id
			if subBuffId then
				collectBuffSkillPainting(subBuffId)
			end
		end
	end

	-- 收集 buffList 中的技能立绘资源
	for _, buffId in ipairs(buffList) do
		collectBuffSkillPainting(buffId)
	end

	-- 收集 phase 中 addBuff 的技能立绘资源
	for _, phaseData in ipairs(phaseList) do
		if phaseData.addBuff then
			for _, buffId in ipairs(phaseData.addBuff) do
				collectBuffSkillPainting(buffId)
			end
		end
	end

	-- Boss额外需要方形头像
	if isBoss then
		resList[#resList + 1] = BattleResourceManager.GetSquareIcon(monsterTmp.icon)
	end

	return resList
end

--- 获取武器资源清单
--- 根据武器类型分别收集：子弹类武器（炮弹/鱼雷/防空炮/导弹等）的子弹资源、
--- 舰载机类武器的飞机资源、以及武器皮肤特效/轨道资源
--- @param weaponID number 武器ID
--- @param equipSkinID number|nil 装备皮肤ID
--- @return table 资源路径列表
function BattleResourceManager.GetWeaponResource(weaponID, equipSkinID)
	local resList = {}

	if weaponID == -1 then
		return resList
	end

	local weaponProperty = BattleDataFunction.GetWeaponPropertyDataFromID(weaponID)

	-- 根据武器类型收集子弹/飞机资源
	if weaponProperty.type == BattleConst.EquipmentType.MAIN_CANNON
		or weaponProperty.type == BattleConst.EquipmentType.SUB_CANNON
		or weaponProperty.type == BattleConst.EquipmentType.TORPEDO
		or weaponProperty.type == BattleConst.EquipmentType.ANTI_AIR
		or weaponProperty.type == BattleConst.EquipmentType.ANTI_SEA
		or weaponProperty.type == BattleConst.EquipmentType.POINT_HIT_AND_LOCK
		or weaponProperty.type == BattleConst.EquipmentType.MANUAL_METEOR
		or weaponProperty.type == BattleConst.EquipmentType.BOMBER_PRE_CAST_ALERT
		or weaponProperty.type == BattleConst.EquipmentType.DEPTH_CHARGE
		or weaponProperty.type == BattleConst.EquipmentType.MANUAL_TORPEDO
		or weaponProperty.type == BattleConst.EquipmentType.DISPOSABLE_TORPEDO
		or weaponProperty.type == BattleConst.EquipmentType.MANUAL_AAMISSILE
		or weaponProperty.type == BattleConst.EquipmentType.BEAM
		or weaponProperty.type == BattleConst.EquipmentType.SPACE_LASER
		or weaponProperty.type == BattleConst.EquipmentType.FLEET_RANGE_ANTI_AIR
		or weaponProperty.type == BattleConst.EquipmentType.MANUAL_MISSILE
		or weaponProperty.type == BattleConst.EquipmentType.AUTO_MISSILE
		or weaponProperty.type == BattleConst.EquipmentType.MISSILE then
		-- 子弹类武器
		for _, bulletID in ipairs(weaponProperty.bullet_ID) do
			local bulletRes = BattleResourceManager.GetBulletResource(bulletID, equipSkinID)
			for _, res in ipairs(bulletRes) do
				resList[#resList + 1] = res
			end
		end
	elseif weaponProperty.type == BattleConst.EquipmentType.INTERCEPT_AIRCRAFT
		or weaponProperty.type == BattleConst.EquipmentType.STRIKE_AIRCRAFT then
		-- 舰载机类武器
		resList = BattleResourceManager.GetAircraftResource(weaponID, nil, equipSkinID)
	elseif weaponProperty.type == BattleConst.EquipmentType.PREVIEW_ARICRAFT then
		-- 预览用飞机
		for _, aircraftID in ipairs(weaponProperty.bullet_ID) do
			resList = BattleResourceManager.GetAircraftResource(aircraftID, nil, equipSkinID)
		end
	end

	-- 舰队防空武器额外需要射程子弹资源
	if weaponProperty.type == BattleConst.EquipmentType.FLEET_RANGE_ANTI_AIR then
		local rangeBulletRes = BattleResourceManager.GetBulletResource(BattleConfig.AntiAirConfig.RangeBulletID)
		for _, res in ipairs(rangeBulletRes) do
			resList[#resList + 1] = res
		end
	end

	-- 装备皮肤（如果有）
	local equipSkinData
	if equipSkinID and equipSkinID ~= 0 then
		equipSkinData = ys.Battle.BattleDataFunction.GetEquipSkinDataFromID(equipSkinID)
	end

	-- 开火特效
	if equipSkinData and equipSkinData.fire_fx_name ~= "" then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(equipSkinData.fire_fx_name)
	else
		resList[#resList + 1] = BattleResourceManager.GetFXPath(weaponProperty.fire_fx)
	end

	-- 预施法特效
	if weaponProperty.precast_param.fx then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(weaponProperty.precast_param.fx)
	end

	-- 装备皮肤轨道
	if equipSkinData then
		local orbitCombat = equipSkinData.orbit_combat
		if orbitCombat ~= "" then
			resList[#resList + 1] = BattleResourceManager.GetOrbitPath(orbitCombat)
		end
	end

	return resList
end

--- 获取装备资源清单（通过武器列表 + 皮肤船体+轨道 + 技能Buff）
--- @param equipID number 装备ID
--- @param equipSkinID number 装备皮肤ID
--- @param battleType number 战斗类型
--- @return table 资源路径列表
function BattleResourceManager.GetEquipResource(equipID, equipSkinID, battleType)
	local resList = {}

	if equipSkinID ~= 0 then
		local equipSkinData = ys.Battle.BattleDataFunction.GetEquipSkinDataFromID(equipSkinID)
		local shipSkinId = equipSkinData.ship_skin_id

		-- 装备皮肤可能包含替换的船体模型
		if shipSkinId ~= 0 then
			local shipSkinData = ys.Battle.BattleDataFunction.GetPlayerShipSkinDataFromID(shipSkinId)
			resList[#resList + 1] = BattleResourceManager.GetCharacterPath(shipSkinData.prefab)
		end

		local orbitCombat = equipSkinData.orbit_combat
		if orbitCombat ~= "" then
			resList[#resList + 1] = BattleResourceManager.GetOrbitPath(orbitCombat)
		end
	end

	local weaponData = ys.Battle.BattleDataFunction.GetWeaponDataFromID(equipID)
	local weaponIds = weaponData.weapon_id

	for _, weaponId in ipairs(weaponIds) do
		local weaponRes = BattleResourceManager.GetWeaponResource(weaponId)
		for _, res in ipairs(weaponRes) do
			resList[#resList + 1] = res
		end
	end

	-- 装备自带技能的Buff资源
	local skillIds = weaponData.skill_id
	for _, skillInfo in ipairs(skillIds) do
		local skillId = battleType and ys.Battle.BattleDataFunction.SkillTranform(battleType, skillInfo[1]) or skillInfo[1]
		local skillLevel = skillInfo[2] or 1
		local buffRes = ys.Battle.BattleDataFunction.GetResFromBuff(skillId, skillLevel, {})
		for _, res in ipairs(buffRes) do
			resList[#resList + 1] = res
		end
	end

	return resList
end

--- 获取子弹资源清单
--- @param bulletID number 子弹模板ID
--- @param equipSkinID number|nil 装备皮肤ID
--- @return table 资源路径列表
function BattleResourceManager.GetBulletResource(bulletID, equipSkinID)
	local resList = {}
	local equipSkinData

	if equipSkinID ~= nil and equipSkinID ~= 0 then
		equipSkinData = BattleDataFunction.GetEquipSkinDataFromID(equipSkinID)
	end

	local bulletTemplate = BattleDataFunction.GetBulletTmpDataFromID(bulletID)
	local modelName

	-- 皮肤可能覆盖子弹模型
	if equipSkinData then
		modelName = equipSkinData.bullet_name

		if equipSkinData.mirror == 1 then
			resList[#resList + 1] = BattleResourceManager.GetBulletPath(modelName .. ys.Battle.BattleBulletUnit.MIRROR_RES)
		end
	else
		modelName = bulletTemplate.modle_ID
	end

	-- 光束/激光/导弹/电弧类型使用FX路径而非Item路径
	if bulletTemplate.type == BattleConst.BulletType.BEAM
		or bulletTemplate.type == BattleConst.BulletType.SPACE_LASER
		or bulletTemplate.type == BattleConst.BulletType.MISSILE
		or bulletTemplate.type == BattleConst.BulletType.ELECTRIC_ARC then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(bulletTemplate.modle_ID)
	else
		resList[#resList + 1] = BattleResourceManager.GetBulletPath(modelName)
	end

	if bulletTemplate.extra_param.mirror then
		resList[#resList + 1] = BattleResourceManager.GetBulletPath(modelName .. ys.Battle.BattleBulletUnit.MIRROR_RES)
	end

	-- 命中/未命中/警报特效
	local hitFXName
	if equipSkinData and equipSkinData.hit_fx_name ~= "" then
		hitFXName = equipSkinData.hit_fx_name
	else
		hitFXName = bulletTemplate.hit_fx
	end

	resList[#resList + 1] = BattleResourceManager.GetFXPath(hitFXName)
	resList[#resList + 1] = BattleResourceManager.GetFXPath(bulletTemplate.miss_fx)
	resList[#resList + 1] = BattleResourceManager.GetFXPath(bulletTemplate.alert_fx)

	-- 区域特效
	if bulletTemplate.extra_param.area_FX then
		resList[#resList + 1] = BattleResourceManager.GetFXPath(bulletTemplate.extra_param.area_FX)
	end

	-- 子母弹（shrapnel）的子弹资源
	if bulletTemplate.extra_param.shrapnel then
		for _, shrapnelData in ipairs(bulletTemplate.extra_param.shrapnel) do
			local shrapnelRes = BattleResourceManager.GetBulletResource(shrapnelData.bullet_ID)
			for _, res in ipairs(shrapnelRes) do
				resList[#resList + 1] = res
			end
		end
	end

	-- 附着Buff的资源和特效
	for _, attachBuff in ipairs(bulletTemplate.attach_buff) do
		if attachBuff.effect_id then
			resList[#resList + 1] = BattleResourceManager.GetFXPath(attachBuff.effect_id)
		end

		if attachBuff.buff_id then
			local buffRes = ys.Battle.BattleDataFunction.GetResFromBuff(attachBuff.buff_id, 1, {})
			for _, res in ipairs(buffRes) do
				resList[#resList + 1] = res
			end
		end
	end

	return resList
end

--- 获取飞机（舰载机）资源清单
--- @param aircraftID number 飞机模板ID
--- @param weaponID number|nil 飞机武器ID（覆盖模板默认武器）
--- @param equipSkinID number 装备皮肤ID
--- @param needIcon boolean 是否需要飞机图标
--- @return table 资源路径列表
function BattleResourceManager.GetAircraftResource(aircraftID, weaponID, equipSkinID, needIcon)
	local resList = {}

	equipSkinID = equipSkinID or 0

	local aircraftTemplate = BattleDataFunction.GetAircraftTmpDataFromID(aircraftID)
	local modelID
	local skinBullet1, skinBullet2, skinBullet3

	if equipSkinID ~= 0 then
		modelID, skinBullet1, skinBullet2, skinBullet3 = BattleDataFunction.GetEquipSkin(equipSkinID)

		-- 皮肤覆盖的子弹资源
		if skinBullet1 ~= "" then
			resList[#resList + 1] = BattleResourceManager.GetBulletPath(skinBullet1)
		end
		if skinBullet2 ~= "" then
			resList[#resList + 1] = BattleResourceManager.GetBulletPath(skinBullet2)
		end
		if skinBullet3 ~= "" then
			resList[#resList + 1] = BattleResourceManager.GetBulletPath(skinBullet3)
		end
	else
		modelID = aircraftTemplate.model_ID
	end

	-- 飞机模型
	resList[#resList + 1] = BattleResourceManager.GetCharacterGoPath(modelID)

	if needIcon then
		resList[#resList + 1] = BattleResourceManager.GetAircraftIconPath(aircraftTemplate.model_ID)
	end

	-- 飞机挂载武器资源
	local actualWeaponID = weaponID or aircraftTemplate.weapon_ID

	if type(actualWeaponID) == "table" then
		for _, wid in ipairs(actualWeaponID) do
			local weaponRes = BattleResourceManager.GetWeaponResource(wid)
			for _, res in ipairs(weaponRes) do
				resList[#resList + 1] = res
			end
		end
	else
		local weaponRes = BattleResourceManager.GetWeaponResource(actualWeaponID)
		for _, res in ipairs(weaponRes) do
			resList[#resList + 1] = res
		end
	end

	return resList
end

--- 获取指挥喵Buff资源清单
function BattleResourceManager.GetCommanderBuffRes(commanderBuffList)
	local resList = {}

	for _, commanderInfo in ipairs(commanderBuffList) do
		local cmdRes = BattleResourceManager.GetCommanderResource(commanderInfo)
		for _, res in ipairs(cmdRes) do
			table.insert(resList, res)
		end
	end

	return resList
end

--- 获取单个指挥喵的资源清单
--- @param commanderInfo table { commanderVO, buffIDList }
function BattleResourceManager.GetCommanderResource(commanderInfo)
	local resList = {}
	local commanderVO = commanderInfo[1]

	resList[#resList + 1] = BattleResourceManager.GetCommanderHrzIconPath(commanderVO:getPainting())
	resList[#resList + 1] = BattleResourceManager.GetCommanderIconPath(commanderVO:getPainting())

	local skillLevel = commanderVO:getSkills()[1]:getLevel()

	for _, buffID in ipairs(commanderInfo[2]) do
		local buffRes = ys.Battle.BattleDataFunction.GetResFromBuff(buffID, skillLevel, {})
		for _, res in ipairs(buffRes) do
			resList[#resList + 1] = res
		end
	end

	return resList
end

--- 从Buff ID列表批量获取资源
function BattleResourceManager.GetResFromBuffIDList(buffIDList)
	local resList = {}

	for _, buffID in ipairs(buffIDList) do
		local buffRes = BattleDataFunction.GetResFromBuff(buffID, 1, {})
		for _, res in ipairs(buffRes) do
			table.insert(resList, res)
		end
	end

	return resList
end

--- 从Buff列表（含id和level）批量获取资源
function BattleResourceManager.GetResFromBuffList(buffList)
	local resList = {}

	for _, buffInfo in ipairs(buffList) do
		local buffRes = BattleDataFunction.GetResFromBuff(buffInfo.id, buffInfo.level, {})
		for _, res in ipairs(buffRes) do
			table.insert(resList, res)
		end
	end

	return resList
end

--- 获取关卡资源清单（所有波次的敌人、支援舰队、环境效果、卡牌等）
--- @param dungeonID number 关卡ID
--- @return table resList 资源路径列表
--- @return table skinIDList 支援舰队皮肤ID列表
function BattleResourceManager.GetStageResource(dungeonID)
	local dungeonData = ys.Battle.BattleDataFunction.GetDungeonTmpDataByID(dungeonID)
	local resList = {}
	local skinIDList = {}

	for _, stage in ipairs(dungeonData.stages) do
		-- 关卡Buff资源
		if stage.stageBuff then
			for _, stageBuffItem in ipairs(stage.stageBuff) do
				local buffRes = ys.Battle.BattleDataFunction.GetResFromBuff(stageBuffItem.id, stageBuffItem.level, {})
				for _, res in ipairs(buffRes) do
					resList[#resList + 1] = res
				end
			end
		end

		for _, wave in ipairs(stage.waves) do
			if wave.triggerType == ys.Battle.BattleConst.WaveTriggerType.NORMAL then
				-- 普通波次：收集怪物资源
				for _, spawnData in ipairs(wave.spawn) do
					local monsterRes = BattleResourceManager.GetMonsterRes(spawnData)
					for _, res in ipairs(monsterRes) do
						table.insert(resList, res)
					end
				end

				-- 增援波次
				if wave.reinforcement then
					for _, reinforceData in ipairs(wave.reinforcement) do
						local monsterRes = BattleResourceManager.GetMonsterRes(reinforceData)
						for _, res in ipairs(monsterRes) do
							table.insert(resList, res)
						end
					end
				end
			elseif wave.triggerType == ys.Battle.BattleConst.WaveTriggerType.AID then
				-- 支援舰队波次：收集支援舰船资源
				local vanguardList = wave.triggerParams.vanguard_unitList
				local mainList = wave.triggerParams.main_unitList
				local subList = wave.triggerParams.sub_unitList

				local function collectAidUnitsRes(unitList)
					local aidRes = BattleResourceManager.GetAidUnitsRes(unitList)
					for _, res in ipairs(aidRes) do
						table.insert(resList, res)
					end

					for _, unitData in ipairs(unitList) do
						skinIDList[#skinIDList + 1] = unitData.skinId
					end
				end

				if vanguardList then
					collectAidUnitsRes(vanguardList)
				end
				if mainList then
					collectAidUnitsRes(mainList)
				end
				if subList then
					collectAidUnitsRes(subList)
				end
			elseif wave.triggerType == ys.Battle.BattleConst.WaveTriggerType.ENVIRONMENT then
				-- 环境效果波次
				for _, envData in ipairs(wave.spawn) do
					BattleResourceManager.GetEnvironmentRes(resList, envData)
				end
			elseif wave.triggerType == ys.Battle.BattleConst.WaveTriggerType.CARD_PUZZLE then
				-- 卡牌塔罗波次
				local cardRes = ys.Battle.BattleDataFunction.GetCardRes(wave.triggerParams.card_id)
				for _, res in ipairs(cardRes) do
					table.insert(resList, res)
				end
			end

			-- 敌方飞机支援
			if wave.airFighter ~= nil then
				for _, airFighterData in pairs(wave.airFighter) do
					local aircraftRes = BattleResourceManager.GetAircraftResource(airFighterData.templateID, airFighterData.weaponID, nil, true)
					for _, res in ipairs(aircraftRes) do
						resList[#resList + 1] = res
					end
				end
			end
		end
	end

	return resList, skinIDList
end

function var_0_5.GetStageBGM(arg_86_0)
	local var_86_0 = var_0_0.Battle.BattleDataFunction.GetDungeonTmpDataByID(arg_86_0)
	local var_86_1 = {}

	for iter_86_0, iter_86_1 in ipairs(var_86_0.stages) do
		for iter_86_2, iter_86_3 in ipairs(iter_86_1.waves) do
			if iter_86_3.triggerType == var_0_0.Battle.BattleConst.WaveTriggerType.BGM then
				local var_86_2 = iter_86_3.triggerParams.bgm

				if var_86_2 then
					table.insert(var_86_1, "cue/bgm-" .. var_86_2 .. ".b")
				end
			end
		end
	end

	return var_86_1
end

function var_0_5.GetEnvironmentRes(arg_87_0, arg_87_1)
	table.insert(arg_87_0, arg_87_1.prefab and var_0_5.GetFXPath(arg_87_1.prefab))

	local var_87_0 = arg_87_1.behaviours
	local var_87_1 = var_0_0.Battle.BattleDataFunction.GetEnvironmentBehaviour(var_87_0).behaviour_list

	for iter_87_0, iter_87_1 in ipairs(var_87_1) do
		local var_87_2 = iter_87_1.type

		if var_87_2 == var_0_0.Battle.BattleConst.EnviroumentBehaviour.BUFF then
			local var_87_3 = var_0_0.Battle.BattleDataFunction.GetResFromBuff(iter_87_1.buff_id, 1, {})

			for iter_87_2, iter_87_3 in ipairs(var_87_3) do
				arg_87_0[#arg_87_0 + 1] = iter_87_3
			end
		elseif var_87_2 == var_0_0.Battle.BattleConst.EnviroumentBehaviour.SPAWN then
			local var_87_4 = iter_87_1.content and iter_87_1.content.alert and iter_87_1.content.alert.alert_fx

			table.insert(arg_87_0, var_87_4 and var_0_5.GetFXPath(var_87_4))

			local var_87_5 = iter_87_1.content and iter_87_1.content.child_prefab

			if var_87_5 then
				var_0_5.GetEnvironmentRes(arg_87_0, var_87_5)
			end
		elseif var_87_2 == var_0_0.Battle.BattleConst.EnviroumentBehaviour.PLAY_FX then
			arg_87_0[#arg_87_0 + 1] = var_0_5.GetFXPath(iter_87_1.FX_ID)
		end
	end
end

function var_0_5.GetMonsterRes(arg_88_0)
	local var_88_0 = {}
	local var_88_1 = var_0_5.GetEnemyResource(arg_88_0)

	for iter_88_0, iter_88_1 in ipairs(var_88_1) do
		var_88_0[#var_88_0 + 1] = iter_88_1
	end

	local var_88_2 = var_0_0.Battle.BattleDataFunction.GetMonsterTmpDataFromID(arg_88_0.monsterTemplateID)
	local var_88_3 = Clone(var_88_2.equipment_list)
	local var_88_4 = var_88_2.buff_list
	local var_88_5 = Clone(arg_88_0.buffList) or {}

	if arg_88_0.phase then
		for iter_88_2, iter_88_3 in ipairs(arg_88_0.phase) do
			if iter_88_3.addWeapon then
				for iter_88_4, iter_88_5 in ipairs(iter_88_3.addWeapon) do
					var_88_3[#var_88_3 + 1] = iter_88_5
				end
			end

			if iter_88_3.addRandomWeapon then
				for iter_88_6, iter_88_7 in ipairs(iter_88_3.addRandomWeapon) do
					for iter_88_8, iter_88_9 in ipairs(iter_88_7) do
						var_88_3[#var_88_3 + 1] = iter_88_9
					end
				end
			end

			if iter_88_3.addBuff then
				for iter_88_10, iter_88_11 in ipairs(iter_88_3.addBuff) do
					var_88_5[#var_88_5 + 1] = iter_88_11
				end
			end
		end
	end

	for iter_88_12, iter_88_13 in ipairs(var_88_4) do
		local var_88_6 = var_0_0.Battle.BattleDataFunction.GetResFromBuff(iter_88_13.ID, iter_88_13.LV, {})

		for iter_88_14, iter_88_15 in ipairs(var_88_6) do
			var_88_0[#var_88_0 + 1] = iter_88_15
		end
	end

	for iter_88_16, iter_88_17 in ipairs(var_88_5) do
		local var_88_7 = var_0_0.Battle.BattleDataFunction.GetResFromBuff(iter_88_17, 1, {})

		for iter_88_18, iter_88_19 in ipairs(var_88_7) do
			var_88_0[#var_88_0 + 1] = iter_88_19
		end

		local var_88_8 = var_0_0.Battle.BattleDataFunction.GetBuffTemplate(iter_88_17, 1)

		for iter_88_20, iter_88_21 in pairs(var_88_8.effect_list) do
			local var_88_9 = iter_88_21.arg_list.skill_id

			if var_88_9 and var_0_0.Battle.BattleDataFunction.NeedSkillPainting(var_88_9) then
				var_88_0[#var_88_0 + 1] = var_0_5.GetPaintingPath(var_0_1.GetMonsterTmpDataFromID(arg_88_0.monsterTemplateID).icon)

				break
			end
		end
	end

	for iter_88_22, iter_88_23 in ipairs(var_88_3) do
		local var_88_10 = var_0_5.GetWeaponResource(iter_88_23)

		for iter_88_24, iter_88_25 in ipairs(var_88_10) do
			var_88_0[#var_88_0 + 1] = iter_88_25
		end
	end

	return var_88_0
end

function var_0_5.GetEquipSkinPreviewRes(arg_89_0)
	local var_89_0 = {}
	local var_89_1 = var_0_1.GetEquipSkinDataFromID(arg_89_0)

	for iter_89_0, iter_89_1 in ipairs(var_89_1.weapon_ids) do
		local var_89_2 = var_0_5.GetWeaponResource(iter_89_1)

		for iter_89_2, iter_89_3 in ipairs(var_89_2) do
			var_89_0[#var_89_0 + 1] = iter_89_3
		end
	end

	local function var_89_3(arg_90_0)
		if arg_90_0 ~= "" then
			var_89_0[#var_89_0 + 1] = var_0_5.GetBulletPath(arg_90_0)
		end
	end

	local var_89_4, var_89_5, var_89_6, var_89_7, var_89_8, var_89_9 = var_0_1.GetEquipSkin(arg_89_0)

	if _.any(EquipType.AirProtoEquipTypes, function(arg_91_0)
		return table.contains(var_89_1.equip_type, arg_91_0)
	end) then
		var_89_0[#var_89_0 + 1] = var_0_5.GetCharacterGoPath(var_89_4)
	else
		var_89_0[#var_89_0 + 1] = var_0_5.GetBulletPath(var_89_4)
	end

	var_89_3(var_89_5)
	var_89_3(var_89_6)
	var_89_3(var_89_7)

	if var_89_8 and var_89_8 ~= "" then
		var_89_0[#var_89_0 + 1] = var_0_5.GetFXPath(var_89_8)
	end

	if var_89_9 and var_89_9 ~= "" then
		var_89_0[#var_89_0 + 1] = var_0_5.GetFXPath(var_89_9)
	end

	return var_89_0
end

function var_0_5.GetEquipSkinBulletRes(arg_92_0)
	local var_92_0 = {}
	local var_92_1, var_92_2, var_92_3, var_92_4 = var_0_1.GetEquipSkin(arg_92_0)

	local function var_92_5(arg_93_0)
		if arg_93_0 ~= "" then
			var_92_0[#var_92_0 + 1] = var_0_5.GetBulletPath(arg_93_0)
		end
	end

	local var_92_6 = var_0_1.GetEquipSkinDataFromID(arg_92_0)
	local var_92_7 = false

	for iter_92_0, iter_92_1 in ipairs(var_92_6.equip_type) do
		if table.contains(EquipType.AircraftSkinType, iter_92_1) then
			var_92_7 = true
		end
	end

	if var_92_7 then
		if var_92_1 ~= "" then
			var_92_0[#var_92_0 + 1] = var_0_5.GetCharacterGoPath(var_92_1)
		end
	else
		var_92_5(var_92_1)

		if var_0_1.GetEquipSkinDataFromID(arg_92_0).mirror == 1 then
			var_92_0[#var_92_0 + 1] = var_0_5.GetBulletPath(var_92_1 .. var_0_0.Battle.BattleBulletUnit.MIRROR_RES)
		end
	end

	var_92_5(var_92_2)
	var_92_5(var_92_3)
	var_92_5(var_92_4)

	return var_92_0
end

function var_0_5.GetAidUnitsRes(arg_94_0)
	local var_94_0 = {}

	for iter_94_0, iter_94_1 in ipairs(arg_94_0) do
		local var_94_1 = var_0_5.GetShipResource(iter_94_1.tmpID, nil, true)

		for iter_94_2, iter_94_3 in ipairs(iter_94_1.equipment) do
			if iter_94_3 ~= 0 then
				if iter_94_2 <= Ship.WEAPON_COUNT then
					local var_94_2 = var_0_1.GetWeaponDataFromID(iter_94_3).weapon_id

					for iter_94_4, iter_94_5 in ipairs(var_94_2) do
						local var_94_3 = var_0_5.GetWeaponResource(iter_94_5)

						for iter_94_6, iter_94_7 in ipairs(var_94_3) do
							table.insert(var_94_1, iter_94_7)
						end
					end
				else
					local var_94_4 = var_0_5.GetEquipResource(iter_94_3)

					for iter_94_8, iter_94_9 in ipairs(var_94_4) do
						table.insert(var_94_1, iter_94_9)
					end
				end
			end
		end

		for iter_94_10, iter_94_11 in ipairs(var_94_1) do
			table.insert(var_94_0, iter_94_11)
		end
	end

	return var_94_0
end

function var_0_5.GetSpWeaponResource(arg_95_0, arg_95_1)
	local var_95_0 = {}
	local var_95_1 = var_0_0.Battle.BattleDataFunction.GetSpWeaponDataFromID(arg_95_0).effect_id

	if var_95_1 ~= 0 then
		var_95_1 = arg_95_1 and var_0_0.Battle.BattleDataFunction.SkillTranform(arg_95_1, var_95_1) or var_95_1

		local var_95_2 = var_0_0.Battle.BattleDataFunction.GetResFromBuff(var_95_1, 1, {})

		for iter_95_0, iter_95_1 in ipairs(var_95_2) do
			var_95_0[#var_95_0 + 1] = iter_95_1
		end
	end

	return var_95_0
end
