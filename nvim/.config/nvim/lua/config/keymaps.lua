-- Global, plugin-independent keymaps.
-- Plugin/leader keymaps live in their plugin specs (LazyVim best practice).
local map = vim.keymap.set

-- Bob's "划词翻译" (bound to F15) simulates Option+C on the focused app to
-- grab the macOS selection. In a terminal that arrives as <M-c> (\E c),
-- which Vim splits into ESC + `c` change operator. Swallow it.
map({ "n", "i", "v", "x", "s", "o", "c", "t" }, "<M-c>", "<Nop>", { desc = "Swallow Bob's Option+C injection" })

-- Save (Ghostty translates Cmd+S → Ctrl+S; Super modifier cannot pass through tmux)
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save" })

-- Quit
map("n", "<C-q>", "<cmd>qa<cr>", { desc = "Quit all" })

-- K splits the line at the cursor.
map("n", "K", "i<cr><esc>", { desc = "Split line" })

-- Visual-block paste keeps the yanked register
map("x", "p", '"_dP', { desc = "Paste without yanking replaced text" })

-- Insert-mode line jumps / start of command line
map("i", "<C-e>", "<esc>A", { desc = "Jump to end of line" })
map("i", "<C-a>", "<esc>I", { desc = "Jump to start of line" })
map("c", "<C-a>", "<C-b>", { desc = "Start of command line" })

-- Toggle full-screen zoom for the current window via a throwaway tab.
-- Preserves the original split layout; press again to restore.
map("n", "<leader>wf", function()
  if vim.t.zoomed then
    vim.cmd("tabclose")
  else
    vim.cmd("tab split")
    vim.t.zoomed = true
  end
end, { desc = "Toggle window zoom (full)" })
