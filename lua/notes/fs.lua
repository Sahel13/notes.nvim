local M = {}
local reference_dir_name = "references"

-- Return the references subdirectory for the given cwd.
function M.reference_dir(cwd)
	return cwd .. "/" .. reference_dir_name
end

-- Return sorted note name stems for Markdown files in cwd (including references).
function M.list_note_stems(cwd)
	local stems = {}
	local seen = {}

	local function add_stem(stem)
		if stem ~= "" and not seen[stem] then
			seen[stem] = true
			table.insert(stems, stem)
		end
	end

	local function scan_dir(dir)
		if vim.fs and vim.fs.dir then
			local ok, iter = pcall(vim.fs.dir, dir)
			if ok then
				for name, type in iter do
					if type == "file" and name:sub(-3) == ".md" then
						local stem = name:sub(1, -4)
						add_stem(stem)
					end
				end
				return true
			end
		end
		return false
	end

	local function scan_glob(dir)
		local matches = vim.fn.globpath(dir, "*.md", false, true)
		for _, path in ipairs(matches) do
			local name = vim.fn.fnamemodify(path, ":t")
			local stem = name:sub(1, -4)
			add_stem(stem)
		end
	end

	if not scan_dir(cwd) then
		scan_glob(cwd)
	end

	local references_dir = M.reference_dir(cwd)
	if vim.fn.isdirectory(references_dir) == 1 then
		if not scan_dir(references_dir) then
			scan_glob(references_dir)
		end
	end

	table.sort(stems)
	return stems
end

return M
