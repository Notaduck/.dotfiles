-- File: lua/plugins/dap-vscode-js.lua

return {
	"mxsdev/nvim-dap-vscode-js",
	dependencies = {
		"mfussenegger/nvim-dap",
	},
	config = function()
		local dap_vscode_js = require("dap-vscode-js")
		dap_vscode_js.setup({
			node_path = "node",
			debugger_path = os.getenv("HOME") .. ".local/share/nvim/lazy/vscode-js-debug",
			adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
		})

		for _, language in ipairs({ "typescript", "javascript" }) do
			require("dap").configurations[language] = {
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch file",
					program = "${file}",
					cwd = "${workspaceFolder}",
				},
				{
					type = "pwa-node",
					request = "attach",
					name = "Attach",
					processId = require("dap.utils").pick_process,
					cwd = "${workspaceFolder}",
				},
				{
					type = "pwa-node",
					request = "launch",
					name = "Debug Jest Tests",
					runtimeExecutable = "node",
					runtimeArgs = {
						"./node_modules/jest/bin/jest.js",
						"--runInBand",
					},
					rootPath = "${workspaceFolder}",
					cwd = "${workspaceFolder}",
					console = "integratedTerminal",
					internalConsoleOptions = "neverOpen",
				},
			}
		end
	end,
}

-- local js_based_languages = {
-- 	-- "node",
-- 	"typescript",
-- 	"javascript",
-- 	-- "typescriptreact",
-- 	-- "javascriptreact",
-- 	-- "vue",
-- }
--
-- return {
-- 	{ "nvim-neotest/nvim-nio" },
-- 	{
-- 		"mfussenegger/nvim-dap",
-- 		config = function()
-- 			local dap = require("dap")
--
-- 			local Config = require("lazyvim.config")
-- 			vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
--
-- 			-- Define signs for DAP UI
-- 			for name, sign in pairs(Config.icons.dap) do
-- 				sign = type(sign) == "table" and sign or { sign }
-- 				vim.fn.sign_define(
-- 					"Dap" .. name,
-- 					{ text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
-- 				)
-- 			end
--
-- 			-- Manually configure TypeScript
-- 			dap.configurations.typescript = {
-- 				{
-- 					type = "pwa-node",
-- 					request = "launch",
-- 					name = "Launch TypeScript file",
-- 					program = "${file}",
-- 					cwd = vim.fn.getcwd(),
-- 					sourceMaps = true,
-- 					protocol = "inspector",
-- 					console = "integratedTerminal",
-- 				},
-- 				{
-- 					type = "pwa-node",
-- 					request = "attach",
-- 					name = "Attach to running TypeScript process",
-- 					processId = require("dap.utils").pick_process,
-- 					cwd = vim.fn.getcwd(),
-- 					sourceMaps = true,
-- 				},
-- 			}
--
-- 			-- Apply same configuration for JavaScript if needed
-- 			-- dap.configurations.javascript = dap.configurations.typescript
-- 			--
-- 			--
-- 			for _, language in ipairs({ "typescript", "javascript" }) do
-- 				require("dap").configurations[language] = {
-- 					{
-- 						type = "pwa-node",
-- 						request = "launch",
-- 						name = "Launch file",
-- 						program = "${file}",
-- 						cwd = "${workspaceFolder}",
-- 					},
-- 					{
-- 						type = "pwa-node",
-- 						request = "attach",
-- 						name = "Attach",
-- 						processId = require("dap.utils").pick_process,
-- 						cwd = "${workspaceFolder}",
-- 					},
-- 					{
-- 						type = "pwa-node",
-- 						request = "launch",
-- 						name = "Debug Jest Tests",
-- 						-- trace = true, -- include debugger info
-- 						runtimeExecutable = "node",
-- 						runtimeArgs = {
-- 							"./node_modules/jest/bin/jest.js",
-- 							"--runInBand",
-- 						},
-- 						rootPath = "${workspaceFolder}",
-- 						cwd = "${workspaceFolder}",
-- 						console = "integratedTerminal",
-- 						internalConsoleOptions = "neverOpen",
-- 					},
-- 				}
-- 			end
--
-- 			-- Configure all JavaScript-based languages in loop
-- 			-- for _, language in ipairs(js_based_languages) do
-- 			-- 	if language ~= "typescript" then -- TypeScript is already configured
-- 			-- 		dap.configurations[language] = dap.configurations[language] or {}
-- 			--
-- 			-- 		-- Debug single nodejs files
-- 			-- 		table.insert(dap.configurations[language], {
-- 			-- 			type = "pwa-node",
-- 			-- 			request = "launch",
-- 			-- 			name = "Launch file",
-- 			-- 			program = "${file}",
-- 			-- 			cwd = vim.fn.getcwd(),
-- 			-- 			sourceMaps = true,
-- 			-- 		})
-- 			--
-- 			-- 		-- Debug nodejs processes (make sure to add --inspect when you run the process)
-- 			-- 		table.insert(dap.configurations[language], {
-- 			-- 			type = "pwa-node",
-- 			-- 			request = "attach",
-- 			-- 			name = "Attach",
-- 			-- 			processId = require("dap.utils").pick_process,
-- 			-- 			cwd = vim.fn.getcwd(),
-- 			-- 			sourceMaps = true,
-- 			-- 		})
-- 			--
-- 			-- 		-- Debug web applications (client side)
-- 			-- 		table.insert(dap.configurations[language], {
-- 			-- 			type = "pwa-chrome",
-- 			-- 			request = "launch",
-- 			-- 			name = "Launch & Debug Chrome",
-- 			-- 			url = function()
-- 			-- 				local co = coroutine.running()
-- 			-- 				return coroutine.create(function()
-- 			-- 					vim.ui.input({
-- 			-- 						prompt = "Enter URL: ",
-- 			-- 						default = "http://localhost:3000",
-- 			-- 					}, function(url)
-- 			-- 						if url == nil or url == "" then
-- 			-- 							return
-- 			-- 						else
-- 			-- 							coroutine.resume(co, url)
-- 			-- 						end
-- 			-- 					end)
-- 			-- 				end)
-- 			-- 			end,
-- 			-- 			webRoot = vim.fn.getcwd(),
-- 			-- 			protocol = "inspector",
-- 			-- 			sourceMaps = true,
-- 			-- 			userDataDir = false,
-- 			-- 		})
-- 			-- 	end
-- 			-- end
-- 		end,
-- 		keys = {
-- 			{
-- 				"<leader>dO",
-- 				function()
-- 					require("dap").step_out()
-- 				end,
-- 				desc = "Step Out",
-- 			},
-- 			{
-- 				"<leader>do",
-- 				function()
-- 					require("dap").step_over()
-- 				end,
-- 				desc = "Step Over",
-- 			},
-- 			{
-- 				"<leader>da",
-- 				function()
-- 					if vim.fn.filereadable(".vscode/launch.json") then
-- 						local dap_vscode = require("dap.ext.vscode")
-- 						dap_vscode.load_launchjs(nil, {
-- 							["pwa-node"] = js_based_languages,
-- 							["chrome"] = js_based_languages,
-- 							["pwa-chrome"] = js_based_languages,
-- 						})
-- 					end
-- 					require("dap").continue()
-- 				end,
-- 				desc = "Run with Args",
-- 			},
-- 		},
-- 		dependencies = {
-- 			-- Install the vscode-js-debug adapter
-- 			{
-- 				"microsoft/vscode-js-debug",
-- 				-- After install, build it and rename the dist directory to out
-- 				build = "npm install --legacy-peer-deps --no-save && npx gulp vsDebugServerBundle && rm -rf out && mv dist out",
-- 				version = "1.*",
-- 			},
-- 			{
-- 				"mxsdev/nvim-dap-vscode-js",
-- 				config = function()
-- 					require("dap-vscode-js").setup({
-- 						-- Path to vscode-js-debug installation.
-- 						debugger_path = vim.fn.resolve(vim.fn.stdpath("data") .. "/lazy/vscode-js-debug"),
--
-- 						-- which adapters to register in nvim-dap
-- 						adapters = {
-- 							"chrome",
-- 							"pwa-node",
-- 							"pwa-chrome",
-- 							"pwa-msedge",
-- 							"pwa-extensionHost",
-- 							"node-terminal",
-- 						},
-- 					})
-- 				end,
-- 			},
-- 			{
-- 				"Joakker/lua-json5",
-- 				build = "./install.sh",
-- 			},
-- 		},
-- 	},
-- }
