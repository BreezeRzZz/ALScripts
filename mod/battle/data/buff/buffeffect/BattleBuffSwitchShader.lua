ys = ys or {}

local ys = ys

ys.Battle.BattleBuffSwitchShader = class("BattleBuffSwitchShader", ys.Battle.BattleBuffEffect)
ys.Battle.BattleBuffSwitchShader.__name = "BattleBuffSwitchShader"

local BattleBuffSwitchShader = ys.Battle.BattleBuffSwitchShader

-- 此类BuffEffect用于做视觉效果的切换，主要是切换Shader和调整透明度
-- 使用例: 玛丽·西莱斯特号1技能
function BattleBuffSwitchShader.Ctor(self, effectData)
	BattleBuffSwitchShader.super.Ctor(self, effectData)
end

function BattleBuffSwitchShader.SetArgs(self, owner, buff)
	self._shader = self._tempData.arg_list.shader
	self._invisible = self._tempData.arg_list.invisible or 0.7
end

function BattleBuffSwitchShader.onAttach(self, owner, buff, args)
	local shaderArgs = {
		invisible = self._invisible
	}

	owner:SwitchShader(self._shader, nil, shaderArgs)
end

function BattleBuffSwitchShader.onRemove(self, owner, buff, args)
	owner:SwitchShader("COLORED_ALPHA")
end
