-- Source guidelines: https://cmp.saghen.dev/development/source-boilerplate.html
local notes = {}
-- Use blink kinds when available; fall back for headless tests.
local ok_types, blink_types = pcall(require, "blink.cmp.types")
local completion_kinds = ok_types and blink_types.CompletionItemKind or vim.lsp.protocol.CompletionItemKind

-- Return sorted note name stems for Markdown files in cwd.
local function list_note_stems(cwd)
  local stems = {}
  local seen = {}

  if vim.fs and vim.fs.dir then
    local ok, iter = pcall(vim.fs.dir, cwd)
    if ok then
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
  else
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

-- Return the completion range when the cursor is inside [[...]].
local function wikilink_range()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]
  local line = vim.api.nvim_get_current_line()
  local left = line:sub(1, col)
  local open_start = left:match(".*()%[%[")
  if not open_start then
    return nil
  end

  local close_before = left:match(".*()%]%]")
  if close_before and close_before > open_start then
    return nil
  end

  local keyword_start = open_start + 2
  return {
    line = row - 1,
    start_col = keyword_start - 1,
    end_col = col,
  }
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

-- Trigger completion when typing a bracket.
function notes:get_trigger_characters()
  return { "[" }
end

-- Provide wiki-link completions from Markdown files in :pwd.
function notes:get_completions(_, callback)
  local range = wikilink_range()
  if not range then
    callback({
      items = {},
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
    return
  end

  local cwd = vim.fn.getcwd()
  local stems = list_note_stems(cwd)
  local items = {}

  for _, stem in ipairs(stems) do
    table.insert(items, {
      label = stem,
      kind = completion_kinds.Text,
      textEdit = {
        newText = stem,
        range = {
          start = { line = range.line, character = range.start_col },
          ["end"] = { line = range.line, character = range.end_col },
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

return notes
