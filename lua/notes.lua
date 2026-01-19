-- Source guidelines: https://cmp.saghen.dev/development/source-boilerplate.html
local notes = {}
local fs = require("notes.fs")
local wikilink = require("notes.wikilink")
local citation = require("notes.citation")
local date = require("notes.date")
-- Use blink kinds when available; fall back for headless tests.
local ok_types, blink_types = pcall(require, "blink.cmp.types")
local completion_kinds = ok_types and blink_types.CompletionItemKind or vim.lsp.protocol.CompletionItemKind
local nav_stack = {}
local config = {
	bib_file = nil,
	mappings = {
		follow = "<CR>",
		follow_split = "<S-CR>",
		follow_vsplit = "<C-CR>",
		back = "<BS>",
		backlinks = "<leader>nb",
		daily_note = "<leader>nd",
		reference_note = "<leader>nr",
		next_wikilink = "<Tab>",
		prev_wikilink = "<S-Tab>",
	},
}

-- Configure notes.nvim behavior (mappings can be overridden or disabled).
function notes.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

-- Return the current configuration.
function notes.get_config()
	return config
end

-- Create a new blink.cmp source instance.
function notes.new(opts)
	local self = setmetatable({}, { __index = notes })
	self.opts = opts or {}
	return self
end

-- Enable completions only for Markdown buffers.
function notes:enabled()
	return vim.bo.filetype == "markdown"
end

-- Trigger completion when typing a bracket or @.
function notes:get_trigger_characters()
	return { "[", "@" }
end

-- Provide wiki-link and citation completions.
function notes:get_completions(_, callback)
	-- Try citation completion first
	local citation_range = citation.citation_range()
	if citation_range and config.bib_file then
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line = vim.api.nvim_get_current_line()
		local suffix = citation.closing_suffix(line, cursor[2])

		-- Expand path to handle ~
		local bib_file = vim.fn.expand(config.bib_file)
		local keys, err = citation.get_citation_keys(bib_file)
		if not keys then
			vim.notify("notes.nvim: " .. (err or "Failed to load citations"), vim.log.levels.WARN)
			callback({
				items = {},
				is_incomplete_forward = false,
				is_incomplete_backward = false,
			})
			return
		end

		local items = {}
		for _, key in ipairs(keys) do
			local metadata = citation.get_citation_metadata(bib_file, key)
			local label_detail = nil
			local documentation = nil

			if metadata then
				if metadata.author and metadata.year then
					label_detail = metadata.author .. " (" .. metadata.year .. ")"
				elseif metadata.year then
					label_detail = "(" .. metadata.year .. ")"
				end

				if metadata.title then
					documentation = metadata.title
				end
			end

			table.insert(items, {
				label = key,
				labelDetails = label_detail and { detail = " " .. label_detail } or nil,
				kind = completion_kinds.Reference,
				documentation = documentation,
				textEdit = {
					newText = key .. suffix,
					range = {
						start = { line = citation_range.line, character = citation_range.start_col },
						["end"] = { line = citation_range.line, character = citation_range.end_col },
					},
				},
			})
		end

		callback({
			items = items,
			is_incomplete_forward = false,
			is_incomplete_backward = false,
		})
		return
	end

	-- Fall back to wikilink completion
	local wikilink_range = wikilink.wikilink_range()
	if not wikilink_range then
		callback({
			items = {},
			is_incomplete_forward = false,
			is_incomplete_backward = false,
		})
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local suffix = wikilink.closing_suffix(line, cursor[2])

	local cwd = vim.fn.getcwd()
	local stems = fs.list_note_stems(cwd)
	local items = {}

	for _, stem in ipairs(stems) do
		table.insert(items, {
			label = stem,
			kind = completion_kinds.Text,
			textEdit = {
				newText = stem .. suffix,
				range = {
					start = { line = wikilink_range.line, character = wikilink_range.start_col },
					["end"] = { line = wikilink_range.line, character = wikilink_range.end_col },
				},
			},
		})
	end

	callback({
		items = items,
		is_incomplete_forward = false,
		is_incomplete_backward = false,
	})
end

-- Open the wiki-link under the cursor using the supplied command.
local function follow_wikilink_with(cmd)
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	local link_text = wikilink.wikilink_under_cursor()
	if not link_text then
		return false
	end

	local cwd = vim.fn.getcwd()
	local target = cwd .. "/" .. link_text .. ".md"

	if vim.fn.filereadable(target) == 0 then
		local ok = pcall(vim.fn.writefile, { "# " .. link_text }, target)
		if not ok then
			vim.notify("notes.nvim: unable to create " .. target, vim.log.levels.ERROR)
			return false
		end
	end

	local current = vim.api.nvim_buf_get_name(0)
	if current ~= "" then
		table.insert(nav_stack, current)
	end

	vim.cmd(cmd .. " " .. vim.fn.fnameescape(target))
	return true
end

-- Open the citation under the cursor using the supplied command.
local function follow_citation_with(cmd)
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	local citation_key = citation.citation_key_under_cursor()
	if not citation_key then
		return false
	end

	if not config.bib_file then
		vim.notify("notes.nvim: bib_file not configured", vim.log.levels.WARN)
		return false
	end

	-- Expand path to handle ~
	local bib_file = vim.fn.expand(config.bib_file)
	local metadata = citation.get_citation_metadata(bib_file, citation_key)
	if not metadata then
		vim.notify("notes.nvim: citation key '" .. citation_key .. "' not found in bib file", vim.log.levels.WARN)
		return false
	end

	local current = vim.api.nvim_buf_get_name(0)
	if current ~= "" then
		table.insert(nav_stack, current)
	end

	vim.cmd(cmd .. " " .. vim.fn.fnameescape(bib_file))
	vim.api.nvim_win_set_cursor(0, { metadata.line, 0 })
	return true
end

-- Follow the wiki-link under the cursor, opening the target note if present.
function notes.follow_wikilink()
	return follow_wikilink_with("edit")
end

-- Follow the wiki-link under the cursor in a horizontal split.
function notes.follow_wikilink_split()
	return follow_wikilink_with("split")
end

-- Follow the wiki-link under the cursor in a vertical split.
function notes.follow_wikilink_vsplit()
	return follow_wikilink_with("vsplit")
end

-- Follow the citation under the cursor, opening the bib file at that entry.
function notes.follow_citation()
	return follow_citation_with("edit")
end

-- Follow the citation under the cursor in a horizontal split.
function notes.follow_citation_split()
	return follow_citation_with("split")
end

-- Follow the citation under the cursor in a vertical split.
function notes.follow_citation_vsplit()
	return follow_citation_with("vsplit")
end

-- Follow either a wiki-link or citation under the cursor.
function notes.follow_link()
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	-- Try citation first
	if notes.follow_citation() then
		return true
	end

	-- Fall back to wikilink
	return notes.follow_wikilink()
end

-- Follow either a wiki-link or citation in a horizontal split.
function notes.follow_link_split()
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	if notes.follow_citation_split() then
		return true
	end

	return notes.follow_wikilink_split()
end

-- Follow either a wiki-link or citation in a vertical split.
function notes.follow_link_vsplit()
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	if notes.follow_citation_vsplit() then
		return true
	end

	return notes.follow_wikilink_vsplit()
end

-- Return to the previous note after following wiki-links.
function notes.go_back()
	local previous = table.remove(nav_stack)
	if not previous then
		return false
	end

	vim.cmd("edit " .. vim.fn.fnameescape(previous))
	return true
end

-- Apply configured key mappings to a buffer.
function notes.apply_mappings(buf)
	local target_buf = buf or 0
	local mappings = config.mappings or {}

	if mappings.follow then
		local follow_map = mappings.follow
		vim.keymap.set("n", follow_map, function()
			if not notes.follow_link() then
				local keys = vim.api.nvim_replace_termcodes(follow_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Follow wiki-link or citation" })
	end

	if mappings.follow_split then
		local split_map = mappings.follow_split
		vim.keymap.set("n", split_map, function()
			if not notes.follow_link_split() then
				local keys = vim.api.nvim_replace_termcodes(split_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Split and follow link" })
	end

	if mappings.follow_vsplit then
		local vsplit_map = mappings.follow_vsplit
		vim.keymap.set("n", vsplit_map, function()
			if not notes.follow_link_vsplit() then
				local keys = vim.api.nvim_replace_termcodes(vsplit_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Vertical split and follow link" })
	end

	if mappings.back then
		local back_map = mappings.back
		vim.keymap.set("n", back_map, function()
			if not notes.go_back() then
				local keys = vim.api.nvim_replace_termcodes(back_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Notes back" })
	end

	if mappings.backlinks then
		vim.keymap.set("n", mappings.backlinks, function()
			notes.find_backlinks()
		end, { buffer = target_buf, silent = true, desc = "Notes backlinks" })
	end

	if mappings.daily_note then
		vim.keymap.set("n", mappings.daily_note, function()
			notes.open_daily_note()
		end, { buffer = target_buf, silent = true, desc = "Open daily note" })
	end

	if mappings.reference_note then
		vim.keymap.set("n", mappings.reference_note, function()
			notes.open_reference_note()
		end, { buffer = target_buf, silent = true, desc = "Open reference note" })
	end

	if mappings.next_wikilink then
		local next_map = mappings.next_wikilink
		vim.keymap.set("n", next_map, function()
			if not notes.jump_to_next_wikilink() then
				local keys = vim.api.nvim_replace_termcodes(next_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Jump to next wiki-link" })
	end

	if mappings.prev_wikilink then
		local prev_map = mappings.prev_wikilink
		vim.keymap.set("n", prev_map, function()
			if not notes.jump_to_prev_wikilink() then
				local keys = vim.api.nvim_replace_termcodes(prev_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Jump to previous wiki-link" })
	end
end

local function trim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function yaml_escape(value)
	return value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
end

local latex_command_map = {
	["\\ae"] = "ae",
	["\\AE"] = "AE",
	["\\oe"] = "oe",
	["\\OE"] = "OE",
	["\\aa"] = "aa",
	["\\AA"] = "AA",
	["\\o"] = "o",
	["\\O"] = "O",
	["\\ss"] = "ss",
	["\\l"] = "l",
	["\\L"] = "L",
	["\\i"] = "i",
	["\\j"] = "j",
}

-- Convert common LaTeX accents/commands to ASCII equivalents.
local function latex_to_ascii(value)
	if not value then
		return value
	end

	local result = value
	result = result:gsub("\\([\"'`^~=%.uvHckr])%s*{(%a)}", "%2")
	result = result:gsub("\\([\"'`^~=%.uvHckr])(%a)", "%2")
	for latex, replacement in pairs(latex_command_map) do
		result = result:gsub(latex, replacement)
	end

	return result
end

-- Strip BibTeX title braces used for capitalization.
local function strip_bibtex_braces(value)
	if not value then
		return value
	end
	return value:gsub("[{}]", "")
end

-- Normalize BibTeX values for frontmatter.
local function normalize_bibtex_value(value)
	if not value then
		return value
	end
	return strip_bibtex_braces(latex_to_ascii(value))
end

-- Split a BibTeX author field into a list of names.
local function parse_authors(author_field)
	if not author_field or author_field == "" then
		return {}
	end

	local authors = {}
	for _, author in ipairs(vim.split(author_field, " and ", { plain = true, trimempty = true })) do
		local cleaned = trim(author)
		if cleaned ~= "" then
			table.insert(authors, cleaned)
		end
	end

	return authors
end

-- Build YAML frontmatter for a reference note.
local function reference_frontmatter_lines(citation_key, metadata)
	local title = normalize_bibtex_value(metadata.title or citation_key)
	local authors = parse_authors(metadata.author)
	local year = metadata.year or ""

	local lines = { "---" }
	table.insert(lines, 'title: "' .. yaml_escape(title) .. '"')
	if #authors > 0 then
		table.insert(lines, "authors:")
		for _, author in ipairs(authors) do
			local normalized_author = normalize_bibtex_value(author)
			table.insert(lines, '  - "' .. yaml_escape(normalized_author) .. '"')
		end
	else
		table.insert(lines, "authors: []")
	end
	table.insert(lines, 'year: "' .. yaml_escape(year) .. '"')
	table.insert(lines, "---")
	table.insert(lines, "")

	return lines
end

local function open_reference_note_for_entry(citation_key, metadata)
	local cwd = vim.fn.getcwd()
	local target = cwd .. "/" .. citation_key .. ".md"

	if vim.fn.filereadable(target) == 0 then
		local lines = reference_frontmatter_lines(citation_key, metadata)
		local ok = pcall(vim.fn.writefile, lines, target)
		if not ok then
			vim.notify("notes.nvim: unable to create " .. target, vim.log.levels.ERROR)
			return false
		end
	end

	local current = vim.api.nvim_buf_get_name(0)
	if current ~= "" then
		table.insert(nav_stack, current)
	end

	vim.cmd("edit " .. vim.fn.fnameescape(target))
	return true
end

-- Open or create a reference note for the given citation key.
function notes.open_reference_note_for_key(citation_key)
	if not citation_key or citation_key == "" then
		return false
	end

	if not config.bib_file then
		vim.notify("notes.nvim: bib_file not configured", vim.log.levels.WARN)
		return false
	end

	local bib_file = vim.fn.expand(config.bib_file)
	local metadata = citation.get_citation_metadata(bib_file, citation_key)
	if not metadata then
		vim.notify("notes.nvim: citation key '" .. citation_key .. "' not found in bib file", vim.log.levels.WARN)
		return false
	end

	return open_reference_note_for_entry(citation_key, metadata)
end

local function build_reference_items(entries)
	local keys = {}
	for key, _ in pairs(entries) do
		table.insert(keys, key)
	end
	table.sort(keys)

	local items = {}
	for _, key in ipairs(keys) do
		local entry = entries[key] or {}
		table.insert(items, {
			key = key,
			line = entry.line,
			title = entry.title,
			author = entry.author,
			year = entry.year,
			display = key,
			ordinal = table.concat({ key, entry.title or "", entry.author or "", entry.year or "" }, " "),
		})
	end

	return items
end

-- Select a citation key and open/create its reference note.
function notes.open_reference_note()
	if not config.bib_file then
		vim.notify("notes.nvim: bib_file not configured", vim.log.levels.WARN)
		return false
	end

	local bib_file = vim.fn.expand(config.bib_file)
	local entries, err = citation.parse_bib_file(bib_file)
	if not entries then
		vim.notify("notes.nvim: " .. (err or "Failed to load citations"), vim.log.levels.WARN)
		return false
	end

	local items = build_reference_items(entries)
	if #items == 0 then
		vim.notify("notes.nvim: no citations found in bib file", vim.log.levels.WARN)
		return false
	end

	local ok_telescope, _ = pcall(require, "telescope")
	if ok_telescope then
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local previewers = require("telescope.previewers")
		local previewers_utils = require("telescope.previewers.utils")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers
			.new({}, {
				prompt_title = "Reference Notes",
				finder = finders.new_table({
					results = items,
					entry_maker = function(item)
						return {
							value = item,
							display = item.display,
							ordinal = item.ordinal,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				previewer = previewers.new_buffer_previewer({
					title = "BibTeX",
					define_preview = function(self, entry)
						local ok, lines = pcall(vim.fn.readfile, bib_file)
						if not ok then
							lines = { "" }
						elseif #lines == 0 then
							lines = { "" }
						end
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
						vim.bo[self.state.bufnr].filetype = "bib"
						previewers_utils.highlighter(self.state.bufnr, "bib")

						pcall(vim.api.nvim_win_set_buf, self.state.winid, self.state.bufnr)
						local line_count = vim.api.nvim_buf_line_count(self.state.bufnr)
						if line_count < 1 then
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "" })
							line_count = 1
						end

						local line = 1
						if entry and entry.value and entry.value.line then
							if entry.value.line >= 1 and entry.value.line <= line_count then
								line = entry.value.line
								vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, "Visual", line - 1, 0, -1)
							end
						end

						if line < 1 then
							line = 1
						elseif line > line_count then
							line = line_count
						end

						pcall(vim.api.nvim_win_set_cursor, self.state.winid, { line, 0 })
					end,
				}),
				attach_mappings = function(prompt_bufnr)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						if selection and selection.value then
							notes.open_reference_note_for_key(selection.value.key)
						end
					end)
					return true
				end,
			})
			:find()

		return true
	end

	vim.ui.select(items, {
		prompt = "Reference Notes",
		format_item = function(item)
			return item.display
		end,
	}, function(choice)
		if choice then
			notes.open_reference_note_for_key(choice.key)
		end
	end)

	return true
end

-- Apply back mapping only (for non-markdown buffers like bib files).
function notes.apply_back_mapping(buf)
	local target_buf = buf or 0
	local mappings = config.mappings or {}

	if mappings.back then
		local back_map = mappings.back
		vim.keymap.set("n", back_map, function()
			if not notes.go_back() then
				local keys = vim.api.nvim_replace_termcodes(back_map, true, false, true)
				vim.api.nvim_feedkeys(keys, "n", false)
			end
		end, { buffer = target_buf, silent = true, desc = "Notes back" })
	end
end

-- Find backlinks to the current note and populate the quickfix list.
function notes.find_backlinks()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" then
		vim.notify("notes.nvim: current buffer has no filename", vim.log.levels.WARN)
		return false
	end

	local stem = vim.fn.fnamemodify(bufname, ":t:r")
	if stem == "" then
		vim.notify("notes.nvim: unable to determine note name", vim.log.levels.WARN)
		return false
	end

	if vim.fn.executable("rg") == 0 then
		vim.notify("notes.nvim: ripgrep (rg) is required for backlinks", vim.log.levels.ERROR)
		return false
	end

	local cwd = vim.fn.getcwd()
	local pattern = "[[" .. stem .. "]]"
	local cmd = { "rg", "--vimgrep", "--fixed-strings", "--glob", "*.md", pattern, cwd }
	local output = vim.fn.systemlist(cmd)
	local exit_code = vim.v.shell_error
	if exit_code > 1 then
		vim.notify("notes.nvim: ripgrep failed while searching backlinks", vim.log.levels.ERROR)
		return false
	end

	local items = {}
	for _, line in ipairs(output) do
		local filename, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
		if filename then
			table.insert(items, {
				filename = filename,
				lnum = tonumber(lnum),
				col = tonumber(col),
				text = text,
			})
		end
	end

	vim.fn.setqflist({}, "r", {
		title = "Backlinks: " .. stem,
		items = items,
	})
	vim.cmd("copen")
	return true
end

-- Open or create the daily note for today.
function notes.open_daily_note()
	local cwd = vim.fn.getcwd()
	local filename = date.daily_filename()
	local target = cwd .. "/" .. filename

	if vim.fn.filereadable(target) == 0 then
		local title = date.daily_title()
		local ok = pcall(vim.fn.writefile, { "# " .. title }, target)
		if not ok then
			vim.notify("notes.nvim: unable to create " .. target, vim.log.levels.ERROR)
			return false
		end
	end

	vim.cmd("edit " .. vim.fn.fnameescape(target))
	return true
end

-- Jump to the next wiki-link in the buffer.
function notes.jump_to_next_wikilink()
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1]
	local cursor_col0 = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = wikilink.cursor_pos_from_col(cursor_col0)

	-- Search current line first
	local next_pos = wikilink.find_next_wikilink(line, cursor_pos)
	if next_pos then
		vim.api.nvim_win_set_cursor(0, { row, next_pos - 1 })
		return true
	end

	-- Search subsequent lines
	local total_lines = vim.api.nvim_buf_line_count(0)
	for i = row + 1, total_lines do
		local next_line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
		next_pos = wikilink.find_next_wikilink(next_line, 0)
		if next_pos then
			vim.api.nvim_win_set_cursor(0, { i, next_pos - 1 })
			return true
		end
	end

	return false
end

-- Jump to the previous wiki-link in the buffer.
function notes.jump_to_prev_wikilink()
	if vim.bo.filetype ~= "markdown" then
		return false
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1]
	local cursor_col0 = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local cursor_pos = wikilink.cursor_pos_from_col(cursor_col0)

	-- Search current line first
	local prev_pos = wikilink.find_prev_wikilink(line, cursor_pos)
	if prev_pos then
		vim.api.nvim_win_set_cursor(0, { row, prev_pos - 1 })
		return true
	end

	-- Search previous lines
	for i = row - 1, 1, -1 do
		local prev_line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
		-- Find the last wikilink on this line
		prev_pos = wikilink.find_prev_wikilink(prev_line, #prev_line + 1)
		if prev_pos then
			vim.api.nvim_win_set_cursor(0, { i, prev_pos - 1 })
			return true
		end
	end

	return false
end

return notes
