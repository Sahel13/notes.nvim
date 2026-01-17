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
        assert.equals(0, #vim.fn.readfile(missing_path))

        vim.api.nvim_buf_delete(0, { force = true })
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

      assert.is_true(has_mapping("Follow wiki-link", "gF"))
      assert.is_true(has_mapping("Notes back", "gB"))
      assert.is_false(has_mapping("Notes backlinks", "<leader>nb"))
    end)

    notes.setup({
      mappings = {
        follow = "<CR>",
        back = "<BS>",
        backlinks = "<leader>nb",
      },
    })
  end)
end)
