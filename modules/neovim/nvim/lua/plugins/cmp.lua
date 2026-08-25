return {
  "saghen/blink.cmp",
  event = "VimEnter",
  version = "1.*",
  dependencies = {
    {
      "L3MON4D3/LuaSnip",
      version = "2.*",
      build = "make install_jsregexp",
    },
  },
  opts = {
    keymap = { preset = "default" },
    sources = {
      default = { "lsp", "path", "snippets" },
    },
    fuzzy = { implementation = "lua" },
    signature = { enabled = true },
  },
}
