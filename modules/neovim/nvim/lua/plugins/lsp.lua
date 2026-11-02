return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
		opts = {
			ensure_installed = {
				-- LSP servers
				"pyright",
				"lua-language-server",
				"bash-language-server",
				"clangd",
				"expert",
				-- formatters
				"stylua",
				"prettier",
				"shfmt",
				"ruff",
				"clang-format",
			},
		},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
		config = function()
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = { diagnostics = { globals = { "vim" } } },
				},
			})
			require("mason-lspconfig").setup()
		end,
	},
}
