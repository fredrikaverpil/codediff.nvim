-- Marking history rows as reviewed, and the commit navigation that skips them.
--
-- Single-file history marks commits rather than files, since each commit is
-- one thing to review; these specs pin that down.

local h = require("tests.support")
h.ensure_plugin_loaded()

local reviewed = require("codediff.ui.reviewed")

describe("history reviewed marks", function()
  local repo

  before_each(function()
    require("codediff").setup({})
    repo = h.create_temp_git_repo()
    repo.write_file("file.txt", { "version 1" })
    repo.git("add .")
    repo.git("commit -m first")
    repo.write_file("file.txt", { "version 2" })
    repo.git("add .")
    repo.git("commit -m second")
    repo.write_file("file.txt", { "version 3" })
    repo.git("add .")
    repo.git("commit -m third")
    repo.write_file("file.txt", { "version 4" })
    repo.git("add .")
    repo.git("commit -m fourth")
    vim.cmd("edit " .. repo.path("file.txt"))
  end)

  after_each(function()
    h.close_extra_tabs()
    if repo then
      repo.cleanup()
    end
  end)

  local function open_history()
    vim.cmd("CodeDiff history %")
    local appeared = vim.wait(5000, function()
      return h.find_window_by_filetype("codediff-history") ~= nil
    end, 50)
    assert.is_true(appeared, "history panel should appear within 5s")

    local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
    assert.is_not_nil(session, "history session should exist")
    local history = session.panel.view
    assert.is_not_nil(history, "history panel object should be attached to the session")
    assert.is_true(history.is_single_file_mode, "`CodeDiff history %` should open single-file history")
    return history
  end

  it("carries a mark set the renderer holds", function()
    local history = open_history()
    assert.is_not_nil(history.reviewed_files, "the history panel should carry a mark set")
    assert.is_nil(next(history.reviewed_files), "nothing should be marked on open")
  end)

  it("marks the commit under the cursor and renders a marker", function()
    local history = open_history()
    local render = require("codediff.ui.history.render")

    local commits = render.get_all_commits(history.tree)
    assert.is_true(#commits >= 4, "fixture should produce at least four commits")

    local target = commits[2]
    local file_path = target.data.file_path or history.data.opts.file_path
    reviewed.toggle(history.reviewed_files, target.data.hash, file_path)
    history.tree:render()

    local _, history_buf = h.find_window_by_filetype("codediff-history")
    local marked_rows = {}
    for _, line in ipairs(h.get_buffer_lines(history_buf)) do
      if line:find(reviewed.GLYPH, 1, true) then
        marked_rows[#marked_rows + 1] = line
      end
    end
    assert.equals(1, #marked_rows, "exactly one commit row should carry the marker")
    assert.is_true(
      marked_rows[1]:find(target.data.hash:sub(1, 8), 1, true) ~= nil,
      "the marker should sit on the marked commit's row, got: " .. marked_rows[1]
    )
  end)

  it("skips marked commits when navigating to the next commit", function()
    local history = open_history()
    local render = require("codediff.ui.history.render")

    local commits = render.get_all_commits(history.tree)

    -- Take wherever the panel settled as the starting point, then mark the
    -- commit ]f would otherwise land on next.
    local start_index = 0
    for i, commit in ipairs(commits) do
      if commit.data.hash == history.data.current_commit then
        start_index = i
        break
      end
    end
    assert.is_true(start_index + 2 <= #commits, "fixture should leave two commits ahead of the selection")

    local skipped = commits[start_index + 1]
    reviewed.toggle(history.reviewed_files, skipped.data.hash, skipped.data.file_path or history.data.opts.file_path)

    render.navigate_next_commit(history)

    assert.equals(
      commits[start_index + 2].data.hash,
      history.data.current_commit,
      "navigation should land past the marked commit"
    )
  end)

  it("stays put once every commit is marked", function()
    local history = open_history()
    local render = require("codediff.ui.history.render")

    render.navigate_next_commit(history)
    local settled_on = history.data.current_commit
    assert.is_not_nil(settled_on)

    for _, commit in ipairs(render.get_all_commits(history.tree)) do
      reviewed.toggle(history.reviewed_files, commit.data.hash, commit.data.file_path or history.data.opts.file_path)
    end

    render.navigate_next_commit(history)
    assert.equals(settled_on, history.data.current_commit, "nothing unreviewed is left, so the selection must not move")
  end)
end)
