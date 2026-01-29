ys = ys or {}

local ys = ys
local BattleSpecialWeapon = class("BattleSpecialWeapon", ys.Battle.BattleWeaponUnit)

ys.Battle.BattleSpecialWeapon = BattleSpecialWeapon
BattleSpecialWeapon.__name = "BattleSpecialWeapon"

function BattleSpecialWeapon.Ctor(self)
	BattleSpecialWeapon.super.Ctor(self)
end

function BattleSpecialWeapon.CheckPreCast(self)
	-- 这个方法在BattleDataProxy中已经删除了
	--- @type SeqCenter
	local seqCenter = self._dataProxy:GetSeqCenter()
	local bulletID = self._tmpData.bullet_ID[1]

	if not bulletID then
		self._castInfo = {
			weapon = self
		}

		return true
	end

	local precastSeq = seqCenter:NewSeq("precast")
	local node = ys.Battle.NodeData.New(self._host, {
		weapon = self
	}, precastSeq)

	pg.NodeMgr.GetInstance():GenNode(node, pg.BattleNodesCfg[bulletID], precastSeq)

	local nodeData = node:GetData()

	if nodeData.targets[1] == nil then
		return false
	end

	self._castInfo = nodeData

	return true
end

function BattleSpecialWeapon.Fire(self)
	assert(self._castInfo ~= nil, "需要指定施法信息，有特殊需求可默认指定为{ weapon = self }")

	local seqCenter = self._dataProxy:GetSeqCenter()
	local bulletID = self._tmpData.bullet_ID[1]
	local castInfo = self._castInfo
	local castSeq = seqCenter:NewSeq("cast")
	local node = ys.Battle.NodeData.New(self._host, castInfo, castSeq)

	pg.NodeMgr.GetInstance():GenNode(node, pg.BattleNodesCfg[self._tmpData.barrage_ID[1]], castSeq)
	self._host:SetCurNodeList(node:GetAllSeq())

	self._currentState = self.STATE_ATTACK
	self._castInfo = nil

	self:CheckAndShake()
	castSeq:Add(ys.Battle.CallbackNode.New(function()
		self:EnterCoolDown()
	end))

	return true
end
