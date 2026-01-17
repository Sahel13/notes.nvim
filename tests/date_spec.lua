describe("date module", function()
	it("loads the module", function()
		local date = require("notes.date")
		assert.is_table(date)
		assert.is_function(date.daily_filename)
		assert.is_function(date.daily_title)
	end)

	it("generates daily filename in YYYY-MM-DD.md format", function()
		local date = require("notes.date")

		-- Test with specific timestamp: 2026-01-17 12:00:00
		local timestamp = os.time({ year = 2026, month = 1, day = 17, hour = 12, min = 0, sec = 0 })
		local filename = date.daily_filename(timestamp)

		assert.equals("2026-01-17.md", filename)
	end)

	it("generates daily title with correct format", function()
		local date = require("notes.date")

		-- Test with specific timestamp: 2026-01-17 (Saturday)
		local timestamp = os.time({ year = 2026, month = 1, day = 17, hour = 12, min = 0, sec = 0 })
		local title = date.daily_title(timestamp)

		assert.equals("Saturday, 17 January", title)
	end)

	it("formats day numbers correctly without leading zeros", function()
		local date = require("notes.date")

		-- 1st day
		local ts1 = os.time({ year = 2026, month = 1, day = 1, hour = 12, min = 0, sec = 0 })
		assert.equals("Thursday, 1 January", date.daily_title(ts1))

		-- 11th day
		local ts11 = os.time({ year = 2026, month = 1, day = 11, hour = 12, min = 0, sec = 0 })
		assert.equals("Sunday, 11 January", date.daily_title(ts11))

		-- 21st day
		local ts21 = os.time({ year = 2026, month = 1, day = 21, hour = 12, min = 0, sec = 0 })
		assert.equals("Wednesday, 21 January", date.daily_title(ts21))

		-- 31st day
		local ts31 = os.time({ year = 2026, month = 1, day = 31, hour = 12, min = 0, sec = 0 })
		assert.equals("Saturday, 31 January", date.daily_title(ts31))
	end)

	it("uses current time when no timestamp provided", function()
		local date = require("notes.date")

		local filename = date.daily_filename()
		local title = date.daily_title()

		-- Should generate valid output (basic format checks)
		assert.is_true(filename:match("^%d%d%d%d%-%d%d%-%d%d%.md$") ~= nil)
		assert.is_true(title:match("^%w+, %d+ %w+$") ~= nil)
	end)
end)
