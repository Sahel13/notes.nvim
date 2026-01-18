local M = {}

-- Cache for parsed bib entries
local bib_cache = {
	entries = {},
	file_path = nil,
	mtime = nil,
}

-- Convert a 0-based cursor column to a 1-based position for Lua strings.
function M.cursor_pos_from_col(cursor_col0)
	return cursor_col0 + 1
end

-- Find if cursor is inside a citation bracket [...] and return bounds.
-- Returns open_start, close_start if inside citation brackets, nil otherwise.
function M.citation_bounds(line, cursor_pos)
	local open_start
	local search_from = 1

	-- Find the last '[' before cursor
	while true do
		local found = line:find("%[", search_from)
		if not found or found > cursor_pos then
			break
		end
		open_start = found
		search_from = found + 1
	end

	if not open_start then
		return nil
	end

	-- Find the closing ']' after the opening '['
	local close_start = line:find("%]", open_start + 1)
	if not close_start then
		return open_start, nil
	end

	-- Check if cursor is within the bounds
	if cursor_pos < open_start or cursor_pos > close_start then
		return nil
	end

	return open_start, close_start
end

-- Extract citation key at cursor position from a citation.
-- Handles: [@key], [@key1; @key2], [see @key, p. 20]
-- Returns the citation key under cursor or nil.
function M.citation_key_under_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_col0 = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = M.cursor_pos_from_col(cursor_col0)

	local open_start, close_start = M.citation_bounds(line, cursor_pos)
	if not open_start or not close_start then
		return nil
	end

	-- Extract the content inside brackets
	local content = line:sub(open_start + 1, close_start - 1)

	-- Check if this looks like a citation (contains @)
	if not content:match("@") then
		return nil
	end

	-- Find all citation keys in the content
	local keys = {}
	for key in content:gmatch("@([%w_%-:]+)") do
		table.insert(keys, key)
	end

	if #keys == 0 then
		return nil
	end

	-- If there's only one key, return it
	if #keys == 1 then
		return keys[1]
	end

	-- Multiple keys: find which one the cursor is on
	local rel_pos = cursor_pos - open_start
	local search_from = 1
	for _, key in ipairs(keys) do
		local pattern = "@" .. key:gsub("([%-:])", "%%%1")
		local key_start, key_end = content:find(pattern, search_from, false)
		if key_start and key_end then
			if rel_pos >= key_start and rel_pos <= key_end then
				return key
			end
			search_from = key_end + 1
		end
	end

	-- Default to first key if we can't determine
	return keys[1]
end

-- Check if a line contains a BibTeX entry start and extract the key.
-- Pattern: @article{key, or @book{key, etc.
-- Returns citation_key, line_content if found, nil otherwise.
function M.parse_bib_entry(line)
	local entry_type, key = line:match("^%s*@(%w+)%s*{%s*([^,]+)%s*,")
	if entry_type and key then
		return key:match("^%s*(.-)%s*$"), line -- trim whitespace
	end
	return nil
end

-- Parse a .bib file and return a table of {key -> line_number}.
-- Also returns entry metadata for completions.
function M.parse_bib_file(file_path)
	if not file_path or vim.fn.filereadable(file_path) == 0 then
		return nil, "Bib file not found or not readable: " .. tostring(file_path)
	end

	-- Check cache validity
	local mtime = vim.fn.getftime(file_path)
	if bib_cache.file_path == file_path and bib_cache.mtime == mtime then
		return bib_cache.entries
	end

	-- Parse the file
	local entries = {}
	local file = io.open(file_path, "r")
	if not file then
		return nil, "Failed to open bib file: " .. file_path
	end

	local line_num = 0
	local current_key = nil
	local current_title = nil
	local current_author = nil
	local current_year = nil

	for line in file:lines() do
		line_num = line_num + 1

		-- Check for entry start
		local key = M.parse_bib_entry(line)
		if key then
			current_key = key
			current_title = nil
			current_author = nil
			current_year = nil
			entries[key] = {
				line = line_num,
				title = nil,
				author = nil,
				year = nil,
			}
		elseif current_key then
			-- Extract metadata fields
			local title = line:match('%s*title%s*=%s*[{"](.-)[}"]')
			if title then
				entries[current_key].title = title
			end

			local author = line:match('%s*author%s*=%s*[{"](.-)[}"]')
			if author then
				entries[current_key].author = author
			end

			local year = line:match('%s*year%s*=%s*[{"](.-)[}"]')
			if year then
				entries[current_key].year = year
			end

			-- Check for end of entry
			if line:match("^%s*}%s*$") then
				current_key = nil
			end
		end
	end

	file:close()

	-- Update cache
	bib_cache.entries = entries
	bib_cache.file_path = file_path
	bib_cache.mtime = mtime

	return entries
end

-- Get all citation keys from the bib file.
-- Returns array of keys sorted alphabetically.
function M.get_citation_keys(bib_file)
	local entries, err = M.parse_bib_file(bib_file)
	if not entries then
		return nil, err
	end

	local keys = {}
	for key, _ in pairs(entries) do
		table.insert(keys, key)
	end
	table.sort(keys)

	return keys
end

-- Get metadata for a citation key.
-- Returns {line, title, author, year} or nil.
function M.get_citation_metadata(bib_file, citation_key)
	local entries, err = M.parse_bib_file(bib_file)
	if not entries then
		return nil, err
	end

	return entries[citation_key]
end

-- Return the completion range when cursor is inside [@...].
function M.citation_range()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1]
	local cursor_col0 = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = M.cursor_pos_from_col(cursor_col0)

	local open_start, close_start = M.citation_bounds(line, cursor_pos)
	if not open_start then
		return nil
	end

	-- Check if this looks like a citation context
	local before_cursor = line:sub(open_start + 1, cursor_pos - 1)
	local at_pos = before_cursor:reverse():find("@")
	if not at_pos then
		return nil
	end

	-- Find the start of the current key (after the @)
	local key_start_pos = cursor_pos - at_pos + 1

	return {
		line = row - 1,
		start_col = key_start_pos - 1,
		end_col = cursor_col0,
	}
end

-- Return the suffix needed to close a citation after completion.
function M.closing_suffix(line, cursor_col0)
	local cursor_pos = M.cursor_pos_from_col(cursor_col0)
	local after = line:sub(cursor_pos, cursor_pos)
	if after == "]" then
		return ""
	end
	return "]"
end

return M
