return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  config = function()
    require("diffview").setup({
      enhanced_diff_hl = true,
      use_icons = vim.g.have_nerd_font,
    })
  end,
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open [G]it [D]iff" },
    { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "[G]it diff [C]lose" },
  },
}
