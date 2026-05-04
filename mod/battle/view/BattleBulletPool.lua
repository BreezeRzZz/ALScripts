ys = ys or {}

local ys = ys

--- @class BattleBulletPool
--- @classdesc 子弹资源对象池，负责子弹GameObject资源的异步加载与缓存。
--- 与 BattleResourceManager 不同，这个池直接缓存加载好的原始资源（不经过 pg.Pool），
--- 避免重复异步加载同一份子弹 prefab。
--- @field _bulletResCache table<string, UnityEngine.Object> 已加载子弹资源的缓存，key为资源名（不含Item/前缀）
local BattleBulletPool = singletonClass("BattleBulletPool")

ys.Battle.BattleBulletPool = BattleBulletPool
BattleBulletPool.__name = "BattleBulletPool"

function BattleBulletPool.Ctor(self)
	return
end

--- 初始化子弹资源缓存
function BattleBulletPool.Init(self)
	self._bulletResCache = {}
end

--- 实例化子弹资源——优先从缓存获取，缓存未命中则异步加载并缓存
--- @param bulletName string 子弹资源名（不含 "Item/" 路径前缀，如 "10020"）
--- @param callback function 加载完成后的回调，参数为加载好的 UnityEngine.Object
--- 异步加载时回调在资源加载完成后触发；缓存命中时间步触发
function BattleBulletPool.InstantiateBullet(self, bulletName, callback)
	if self._bulletResCache[bulletName] ~= nil then
		-- 缓存命中：直接同步回调
		callback(self._bulletResCache[bulletName])
	else
		-- 缓存未命中：异步加载资源，完成后缓存并回调
		ResourceMgr.Inst:getAssetAsync("Item/" .. bulletName, "", UnityEngine.Events.UnityAction_UnityEngine_Object(function(asset)
			assert(asset, "子弹资源加载失败：" .. bulletName)
			callback(asset)

			-- 加载完成后缓存起来，后续实例化直接使用
			self._bulletResCache[bulletName] = asset
		end), true, true)
	end
end

--- 清理所有子弹资源缓存（战斗结束时调用）
function BattleBulletPool.Clear(self)
	self._bulletResCache = nil
end
