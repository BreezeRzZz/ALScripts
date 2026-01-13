ys = ys or {}

local ys = ys

ys.Battle.BattleRangeWave = class("BattleRangeWave", ys.Battle.BattleWaveInfo)
ys.Battle.BattleRangeWave.__name = "BattleRangeWave"

local BattleRangeWave = ys.Battle.BattleRangeWave

function BattleRangeWave.Ctor(self)
	BattleRangeWave.super.Ctor(self)
end

function BattleRangeWave.SetWaveData(self, waveData)
	BattleRangeWave.super.SetWaveData(self, waveData)

	self._pos = Vector3(self._param.rect[1], 0, self._param.rect[2])
	self._width = self._param.rect[3]
	self._height = self._param.rect[4]
	self._lifeTime = 99999
end

-- RangeWave的意思是，到了这个区域内就可以了?
-- 但我没看到有使用过这类wave的关卡
function BattleRangeWave.DoWave(self)
	BattleRangeWave.super.DoWave(self)
	self._spawnFunc(self._pos, self._width, self._height, self._lifeTime, function(unitList, aoe)
		for _, unit in ipairs(unitList) do
			if unit.IFF ~= aoe:GetCldData().IFF then
				aoe:SetActiveFlag(false)
				self:doPass()

				break
			end
		end
	end)
end
