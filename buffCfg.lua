local cachedBuffIDs = {}

pg.buffCfg = setmetatable({}, {
	__index = function(buffTable, buffIDString)
		-- __index表示的是访问不存在的键时触发的行为
		if cachedBuffIDs[buffIDString] then
			-- 这个return true是什么意思？
			return true
		else
			cachedBuffIDs[buffIDString] = true

			local configPaths = {
				"GameCfg.buff." .. buffIDString
			}
			-- 没找到这个路径...
			if LUA_CONFIG_EXTRA then
				table.insert(configPaths, "GameCfg.battle_lua.buff_extra." .. buffIDString)
			end

			for _, configPath in ipairs(configPaths) do
				-- pcall表示"保护模式调用"，即使require报错也不会中断程序
				if pcall(function()
					buffTable[buffIDString] = require(configPath)
				end) then
					return buffTable[buffIDString]
				end
			end

			if IsUnityEditor then
				warning("找不到技能配置: " .. "GameCfg.buff." .. buffIDString)
			end

			return nil
		end
	end
})

ys.Battle.BattleDataFunction.ConvertBuffTemplate()
