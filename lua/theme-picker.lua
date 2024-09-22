local cached_opts = {}

local function get_config_path()
  return vim.fn.stdpath 'data' .. '/theme-picker.nvim/theme.json'
end

local function apply_selection(entry)
  if entry.before then
    entry.before()
  end

  vim.cmd('colorscheme ' .. entry.colorscheme)

  if entry.after then
    entry.after()
  end
end

local function save_selection(entry)
  local data_path = get_config_path()

  -- Ensure the directory exists
  vim.fn.mkdir(vim.fn.fnamemodify(data_path, ':h'), 'p')

  vim.fn.writefile({
    vim.fn.json_encode({
      colorscheme = entry.colorscheme,
      name = entry.name,
    }), ''
  }, data_path)
end

local function get_current_selection()
  local data_path = get_config_path()

  if vim.fn.filereadable(data_path) == 0 then
    return nil
  end

  local ok, data = pcall(function()
    return vim.fn.json_decode(vim.fn.readfile(data_path)[1])
  end)

  if not ok then
    return nil
  end

  return data
end

local function restore()
  local current_selection = get_current_selection()

  if not current_selection then
    return
  end

  local themes = cached_opts.themes or {}

  local theme = vim.tbl_filter(function(entry)
    return entry.name == current_selection.name
  end, themes)[1]

  if not theme then
    return
  end

  apply_selection(theme)
end

local function open_theme_picker(opts)
  local action_state = require 'telescope.actions.state'
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require 'telescope.config'.values

  opts = opts or cached_opts or {}

  local themes = opts.themes or {}
  local picker_opts = opts.picker or {}

  local need_restore = true

  local picker = pickers
      .new(picker_opts, {
        prompt_title = 'Theme Picker',
        finder = finders.new_table {
          results = themes,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.name,
              ordinal = entry.name,
            }
          end,
        },
        sorter = conf.generic_sorter(picker_opts),
        attach_mappings = function(prompt_bufnr)
          local actions = require 'telescope.actions'

          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()

            if not selection then
              return
            end

            apply_selection(selection.value)
            save_selection(selection.value)

            need_restore = false
            actions.close(prompt_bufnr)
          end)

          return true
        end,
      })

  local close_windows = picker.close_windows
  picker.close_windows = function(status)
    close_windows(status)

    if need_restore then
      restore()
    end
  end

  local set_selection = picker.set_selection
  picker.set_selection = function(self, row)
    set_selection(self, row)

    local selection = action_state.get_selected_entry()

    if not selection then
      return
    end

    apply_selection(selection.value)
  end

  picker:find()
end

local function setup(opts)
  cached_opts = opts or cached_opts

  restore()
end

return {
  open_theme_picker = open_theme_picker,
  setup = setup,
}
