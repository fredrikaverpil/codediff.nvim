-- Default file row: `[indent] [icon] [reviewed] filename [directory] [stats] [status]`.
-- The `[stats]` segment renders only when `explorer.line_stats.enabled = true`.
-- The `[reviewed]` slot is always two cells wide, so marking a row reviewed
-- tints it without shifting anything to its right.

local common = require("codediff.ui.explorer.formatters.common")
local stats = require("codediff.ui.explorer.formatters.stats")
local reviewed = require("codediff.ui.reviewed")

return function(ctx)
  local marker_text, marker_hl = reviewed.segment(ctx.reviewed)
  local name_hl = ctx.reviewed and reviewed.HL or "Normal"
  local directory_hl = ctx.reviewed and reviewed.HL or "ExplorerDirectorySmall"
  local left = {
    { segments = common.prefix(ctx) },
    { segments = { { text = marker_text, hl = marker_hl } } },
    {
      segments = { { text = ctx.filename, hl = name_hl } },
      truncate_priority = 2,
    },
  }
  if ctx.directory ~= "" then
    left[#left + 1] = {
      segments = {
        { text = " ", hl = name_hl },
        { text = ctx.directory, hl = directory_hl },
      },
      truncate_priority = 1,
    }
  end

  local right = {}
  local file_stats = stats.file_segments(ctx.stats)
  if #file_stats > 0 then
    file_stats[#file_stats + 1] = { text = " ", hl = "Normal" }
    right[#right + 1] = { segments = file_stats, truncate_priority = 3 }
  end
  right[#right + 1] = {
    segments = {
      { text = ctx.status, hl = ctx.status_hl },
      { text = string.rep(" ", ctx.status_right_margin), hl = "Normal" },
    },
  }

  return {
    left = left,
    right = right,
    min_gap = 2,
  }
end
