ys = ys or {}

local ys = ys

ys.Battle.BattleTriggerBulletFactory = singletonClass("BattleTriggerBulletFactory", ys.Battle.BattleBombBulletFactory)
ys.Battle.BattleTriggerBulletFactory.__name = "BattleTriggerBulletFactory"

local BattleTriggerBulletFactory = ys.Battle.BattleTriggerBulletFactory

function BattleTriggerBulletFactory.Ctor(arg_1_0)
	BattleTriggerBulletFactory.super.Ctor(arg_1_0)
end

function BattleTriggerBulletFactory.OutRangeFunc(bullet)
	local bulletTemplate = bullet:GetTemplate()
	local hit_type = bulletTemplate.hit_type
	local multy = bulletTemplate.extra_param.multy or 1
	local battleDataProxy = BattleTriggerBulletFactory.GetDataProxy()
	local diveFilter = bullet:GetDiveFilter()
	local aoeData

	local function cldFunc(cldObjList)
		local decay = hit_type.decay

		if decay then
			aoeData:UpdateDistanceInfo()
		end

		for _, cldObject in ipairs(cldObjList) do
			if cldObject.Active then
				local cldObjectUID = cldObject.UID
				local distanceReduce = 0

				if decay then
					distanceReduce = aoeData:GetDistance(cldObjectUID) / (hit_type.range * 0.5) * decay
				end

				local target = BattleTriggerBulletFactory.GetSceneMediator():GetCharacter(cldObjectUID):GetUnitData()
				local damageCount = 0

				while target:IsAlive() and damageCount < multy do
					battleDataProxy:HandleDamage(bullet, target, distanceReduce)

					damageCount = damageCount + 1
				end
			end
		end

		ys.Battle.PlayBattleSFX(bullet:GetHitSFX())
		battleDataProxy:SpawnEffect(bulletTemplate.hit_fx, bullet:GetExplodePostion())
	end

	aoeData = battleDataProxy:SpawnTriggerColumnArea(bullet:GetEffectField(), bullet:GetIFF(), bullet:GetExplodePostion(), hit_type.range, hit_type.time, false, bulletTemplate.miss_fx, cldFunc)

	aoeData:SetDiveFilter(diveFilter)
	battleDataProxy:RemoveBulletUnit(bullet:GetUniqueID())
end

function BattleTriggerBulletFactory.onBulletHitFunc(arg_4_0, arg_4_1, arg_4_2)
	return
end

function BattleTriggerBulletFactory.CreateBulletAlert(arg_5_0)
	return
end
