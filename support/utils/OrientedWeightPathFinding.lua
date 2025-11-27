local OrientedWeightPathFinding = class("OrientedWeightPathFinding", OrientedPathFinding)

OrientedWeightPathFinding = OrientedWeightPathFinding

local directions = {
	{
		1,
		0
	},
	{
		-1,
		0
	},
	{
		0,
		1
	},
	{
		0,
		-1
	}
}

--- @param pathCells table<number, table<number, ChapterCell>>
--- @param maxRow number
--- @param maxColumn number
--- @param startCell ChapterCell
--- @param targetCell ChapterCell
--- @return number, table<number, ChapterCell>
--- 寻路算法主体
local function _Find(pathCells, maxRow, maxColumn, startCell, targetCell)
	-- openList(尚未考察的节点)
	-- closedList(已考察的节点)
	local priority = OrientedWeightPathFinding.PrioForbidden
	local path = {}
	local openList = {
		startCell
	}
	local closedList = {}
	-- OrientedWeightPathFinding的pathTable比OrientedPathFinding多了enemyCount字段
	--- @type table<number, table<number, table>>
	local pathTable = {
		[startCell.row] = {
			[startCell.column] = {
				enemyCount = 0,
				priority = 0,
				path = {}
			}
		}
	}

	while #openList > 0 do
		local currentCell = table.remove(openList, 1)

		if currentCell.row == targetCell.row and currentCell.column == targetCell.column then
			local currentPath = pathTable[currentCell.row][currentCell.column]

			priority = currentPath.priority
			path = currentPath.path

			break
		end

		table.insert(closedList, currentCell)
		_.each(directions, function(direction)
			local newCell = {
				row = currentCell.row + direction[1],
				column = currentCell.column + direction[2]
			}

			if not _.any(closedList, function(cell)
				return cell.row == newCell.row and cell.column == newCell.column
			end) and newCell.row >= 0 and newCell.row < maxRow and newCell.column >= 0 and newCell.column < maxColumn and not OrientedWeightPathFinding.IsDirectionForbidden(pathCells[currentCell.row][currentCell.column], direction[1], direction[2]) then
				local currentPath = pathTable[currentCell.row][currentCell.column]
				local pathCell = pathCells[newCell.row][newCell.column]
				local newPriority = currentPath.priority + pathCell.priority
				local newEnemyCount = currentPath.enemyCount + (pathCell.isEnemy and 1 or 0)

				if newPriority < OrientedWeightPathFinding.PrioObstacle then
					local currentNewPath = Clone(currentPath)

					table.insert(currentNewPath.path, newCell)

					currentNewPath.priority = newPriority
					-- ! 注意：此处为逻辑错误，重复计算了两次currentPath.enemyCount
					currentNewPath.enemyCount = currentPath.enemyCount + newEnemyCount

					-- underscore.detect(items, func): 返回第一个能让func(item)返回true的item，否则返回nil
					local newCellAlreadyExists = _.detect(openList, function(cell)
						return cell.row == newCell.row and cell.column == newCell.column
					end)

					local isNewPathBetter = not newCellAlreadyExists

					if newCellAlreadyExists then
						local originalNewPath = pathTable[newCell.row][newCell.column]

						isNewPathBetter = originalNewPath.enemyCount > currentNewPath.enemyCount or originalNewPath.enemyCount == currentNewPath.enemyCount and originalNewPath.priority > currentNewPath.priority

						-- 此处如果确定了新路径更优，则将openList中的旧节点移除，后续会重新插入
						-- 这样能确保之后从这个节点扩散时，使用的是更优的路径信息
						-- 额外说明：为什么普通的OrientedPathFinding不需要这样做？因为只有priority一个维度，根据Dijkstra算法的性质，后续扩展时不会出现更优路径的可能
						if isNewPathBetter then
							table.removebyvalue(openList, newCellAlreadyExists)
						end
					end

					if isNewPathBetter then
						pathTable[newCell.row] = pathTable[newCell.row] or {}
						pathTable[newCell.row][newCell.column] = currentNewPath

						local insertPos = 0

						-- 此处是一个倒序遍历，用于找到插入newCell的位置，维护openList作为优先队列从而BFS
						-- openList按enemyCount升序排列，enemyCount相同时按priority升序排列
						-- 每次扩展时，取出的队头是enemyCount最少且priority最小的节点
						for i = #openList, 1, -1 do
							local cell = openList[i]
							local path = pathTable[cell.row][cell.column]

							if currentNewPath.enemyCount > path.enemyCount or currentNewPath.enemyCount == path.enemyCount and currentNewPath.priority >= path.priority then
								insertPos = i

								break
							end
						end

						table.insert(openList, insertPos + 1, newCell)
					end
				else
					priority = math.min(priority, newPriority)
				end
			end
		end)
	end

	-- 这一段目的是当无法到达目标节点时，选择一个离目标节点最近的节点作为替代路径
	if priority >= OrientedWeightPathFinding.PrioObstacle then
		local minDistance = 1000000
		local minPriority = OrientedWeightPathFinding.PrioForbidden

		for row, columnTable in pairs(pathTable) do
			-- path(字段：enemyCount、priority和path)
			for column, path in pairs(columnTable) do
				-- distance: path所在节点到目标节点的曼哈顿距离
				local distance = math.abs(targetCell.row - row) + math.abs(targetCell.column - column)

				-- 优先距离最短
				-- 如果距离相同，则选择priority更小的路径
					--(这逻辑是否有点问题？minPriority应该是对每个distance更新时要重置的吧？否则priority只会越来越小，可能选不到distance更小的路径)
				if distance < minDistance or distance == minDistance and minPriority > path.priority then
					minDistance = distance
					minPriority = path.priority
					path = path.path
				end
			end
		end
	end

	return priority, path
end

--- @param pathCells table<number, table<number, ChapterCell>>
--- @param maxRow number
--- @param maxColumn number
--- @param startCell ChapterCell
--- @param targetCell ChapterCell
--- @return number, table<number, ChapterCell>\
--- 设置一些参数，再使用寻路算法
function OrientedWeightPathFinding.StaticFind(pathCells, maxRow, maxColumn, startCell, targetCell)
	startCell = {
		row = startCell.row,
		column = startCell.column
	}
	targetCell = {
		row = targetCell.row,
		column = targetCell.column
	}

	if pathCells[startCell.row][startCell.column].priority < 0 or pathCells[targetCell.row][targetCell.column].priority < 0 then
		return 0, {}
	else
		return _Find(pathCells, maxRow, maxColumn, startCell, targetCell)
	end
end

return OrientedWeightPathFinding
