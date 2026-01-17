local M = {}

-- Return the daily note filename for a given timestamp (YYYY-MM-DD.md).
function M.daily_filename(timestamp)
	timestamp = timestamp or os.time()
	return os.date("%Y-%m-%d", timestamp) .. ".md"
end

-- Return the daily note title for a given timestamp (Day, DD Month).
function M.daily_title(timestamp)
	timestamp = timestamp or os.time()
	local day_name = os.date("%A", timestamp)
	local day_num = tonumber(os.date("%d", timestamp))
	local month_name = os.date("%B", timestamp)

	return string.format("%s, %d %s", day_name, day_num, month_name)
end

return M
