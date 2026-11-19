-- lua/plugins/snacks/npm_scripts.lua
local M = {}

-- Find the nearest package.json above the current buffer (or cwd)
local function find_package_json()
  local start = vim.fn.expand '%:p:h'
  if start == '' then
    start = vim.uv.cwd()
  end
  return vim.fs.find('package.json', { path = start, upward = true })[1]
end

-- Parse package.json and return its scripts and directory
local function get_npm_scripts()
  local package_path = find_package_json()
  if not package_path then
    Snacks.notifier.notify('No package.json found in parent directories', 'error')
    return {}
  end

  local ok, package_json = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_path), '\n'))
  if not ok or type(package_json.scripts) ~= 'table' then
    Snacks.notifier.notify('Failed to parse package.json or no scripts found', 'error')
    return {}
  end

  return package_json.scripts, vim.fs.dirname(package_path)
end

-- Pick a script from package.json and run it with the given runner in a Snacks terminal
local function run_script(runner)
  local scripts, package_dir = get_npm_scripts()
  if vim.tbl_isempty(scripts) then
    return
  end

  local names = vim.tbl_keys(scripts)
  table.sort(names)

  vim.ui.select(names, {
    prompt = 'Select ' .. runner .. ' script to run',
    format_item = function(name)
      return name .. '  —  ' .. scripts[name]
    end,
  }, function(name)
    if not name then
      return
    end
    local cmd = runner == 'npm' and { 'npm', 'run', name } or { 'yarn', name }
    Snacks.terminal.open(cmd, {
      cwd = package_dir,
      interactive = false,
      win = { title = runner .. ': ' .. name },
    })
  end)
end

function M.run_npm_script()
  run_script 'npm'
end

function M.run_yarn_script()
  run_script 'yarn'
end

return M
