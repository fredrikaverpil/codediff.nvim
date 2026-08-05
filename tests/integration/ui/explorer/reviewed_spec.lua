-- Marking explorer rows as reviewed, and the navigation that skips them.

local h = require("tests.support")
h.ensure_plugin_loaded()

local reviewed = require("codediff.ui.reviewed")

describe("reviewed marks", function()
  describe("in a live explorer", function()
    local repo

    before_each(function()
      require("codediff").setup({})
      repo = h.create_temp_git_repo()
      repo.write_file("a.txt", { "aaa" })
      repo.write_file("b.txt", { "bbb" })
      repo.write_file("c.txt", { "ccc" })
      repo.git("add .")
      repo.git("commit -m initial")
      repo.write_file("a.txt", { "aaa modified" })
      repo.write_file("b.txt", { "bbb modified" })
      repo.write_file("c.txt", { "ccc modified" })
      vim.cmd("edit " .. vim.fn.fnameescape(repo.path("a.txt")))
    end)

    after_each(function()
      h.close_extra_tabs()
      if repo then
        repo.cleanup()
      end
    end)

    local function open_explorer()
      vim.cmd("CodeDiff")
      assert.is_true(h.wait_for_explorer(5000))
      assert.is_true(h.wait_for_diff_ready(5000))
      local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
      assert.is_not_nil(session, "explorer session should exist")
      return session.panel.view
    end

    it("renders a marker on the reviewed row only", function()
      local explorer = open_explorer()
      local explorer_module = require("codediff.ui.explorer")

      local _, explorer_buf = h.find_window_by_filetype("codediff-explorer")
      assert.is_false(
        h.get_buffer_content(explorer_buf):find(reviewed.GLYPH, 1, true) ~= nil,
        "no row should carry a marker before anything is reviewed"
      )

      local marked = explorer.data.current_file_path
      assert.is_not_nil(marked, "a file should be selected after opening")
      explorer_module.toggle_reviewed(explorer)

      local lines = h.get_buffer_lines(explorer_buf)
      local marked_rows = {}
      for _, line in ipairs(lines) do
        if line:find(reviewed.GLYPH, 1, true) then
          marked_rows[#marked_rows + 1] = line
        end
      end
      assert.equals(1, #marked_rows, "exactly one row should carry the marker")
      assert.is_true(
        marked_rows[1]:find(vim.fn.fnamemodify(marked, ":t"), 1, true) ~= nil,
        "the marker should sit on the reviewed file's row, got: " .. marked_rows[1]
      )
    end)

    it("mutates the set the renderer holds rather than replacing it", function()
      local explorer = open_explorer()
      local marks = explorer.reviewed_files
      assert.is_not_nil(marks, "the explorer should carry a mark set")

      require("codediff.ui.explorer").toggle_reviewed(explorer)

      assert.is_true(rawequal(marks, explorer.reviewed_files), "the mark set must not be swapped for a new table")
      assert.is_not_nil(next(marks), "the mark should land in that same table")
    end)

    it("skips reviewed files when navigating to the next file", function()
      local explorer = open_explorer()
      local navigation = require("codediff.ui.view.navigation")
      local tree_module = require("codediff.ui.explorer.tree")

      local all_files = tree_module.get_all_files(explorer.tree)
      assert.equals(3, #all_files, "fixture should produce three changed files")

      -- Mark the file that ]f would otherwise land on next.
      local start_path = explorer.data.current_file_path
      local start_group = explorer.data.current_file_group
      local start_index
      for i, file in ipairs(all_files) do
        if file.data.path == start_path and file.data.group == start_group then
          start_index = i
          break
        end
      end
      assert.is_not_nil(start_index, "the selected file should appear in the file list")
      assert.is_true(start_index + 2 <= #all_files, "fixture should leave two files ahead of the selection")

      local skipped = all_files[start_index + 1].data
      reviewed.toggle(explorer.reviewed_files, skipped.group, skipped.path)

      navigation.next_file()
      assert.is_true(h.wait_for_diff_ready(5000))

      assert.equals(
        all_files[start_index + 2].data.path,
        explorer.data.current_file_path,
        "navigation should land past the reviewed file"
      )
    end)
  end)
end)
