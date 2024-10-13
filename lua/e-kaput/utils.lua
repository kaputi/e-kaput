local api = vim.api

local utils = {}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- local functions

local break_lines = function(inputstr, sep)
  if sep == nil then
    sep = '%s'
  end
  local t = {}
  for str in string.gmatch(inputstr, '([^' .. sep .. ']+)') do
    for cleanstr in string.gmatch(str, '%S[%S%s]+') do
      table.insert(t, cleanstr)
    end
  end
  return t
end

local bufferWidth = function(buf)
  local lines = api.nvim_buf_get_lines(
    buf,
    0,
    api.nvim_buf_line_count(buf),
    true
  )

  local width = 0

  for _, value in pairs(lines) do
    if #value > width then
      width = #value
    end
  end

  return width
end
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Check if table is empty

-- bind next to local variable for efficiency
local next = next

utils.tableIsEmpty = function(table)
  if next(table) == nil then
    return true
  end
  return false
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Get formated errors

utils.formatErrors = function(diagnostics, config)
  local severitySigns = {}
  severitySigns[1] = config.error_sign
  severitySigns[2] = config.warning_sign
  severitySigns[3] = config.information_sign
  severitySigns[4] = config.hint_sign

  local errors = {}
  for key, value in ipairs(diagnostics) do
    local source = ''
    if value['source'] ~= nil then
      source = '[' .. value['source'] .. ']'
    end

    local error = break_lines(value['message'], '\n')
    if type(error) == 'table' then
      for multiKey, multiValue in ipairs(error) do
        local errorMessage = ' '
        if multiKey == 1 then
          errorMessage = severitySigns[value['severity']] .. ' '
        end
        errorMessage = errorMessage .. multiValue
        if multiKey == #error then
          errorMessage = errorMessage .. source
        end
        table.insert(
          errors,
          { message = errorMessage, severity = value['severity'] }
        )
      end
    elseif type(error) == 'string' then
      local errorMessage = severitySigns[value['severity']]
        .. ' '
        .. error
        .. source
      errors[key] = { message = errorMessage, severity = value['severity'] }
    end
  end
  return errors
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Create errors buffer

-- Errors highlight namespace
local ns_errors = api.nvim_create_namespace('ekaput.floatErrors')

utils.errorBuffer = function(errors)
  local buf = api.nvim_create_buf(false, true)

  local severityHighlight = {}
  severityHighlight[1] = 'EKaputError'
  severityHighlight[2] = 'EKaputWarning'
  severityHighlight[3] = 'EKaputInformation'
  severityHighlight[4] = 'EKaputHint'

  if next(errors) == nil then
    return nil
  end

  for key, value in ipairs(errors) do
    local message = value['message']

    local line = key - 1
    api.nvim_buf_set_lines(buf, line, -1, false, { message })

    api.nvim_buf_add_highlight(
      buf,
      ns_errors,
      severityHighlight[value['severity']],
      line,
      1,
      #message
    )
  end
  return buf
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Create error window

utils.createErrorWindow = function(buf, config)
  local bufWidth = bufferWidth(buf)

  local row = 0
  local col = 2
  local border = 'none'

  if config.borders == true then
    row = -1
    border = {
      { '╭', 'EKaputBorder' },
      { '─', 'EKaputBorder' },
      { '╮', 'EKaputBorder' },
      { '│', 'EKaputBorder' },
      { '╯', 'EKaputBorder' },
      { '─', 'EKaputBorder' },
      { '╰', 'EKaputBorder' },
      { '│', 'EKaputBorder' },
    }
  end

  local window_config = {
    relative = 'cursor',
    anchor = 'SW',
    row = row,
    col = col,
    height = api.nvim_buf_line_count(buf),
    width = bufWidth,
    focusable = false,
    style = 'minimal',
    border = border,
  }

  local window = api.nvim_open_win(buf, false, window_config)
  vim.api.nvim_win_set_option(window, 'winblend', config.transparency)
  vim.api.nvim_win_set_option(window, 'winhl', 'NormalFloat:EKaputBackground')

  return window
end

utils.highlights = function()
  vim.cmd([[
    highlight default link EKaputError LspDiagnosticsSignError
    highlight default link EKaputWarning LspDiagnosticsSignWarning
    highlight default link EKaputInformation LspDiagnosticsSignInformation
    highlight default link EKaputHint LspDiagnosticsSignHint
    highlight default link EKaputBorder LspDiagnosticsSignInformation
    highlight default link EkaputBackground NormalFloat
  ]])
end

utils.commands = function()
  vim.cmd([[
    command! EKaputToggle lua require('e-kaput').toggle()

    augroup EkaputAutocommands
      autocmd!
      autocmd CursorHold * lua require('e-kaput').openFloatingWindow()
      autocmd CursorMoved * lua require('e-kaput').closeFloatingWindow()
      autocmd InsertEnter * lua require('e-kaput').closeFloatingWindow()
      autocmd VimLeavePre * lua require('e-kaput').closeFloatingWindow()
    augroup END
  ]])
end

return utils
