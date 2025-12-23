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

function BattlePopNumBundle.Ctor(arg_1_0, arg_1_1, arg_1_2)
	arg_1_0.pool = arg_1_1
	arg_1_0._container = cloneTplTo(arg_1_2.containerTpl, arg_1_2.containerTpl.parent)
	arg_1_0._bundleType = arg_1_2.type
	arg_1_0._score = arg_1_2.score

	arg_1_0:init()
end

function BattlePopNumBundle.InitPopScore(arg_2_0, arg_2_1)
	arg_2_0._allPool[BattlePopNumManager.POP_SCORE] = arg_2_0:generateTempPool(BattlePopNumManager.POP_SCORE, arg_2_0._container, arg_2_1, 1)
end

function BattlePopNumBundle.GetContainer(arg_3_0)
	return arg_3_0._container
end

function BattlePopNumBundle.init(arg_4_0)
	arg_4_0._allPool = {}

	local var_4_0 = BattlePopNumManager.GetInstance():GetPopSkin()

	if arg_4_0._score then
		arg_4_0._allPool[BattlePopNumManager.POP_SCORE] = arg_4_0:generateTempPool(BattlePopNumManager.POP_SCORE, arg_4_0._container, var_4_0, 1)
	else
		arg_4_0._allPool[BattlePopNumManager.POP_COMMON] = arg_4_0:generateTempPool(BattlePopNumManager.POP_COMMON, arg_4_0._container, var_4_0, 1)
		arg_4_0._allPool[BattlePopNumManager.POP_CT_EXPLO] = arg_4_0:generateTempPool(BattlePopNumManager.POP_CT_EXPLO, arg_4_0._container, var_4_0, 0)
		arg_4_0._allPool[BattlePopNumManager.POP_MISS] = arg_4_0:generateTempPool(BattlePopNumManager.POP_MISS, arg_4_0._container, var_4_0, 0)
		arg_4_0._allPool[BattlePopNumManager.POP_NORMAL] = arg_4_0:generateTempPool(BattlePopNumManager.POP_NORMAL, arg_4_0._container, var_4_0, 0)
		arg_4_0._allPool[BattlePopNumManager.POP_CT_NORMAL] = arg_4_0:generateTempPool(BattlePopNumManager.POP_CT_NORMAL, arg_4_0._container, var_4_0, 0)

		if arg_4_0._bundleType == BattlePopNumBundle.PRO then
			arg_4_0._allPool[BattlePopNumManager.POP_UNBREAK] = arg_4_0:generateTempPool(BattlePopNumManager.POP_UNBREAK, arg_4_0._container, var_4_0, 1)
			arg_4_0._allPool[BattlePopNumManager.POP_HEAL] = arg_4_0:generateTempPool(BattlePopNumManager.POP_HEAL, arg_4_0._container, var_4_0, 1)
			arg_4_0._allPool[BattlePopNumManager.POP_EXPLO] = arg_4_0:generateTempPool(BattlePopNumManager.POP_EXPLO, arg_4_0._container, var_4_0, 0)
			arg_4_0._allPool[BattlePopNumManager.POP_PIERCE] = arg_4_0:generateTempPool(BattlePopNumManager.POP_PIERCE, arg_4_0._container, var_4_0, 0)
			arg_4_0._allPool[BattlePopNumManager.POP_CT_PIERCE] = arg_4_0:generateTempPool(BattlePopNumManager.POP_CT_PIERCE, arg_4_0._container, var_4_0, 0)
		end
	end
end

function BattlePopNumBundle.Clear(arg_5_0)
	arg_5_0.pool:Recycle(arg_5_0)
end
-- TODO
function BattlePopNumBundle.GetPop(self, isHeal, isCri, isMiss, dHP, font)
	local var_6_0, var_6_1 = BattlePopNumManager.getType(isHeal, isCri, isMiss, font)
	local var_6_2 = self._allPool[var_6_0]:GetObject()

	if var_6_0 ~= BattlePopNumManager.POP_MISS then
		var_6_2:SetText(dHP)
	end

	var_6_2:SetScale(var_6_1)

	return var_6_2
end

function BattlePopNumBundle.GetScorePop(arg_7_0, arg_7_1)
	local var_7_0 = arg_7_0._allPool[BattlePopNumManager.POP_SCORE]:GetObject()

	var_7_0:SetText(arg_7_1)

	return var_7_0
end

function BattlePopNumBundle.generateTempPool(arg_8_0, arg_8_1, arg_8_2, arg_8_3, arg_8_4)
	return pg.LuaObPool.New(ys.Battle.BattlePopNum, {
		template = arg_8_3.transform:Find(arg_8_1).gameObject,
		parentTF = arg_8_2,
		mgr = arg_8_0
	}, arg_8_4)
end

function BattlePopNumBundle.Init(arg_9_0)
	return
end

function BattlePopNumBundle.Recycle(arg_10_0)
	return
end

function BattlePopNumBundle.IsScorePop(arg_11_0)
	return arg_11_0._score
end

function BattlePopNumBundle.Dispose(arg_12_0)
	for iter_12_0, iter_12_1 in pairs(arg_12_0._allPool) do
		iter_12_1:Dispose()
	end

	arg_12_0._allPool = nil

	Object.Destroy(arg_12_0._container.gameObject)

	arg_12_0._container = nil
end
