local citation = require("notes.citation")

describe("notes.citation", function()
	describe("cursor_pos_from_col", function()
		it("converts 0-based column to 1-based position", function()
			assert.equals(1, citation.cursor_pos_from_col(0))
			assert.equals(5, citation.cursor_pos_from_col(4))
			assert.equals(100, citation.cursor_pos_from_col(99))
		end)
	end)

	describe("citation_bounds", function()
		it("finds citation bounds when cursor is inside []", function()
			local open, close = citation.citation_bounds("[@key]", 3)
			assert.equals(1, open)
			assert.equals(6, close)
		end)

		it("returns nil when cursor is outside []", function()
			assert.is_nil(citation.citation_bounds("text [@key]", 1))
			assert.is_nil(citation.citation_bounds("[@key]", 7))
		end)

		it("finds the correct [] when multiple exist", function()
			local open, close = citation.citation_bounds("[text] [@key]", 10)
			assert.equals(8, open)
			assert.equals(13, close)
		end)

		it("handles incomplete citation (no closing bracket)", function()
			local open, close = citation.citation_bounds("[@key", 3)
			assert.equals(1, open)
			assert.is_nil(close)
		end)
	end)

	describe("parse_bib_entry", function()
		it("parses article entry", function()
			local key, line = citation.parse_bib_entry("@article{lindley1956measure,")
			assert.equals("lindley1956measure", key)
		end)

		it("parses book entry", function()
			local key, line = citation.parse_bib_entry("@book{smith2020learning,")
			assert.equals("smith2020learning", key)
		end)

		it("handles whitespace variations", function()
			local key, line = citation.parse_bib_entry("  @article  {  key123  ,  ")
			assert.equals("key123", key)
		end)

		it("handles keys with hyphens and colons", function()
			local key, line = citation.parse_bib_entry("@article{doe:2020-learning,")
			assert.equals("doe:2020-learning", key)
		end)

		it("returns nil for non-entry lines", function()
			assert.is_nil(citation.parse_bib_entry("  title = {Some Title},"))
			assert.is_nil(citation.parse_bib_entry("  author = {John Doe},"))
		end)

		it("returns nil for malformed entries", function()
			assert.is_nil(citation.parse_bib_entry("@article{"))
			assert.is_nil(citation.parse_bib_entry("@article"))
		end)
	end)

	describe("parse_bib_file", function()
		local temp_file

		before_each(function()
			temp_file = os.tmpname()
		end)

		after_each(function()
			if temp_file then
				os.remove(temp_file)
			end
		end)

		it("parses a simple bib file", function()
			local content = [[
@article{key1,
  title = {First Article},
  author = {John Doe},
  year = {2020}
}

@book{key2,
  title = {Second Book},
  author = {Jane Smith},
  year = {2021}
}
]]
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()

			local entries = citation.parse_bib_file(temp_file)
			assert.is_not_nil(entries)
			assert.is_not_nil(entries.key1)
			assert.is_not_nil(entries.key2)
			assert.equals(1, entries.key1.line)
			assert.equals("First Article", entries.key1.title)
			assert.equals("John Doe", entries.key1.author)
			assert.equals("2020", entries.key1.year)
		end)

		it("parses titles with nested braces", function()
			local content = [[
@article{key1,
  title = {User-friendly introduction to {PAC-Bayes} bounds},
  author = {Jane Doe},
  year = {2022}
}
]]
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()

			local entries = citation.parse_bib_file(temp_file)
			assert.is_not_nil(entries)
			assert.equals("User-friendly introduction to {PAC-Bayes} bounds", entries.key1.title)
		end)

		it("does not treat booktitle as title", function()
			local content = [[
@inproceedings{key1,
  title = {Actual Title},
  booktitle = {Conference Name},
  year = {2012}
}
]]
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()

			local entries = citation.parse_bib_file(temp_file)
			assert.is_not_nil(entries)
			assert.equals("Actual Title", entries.key1.title)
		end)

		it("handles entries without metadata", function()
			local content = [[
@article{key1,
}
]]
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()

			local entries = citation.parse_bib_file(temp_file)
			assert.is_not_nil(entries)
			assert.is_not_nil(entries.key1)
			assert.equals(1, entries.key1.line)
		end)

		it("returns nil for non-existent file", function()
			local entries, err = citation.parse_bib_file("/nonexistent/file.bib")
			assert.is_nil(entries)
			assert.is_not_nil(err)
		end)

		it("caches parsed entries", function()
			local content = "@article{key1,\n}\n"
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()

			local entries1 = citation.parse_bib_file(temp_file)
			local entries2 = citation.parse_bib_file(temp_file)
			-- Should return same cached table
			assert.equals(entries1, entries2)
		end)
	end)

	describe("get_citation_keys", function()
		local temp_file

		before_each(function()
			temp_file = os.tmpname()
			local content = [[
@article{zebra2020,
}
@book{alpha2021,
}
@inproceedings{beta2019,
}
]]
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()
		end)

		after_each(function()
			if temp_file then
				os.remove(temp_file)
			end
		end)

		it("returns sorted list of citation keys", function()
			local keys = citation.get_citation_keys(temp_file)
			assert.is_not_nil(keys)
			assert.equals(3, #keys)
			-- Should be sorted alphabetically
			assert.equals("alpha2021", keys[1])
			assert.equals("beta2019", keys[2])
			assert.equals("zebra2020", keys[3])
		end)
	end)

	describe("get_citation_metadata", function()
		local temp_file

		before_each(function()
			temp_file = os.tmpname()
			local content = [[
@article{key1,
  title = {Test Article},
  author = {Test Author},
  year = {2020}
}
]]
			local file = io.open(temp_file, "w")
			file:write(content)
			file:close()
		end)

		after_each(function()
			if temp_file then
				os.remove(temp_file)
			end
		end)

		it("returns metadata for existing key", function()
			local metadata = citation.get_citation_metadata(temp_file, "key1")
			assert.is_not_nil(metadata)
			assert.equals(1, metadata.line)
			assert.equals("Test Article", metadata.title)
			assert.equals("Test Author", metadata.author)
			assert.equals("2020", metadata.year)
		end)

		it("returns nil for non-existent key", function()
			local metadata = citation.get_citation_metadata(temp_file, "nonexistent")
			assert.is_nil(metadata)
		end)
	end)

	describe("citation_range", function()
		local original_vim

		before_each(function()
			original_vim = _G.vim
		end)

		after_each(function()
			_G.vim = original_vim
		end)

		it("returns nil when not in a citation context", function()
			-- Mock vim API
			_G.vim = {
				api = {
					nvim_win_get_cursor = function()
						return { 1, 5 }
					end,
					nvim_get_current_line = function()
						return "plain text"
					end,
				},
			}
			assert.is_nil(citation.citation_range())
		end)

		it("detects citation context after [@", function()
			_G.vim = {
				api = {
					nvim_win_get_cursor = function()
						return { 1, 2 }
					end,
					nvim_get_current_line = function()
						return "[@key]"
					end,
				},
			}
			local range = citation.citation_range()
			assert.is_not_nil(range)
		end)
	end)

	describe("closing_suffix", function()
		it("returns empty string when ] is next", function()
			assert.equals("", citation.closing_suffix("[@key]", 5))
		end)

		it("returns ] when not present", function()
			assert.equals("]", citation.closing_suffix("[@key", 5))
		end)
	end)
end)
