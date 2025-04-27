local M = {}

---@param struct_name string?
function M.run(struct_name)
	if struct_name == nil or struct_name == "" then
		struct_name = "T"
	end
	local start_lnum = vim.fn.line("'<") - 1
	local end_lnum = vim.fn.line("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start_lnum, end_lnum, true)
	local ok, decoded_json = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok then
		vim.notify("Invalid JSON", vim.log.levels.ERROR)
		return
	end
	local go_struct = M.generate_go_struct(decoded_json, struct_name)
	vim.api.nvim_buf_set_lines(0, start_lnum, end_lnum, true, go_struct)
end

---@param tbl table
---@param struct_name string
---@return string[]
function M.generate_go_struct(tbl, struct_name)
	local converted = "type " .. struct_name .. " " .. M.generate_field(tbl, 0)
	return vim.split(converted, "\n")
end

---@param value any
---@param indent integer
---@return string
function M.generate_field(value, indent)
	local lines = {}
	local pad = string.rep("\t", indent)

	if type(value) ~= "table" then
		error("generate_field expects a table")
	end

	table.insert(lines, "struct {")

	for key, val in pairs(value) do
		local field_name = M.to_pascal_case(key)
		local go_type = M.infer_go_type(val)

		if go_type == "struct" then
			table.insert(lines, pad .. "\t" .. field_name .. " struct {")
			for child_key, child_value in pairs(val) do
				local child_field_name = M.to_pascal_case(child_key)
				local child_go_type = M.infer_go_type(child_value)

				if child_go_type == "struct" then
					table.insert(
						lines,
						pad
							.. "\t\t"
							.. child_field_name
							.. " "
							.. M.generate_field(child_value, indent + 2)
							.. ' `json:"'
							.. child_key
							.. '"`'
					)
				else
					table.insert(
						lines,
						pad .. "\t\t" .. child_field_name .. " " .. child_go_type .. ' `json:"' .. child_key .. '"`'
					)
				end
			end
			table.insert(lines, pad .. '\t} `json:"' .. key .. '"`')
		elseif vim.islist(val) then
			if #val == 0 then
				table.insert(lines, pad .. "\t" .. field_name .. ' []interface{} `json:"' .. key .. '"`')
			else
				local elem_type = M.infer_go_type(val[1])
				if elem_type == "struct" then
					table.insert(
						lines,
						pad
							.. "\t"
							.. field_name
							.. " []"
							.. M.generate_field(val[1], indent + 1)
							.. ' `json:"'
							.. key
							.. '"`'
					)
				else
					table.insert(lines, pad .. "\t" .. field_name .. " []" .. elem_type .. ' `json:"' .. key .. '"`')
				end
			end
		else
			table.insert(lines, pad .. "\t" .. field_name .. " " .. go_type .. ' `json:"' .. key .. '"`')
		end
	end

	table.insert(lines, pad .. "}")
	return table.concat(lines, "\n")
end

---@param str string
---@return string
function M.to_pascal_case(str)
	if str:find("_") then
		-- snake_case → PascalCase
		return (
			str:gsub("(%a)([%w_]*)", function(first, rest)
				return first:upper() .. rest:lower()
			end):gsub("_", "")
		)
	else
		-- camelCase or others
		return (str:gsub("^(%l)", string.upper))
	end
end

---@param value any
---@return string Go type
function M.infer_go_type(value)
	local lua_type = type(value)

	if lua_type == "string" then
		return "string"
	elseif lua_type == "number" then
		if math.floor(value) == value then
			return "int"
		else
			return "float64"
		end
	elseif lua_type == "boolean" then
		return "bool"
	elseif lua_type == "table" then
		if vim.islist(value) then
			local elem_type = M.infer_go_type(value[1])
			local is_all_same = vim.iter(value):all(function(elem)
				return M.infer_go_type(elem) == elem_type
			end)
			if is_all_same then
				return "[]" .. elem_type
			else
				return "[]interface{}"
			end
		else
			return "struct"
		end
	else
		return "interface{}"
	end
end

return M
