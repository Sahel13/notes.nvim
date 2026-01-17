local M = {}

-- Return sorted note name stems for Markdown files in cwd.
function M.list_note_stems(cwd)
  local stems = {}
  local seen = {}

  local used_fs = false
  if vim.fs and vim.fs.dir then
    local ok, iter = pcall(vim.fs.dir, cwd)
    if ok then
      used_fs = true
      for name, type in iter do
        if type == "file" and name:sub(-3) == ".md" then
          local stem = name:sub(1, -4)
          if stem ~= "" and not seen[stem] then
            seen[stem] = true
            table.insert(stems, stem)
          end
        end
      end
    end
  end

  if not used_fs then
    local matches = vim.fn.globpath(cwd, "*.md", false, true)
    for _, path in ipairs(matches) do
      local name = vim.fn.fnamemodify(path, ":t")
      local stem = name:sub(1, -4)
      if stem ~= "" and not seen[stem] then
        seen[stem] = true
        table.insert(stems, stem)
      end
    end
  end

  table.sort(stems)
  return stems
end

return M
