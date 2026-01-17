local fs = require("notes.fs")

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

describe("notes.fs", function()
  it("lists note stems from markdown files", function()
    with_temp_dir({
      { name = "alpha.md", lines = { "# alpha" } },
      { name = "beta.md", lines = { "# beta" } },
      { name = "project-notes.md", lines = { "# project notes" } },
    }, function(tmp_dir)
      local stems = fs.list_note_stems(tmp_dir)
      table.sort(stems)
      assert.equals(3, #stems)
      assert.equals("alpha", stems[1])
      assert.equals("beta", stems[2])
      assert.equals("project-notes", stems[3])
    end)
  end)

  it("excludes non-markdown files", function()
    with_temp_dir({
      { name = "note.md", lines = { "# note" } },
      { name = "readme.txt", lines = { "readme" } },
      { name = "data.json", lines = { "{}" } },
    }, function(tmp_dir)
      local stems = fs.list_note_stems(tmp_dir)
      table.sort(stems)
      assert.equals(1, #stems)
      assert.equals("note", stems[1])
    end)
  end)

  it("handles empty directory", function()
    with_temp_dir({}, function(tmp_dir)
      local stems = fs.list_note_stems(tmp_dir)
      assert.equals(0, #stems)
    end)
  end)

  it("handles files with duplicate stems", function()
    with_temp_dir({
      { name = "note.md", lines = { "# note" } },
      { name = "note.txt", lines = { "note" } },
    }, function(tmp_dir)
      local stems = fs.list_note_stems(tmp_dir)
      table.sort(stems)
      assert.equals(1, #stems)
      assert.equals("note", stems[1])
    end)
  end)

  it("handles files with dots in names", function()
    with_temp_dir({
      { name = "project.v2.notes.md", lines = { "# project v2" } },
    }, function(tmp_dir)
      local stems = fs.list_note_stems(tmp_dir)
      table.sort(stems)
      assert.equals(1, #stems)
      assert.equals("project.v2.notes", stems[1])
    end)
  end)

  it("sorts stems alphabetically", function()
    with_temp_dir({
      { name = "zebra.md", lines = { "# zebra" } },
      { name = "alpha.md", lines = { "# alpha" } },
      { name = "beta.md", lines = { "# beta" } },
    }, function(tmp_dir)
      local stems = fs.list_note_stems(tmp_dir)
      assert.equals("alpha", stems[1])
      assert.equals("beta", stems[2])
      assert.equals("zebra", stems[3])
    end)
  end)
end)
