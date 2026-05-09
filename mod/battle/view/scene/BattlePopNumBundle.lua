ys = ys or {}

local ys = ys
local BattleUnitEvent = ys.Battle.BattleUnitEvent
local BattleConst = ys.Battle.BattleConst
local BattlePopNumManager = ys.Battle.BattlePopNumManager

ys.Battle.BattlePopNumBundle = class("BattlePopNumBundle")
ys.Battle.BattlePopNumBundle.__name = "BattlePopNumBundle"

local BattlePopNumBundle = ys.Battle.BattlePopNumBundle

BattlePopNumBundle.PRO = 0
BattlePopNumBundle.SLIM = 1

--- @class BattlePopNumBundle
--- @param pool pg.LuaObPool 所属对象池
--- @param cfg table { containerTpl, type, score }
function BattlePopNumBundle.Ctor(self, pool, cfg)
	self.pool = pool
	self._container = cloneTplTo(cfg.containerTpl, cfg.containerTpl.parent)
	self._bundleType = cfg.type
	self._score = cfg.score

	self:init()
end

--- 初始化分数弹出模板池
--- @param skinGO GameObject 弹出分数皮肤模板
function BattlePopNumBundle.InitPopScore(self, skinGO)
	self._allPool[BattlePopNumManager.POP_SCORE] = self:generateTempPool(BattlePopNumManager.POP_SCORE, self._container, skinGO, 1)
end

--- 获取容器Transform
function BattlePopNumBundle.GetContainer(self)
	return self._container
end

--- 初始化所有弹出数字的模板池
function BattlePopNumBundle.init(self)
	self._allPool = {}

	local popSkin = BattlePopNumManager.GetInstance():GetPopSkin()

	if self._score then
		self._allPool[BattlePopNumManager.POP_SCORE] = self:generateTempPool(BattlePopNumManager.POP_SCORE, self._container, popSkin, 1)
	else
		self._allPool[BattlePopNumManager.POP_COMMON] = self:generateTempPool(BattlePopNumManager.POP_COMMON, self._container, popSkin, 1)
		self._allPool[BattlePopNumManager.POP_CT_EXPLO] = self:generateTempPool(BattlePopNumManager.POP_CT_EXPLO, self._container, popSkin, 0)
		self._allPool[BattlePopNumManager.POP_MISS] = self:generateTempPool(BattlePopNumManager.POP_MISS, self._container, popSkin, 0)
		self._allPool[BattlePopNumManager.POP_NORMAL] = self:generateTempPool(BattlePopNumManager.POP_NORMAL, self._container, popSkin, 0)
		self._allPool[BattlePopNumManager.POP_CT_NORMAL] = self:generateTempPool(BattlePopNumManager.POP_CT_NORMAL, self._container, popSkin, 0)

		if self._bundleType == BattlePopNumBundle.PRO then
			self._allPool[BattlePopNumManager.POP_UNBREAK] = self:generateTempPool(BattlePopNumManager.POP_UNBREAK, self._container, popSkin, 1)
			self._allPool[BattlePopNumManager.POP_HEAL] = self:generateTempPool(BattlePopNumManager.POP_HEAL, self._container, popSkin, 1)
			self._allPool[BattlePopNumManager.POP_EXPLO] = self:generateTempPool(BattlePopNumManager.POP_EXPLO, self._container, popSkin, 0)
			self._allPool[BattlePopNumManager.POP_PIERCE] = self:generateTempPool(BattlePopNumManager.POP_PIERCE, self._container, popSkin, 0)
			self._allPool[BattlePopNumManager.POP_CT_PIERCE] = self:generateTempPool(BattlePopNumManager.POP_CT_PIERCE, self._container, popSkin, 0)
		end
	end
end

--- 清除并回收到池
function BattlePopNumBundle.Clear(self)
	self.pool:Recycle(self)
end

--- 获取弹出数字对象
--- @param numType number 数字类型（伤害/暴击/治疗等）
--- @param isCritical boolean 是否暴击
--- @param isCld boolean 是否CLD
--- @param text string 要显示的文本
--- @param shieldWall boolean 是否盾墙
function BattlePopNumBundle.GetPop(self, numType, isCritical, isCld, text, shieldWall)
	local popType, scaleType = BattlePopNumManager.getType(numType, isCritical, isCld, shieldWall)
	local popNum = self._allPool[popType]:GetObject()

	-- MISS类型不设置文本
	if popType ~= BattlePopNumManager.POP_MISS then
		popNum:SetText(text)
	end

	popNum:SetScale(scaleType)

	return popNum
end

--- 获取分数弹出数字
--- @param scoreText string 分数文本
function BattlePopNumBundle.GetScorePop(self, scoreText)
	local popNum = self._allPool[BattlePopNumManager.POP_SCORE]:GetObject()

	popNum:SetText(scoreText)

	return popNum
end

--- 生成临时Lua对象池
--- @param poolKey string 池键名（如 "POP_NORMAL"）
--- @param parentTF Transform 父Transform
--- @param popSkin GameObject 弹出数字皮肤
--- @param initSize number 初始池大小
function BattlePopNumBundle.generateTempPool(self, poolKey, parentTF, popSkin, initSize)
	return pg.LuaObPool.New(ys.Battle.BattlePopNum, {
		template = popSkin.transform:Find(poolKey).gameObject,
		parentTF = parentTF,
		mgr = self
	}, initSize)
end

function BattlePopNumBundle.Init(self)
	return
end

function BattlePopNumBundle.Recycle(self)
	return
end

--- 是否分数弹出bundle
function BattlePopNumBundle.IsScorePop(self)
	return self._score
end

--- 销毁并清理所有子池
function BattlePopNumBundle.Dispose(self)
	for _, pool in pairs(self._allPool) do
		pool:Dispose()
	end

	self._allPool = nil

	Object.Destroy(self._container.gameObject)

	self._container = nil
end
