local function with_temp_dir(files, fn)
	local original_cwd = vim.fn.getcwd()
	local tmp_dir = vim.fn.tempname()
	vim.fn.mkdir(tmp_dir, "p")

	for _, file in ipairs(files or {}) do
		vim.fn.writefile(file.lines, tmp_dir .. "/" .. file.name)
	end

	vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
	local ok, err = pcall(fn, tmp_dir)
	vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
	if not ok then
		error(err)
	end
end

local function with_markdown_buf(fn)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	vim.bo.filetype = "markdown"
	local ok, err = pcall(fn, buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
	if not ok then
		error(err)
	end
end

local function with_stubbed(target, key, value, fn)
	local original = target[key]
	target[key] = value
	local ok, err = pcall(fn)
	target[key] = original
	if not ok then
		error(err)
	end
end

local function clear_nav_stack(notes)
	while notes.go_back() do
		-- keep going
	end
end

describe("notes.nvim", function()
	it("loads the module", function()
		local notes = require("notes")
		assert.is_table(notes)
		assert.is_function(notes.new)
	end)

	it("adds closing brackets to wiki-link completions when missing", function()
		local notes = require("notes")
		local source = notes.new()
		with_temp_dir({
			{ name = "alpha.md", lines = { "# alpha" } },
		}, function()
			with_markdown_buf(function()
				local function fetch_alpha_new_text(line, col)
					vim.api.nvim_set_current_line(line)
					vim.api.nvim_win_set_cursor(0, { 1, col })
					local result
					source:get_completions({}, function(res)
						result = res
					end)
					assert.is_table(result)
					local alpha_item
					for _, item in ipairs(result.items or {}) do
						if item.label == "alpha" then
							alpha_item = item
							break
						end
					end
					assert.is_table(alpha_item)
					return alpha_item.textEdit.newText
				end

				local missing_both = fetch_alpha_new_text("[[al", 4)
				assert.equals("alpha]]", missing_both)

				local missing_one = fetch_alpha_new_text("[[al]", 4)
				assert.equals("alpha]", missing_one)

				local missing_none = fetch_alpha_new_text("[[al]]", 4)
				assert.equals("alpha", missing_none)
			end)
		end)
	end)

	it("does not offer completions when cursor is outside wiki-link bounds", function()
		local notes = require("notes")
		local source = notes.new()
		with_temp_dir({
			{ name = "alpha.md", lines = { "# alpha" } },
		}, function()
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("[[alpha]] trailing")
				vim.api.nvim_win_set_cursor(0, { 1, 12 })

				local result
				source:get_completions({}, function(res)
					result = res
				end)

				assert.is_table(result)
				assert.equals(0, #result.items)
			end)
		end)
	end)

	it("follows wiki-links under the cursor", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "A.md", lines = { "# A", "[[B]]" } },
			{ name = "B.md", lines = { "# B" } },
		}, function()
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("[[B]]")
				vim.api.nvim_win_set_cursor(0, { 1, 2 })

				local handled = notes.follow_wikilink()
				assert.is_true(handled)
				assert.equals("B.md", vim.fn.expand("%:t"))

				vim.api.nvim_buf_delete(0, { force = true })
			end)
		end)
	end)

	it("does not warn about missing bib_file when following wiki-links", function()
		local notes = require("notes")
		notes.setup({ bib_file = nil })
		with_temp_dir({
			{ name = "B.md", lines = { "# B" } },
		}, function()
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("[[B]]")
				vim.api.nvim_win_set_cursor(0, { 1, 2 })

				local notices = {}
				with_stubbed(vim, "notify", function(msg, level)
					table.insert(notices, { msg = msg, level = level })
				end, function()
					local handled = notes.follow_link()
					assert.is_true(handled)
					assert.equals("B.md", vim.fn.expand("%:t"))
				end)

				assert.equals(0, #notices)
				vim.api.nvim_buf_delete(0, { force = true })
			end)
		end)
	end)

	it("creates missing notes when following wiki-links", function()
		local notes = require("notes")
		with_temp_dir({}, function(tmp_dir)
			local missing_path = tmp_dir .. "/missing.md"
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("[[missing]]")
				vim.api.nvim_win_set_cursor(0, { 1, 3 })

				local handled = notes.follow_wikilink()
				assert.is_true(handled)
				assert.equals("missing.md", vim.fn.expand("%:t"))
				assert.equals(1, vim.fn.filereadable(missing_path))
				assert.same({ "# missing" }, vim.fn.readfile(missing_path))

				vim.api.nvim_buf_delete(0, { force = true })
			end)
		end)
	end)

	it("follows wiki-links in a split", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "A.md", lines = { "# A", "[[B]]" } },
			{ name = "B.md", lines = { "# B" } },
		}, function(tmp_dir)
			vim.cmd("only")
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/A.md"))
			vim.bo.filetype = "markdown"
			vim.api.nvim_win_set_cursor(0, { 2, 2 })

			local win_count_before = #vim.api.nvim_list_wins()
			local handled = notes.follow_wikilink_split()
			assert.is_true(handled)
			assert.equals(win_count_before + 1, #vim.api.nvim_list_wins())
			assert.equals("B.md", vim.fn.expand("%:t"))

			vim.cmd("only")
			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
			clear_nav_stack(notes)
		end)
	end)

	it("creates missing notes when following wiki-links in a vertical split", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "A.md", lines = { "# A", "[[missing]]" } },
		}, function(tmp_dir)
			local missing_path = tmp_dir .. "/missing.md"
			vim.cmd("only")
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/A.md"))
			vim.bo.filetype = "markdown"
			vim.api.nvim_win_set_cursor(0, { 2, 3 })

			local win_count_before = #vim.api.nvim_list_wins()
			local handled = notes.follow_wikilink_vsplit()
			assert.is_true(handled)
			assert.equals(win_count_before + 1, #vim.api.nvim_list_wins())
			assert.equals("missing.md", vim.fn.expand("%:t"))
			assert.equals(1, vim.fn.filereadable(missing_path))

			vim.cmd("only")
			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
			clear_nav_stack(notes)
		end)
	end)

	it("follows citations in a split", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "A.md", lines = { "# A", "See [@doe2020]" } },
			{
				name = "refs.bib",
				lines = {
					"@article{doe2020,",
					"  title = {Example},",
					"  author = {Doe, Jane},",
					"  year = {2020}",
					"}",
				},
			},
		}, function(tmp_dir)
			notes.setup({ bib_file = tmp_dir .. "/refs.bib" })
			vim.cmd("only")
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/A.md"))
			vim.bo.filetype = "markdown"
			vim.api.nvim_win_set_cursor(0, { 2, 7 })

			local win_count_before = #vim.api.nvim_list_wins()
			local handled = notes.follow_link_split()
			assert.is_true(handled)
			assert.equals(win_count_before + 1, #vim.api.nvim_list_wins())
			assert.equals("refs.bib", vim.fn.expand("%:t"))

			vim.cmd("only")
			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
			clear_nav_stack(notes)
			notes.setup({ bib_file = nil })
		end)
	end)

	it("does not overwrite existing notes when following wiki-links", function()
		local notes = require("notes")
		with_temp_dir({}, function(tmp_dir)
			local missing_path = tmp_dir .. "/missing.md"
			with_markdown_buf(function(buf)
				vim.api.nvim_set_current_line("[[missing]]")
				vim.api.nvim_win_set_cursor(0, { 1, 3 })

				local handled = notes.follow_wikilink()
				assert.is_true(handled)
				assert.equals("missing.md", vim.fn.expand("%:t"))
				assert.same({ "# missing" }, vim.fn.readfile(missing_path))

				vim.fn.writefile({ "# missing", "", "extra" }, missing_path)
				vim.api.nvim_set_current_buf(buf)
				vim.api.nvim_set_current_line("[[missing]]")
				vim.api.nvim_win_set_cursor(0, { 1, 3 })

				local handled_again = notes.follow_wikilink()
				assert.is_true(handled_again)
				assert.same({ "# missing", "", "extra" }, vim.fn.readfile(missing_path))
			end)
		end)
	end)

	it("tracks navigation history for wiki-link jumps", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "A.md", lines = { "# A", "[[B]]", "[[C]]" } },
			{ name = "B.md", lines = { "# B" } },
			{ name = "C.md", lines = { "# C", "[[D]]" } },
			{ name = "D.md", lines = { "# D" } },
		}, function(tmp_dir)
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/A.md"))
			vim.bo.filetype = "markdown"

			vim.api.nvim_win_set_cursor(0, { 2, 2 })
			assert.is_true(notes.follow_wikilink())
			assert.equals("B.md", vim.fn.expand("%:t"))

			assert.is_true(notes.go_back())
			assert.equals("A.md", vim.fn.expand("%:t"))
			vim.bo.filetype = "markdown"

			vim.api.nvim_win_set_cursor(0, { 3, 2 })
			assert.is_true(notes.follow_wikilink())
			assert.equals("C.md", vim.fn.expand("%:t"))
			vim.bo.filetype = "markdown"

			vim.api.nvim_win_set_cursor(0, { 2, 2 })
			assert.is_true(notes.follow_wikilink())
			assert.equals("D.md", vim.fn.expand("%:t"))

			assert.is_true(notes.go_back())
			assert.equals("C.md", vim.fn.expand("%:t"))

			assert.is_true(notes.go_back())
			assert.equals("A.md", vim.fn.expand("%:t"))

			assert.is_false(notes.go_back())
		end)
	end)

	it("finds backlinks with ripgrep and populates quickfix list", function()
		local notes = require("notes")
		if vim.fn.executable("rg") == 0 then
			return
		end

		with_temp_dir({
			{ name = "target.md", lines = { "# target" } },
			{ name = "alpha.md", lines = { "# alpha", "See [[target]] here" } },
			{ name = "beta.md", lines = { "[[target]]" } },
		}, function(tmp_dir)
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/target.md"))
			vim.bo.filetype = "markdown"

			local handled = notes.find_backlinks()
			assert.is_true(handled)

			local qf = vim.fn.getqflist({ title = 1, items = 1 })
			assert.equals("Backlinks: target", qf.title)
			assert.equals(2, #qf.items)

			local filenames = {}
			for _, item in ipairs(qf.items) do
				local name = item.filename
				if name == nil or name == "" then
					name = vim.fn.bufname(item.bufnr)
				end
				if name ~= nil and name ~= "" then
					filenames[vim.fn.fnamemodify(name, ":t")] = item
				end
			end

			assert.is_table(filenames["alpha.md"])
			assert.is_table(filenames["beta.md"])
			assert.equals(2, filenames["alpha.md"].lnum)
			assert.equals(5, filenames["alpha.md"].col)

			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
		end)
	end)

	it("fails gracefully when ripgrep is unavailable", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "target.md", lines = { "# target" } },
		}, function(tmp_dir)
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/target.md"))
			vim.bo.filetype = "markdown"

			vim.fn.setqflist({}, "r", {
				title = "Existing",
				items = {
					{ filename = tmp_dir .. "/alpha.md", lnum = 1, col = 1, text = "dummy" },
				},
			})

			local notices = {}
			with_stubbed(vim.fn, "executable", function()
				return 0
			end, function()
				with_stubbed(vim, "notify", function(msg, level)
					table.insert(notices, { msg = msg, level = level })
				end, function()
					local handled = notes.find_backlinks()
					assert.is_false(handled)
				end)
			end)

			assert.is_true(#notices > 0)
			local qf = vim.fn.getqflist({ title = 1, items = 1 })
			assert.equals("Existing", qf.title)
			assert.equals(1, #qf.items)

			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
		end)
	end)

	it("allows mapping overrides via setup", function()
		local notes = require("notes")
		notes.setup({
			mappings = {
				follow = "gF",
				back = "gB",
				backlinks = false,
			},
		})

		with_markdown_buf(function(buf)
			vim.api.nvim_set_current_buf(buf)
			local calls = {}
			with_stubbed(vim.keymap, "set", function(mode, lhs, _, opts)
				table.insert(calls, { mode = mode, lhs = lhs, desc = opts and opts.desc or "" })
			end, function()
				notes.apply_mappings(buf)
			end)

			local function has_mapping(desc, lhs)
				for _, call in ipairs(calls) do
					if call.desc == desc and call.lhs == lhs then
						return true
					end
				end
				return false
			end

			assert.is_true(has_mapping("Follow wiki-link or citation", "gF"))
			assert.is_true(has_mapping("Notes back", "gB"))
			assert.is_false(has_mapping("Notes backlinks", "<leader>nb"))
		end)

		notes.setup({
			mappings = {
				follow = "<CR>",
				follow_split = "<S-CR>",
				follow_vsplit = "<C-CR>",
				back = "<BS>",
				backlinks = "<leader>nb",
				daily_note = "<leader>nd",
				next_wikilink = "<Tab>",
				prev_wikilink = "<S-Tab>",
			},
		})
	end)

	it("ships a non-Tree-sitter syntax highlight file for wiki-links", function()
		local source = debug.getinfo(1, "S").source
		local script = source
		if script:sub(1, 1) == "@" then
			script = script:sub(2)
		end
		local root = vim.fn.fnamemodify(script, ":h:h")
		local syntax_path = root .. "/after/syntax/markdown.vim"
		assert.equals(1, vim.fn.filereadable(syntax_path))

		local lines = vim.fn.readfile(syntax_path)
		local content = table.concat(lines, "\n")
		assert.is_true(content:find("markdownWikiLink") ~= nil)
		assert.is_true(content:find("markdownLinkText") ~= nil)
	end)

	it("creates daily note with correct filename and title", function()
		local notes = require("notes")
		local date = require("notes.date")

		with_temp_dir({}, function(tmp_dir)
			local timestamp = os.time({ year = 2026, month = 1, day = 17, hour = 12, min = 0, sec = 0 })
			local filename = date.daily_filename(timestamp)
			local title = date.daily_title(timestamp)
			local daily_path = tmp_dir .. "/" .. filename

			-- Stub the date functions to use our test timestamp
			local original_daily_filename = date.daily_filename
			local original_daily_title = date.daily_title
			date.daily_filename = function()
				return filename
			end
			date.daily_title = function()
				return title
			end

			with_markdown_buf(function()
				local handled = notes.open_daily_note()
				assert.is_true(handled)
				assert.equals(filename, vim.fn.expand("%:t"))
				assert.equals(1, vim.fn.filereadable(daily_path))
				assert.same({ "# " .. title }, vim.fn.readfile(daily_path))

				vim.api.nvim_buf_delete(0, { force = true })
			end)

			-- Restore original functions
			date.daily_filename = original_daily_filename
			date.daily_title = original_daily_title
		end)
	end)

	it("opens existing daily note without overwriting", function()
		local notes = require("notes")
		local date = require("notes.date")

		with_temp_dir({}, function(tmp_dir)
			local timestamp = os.time({ year = 2026, month = 1, day = 17, hour = 12, min = 0, sec = 0 })
			local filename = date.daily_filename(timestamp)
			local title = date.daily_title(timestamp)
			local daily_path = tmp_dir .. "/" .. filename

			-- Create existing daily note with content
			vim.fn.writefile({ "# " .. title, "", "Existing content" }, daily_path)

			-- Stub the date functions
			local original_daily_filename = date.daily_filename
			local original_daily_title = date.daily_title
			date.daily_filename = function()
				return filename
			end
			date.daily_title = function()
				return title
			end

			with_markdown_buf(function()
				local handled = notes.open_daily_note()
				assert.is_true(handled)
				assert.equals(filename, vim.fn.expand("%:t"))
				assert.same({ "# " .. title, "", "Existing content" }, vim.fn.readfile(daily_path))

				vim.api.nvim_buf_delete(0, { force = true })
			end)

			-- Restore original functions
			date.daily_filename = original_daily_filename
			date.daily_title = original_daily_title
		end)
	end)

	it("includes daily note mapping in apply_mappings", function()
		local notes = require("notes")
		notes.setup({
			mappings = {
				follow = "<CR>",
				back = "<BS>",
				backlinks = "<leader>nb",
				daily_note = "<leader>nd",
			},
		})

		with_markdown_buf(function(buf)
			vim.api.nvim_set_current_buf(buf)
			local calls = {}
			with_stubbed(vim.keymap, "set", function(mode, lhs, _, opts)
				table.insert(calls, { mode = mode, lhs = lhs, desc = opts and opts.desc or "" })
			end, function()
				notes.apply_mappings(buf)
			end)

			local function has_mapping(desc, lhs)
				for _, call in ipairs(calls) do
					if call.desc == desc and call.lhs == lhs then
						return true
					end
				end
				return false
			end

			assert.is_true(has_mapping("Open daily note", "<leader>nd"))
		end)
	end)

	it("handles self-referential links by opening the same buffer", function()
		local notes = require("notes")
		with_temp_dir({
			{ name = "recursive.md", lines = { "# Recursive", "[[recursive]]" } },
		}, function(tmp_dir)
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/recursive.md"))
			vim.bo.filetype = "markdown"
			vim.api.nvim_win_set_cursor(0, { 2, 4 })

			local handled = notes.follow_wikilink()
			assert.is_true(handled)
			assert.equals("recursive.md", vim.fn.expand("%:t"))

			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
		end)
	end)

	it("finds backlinks with note names containing special characters", function()
		local notes = require("notes")
		if vim.fn.executable("rg") == 0 then
			return
		end

		with_temp_dir({
			{ name = "target-note.md", lines = { "# target-note" } },
			{ name = "alpha.md", lines = { "# alpha", "See [[target-note]] here" } },
		}, function(tmp_dir)
			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/target-note.md"))
			vim.bo.filetype = "markdown"

			local handled = notes.find_backlinks()
			assert.is_true(handled)

			local qf = vim.fn.getqflist({ title = 1, items = 1 })
			assert.equals("Backlinks: target-note", qf.title)
			assert.equals(1, #qf.items)

			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
		end)
	end)

	it("jumps across multiple lines when finding next wikilink", function()
		local notes = require("notes")
		with_markdown_buf(function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"line 1",
				"line 2",
				"line 3",
				"line 4",
				"line 5 has [[link]]",
			})
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			local handled = notes.jump_to_next_wikilink()
			assert.is_true(handled)
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(5, cursor[1])
			-- Cursor position is 0-based, so "line 5 has [[link]]" has [[ at position 11 (0-based)
			assert.equals(11, cursor[2])
		end)
	end)

	it("jumps across multiple lines when finding previous wikilink", function()
		local notes = require("notes")
		with_markdown_buf(function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"line 1 has [[link]]",
				"line 2",
				"line 3",
				"line 4",
				"line 5",
			})
			vim.api.nvim_win_set_cursor(0, { 5, 0 })

			local handled = notes.jump_to_prev_wikilink()
			assert.is_true(handled)
			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(1, cursor[1])
			assert.equals(11, cursor[2])
		end)
	end)

	it("correctly disables individual mappings when set to false", function()
		local notes = require("notes")
		notes.setup({
			mappings = {
				follow = false,
				follow_split = false,
				follow_vsplit = false,
				back = false,
				backlinks = false,
				daily_note = false,
				next_wikilink = false,
				prev_wikilink = false,
			},
		})

		with_markdown_buf(function(buf)
			vim.api.nvim_set_current_buf(buf)
			local calls = {}
			with_stubbed(vim.keymap, "set", function(mode, lhs, _, opts)
				table.insert(calls, { mode = mode, lhs = lhs, desc = opts and opts.desc or "" })
			end, function()
				notes.apply_mappings(buf)
			end)

			assert.equals(0, #calls)
		end)

		-- Reset to defaults
		notes.setup({
			mappings = {
				follow = "<CR>",
				follow_split = "<S-CR>",
				follow_vsplit = "<C-CR>",
				back = "<BS>",
				backlinks = "<leader>nb",
				daily_note = "<leader>nd",
				next_wikilink = "<Tab>",
				prev_wikilink = "<S-Tab>",
			},
		})
	end)

	it("handles navigation stack with many jumps", function()
		local notes = require("notes")

		-- Clear any existing navigation history by going back until empty
		while notes.go_back() do
			-- Keep going back
		end

		with_temp_dir({}, function(tmp_dir)
			-- Create 20 notes
			for i = 1, 20 do
				local filename = string.format("note%02d.md", i)
				local next_note = i < 20 and string.format("note%02d", i + 1) or ""
				local content = { "# Note " .. i }
				if next_note ~= "" then
					table.insert(content, "[[" .. next_note .. "]]")
				end
				vim.fn.writefile(content, tmp_dir .. "/" .. filename)
			end

			vim.cmd("edit " .. vim.fn.fnameescape(tmp_dir .. "/note01.md"))
			vim.bo.filetype = "markdown"

			-- Follow links through all 20 notes
			for i = 1, 19 do
				vim.api.nvim_win_set_cursor(0, { 2, 2 })
				assert.is_true(notes.follow_wikilink())
				vim.bo.filetype = "markdown"
			end

			assert.equals("note20.md", vim.fn.expand("%:t"))

			-- Go back through all notes
			for i = 19, 1, -1 do
				assert.is_true(notes.go_back())
				local expected = string.format("note%02d.md", i)
				assert.equals(expected, vim.fn.expand("%:t"))
			end

			-- Should return false when stack is empty
			assert.is_false(notes.go_back())

			if vim.api.nvim_buf_is_valid(0) then
				vim.api.nvim_buf_delete(0, { force = true })
			end
		end)
	end)

	it("handles find_backlinks when buffer has no name", function()
		local notes = require("notes")
		with_markdown_buf(function()
			-- Buffer has no filename
			local notices = {}
			with_stubbed(vim, "notify", function(msg, level)
				table.insert(notices, { msg = msg, level = level })
			end, function()
				local handled = notes.find_backlinks()
				assert.is_false(handled)
			end)

			assert.is_true(#notices > 0)
			assert.is_true(notices[1].msg:find("no filename") ~= nil)
		end)
	end)

	describe("jump_to_next_wikilink", function()
		it("jumps to next wikilink on same line", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("text [[first]] and [[second]]")
				vim.api.nvim_win_set_cursor(0, { 1, 0 })

				local handled = notes.jump_to_next_wikilink()
				assert.is_true(handled)
				local cursor = vim.api.nvim_win_get_cursor(0)
				assert.equals(1, cursor[1])
				assert.equals(5, cursor[2])
			end)
		end)

		it("jumps to next wikilink on subsequent line", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_buf_set_lines(0, 0, -1, false, { "no link", "has [[link]]" })
				vim.api.nvim_win_set_cursor(0, { 1, 0 })

				local handled = notes.jump_to_next_wikilink()
				assert.is_true(handled)
				local cursor = vim.api.nvim_win_get_cursor(0)
				assert.equals(2, cursor[1])
				assert.equals(4, cursor[2])
			end)
		end)

		it("returns false when no wikilink found", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("no links here")
				vim.api.nvim_win_set_cursor(0, { 1, 0 })

				local handled = notes.jump_to_next_wikilink()
				assert.is_false(handled)
			end)
		end)

		it("skips to next line when no wikilink ahead on current line", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[first]] end", "[[second]]" })
				vim.api.nvim_win_set_cursor(0, { 1, 10 })

				local handled = notes.jump_to_next_wikilink()
				assert.is_true(handled)
				local cursor = vim.api.nvim_win_get_cursor(0)
				assert.equals(2, cursor[1])
				assert.equals(0, cursor[2])
			end)
		end)

		it("returns false for non-markdown buffers", function()
			local notes = require("notes")
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.bo.filetype = "text"

			vim.api.nvim_set_current_line("[[link]]")
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			local handled = notes.jump_to_next_wikilink()
			assert.is_false(handled)

			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end)
	end)

	describe("jump_to_prev_wikilink", function()
		it("jumps to previous wikilink on same line", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("[[first]] and [[second]]")
				vim.api.nvim_win_set_cursor(0, { 1, 20 })

				local handled = notes.jump_to_prev_wikilink()
				assert.is_true(handled)
				local cursor = vim.api.nvim_win_get_cursor(0)
				assert.equals(1, cursor[1])
				assert.equals(14, cursor[2])
			end)
		end)

		it("jumps to previous wikilink on previous line", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_buf_set_lines(0, 0, -1, false, { "has [[link]]", "no link" })
				vim.api.nvim_win_set_cursor(0, { 2, 0 })

				local handled = notes.jump_to_prev_wikilink()
				assert.is_true(handled)
				local cursor = vim.api.nvim_win_get_cursor(0)
				assert.equals(1, cursor[1])
				assert.equals(4, cursor[2])
			end)
		end)

		it("returns false when no wikilink found", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_set_current_line("no links here")
				vim.api.nvim_win_set_cursor(0, { 1, 5 })

				local handled = notes.jump_to_prev_wikilink()
				assert.is_false(handled)
			end)
		end)

		it("finds last wikilink on previous line", function()
			local notes = require("notes")
			with_markdown_buf(function()
				vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[[first]] [[second]]", "text" })
				vim.api.nvim_win_set_cursor(0, { 2, 2 })

				local handled = notes.jump_to_prev_wikilink()
				assert.is_true(handled)
				local cursor = vim.api.nvim_win_get_cursor(0)
				assert.equals(1, cursor[1])
				assert.equals(10, cursor[2])
			end)
		end)

		it("returns false for non-markdown buffers", function()
			local notes = require("notes")
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.bo.filetype = "text"

			vim.api.nvim_set_current_line("[[link]]")
			vim.api.nvim_win_set_cursor(0, { 1, 5 })

			local handled = notes.jump_to_prev_wikilink()
			assert.is_false(handled)

			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end)
	end)
end)
