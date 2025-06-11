-- Adapted from nvim-lspconfig's ui/windows.lua

local api = vim.api
local M = {}

local function capitalize_string(str)
  return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

-- Colors for client status
local status_colors = {
  connected = 'LspInfoBorderActive',
  starting = 'LspInfoBorderStarting',
  failed = 'LspInfoBorderFailed',
}

-- Define highlight groups
local function define_highlights()
  local highlights = {
    LspInfoBorder = { link = 'FloatBorder' },
    LspInfoBorderActive = { fg = '#50FA7B', bold = true },  -- Green
    LspInfoBorderStarting = { fg = '#F1FA8C', bold = true }, -- Yellow
    LspInfoBorderFailed = { fg = '#FF5555', bold = true },  -- Red
    LspInfoTitle = { link = 'Title' },
    LspInfoTip = { link = 'Comment' },
    LspInfoList = { link = 'Comment' },
    LspInfoFiletype = { link = 'Type' },
    LspInfoCurrent = { bold = true, fg = '#BD93F9' }, -- Purple
  }

  for group, attrs in pairs(highlights) do
    if attrs.link then
      vim.cmd(string.format('highlight! link %s %s', group, attrs.link))
    else
      local fg = attrs.fg and 'guifg=' .. attrs.fg or ''
      local bg = attrs.bg and 'guibg=' .. attrs.bg or ''
      local style = attrs.bold and 'gui=bold' or ''
      vim.cmd(string.format('highlight %s %s %s %s', group, fg, bg, style))
    end
  end
end

function M.server_status()
  define_highlights()
  
  local buf = api.nvim_create_buf(false, true)
  local border_buf = api.nvim_create_buf(false, true)

  local clients = vim.lsp.get_active_clients()
  local buffer_clients = vim.lsp.get_clients({ bufnr = api.nvim_get_current_buf() })
  local current_buf_ft = vim.bo.filetype
  
  -- Create formatted output
  local lines = {}
  local border_lines = {}
  
  local header_text = ' LSP Status '
  local tip_text = ' Press q or <Esc> to close '
  
  -- Create header line
  table.insert(border_lines, string.format('╭%s╮', string.rep('─', #header_text + 2)))
  table.insert(border_lines, string.format('│ %s │', header_text))
  table.insert(border_lines, string.format('├%s┤', string.rep('─', #header_text + 2)))
  
  if #clients == 0 then
    table.insert(lines, 'No active clients')
  else
    for i, client in ipairs(clients) do
      -- Check if this client is attached to current buffer
      local is_attached = false
      for _, buf_client in ipairs(buffer_clients) do
        if buf_client.id == client.id then
          is_attached = true
          break
        end
      end
      
      -- Determine status and corresponding color
      local status = client.initialized and 'connected' or 'starting'
      if client.failed then status = 'failed' end
      
      -- Create formatted entry
      table.insert(lines, '')
      local client_str = string.format('%d. %s (%s)', i, client.name, status)
      if is_attached then
        client_str = client_str .. ' *'
      end
      table.insert(lines, client_str)
      
      -- Add client details
      if client.config then
        if client.config.root_dir then
          table.insert(lines, '   Root: ' .. client.config.root_dir)
        end
        if client.config.filetypes then
          table.insert(lines, '   Filetypes: ' .. table.concat(client.config.filetypes, ', '))
        end
      end
    end
    
    table.insert(lines, '')
    table.insert(lines, '* attached to current buffer')
  end
  
  -- Add tip at the bottom
  table.insert(lines, '')
  table.insert(lines, tip_text)
  
  -- Calculate window dimensions
  local width = math.min(80, api.nvim_get_option('columns') - 4)
  local height = math.min(#lines, api.nvim_get_option('lines') - 6)
  
  -- Complete the border
  for _ = 1, height do
    table.insert(border_lines, string.format('│%s│', string.rep(' ', #header_text + 2)))
  end
  table.insert(border_lines, string.format('╰%s╯', string.rep('─', #header_text + 2)))
  
  -- Set content
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  api.nvim_buf_set_lines(border_buf, 0, -1, true, border_lines)
  
  -- Apply syntax highlighting
  api.nvim_buf_add_highlight(buf, -1, 'LspInfoTitle', 0, 0, -1)
  api.nvim_buf_add_highlight(buf, -1, 'LspInfoTip', #lines - 1, 0, -1)
  
  -- Open the border window first
  local border_win = api.nvim_open_win(border_buf, false, {
    relative = 'editor',
    width = width + 4,
    height = height + 4,
    row = math.floor((api.nvim_get_option('lines') - height - 4) / 2),
    col = math.floor((api.nvim_get_option('columns') - width - 4) / 2),
    style = 'minimal',
    focusable = false,
    border = 'none',
  })
  
  -- Then open the content window
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((api.nvim_get_option('lines') - height) / 2),
    col = math.floor((api.nvim_get_option('columns') - width) / 2),
    style = 'minimal',
    border = 'none',
  })
  
  -- Set window options
  api.nvim_win_set_option(win, 'wrap', false)
  api.nvim_buf_set_option(buf, 'modifiable', false)
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>bdelete<CR>', { silent = true })
  api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>bdelete<CR>', { silent = true })
  
  -- Set buffer name
  api.nvim_buf_set_name(buf, '[lspinfo]')
  
  -- Autocommand to close both windows when one is closed
  api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      if api.nvim_win_is_valid(border_win) then
        api.nvim_win_close(border_win, true)
      end
      api.nvim_buf_delete(border_buf, { force = true })
    end,
  })
  
  return buf, win
end

return M