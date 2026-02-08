ys = ys or {}

local ys = ys

ys.Battle.BattleBuffStory = class("BattleBuffStory", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffStory.__name = "BattleBuffStory"

local BattleBuffStory = ys.Battle.BattleBuffStory

-- 此类BuffEffect大概是想让某个单位在血量达到某个百分比时播放某个剧情
-- 但目前没有被使用过
function BattleBuffStory.Ctor(self, effectData)
	BattleBuffStory.super.Ctor(self, effectData)
end

function BattleBuffStory.SetArgs(self, owner, buff)
	local arg_list = self._tempData.arg_list

	self._storyID = arg_list.story_id
	self._countType = arg_list.countType
end

function BattleBuffStory.doOnHPRatioUpdate(self, owner, buff, args)
	pg.NewStoryMgr.GetInstance():Play(self._storyID)
end
