vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.termguicolors = true

vim.g.mapleader = ' '
vim.api.nvim_create_user_command('Q', 'qa', {})
vim.api.nvim_create_user_command('WQ', 'wqa', {})
vim.api.nvim_create_user_command('W', 'wa', {})
vim.api.nvim_set_keymap('n', '<Leader><Tab>', ':tabnew<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<F3>', ':!ruff format %<CR>', { noremap = true, silent = false })

-- clipboard setting --
vim.opt.clipboard = 'unnamedplus'

vim.g.clipboard = {
  name = 'WslClipboard',
  copy = {
    ['+'] = '/mnt/c/Windows/system32/clip.exe',
    ['*'] = '/mnt/c/Windows/system32/clip.exe',
  },
  paste = {
    ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
  },
  cache_enabled = 0,
}



local map = vim.keymap.set
local expr_options = { expr = true, silent = true }
--Remap for dealing with visual line wraps
map("n", "k", "v:count == 0 ? 'gk' : 'k'", expr_options)
map("n", "j", "v:count == 0 ? 'gj' : 'j'", expr_options)
vim.api.nvim_set_keymap('n', 'H', '^', { noremap = true })
vim.api.nvim_set_keymap('n', 'L', '$', { noremap = true })

-- node environment --
vim.g.coc_node_path = '/usr/bin/node'

-- vim-plug --
local vim = vim
local Plug = vim.fn['plug#']
vim.call('plug#begin')

Plug('/home/linuxbrew/.linuxbrew/opt/fzf/')
Plug('ibhagwan/fzf-lua', {['branch']= 'main'})

Plug('nvim-lua/plenary.nvim')
Plug("folke/todo-comments.nvim")

Plug('neoclide/coc.nvim', { ['branch'] = 'release' })
Plug('sitiom/nvim-numbertoggle')
Plug('github/copilot.vim')
Plug('Pocco81/auto-save.nvim')
Plug('max397574/better-escape.nvim')
Plug('nvim-treesitter/nvim-treesitter', {['do']=':TSUpdate'})
Plug('mfussenegger/nvim-dap')
Plug('mfussenegger/nvim-dap-python')
Plug('nvim-neotest/nvim-nio')
Plug('rcarriga/nvim-dap-ui')

Plug('mbbill/undotree')

Plug('loctvl842/monokai-pro.nvim')

vim.call('plug#end')

-- Plug config --
require("auto-save").setup {enabled = true}

require("fzf-lua").setup{files={git_icons=false}}
vim.keymap.set("n", "<c-P>", require('fzf-lua').files, { desc = "Fzf Files" })

require("monokai-pro").setup({})
vim.cmd([[colorscheme monokai-pro]])

require("better_escape").setup {
    mappings = {
        i = {
            j = {
                k = function()
                    vim.api.nvim_input("<esc>")
                end
            },
            k = {
                j = function()
                    vim.api.nvim_input("<esc>")
                end
            },
        }
    }
}

require'nvim-treesitter.configs'.setup {
  ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "json", "yaml", "toml", "html", "python", "rust", "cpp", "bash", "make", "cmake", "fortran", "latex"},
  sync_install = false,
  auto_install = true,
  highlight = {
    enable = true,
    disable = function(lang, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok and stats and stats.size > max_filesize then
            return true
        end
    end,
    additional_vim_regex_highlighting = false,
  },
}

vim.keymap.set('n', '<F2>', vim.cmd.UndotreeToggle)

require'todo-comments'.setup {
  signs = true,
  sign_priority = 8,
  keywords = {
    FIX = {
      icon = "飭?",
      color = "error",
      alt = { "FIXME", "BUG", "FIXIT", "ISSUE" }, 
    },
    TODO = { icon = "飥?", color = "info" },
    HACK = { icon = "飹?", color = "warning" },
    WARN = { icon = "飦?", color = "warning", alt = { "WARNING", "XXX" } },
    PERF = { icon = "飷?", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
    NOTE = { icon = "瞟?", color = "hint", alt = { "INFO" } },
    TEST = { icon = "鈴?", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
  },
  gui_style = {
    fg = "NONE",
    bg = "BOLD",
  },
  merge_keywords = true, 
  highlight = {
    multiline = true,
    multiline_pattern = "^.",
    multiline_context = 10,
    before = "",
    keyword = "wide",
    after = "fg", -- "fg" or "bg" or empty
    pattern = [[.*<(KEYWORDS)\s*:]],
    comments_only = true,
    max_line_len = 400,
    exclude = {},
  },
  colors = {
    error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
    warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
    info = { "DiagnosticInfo", "#2563EB" },
    hint = { "DiagnosticHint", "#10B981" },
    default = { "Identifier", "#7C3AED" },
    test = { "Identifier", "#FF00FF" }
  },
  search = {
    command = "rg",
    args = {
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
    },
    pattern = [[\b(KEYWORDS):]],
  },
}

require("dap-python").setup("/home/drawer/software/miniconda3/envs/py12/bin/python")
vim.api.nvim_set_keymap('n', '<leader>sn', ':lua require("dap-python").test_method()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>sf', ':lua require("dap-python").test_class()<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<leader>ss', '<ESC>:lua require("dap-python").debug_selection()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
vim.keymap.set('n', '<Leader>b', function() require('dap').toggle_breakpoint() end)
vim.keymap.set('n', '<Leader>B', function() require('dap').set_breakpoint() end)
require("dapui").setup()
local dap, dapui = require("dap"), require("dapui")
dap.listeners.before.attach.dapui_config = function()
  dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

-- coc + copilot
local keyset = vim.keymap.set
-- Autocomplete
function _G.check_back_space()
    local col = vim.fn.col('.') - 1
    return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') ~= nil
end

vim.api.nvim_set_keymap('i', '<C-e>', 'copilot#Accept("<CR>")', {silent = true, script = true, expr = true})
local opts = {silent = true, noremap = true, expr = true, replace_keycodes = false}

keyset("i", "<C-j>", 'coc#pum#visible() ? coc#pum#next(1) : v:lua.check_back_space() ? "<C-j>" : coc#refresh()', opts)
keyset("i", "<C-k>", [[coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"]], opts)

local function map(mode, lhs, rhs, opts)
  vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
end

local opts = {expr = true, noremap = true}

map('i', '<Up>', 'pumvisible() ? "\\<C-k>\\<Up>" : "\\<Up>"', opts)
map('i', '<Down>', 'pumvisible() ? "\\<C-j>\\<Down>" : "\\<Down>"', opts)

