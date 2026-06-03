local BaseVO = class("BaseVO")

--- @class BaseVO
--- @param args table<string, any>
--- @return nil
--- 构造函数
function BaseVO.Ctor(self, args)
	for key, value in pairs(args) do
		self[key] = value
	end
end

--- @class BaseVO
--- @param log string
--- @param flag boolean
--- 打印对象信息
function BaseVO.display(self, log, flag)
	if log == "loaded" or not flag then
		return
	end

	local logString = self.__cname .. " id: " .. tostring(self.id) .. " " .. (log or ".")

	for key, value in pairs(self) do
		if key ~= "class" then
			local valueType = type(value)

			logString = logString .. "\n" .. key .. ":" .. tostring(value)

			if valueType == "table" then
				logString = logString .. " ["

				for _, member in pairs(value) do
					logString = logString .. tostring(member) .. ", "
				end

				logString = logString .. "]"
			end
		end
	end

	print(logString)
end

--- @class BaseVO
--- @return BaseVO
--- 克隆对象
function BaseVO.clone(self)
	return Clone(self)
end

--- @class BaseVO
--- @return any
--- 绑定配置表
--- - 需要在子类中重写此方法
function BaseVO.bindConfigTable(self)
	return
end

--- @class BaseVO
--- @return number
--- 获取配置ID
function BaseVO.GetConfigID(self)
	return self.configId
end

--- @class BaseVO
--- @return table
--- 获取配置表
function BaseVO.getConfigTable(self)
	--- @type table<number, table>
	local configTableList = self:bindConfigTable()

	assert(configTableList, "should bindConfigTable() first: " .. self.__cname)

	return configTableList[self.configId]
end

--- @class BaseVO
--- @param key string
--- @return any
--- 获取配置表中的字段值
function BaseVO.getConfig(self, key)
	local configTable = self:getConfigTable()

	assert(configTable ~= nil, "Config missed, type -" .. self.__cname .. " configId: " .. tostring(self.configId))

	if key == "name" then
		return HXSet.hxLan(configTable[key])
	elseif key == "desc" then
		return HXSet.hxLan(configTable[key])
	end

	return configTable[key]
end

return BaseVO
