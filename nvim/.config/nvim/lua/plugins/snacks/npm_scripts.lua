-- lua/plugins/snacks/npm_scripts.lua
local M = {}

-- Function to find the nearest package.json file
local function find_package_json()
  -- Start from the current buffer's directory
  local current_file = vim.fn.expand '%:p'
  local current_dir = vim.fn.fnamemodify(current_file, ':h')

  -- Keep going up directories until we find a package.json or hit the root
  local dir = current_dir
  while dir ~= '/' do
    local package_path = dir .. '/package.json'
    if vim.fn.filereadable(package_path) == 1 then
      return package_path
    end
    -- Go up one directory
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return nil
end

-- Function to parse package.json and extract scripts
local function get_npm_scripts()
  local package_path = find_package_json()
  if not package_path then
    Snacks.notifier.notify('No package.json found in parent directories', 'error')
    return {}
  end

  local content = vim.fn.readfile(package_path)
  local json_str = table.concat(content, '\n')

  -- Parse the JSON
  local success, package_json = pcall(vim.fn.json_decode, json_str)
  if not success or not package_json.scripts then
    Snacks.notifier.notify('Failed to parse package.json or no scripts found', 'error')
    return {}
  end

  -- Return the scripts section
  return package_json.scripts, vim.fn.fnamemodify(package_path, ':h')
end
-- Main function to show and execute npm scripts
function M.run_npm_script()
  local scripts, package_dir = get_npm_scripts()
  if vim.tbl_isempty(scripts) then
    return
  end

  -- Convert scripts to a format suitable for Snacks.input
  local script_items = {}
  for name, command in pairs(scripts) do
    table.insert(script_items, {
      id = name,
      text = name,
      description = command,
    })
  end

  -- Sort scripts alphabetically
  table.sort(script_items, function(a, b)
    return a.text < b.text
  end)

  -- Use Snacks.input to create a nice selection UI
  Snacks.input.select {
    prompt = 'Select npm script to run',
    items = script_items,
    on_select = function(item)
      if not item then
        return
      end

      -- Create terminal command
      local cmd = string.format('cd %s && npm run %s', package_dir, item.id)

      -- Run in Snacks terminal
      Snacks.terminal {
        cmd = cmd,
        cwd = package_dir,
        title = 'npm: ' .. item.id,
        focus = true,
        on_exit = function()
          Snacks.notifier.notify('npm script "' .. item.id .. '" completed', 'info')
        end,
      }
    end,
  }
end

-- Alternative for yarn
function M.run_yarn_script()
  local scripts, package_dir = get_npm_scripts()
  if vim.tbl_isempty(scripts) then
    return
  end

  -- Convert scripts to a format suitable for Snacks.input
  local script_items = {}
  for name, command in pairs(scripts) do
    table.insert(script_items, {
      id = name,
      text = name,
      description = command,
    })
  end

  -- Sort scripts alphabetically
  table.sort(script_items, function(a, b)
    return a.text < b.text
  end)

  -- Use Snacks.input to create a nice selection UI
  Snacks.input.select {
    prompt = 'Select yarn script to run',
    items = script_items,
    on_select = function(item)
      if not item then
        return
      end

      -- Create terminal command
      local cmd = string.format('cd %s && yarn %s', package_dir, item.id)

      -- Run in Snacks terminal
      Snacks.terminal {
        cmd = cmd,
        cwd = package_dir,
        title = 'yarn: ' .. item.id,
        focus = true,
        on_exit = function()
          Snacks.notifier.notify('yarn script "' .. item.id .. '" completed', 'info')
        end,
      }
    end,
  }
end

return M
