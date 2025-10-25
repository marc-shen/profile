return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    ft = {"python"},
    config = function()
      require "configs.lspconfig"
      local servers = {"pyright"}
      vim.lsp.enable(servers)
    end,
  },

  {
    "folke/todo-comments.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- lazy = false, 
    event = "VeryLazy",
    opts = {},
  },

  {
    "goerz/jupytext.nvim",
    version = "0.2.0",
    -- lazy = false,
    ft = {"json","ipynb"},
    opts = {
      jupytext = "/Users/marcshen/.pixi/bin/jupytext",
      format = "markdown",
      update = true,
      autosync = true,
    },
  },

  {
    "Vigemus/iron.nvim",
    ft = { "python"}, -- 按文件类型懒加载
    version = "*",
    config = function()
      local iron = require("iron.core")
      local view = require("iron.view")
      local common = require("iron.fts.common")

      iron.setup({
        config = {
          scratch_repl = true, -- 是否使用临时 REPL
          repl_definition = {
            sh = { command = { "zsh" } },
            python = {
              command = {"pixi", "run", "ipython", "--no-autoindent" },
              -- command = {"pixi","run","python"},
              format = common.bracketed_paste_python,
              block_dividers = { "# %%", "#%%" },
              env = { PYTHON_BASIC_REPL = "1" },
            },
          },
          repl_filetype = function(_, ft)
            return ft
          end,
          dap_integration = true,
          -- 默认 REPL 打开在底部 40 行
          -- repl_open_cmd = view.split.rightbelow("%40"),
          repl_open_cmd = view.split.vertical.rightbelow("%40"),
        },
        keymaps = {
          toggle_repl = "<space>rr",
          restart_repl = "<space>rR",
          send_motion = "<space>sc",
          visual_send = "<space>sc",
          send_file = "<space>sf",
          send_line = "<space>sl",
          send_paragraph = "<space>sp",
          send_until_cursor = "<space>su",
          send_mark = "<space>sm",
          send_code_block = "<space>sb",
          send_code_block_and_move = "<space>sn",
          mark_motion = "<space>mc",
          mark_visual = "<space>mc",
          remove_mark = "<space>md",
          cr = "<space>s<cr>",
          interrupt = "<space>s<space>",
          exit = "<space>sq",
          clear = "<space>cl",
        },
        highlight = {
          italic = true
        },
        ignore_blank_lines = true,
      })

      -- 可选快捷键，快速聚焦或隐藏 REPL
      vim.keymap.set("n", "<space>rf", "<cmd>IronFocus<cr>")
      vim.keymap.set("n", "<space>rh", "<cmd>IronHide<cr>")
    end,
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
    opts = {
      completions = { lsp = { enabled = true } },
    },
    ft = { "markdown", "norg", "rmd", "org", "codecompanion" },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      -- Link H1 foreground/background to the 'Search' highlight so headings match Search
      if vim.api and vim.api.nvim_set_hl then
        vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { link = "Search" })
        vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg", { link = "DiffDelete" })

      else
        vim.cmd("highlight link RenderMarkdownH1Bg Search")
        vim.cmd("highlight link RenderMarkdownH3Bg DiffDelete")
      end
    end,
  },

  {
    "github/copilot.vim",
    event = "VeryLazy",

    config = function()
      -- 禁用默认 <Tab>
      vim.g.copilot_no_tab_map = true
    end,

    keys = {
      {
        "<C-j>", 
        'copilot#Accept("<CR>")', 
        mode = "i", 
        expr = true, 
        silent = true,
        replace_keycodes = false,
        desc = "Copilot Accept",
      },
    },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    event = "User FilePost",
    main = "ibl",
    opts = {},
    config = function(_, opts)
      local highlight = {
        "RainbowRed",
        "RainbowYellow",
        "RainbowBlue",
        "RainbowOrange",
        "RainbowGreen",
        "RainbowViolet",
        "RainbowCyan",
      }
      local hooks = require "ibl.hooks"
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "RainbowRed",    { fg = "#E06C75" })
        vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
        vim.api.nvim_set_hl(0, "RainbowBlue",   { fg = "#61AFEF" })
        vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
        vim.api.nvim_set_hl(0, "RainbowGreen",  { fg = "#98C379" })
        vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
        vim.api.nvim_set_hl(0, "RainbowCyan",   { fg = "#56B6C2" })
      end)
      require("ibl").setup {
        indent = { highlight = highlight },
      }
    end,
  },

  {
    "Isrothy/neominimap.nvim",
    version = "v3.x.x",
    lazy = false, -- NOTE: NO NEED to Lazy load
    keys = {
      { "<leader>nm", "<cmd>Neominimap Toggle<cr>", desc = "Toggle global minimap" },
      {"<C-,>", "<cmd>Neominimap Toggle<cr>", desc = "Toggle global minimap"},
    },
    init = function()
      vim.opt.wrap = true
      vim.opt.sidescrolloff = 36 -- Set a large value
      vim.opt.linebreak = true

      vim.g.neominimap = {
        auto_enable = true,
        layout = "split",
        split = {
          close_if_last_window = true,
        }
      }
    end,
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    lazy = false,
  },

  {
    "chrisgrieser/nvim-origami",
    event = "VeryLazy",
    opts = {
      foldtext ={
        lineCount = {
          template = "-- %d lines --",
          hlgroup = "Folded",
        }
      },
      foldKeymaps = {
      setup = false, -- modifies `h`, `l`, and `$`
      },
    }, -- needed even when using default config

    -- recommended: disable vim's auto-folding
    init = function()
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
    end,
  },
  {
    'Pocco81/auto-save.nvim',
    lazy = false,
    config = function()
		  require("auto-save").setup {
        trigger_events = {"InsertLeave", "TextChanged"},
		  }
	  end,
  },
}

