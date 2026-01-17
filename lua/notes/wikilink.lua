local M = {}

-- Convert a 0-based cursor column to a 1-based position for Lua strings.
function M.cursor_pos_from_col(cursor_col0)
	return cursor_col0 + 1
end

-- Find the last wiki-link opening before the cursor position.
function M.last_open_start(line, cursor_pos)
	local open_start
	local search_from = 1
	while true do
		local found = line:find("[[", search_from, true)
		if not found or found > cursor_pos then
			break
		end
		open_start = found
		search_from = found + 2
	end
	return open_start
end

-- Return wiki-link bounds for the cursor position; optionally require closing brackets.
function M.wikilink_bounds(line, cursor_pos, require_close)
	local open_start = M.last_open_start(line, cursor_pos)
	if not open_start then
		return nil
	end

	local close_start = line:find("]]", open_start + 2, true)
	if not close_start then
		if require_close then
			return nil
		end
		return open_start, nil
	end

	if require_close then
		if cursor_pos < open_start or cursor_pos > close_start + 1 then
			return nil
		end
	elseif close_start + 1 < cursor_pos then
		return nil
	end

	return open_start, close_start
end

-- Return the completion range when the cursor is inside [[...]].
function M.wikilink_range()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1]
	local cursor_col0 = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = M.cursor_pos_from_col(cursor_col0)
	local open_start = M.wikilink_bounds(line, cursor_pos, false)
	if not open_start then
		return nil
	end

	local keyword_start = open_start + 2
	return {
		line = row - 1,
		start_col = keyword_start - 1,
		end_col = cursor_col0,
	}
end

-- Return the suffix needed to close a wiki-link after completion.
function M.closing_suffix(line, cursor_col0)
	local cursor_pos = M.cursor_pos_from_col(cursor_col0)
	local after = line:sub(cursor_pos, cursor_pos + 1)
	if after == "]]" then
		return ""
	end
	if after:sub(1, 1) == "]" then
		return "]"
	end
	return "]]"
end

-- Return the wiki-link text under the cursor when inside [[...]].
function M.wikilink_under_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_col0 = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = M.cursor_pos_from_col(cursor_col0)
	local open_start, close_start = M.wikilink_bounds(line, cursor_pos, true)
	if not open_start then
		return nil
	end

	local link_text = line:sub(open_start + 2, close_start - 1)
	if link_text == "" then
		return nil
	end

	if link_text:find("[%[%]|]") or link_text:find("/") then
		return nil
	end

	return link_text
end

return M
