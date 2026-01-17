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
end)
