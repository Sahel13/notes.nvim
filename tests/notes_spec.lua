describe("notes.nvim", function()
  it("loads the module", function()
    local notes = require("notes")
    assert.is_table(notes)
    assert.is_function(notes.new)
  end)

  it("adds closing brackets to wiki-link completions when missing", function()
    local notes = require("notes")
    local source = notes.new()
    local original_cwd = vim.fn.getcwd()
    local tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    vim.fn.writefile({ "# alpha" }, tmp_dir .. "/alpha.md")

    vim.cmd("cd " .. vim.fn.fnameescape(tmp_dir))
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo.filetype = "markdown"

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

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
  end)
end)
