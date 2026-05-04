ys = ys or {}

local ys = ys
local BattleConst = ys.Battle.BattleConst
local BattlePopNumManager = singletonClass("BattlePopNumManager")

ys.Battle.BattlePopNumManager = BattlePopNumManager
BattlePopNumManager.__name = "BattlePopNumManager"

-- ============================================================
-- 伤害数字类型常量
-- ============================================================
--- 角色HP文字容器名称
BattlePopNumManager.CONTAINER_CHARACTER_HP = "HPTextCharacterContainer"
--- 分数弹出
BattlePopNumManager.POP_SCORE = "score"
--- 未命中
BattlePopNumManager.POP_MISS = "miss"
--- 治疗
BattlePopNumManager.POP_HEAL = "heal"
--- 常规伤害（非特殊类型）
BattlePopNumManager.POP_COMMON = "common"
--- 不可破坏护盾伤害
BattlePopNumManager.POP_UNBREAK = "unbreak"
--- 普通装甲伤害
BattlePopNumManager.POP_NORMAL = "normal"
--- 易爆装甲伤害
BattlePopNumManager.POP_EXPLO = "explo"
--- 穿甲伤害
BattlePopNumManager.POP_PIERCE = "pierce"
--- 暴击-普通装甲
BattlePopNumManager.POP_CT_NORMAL = "critical_normal"
--- 暴击-易爆装甲
BattlePopNumManager.POP_CT_EXPLO = "critical_explo"
--- 暴击-穿甲
BattlePopNumManager.POP_CT_PIERCE = "critical_pierce"

--- 常规字体索引（非暴击）: normal, pierce, explo, unbreak
BattlePopNumManager.FontIndex = {
	BattlePopNumManager.POP_NORMAL,
	BattlePopNumManager.POP_PIERCE,
	BattlePopNumManager.POP_EXPLO,
	BattlePopNumManager.POP_UNBREAK
}
--- 暴击字体索引: critical_normal, critical_pierce, critical_explo, unbreak
BattlePopNumManager.CTFontIndex = {
	BattlePopNumManager.POP_CT_NORMAL,
	BattlePopNumManager.POP_CT_PIERCE,
	BattlePopNumManager.POP_CT_EXPLO,
	BattlePopNumManager.POP_UNBREAK
}
--- 空军单位类型（使用SLIM弹窗样式）
BattlePopNumManager.AIR_UNIT_TYPE = {
	BattleConst.UnitType.AIRCRAFT_UNIT,
	BattleConst.UnitType.AIRFIGHTER_UNIT,
	BattleConst.UnitType.FUNNEL_UNIT,
	BattleConst.UnitType.UAV_UNIT
}

--- @class BattlePopNumManager : singletonClass
--- 构造函数（singleton，空实现）
function BattlePopNumManager.Ctor(self)
	return
end

--- 初始化：创建bundle池和活跃列表，保存弹窗皮肤
--- @param popSkin Transform 弹窗皮肤模板（不同活动可能有不同皮肤）
function BattlePopNumManager.Init(self, popSkin)
	self._allBundlePool = {}
	self._activeList = {}
	self._popSkin = popSkin
end

--- 获取当前弹窗皮肤Transform
--- @return Transform
function BattlePopNumManager.GetPopSkin(self)
	return self._popSkin
end

--- 为角色HP弹窗创建PRO和SLIM两种bundle对象池
--- @param containerTpl Transform 容器模板
function BattlePopNumManager.InitialBundlePool(self, containerTpl)
	self._allBundlePool[ys.Battle.BattlePopNumBundle.PRO] = pg.LuaObPool.New(ys.Battle.BattlePopNumBundle, {
		containerTpl = containerTpl,
		type = ys.Battle.BattlePopNumBundle.PRO
	}, 6)
	self._allBundlePool[ys.Battle.BattlePopNumBundle.SLIM] = pg.LuaObPool.New(ys.Battle.BattlePopNumBundle, {
		containerTpl = containerTpl,
		type = ys.Battle.BattlePopNumBundle.SLIM
	}, 4)
end

--- 为分数弹窗创建对象池
--- @param containerTpl Transform 容器模板
function BattlePopNumManager.InitialScorePool(self, containerTpl)
	self._allBundlePool[ys.Battle.BattlePopNumBundle.PRO] = pg.LuaObPool.New(ys.Battle.BattlePopNumBundle, {
		score = true,
		containerTpl = containerTpl,
		type = ys.Battle.BattlePopNumBundle.PRO
	}, 1)
	self._allBundlePool[ys.Battle.BattlePopNumBundle.SLIM] = pg.LuaObPool.New(ys.Battle.BattlePopNumBundle, {
		score = true,
		containerTpl = containerTpl,
		type = ys.Battle.BattlePopNumBundle.SLIM
	}, 2)
end

--- 清空所有bundle池和活跃列表
function BattlePopNumManager.Clear(self)
	for _, bundlePool in pairs(self._allBundlePool) do
		bundlePool:Dispose()
	end

	self._popSkin = nil
	self._activeList = {}
end

--- 获取一个bundle对象（根据unitType自动选择PRO或SLIM）
--- @param unitType number 单位类型
--- @return BattlePopNumBundle
function BattlePopNumManager.GetBundle(self, unitType)
	local bundleType = BattlePopNumManager.getBundleType(unitType)

	return (self._allBundlePool[bundleType]:GetObject())
end

--- 静态方法：根据isHeal/isCri/isMiss/font判定弹出文字类型和缩放
--- @param isHeal boolean 是否为治疗
--- @param isCri boolean 是否为暴击
--- @param isMiss boolean 是否未命中
--- @param font table {armorTypeIndex, scale} 来自武器/子弹的字体配置
--- @return string popType 弹窗类型（POP_HEAL/POP_MISS/etc）
--- @return number scale 缩放倍率
function BattlePopNumManager.getType(isHeal, isCri, isMiss, font)
	local scale = 1
	local popType

	if isHeal and not isMiss then
		-- 治疗
		popType = BattlePopNumManager.POP_HEAL
	elseif isMiss then
		-- 未命中
		popType = BattlePopNumManager.POP_MISS
	elseif font then
		-- 有字体配置：按装甲类型和暴击状态选择
		local armorTypeIndex = font[1]
		local fontScale = font[2]

		if isCri then
			popType = BattlePopNumManager.CTFontIndex[armorTypeIndex]
		else
			popType = BattlePopNumManager.FontIndex[armorTypeIndex]
		end

		scale = font[2]
	elseif isCri then
		-- 暴击但无特定装甲类型配置
		popType = BattlePopNumManager.POP_CT_EXPLO
	else
		-- 默认常规伤害
		popType = BattlePopNumManager.POP_COMMON
	end

	return popType, scale
end

--- 根据单位类型判断使用PRO还是SLIM样式的bundle
--- 空军单位使用SLIM（小号），其他用PRO（大号）
--- @param unitType number 单位类型
--- @return number bundleType
function BattlePopNumManager.getBundleType(unitType)
	local bundleType

	if table.contains(BattlePopNumManager.AIR_UNIT_TYPE, unitType) then
		bundleType = ys.Battle.BattlePopNumBundle.SLIM
	else
		bundleType = ys.Battle.BattlePopNumBundle.PRO
	end

	return bundleType
end

--- 生成一个临时BattlePopNum对象池
--- @param popType string 弹窗类型（对应模板子节点名）
--- @param parentTF Transform 父节点
--- @param popSkin Transform 弹窗皮肤
--- @param preloadCount number 预加载数量
--- @return LuaObPool
function BattlePopNumManager.generateTempPool(self, popType, parentTF, popSkin, preloadCount)
	return pg.LuaObPool.New(ys.Battle.BattlePopNum, {
		template = popSkin.transform:Find(popType).gameObject,
		parentTF = parentTF,
		mgr = self
	}, preloadCount)
end

--- 重置pop的父节点（用于UI切换时重新挂载）
--- @param bundle BattlePopNumBundle
--- @param newParentTF Transform 新的父节点
function BattlePopNumManager.resetPopParent(self, bundle, newParentTF)
	bundle:UpdateInfo("parentTF", newParentTF)

	for _, popNum in ipairs(bundle.list) do
		popNum:SetParent(newParentTF)
	end
end
