local FleetAIAction = class("FleetAIAction")

function FleetAIAction.Ctor(arg_1_0, arg_1_1)
	arg_1_0.actType = arg_1_1.act_type
	arg_1_0.line = {
		row = arg_1_1.ai_pos.row,
		column = arg_1_1.ai_pos.column
	}

	if arg_1_1.target_pos and arg_1_1.target_pos.row < 9999 and arg_1_1.target_pos.column < 9999 then
		arg_1_0.target = {
			row = arg_1_1.target_pos.row,
			column = arg_1_1.target_pos.column
		}
	end

	arg_1_0.shipUpdate = _.map(arg_1_1.ship_update, function(arg_2_0)
		return {
			id = arg_2_0.id,
			hpRant = arg_2_0.hp_rant
		}
	end)
	arg_1_0.cellUpdates = {}

	_.each(arg_1_1.map_update, function(arg_3_0)
		if arg_3_0.item_type ~= ChapterConst.AttachNone and arg_3_0.item_type ~= ChapterConst.AttachBorn and arg_3_0.item_type ~= ChapterConst.AttachBorn_Sub and (arg_3_0.item_type ~= ChapterConst.AttachStory or arg_3_0.item_data ~= ChapterConst.StoryTrigger) then
			local var_3_0 = arg_3_0.item_type == ChapterConst.AttachChampion and ChapterChampionPackage.New(arg_3_0) or ChapterCell.New(arg_3_0)

			table.insert(arg_1_0.cellUpdates, var_3_0)
		end
	end)

	arg_1_0.commanderSkillEffectId = arg_1_1.commander_skill_effect_id
end

function FleetAIAction.applyTo(arg_4_0, arg_4_1, arg_4_2)
	local var_4_0 = arg_4_1:getFleet(FleetType.Normal, arg_4_0.line.row, arg_4_0.line.column)

	if var_4_0 then
		return arg_4_0:applyToFleet(arg_4_1, var_4_0, arg_4_2)
	end

	return false, "can not find any fleet at: [" .. arg_4_0.line.row .. ", " .. arg_4_0.line.column .. "]"
end

function FleetAIAction.applyToFleet(arg_5_0, arg_5_1, arg_5_2, arg_5_3)
	if not arg_5_2:isValid() then
		return false, "fleet " .. arg_5_2.id .. " is invalid."
	end

	local var_5_0 = 0

	if arg_5_1:isPlayingWithBombEnemy() then
		if not arg_5_3 then
			_.each(arg_5_0.cellUpdates, function(arg_6_0)
				local var_6_0 = arg_5_1:getChapterCell(arg_6_0.row, arg_6_0.column)

				if var_6_0.flag == ChapterConst.CellFlagActive and arg_6_0.flag == ChapterConst.CellFlagDisabled then
					local var_6_1 = pg.specialunit_template[var_6_0.attachmentId]

					assert(var_6_1, "specialunit_template not exist: " .. var_6_0.attachmentId)

					arg_5_1.modelCount = arg_5_1.modelCount + var_6_1.enemy_point
				end

				arg_5_1:mergeChapterCell(arg_6_0)

				var_5_0 = bit.bor(var_5_0, ChapterConst.DirtyAttachment)
			end)
		end
	elseif arg_5_0.target then
		local var_5_1 = _.detect(arg_5_0.cellUpdates, function(arg_7_0)
			return arg_7_0.row == arg_5_0.target.row and arg_7_0.column == arg_5_0.target.column
		end)

		if not arg_5_3 then
			if arg_5_0.shipUpdate then
				_.each(arg_5_0.shipUpdate, function(arg_8_0)
					arg_5_1:updateFleetShipHp(arg_8_0.id, arg_8_0.hpRant)
				end)

				var_5_0 = bit.bor(var_5_0, ChapterConst.DirtyFleet)
			end

			if var_5_1 then
				if isa(var_5_1, ChapterChampionPackage) then
					arg_5_1:mergeChampion(var_5_1)

					var_5_0 = bit.bor(var_5_0, ChapterConst.DirtyChampion)
				else
					arg_5_1:mergeChapterCell(var_5_1)

					var_5_0 = bit.bor(var_5_0, ChapterConst.DirtyAttachment)
				end

				var_5_0 = bit.bor(var_5_0, ChapterConst.DirtyFleet)
			end
		end
	end

	return true, var_5_0
end

--- @param ChapterVO ChapterLevelData
--- @param LevelMediator LevelMediator2
--- @param callback function
--- @return nil
--- 播放对应的AI动画
function FleetAIAction.PlayAIAction(self, chapterVO, levelMediator, callback)
	local fleetIndex = chapterVO:getFleetIndex(FleetType.Normal, self.line.row, self.line.column)

	assert(fleetIndex)

	if chapterVO:isPlayingWithBombEnemy() then
		local fleet = chapterVO.fleets[fleetIndex]
		local mapShip = chapterVO:getMapShip(fleet)

		levelMediator.viewComponent:doPlayStrikeAnim(mapShip, mapShip:GetMapStrikeAnim(), callback)
	elseif self.actType == ChapterConst.ActType_Poison then
		callback()
	elseif self.target then
		local fleet = chapterVO.fleets[fleetIndex]
		local targetCell = _.detect(self.cellUpdates, function(cellUpdate)
			return cellUpdate.row == self.target.row and cellUpdate.column == self.target.column
		end)

		assert(targetCell, "can not find cell")

		if targetCell.attachment == ChapterConst.AttachLandbase then
			if pg.land_based_template[targetCell.attachmentId].type == ChapterConst.LBCoastalGun then
				local mapShip = chapterVO:getMapShip(fleet)

				levelMediator.viewComponent:doPlayStrikeAnim(mapShip, mapShip:GetMapStrikeAnim(), callback)
			else
				assert(false)
			end

			return
		end

		local damagePercent = "-" .. targetCell.data / 100 .. "%"
		local skillId = self.commanderSkillEffectId
		local skill = fleet:getSkill(skillId)

		assert(skill, "can not find skill: " .. skillId)

		local commander = fleet:findCommanderBySkillId(skillId)

		assert(commander, "command can not find by skill id: " .. skillId)
		levelMediator.viewComponent:doPlayCommander(commander, function()
			if skill:GetType() == FleetSkill.TypeAirStrikeDodge then
				levelMediator.viewComponent:easeAvoid(levelMediator.viewComponent.grid.cellFleets[fleet.id].tf.position, callback)

				return
			elseif skill:GetType() == FleetSkill.TypeAttack then
				local skillArgs = skill:GetArgs()
				local strikeUI

				switch(skillArgs[1], {
					airfight = function()
						strikeUI = "AirStrikeUI"
					end,
					torpedo = function()
						strikeUI = "SubTorpedoUI"
					end,
					cannon = function()
						strikeUI = "CannonUI"
					end
				})
				assert(strikeUI)
				levelMediator.viewComponent:doPlayStrikeAnim(chapterVO:getStrikeAnimShip(fleet, strikeUI), strikeUI, function()
					levelMediator.viewComponent:strikeEnemy(self.target, damagePercent, callback)
				end)

				return
			else
				assert(false)
			end
		end)
	else
		callback()
	end
end

return FleetAIAction
