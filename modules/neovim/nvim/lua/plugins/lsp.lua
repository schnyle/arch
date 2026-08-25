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
			require("mason-lspconfig").setup({
				handlers = {
					function(server_name)
						require("lspconfig")[server_name].setup({
							capabilities = require("blink.cmp").get_lsp_capabilities(),
						})
					end,
					["lua_ls"] = function()
						require("lspconfig").lua_ls.setup({
							capabilities = require("blink.cmp").get_lsp_capabilities(),
							settings = {
								Lua = { diagnostics = { globals = { "vim" } } },
							},
						})
					end,
				},
			})
		end,
	},
}
