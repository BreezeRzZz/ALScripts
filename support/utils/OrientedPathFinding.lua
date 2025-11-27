local OrientedPathFinding = class("OrientedPathFinding", PathFinding)

OrientedPathFinding = OrientedPathFinding

--- @param startCell ChapterCell
--- @param targetCell ChapterCell
--- @return number, table<number, ChapterCell>
function OrientedPathFinding.Find(self, startCell, targetCell)
	startCell = {
		row = startCell.row,
		column = startCell.column
	}
	targetCell = {
		row = targetCell.row,
		column = targetCell.column
	}

	if self.cells[startCell.row][startCell.column].priority < 0 or self.cells[targetCell.row][targetCell.column].priority < 0 then
		return 0, {}
	else
		return self:_Find(startCell, targetCell)
	end
end

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

--- @param startCell ChapterCell
--- @param targetCell ChapterCell
--- @return number, table<number, ChapterCell>
--- 寻路算法主体
function OrientedPathFinding._Find(self, startCell, targetCell)
	-- openList(尚未考察的节点)
	-- closedList(已考察的节点)
	local priority = OrientedPathFinding.PrioForbidden
	local path = {}
	local openList = {
		startCell
	}
	local closedList = {}
	-- 这个表用于记录从startCell到各个节点的路径和priority值，与Cell结构不完全相同
	--- @type table<number, table<number, table>>
	local pathTable = {
		[startCell.row] = {
			[startCell.column] = {
				priority = 0,
				path = {}
			}
		}
	}

	while #openList > 0 do
		-- table.remove(table, index): 从table中移除index位置的元素，并返回该元素
		-- 这里每次取出openList的第一个元素进行考察(相当于队列的出队操作，做BFS)
		local currentCell = table.remove(openList, 1)

		-- 如果currentCell是目标节点，则取出路径和priority，跳出循环
		if currentCell.row == targetCell.row and currentCell.column == targetCell.column then
			local currentPath = pathTable[currentCell.row][currentCell.column]

			priority = currentPath.priority
			path = currentPath.path

			break
		end
		
		-- table.insert(table, value): 向table的末尾添加value元素
			-- 这里将currentCell加入closedList，表示已考察
		table.insert(closedList, currentCell)

		-- underscore.each(items, func): 对每个元素执行func函数
			-- 这里对四个方向进行遍历考察
		_.each(directions, function(direction)
			local newCell = {
				row = currentCell.row + direction[1],
				column = currentCell.column + direction[2]
			}

			-- underscore.any(items, [func]): if exist item in items能让func(item)返回true，则返回true，否则返回false（有一个满足就返回true）
				-- 这里检查newCell是否已经在openList或closedList中存在
				-- 同时检查newCell是否在地图范围内
				-- 最后检查从currentCell到newCell的方向是否被禁止
				-- 同时满足以上条件，才进行BFS的扩展
			if not (_.any(openList, function(cell)
				return cell.row == newCell.row and cell.column == newCell.column
			end) or _.any(closedList, function(cell)
				return cell.row == newCell.row and cell.column == newCell.column
			end)) and newCell.row >= 0 and newCell.row < self.rows and newCell.column >= 0 and newCell.column < self.columns and not OrientedPathFinding.IsDirectionForbidden(self.cells[currentCell.row][currentCell.column], direction[1], direction[2]) then
				-- currentPath.priority: 从startCell到currentCell到priority之和
				-- self.cells[newCell.row][newCell.column].priority: 从currentCell到newCell的priority
				-- newPriority: 从startCell到newCell的priority之和
				local currentPath = pathTable[currentCell.row][currentCell.column]
				local newPriority = currentPath.priority + self.cells[newCell.row][newCell.column].priority

				if newPriority < OrientedPathFinding.PrioObstacle then
					local currentNewPath = Clone(currentPath)

					-- 将newCell加入路径
					table.insert(currentNewPath.path, newCell)
					-- 更新pathTable
					currentNewPath.priority = newPriority
					pathTable[newCell.row] = pathTable[newCell.row] or {}
					pathTable[newCell.row][newCell.column] = currentNewPath

					local insertPos = 0

					-- 此处是一个倒序遍历，用于在openList中找到合适的位置插入newCell，以保持openList按priority升序排列
					for i = #openList, 1, -1 do
						local cell = openList[i]
						local path = pathTable[cell.row][cell.column]

						if currentNewPath.priority >= path.priority then
							insertPos = i

							break
						end
					end

					table.insert(openList, insertPos + 1, newCell)
				else
					priority = math.min(priority, newPriority)
				end
			end
		end)
	end

	-- 这一段的目的是当无法到达目标节点时，选择一个离目标节点最近的节点作为替代路径
	if priority >= OrientedPathFinding.PrioObstacle then
		local minDistance = 1000000
		-- PrioForbidden = 1000000
		local minPriority = OrientedPathFinding.PrioForbidden

		for row, columnTable in pairs(pathTable) do
			-- path(字段：priority和path)
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

--- @param cell ChapterCell
--- @param dx number
--- @param dy number
--- @return boolean|nil
--- 判定这个方向是否被禁止
--- 注意x轴正方向向下，y轴正方向向右
function OrientedPathFinding.IsDirectionForbidden(cell, dx, dy)
	if cell.forbiddens == ChapterConst.ForbiddenNone then
		return
	end

	local directionFlags

	if dx ~= 0 then
		directionFlags = dx < 0 and ChapterConst.ForbiddenUp or ChapterConst.ForbiddenDown
	else
		directionFlags = dy < 0 and ChapterConst.ForbiddenLeft or ChapterConst.ForbiddenRight
	end

	return bit.band(directionFlags, cell.forbiddens) > 0
end

return OrientedPathFinding
