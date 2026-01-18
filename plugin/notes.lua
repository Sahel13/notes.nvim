local group = vim.api.nvim_create_augroup("notes.nvim", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "markdown",
	callback = function(event)
		require("notes").apply_mappings(event.buf)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "bib",
	callback = function(event)
		require("notes").apply_back_mapping(event.buf)
	end,
})
