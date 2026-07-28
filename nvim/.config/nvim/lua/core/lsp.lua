-- LSP setup using the native vim.lsp.config / vim.lsp.enable API (Neovim 0.11+).
-- Per-server configs live in lua/lsp/*.lua and are loaded at the bottom of this file.

vim.api.nvim_set_hl(0, "Parameter", { fg = "#88CCFF", bold = true })

vim.opt.updatetime = 300

local function make_default_capabilities()
	local ok, blink_cmp = pcall(require, "blink.cmp")
	if ok and type(blink_cmp.get_lsp_capabilities) == "function" then
		return blink_cmp.get_lsp_capabilities()
	end

	local capabilities = vim.lsp.protocol.make_client_capabilities()
	capabilities.textDocument.completion.completionItem.snippetSupport = true
	capabilities.textDocument.completion.completionItem.resolveSupport = {
		properties = { "documentation", "detail", "additionalTextEdits" },
	}
	capabilities.textDocument.foldingRange = {
		dynamicRegistration = false,
		lineFoldingOnly = true,
	}
	return capabilities
end

-- Defaults inherited by every vim.lsp.config(name, ...) registration.
vim.lsp.config("*", {
	capabilities = make_default_capabilities(),
})

-- Diagnostic config
vim.diagnostic.config({
	virtual_text = {
		prefix = "●",
		spacing = 4,
		source = "if_many",
		severity = { min = vim.diagnostic.severity.WARN },
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚",
			[vim.diagnostic.severity.WARN] = "󰀪",
			[vim.diagnostic.severity.INFO] = "󰋽",
			[vim.diagnostic.severity.HINT] = "󰌶",
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
			[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
		},
	},
	underline = false,
	update_in_insert = false,
	severity_sort = true,
	float = {
		border = "rounded",
		source = "if_many",
		header = "",
		prefix = "",
		focusable = false,
	},
})

-- Suppress noisy tsconfig diagnostic: ts(5102) baseUrl deprecation.
do
	local base_publish = vim.lsp.handlers["textDocument/publishDiagnostics"]
	if type(base_publish) == "function" then
		vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
			if result and result.diagnostics then
				local filtered = {}
				for _, diagnostic in ipairs(result.diagnostics) do
					local code = tonumber(diagnostic.code)
					local source = (diagnostic.source or ""):lower()
					local message = diagnostic.message or ""
					local is_ts = source == "ts" or source == "typescript"
					local suppress = is_ts
						and code == 5102
						and message:find("Option 'baseUrl' has been removed", 1, true) ~= nil
					if not suppress then
						table.insert(filtered, diagnostic)
					end
				end
				result.diagnostics = filtered
			end
			return base_publish(err, result, ctx, config)
		end
	end
end

-- Let fidget.nvim handle progress UI
vim.lsp.handlers["$/progress"] = nil

-- Show diagnostic float on CursorHold (skip immediately after save)
vim.api.nvim_create_autocmd("CursorHold", {
	group = vim.api.nvim_create_augroup("UserDiagnosticHover", { clear = true }),
	callback = function()
		local now = vim.uv.now()
		local last_save = vim._last_save_time or 0
		if (now - last_save) < 500 then
			return
		end

		local line = vim.api.nvim_win_get_cursor(0)[1] - 1
		local diagnostics = vim.diagnostic.get(0, { lnum = line })
		if #diagnostics > 0 then
			vim.diagnostic.open_float(nil, {
				focusable = false,
				close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
				border = "rounded",
				source = "if_many",
				prefix = " ",
				scope = "line",
			})
		end
	end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
	group = vim.api.nvim_create_augroup("UserTrackSaveTime", { clear = true }),
	callback = function()
		vim._last_save_time = vim.uv.now()
	end,
})

-- Buffer-local LSP keymaps + features
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		local bufnr = ev.buf
		local function map(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
		end

		-- Navigation (gr* prefix is native default in 0.11+: grr/gri/grn/grt/gra)
		map("n", "gd", vim.lsp.buf.definition, "Go to Definition")
		map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")

		-- Hover and signature
		map("n", "K", vim.lsp.buf.hover, "Hover Documentation")
		map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")

		-- Code actions and refactoring
		map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
		map("n", "<leader>cr", vim.lsp.buf.rename, "Rename Symbol")

		-- Inlay hints (opt-in; visually noisy by default in TS/JS)
		map("n", "<leader>th", function()
			local current = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
			vim.lsp.inlay_hint.enable(not current, { bufnr = bufnr })
			vim.notify("Inlay hints " .. (current and "disabled" or "enabled"))
		end, "Toggle Inlay Hints")

		if client and client:supports_method("textDocument/codeLens") then
			map("n", "<leader>cl", vim.lsp.codelens.run, "Run Code Lens")
		end
	end,
})

-- Format on save via conform (with LSP fallback)
vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("UserLspFormatOnSave", { clear = true }),
	pattern = { "*.ts", "*.tsx", "*.js", "*.jsx", "*.lua", "*.py", "*.go" },
	callback = function(ev)
		local conform_ok, conform = pcall(require, "conform")
		if conform_ok then
			conform.format({
				bufnr = ev.buf,
				async = false,
				timeout_ms = 1500,
				lsp_fallback = true,
				stop_after_first = true,
			})
		else
			vim.lsp.buf.format({ async = false, timeout_ms = 1500 })
		end
	end,
})

-- Load all per-server configs
local lsp_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../lsp"
for _, file in ipairs(vim.fn.readdir(lsp_dir)) do
	if file:match("%.lua$") then
		local mod = "lsp." .. file:gsub("%.lua$", "")
		local ok, err = pcall(require, mod)
		if not ok then
			vim.notify("Failed to load LSP module " .. mod .. ": " .. tostring(err), vim.log.levels.WARN)
		end
	end
end
