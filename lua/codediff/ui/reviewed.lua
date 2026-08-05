-- Session-local "reviewed" marks for explorer and history rows.
--
-- A mark records that the user has looked at one row during the current review
-- pass, so `]f`/`[f` can skip it. It is deliberately not persisted: the same
-- file is worth reviewing again in the next diff, and nothing here should
-- outlive the tab that owns the panel.
--
-- Both panels store their marks as a plain set on the panel object, keyed by
-- the two-part identity below.

local M = {}

-- The mark itself, plus the fixed two-cell slot file rows reserve for it, so
-- marking a row cannot shift the columns to its right. History commit rows
-- render the bare glyph in place of their expand chevron instead.
M.GLYPH = "✓"
M.MARKER = M.GLYPH .. " "
M.BLANK = "  "
M.HL = "CodeDiffExplorerReviewed"

--- Key identifying one reviewable row.
---
--- The scope is what makes a path unique within a panel: explorer rows are
--- scoped by group, because a path can appear under both Staged and Unstaged
--- and each copy is reviewed separately; history rows are scoped by commit hash.
--- @param scope string|nil Explorer group, or history commit hash
--- @param path string|nil
--- @return string|nil key nil when the row cannot be marked
function M.key(scope, path)
  if not scope or not path or scope == "" or path == "" then
    return nil
  end
  return scope .. ":" .. path
end

--- @param marks table<string, boolean>|nil
--- @return boolean
function M.is_marked(marks, scope, path)
  local key = M.key(scope, path)
  return key ~= nil and marks ~= nil and marks[key] == true
end

--- Flip the mark on one row.
--- @param marks table<string, boolean> Mutated in place
--- @return boolean|nil marked New state, or nil when the row cannot be marked
function M.toggle(marks, scope, path)
  local key = M.key(scope, path)
  if not key then
    return nil
  end
  if marks[key] then
    marks[key] = nil
    return false
  end
  marks[key] = true
  return true
end

--- The marker cell for a row, ready to hand to a renderer.
--- @return string text, string hl
function M.segment(marked)
  if marked then
    return M.MARKER, M.HL
  end
  return M.BLANK, "Normal"
end

--- The order to visit a flat list of rows in, looking for the next unreviewed
--- one. Shared by the explorer's file list and single-file history's commit
--- list, which walk identically over different rows.
---
--- With nothing selected (`current_index` 0) the whole list is fair game,
--- starting from the end the walk comes in from. Otherwise the walk stops at
--- the list edge unless `cycle` wraps it, and never revisits its starting row.
--- @param count integer Number of rows
--- @param current_index integer Selected row, or 0 for none
--- @param step integer 1 forwards, -1 back
--- @param cycle boolean Wrap around at the list edge
--- @return integer[] indices
function M.walk_order(count, current_index, step, cycle)
  local indices = {}

  if current_index == 0 then
    for offset = 1, count do
      indices[offset] = step > 0 and offset or count + 1 - offset
    end
    return indices
  end

  local limit
  if cycle then
    limit = count - 1
  else
    limit = step > 0 and count - current_index or current_index - 1
  end

  for offset = 1, limit do
    local index = current_index + offset * step
    if cycle then
      index = (index - 1) % count + 1
    end
    indices[offset] = index
  end
  return indices
end

return M
