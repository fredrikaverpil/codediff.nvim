-- Reviewed-mark bookkeeping and the walk order both panels share.

local reviewed = require("codediff.ui.reviewed")

describe("reviewed marks", function()
  it("keys a row by scope and path, and refuses incomplete rows", function()
    assert.equals("unstaged:src/a.txt", reviewed.key("unstaged", "src/a.txt"))
    -- The same path under two groups is two independently reviewable rows.
    assert.equals("staged:src/a.txt", reviewed.key("staged", "src/a.txt"))
    assert.is_nil(reviewed.key(nil, "src/a.txt"))
    assert.is_nil(reviewed.key("unstaged", nil))
    assert.is_nil(reviewed.key("", "src/a.txt"))
    assert.is_nil(reviewed.key("unstaged", ""))
  end)

  it("toggles a mark on and back off in place", function()
    local marks = {}

    assert.is_true(reviewed.toggle(marks, "unstaged", "a.txt"))
    assert.is_true(reviewed.is_marked(marks, "unstaged", "a.txt"))
    -- A path marked in one group is untouched in another.
    assert.is_false(reviewed.is_marked(marks, "staged", "a.txt"))

    assert.is_false(reviewed.toggle(marks, "unstaged", "a.txt"))
    assert.is_false(reviewed.is_marked(marks, "unstaged", "a.txt"))
    -- Unmarking clears the key rather than storing false, so `next()` can be
    -- used to ask whether any marks exist at all.
    assert.is_nil(next(marks))
  end)

  it("reports unmarkable rows without touching the set", function()
    local marks = {}
    assert.is_nil(reviewed.toggle(marks, nil, "a.txt"))
    assert.is_nil(next(marks))
    assert.is_false(reviewed.is_marked(nil, "unstaged", "a.txt"))
  end)
end)

describe("reviewed walk order", function()
  -- The shared walk both panels use to decide which row to visit next.
  local cases = {
    {
      name = "forwards from the middle, no wrap",
      count = 4,
      current = 2,
      step = 1,
      cycle = false,
      want = { 3, 4 },
    },
    {
      name = "backwards from the middle, no wrap",
      count = 4,
      current = 3,
      step = -1,
      cycle = false,
      want = { 2, 1 },
    },
    {
      name = "forwards at the last row, no wrap, yields nothing",
      count = 3,
      current = 3,
      step = 1,
      cycle = false,
      want = {},
    },
    {
      name = "backwards at the first row, no wrap, yields nothing",
      count = 3,
      current = 1,
      step = -1,
      cycle = false,
      want = {},
    },
    {
      name = "forwards with wrap visits every other row once",
      count = 4,
      current = 3,
      step = 1,
      cycle = true,
      want = { 4, 1, 2 },
    },
    {
      name = "backwards with wrap visits every other row once",
      count = 4,
      current = 2,
      step = -1,
      cycle = true,
      want = { 1, 4, 3 },
    },
    {
      name = "no selection walks the whole list forwards",
      count = 3,
      current = 0,
      step = 1,
      cycle = false,
      want = { 1, 2, 3 },
    },
    {
      name = "no selection walks the whole list backwards",
      count = 3,
      current = 0,
      step = -1,
      cycle = false,
      want = { 3, 2, 1 },
    },
    {
      name = "a single row never revisits itself",
      count = 1,
      current = 1,
      step = 1,
      cycle = true,
      want = {},
    },
  }

  for _, case in ipairs(cases) do
    it(case.name, function()
      local got = reviewed.walk_order(case.count, case.current, case.step, case.cycle)
      assert.same(case.want, got)
    end)
  end
end)
