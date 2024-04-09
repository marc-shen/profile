vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.clipboard="unnamedplus"
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.termguicolors = true

local function bootstrap_pckr()
  local pckr_path = vim.fn.stdpath("data") .. "/pckr/pckr.nvim"

  if not vim.loop.fs_stat(pckr_path) then
    vim.fn.system({
      'git',
      'clone',
      "--filter=blob:none",
      'https://github.com/lewis6991/pckr.nvim',
      pckr_path
    })
  end

  vim.opt.rtp:prepend(pckr_path)
end

bootstrap_pckr()

require('pckr').add{
  -- My plugins here
  { "max397574/better-escape.nvim",
    config = function()
      require("better_escape").setup()
    end,
  },
  {'mbbill/undotree'},
  {'github/copilot.vim'},
  {"sitiom/nvim-numbertoggle"},
  {'nvim-tree/nvim-tree.lua'},
  {"pocco81/auto-save.nvim"},
}

-- nvim-tree
require("nvim-tree").setup({
    renderer = {
        icons = {
            show = {
                git = false,
                folder = false,
                file = false,
                modified = false,
                bookmarks = false,
                diagnostics = false,
                folder_arrow = false,
            },
        },
    },
})

local function open_nvim_tree(data)

  -- buffer is a real file on the disk
  local real_file = vim.fn.filereadable(data.file) == 1

  -- buffer is a [No Name]
  local no_name = data.file == "" and vim.bo[data.buf].buftype == ""

  if not real_file and not no_name then
    return
  end

  -- open the tree, find the file but don't focus it
  require("nvim-tree.api").tree.toggle({ focus = false, find_file = true, })
end

vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

-- better escape
vim.o.timeoutlen = 200
require("better_escape").setup({
    mapping = {"jk", "kj"}, -- a table with mappings to use
    timeout = vim.o.timeoutlen, -- the time in which the keys must be hit in ms. Use option timeoutlen by default
    clear_empty_lines = false, -- clear line after escaping if there is only whitespace
    keys = "<Esc>", -- keys used for escaping, if it is a function will use the result everytime
})

-- undo tree
vim.keymap.set('n', '<F5>', vim.cmd.UndotreeToggle)

-- copilot
vim.api.nvim_set_hl(0, "CopilotSuggestion", {fg = "lightgreen", bg = "grey"})


