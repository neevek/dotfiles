--[[
lvim is the global options object
Linters should be
filled in as strings with either
a global executable or a path to
an executable
]]
-- THESE ARE EXAMPLE CONFIGS FEEL FREE TO CHANGE TO WHATEVER YOU WANT

-- general
lvim.log.level = "warn"
lvim.format_on_save = true
lvim.colorscheme = "tokyodark"
-- to disable icons and use a minimalist setup, uncomment the following
-- lvim.use_icons = false

-- keymappings [view all the defaults by pressing <leader>Lk]
lvim.leader = ","
-- add your own keymapping
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
-- lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
-- lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"
-- unmap a default keymapping
-- vim.keymap.del("n", "<C-Up>")
-- override a default keymapping
-- lvim.keys.normal_mode["<C-q>"] = ":q<cr>" -- or vim.keymap.set("n", "<C-q>", ":q<cr>" )

-- Change Telescope navigation to use j and k for navigation and n and p for history in both input and normal mode.
-- we use protected-mode (pcall) just in case the plugin wasn't loaded yet.
-- local _, actions = pcall(require, "telescope.actions")
-- lvim.builtin.telescope.defaults.mappings = {
--   -- for input mode
--   i = {
--     ["<C-j>"] = actions.move_selection_next,
--     ["<C-k>"] = actions.move_selection_previous,
--     ["<C-n>"] = actions.cycle_history_next,
--     ["<C-p>"] = actions.cycle_history_prev,
--   },
--   -- for normal mode
--   n = {
--     ["<C-j>"] = actions.move_selection_next,
--     ["<C-k>"] = actions.move_selection_previous,
--   },
-- }

-- Use which-key to add extra bindings with the leader-key prefix
-- lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }
-- lvim.builtin.which_key.mappings["t"] = {
--   name = "+Trouble",
--   r = { "<cmd>Trouble lsp_references<cr>", "References" },
--   f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
--   d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
--   q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
--   l = { "<cmd>Trouble loclist<cr>", "LocationList" },
--   w = { "<cmd>Trouble workspace_diagnostics<cr>", "Workspace Diagnostics" },
-- }

-- TODO: User Config for predefined plugins
-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = true
lvim.builtin.nvimtree.setup.filters.dotfiles = true

-- if you don't want all the parsers change this to a table of the ones you want
lvim.builtin.treesitter.ensure_installed = {
  "bash",
  "c",
  "javascript",
  "json",
  "lua",
  "python",
  "typescript",
  "tsx",
  "css",
  "rust",
  "java",
  "yaml",
}

lvim.builtin.treesitter.ignore_install = { "haskell" }
lvim.builtin.treesitter.highlight.enabled = true

-- generic LSP settings

-- -- make sure server will always be installed even if the server is in skipped_servers list
-- lvim.lsp.installer.setup.ensure_installed = {
--     "sumeko_lua",
--     "jsonls",
-- }
-- -- change UI setting of `LspInstallInfo`
-- -- see <https://github.com/williamboman/nvim-lsp-installer#default-configuration>
-- lvim.lsp.installer.setup.ui.check_outdated_servers_on_open = false
-- lvim.lsp.installer.setup.ui.border = "rounded"
-- lvim.lsp.installer.setup.ui.keymaps = {
--     uninstall_server = "d",
--     toggle_server_expand = "o",
-- }

-- ---@usage disable automatic installation of servers
-- lvim.lsp.installer.setup.automatic_installation = false

-- ---configure a server manually. !!Requires `:LvimCacheReset` to take effect!!
-- ---see the full default list `:lua print(vim.inspect(lvim.lsp.automatic_configuration.skipped_servers))`
-- vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "pyright" })
-- local opts = {} -- check the lspconfig documentation for a list of all possible options
-- require("lvim.lsp.manager").setup("pyright", opts)

-- ---remove a server from the skipped list, e.g. eslint, or emmet_ls. !!Requires `:LvimCacheReset` to take effect!!
-- ---`:LvimInfo` lists which server(s) are skipped for the current filetype
-- lvim.lsp.automatic_configuration.skipped_servers = vim.tbl_filter(function(server)
--   return server ~= "emmet_ls"
-- end, lvim.lsp.automatic_configuration.skipped_servers)

-- -- you can set a custom on_attach function that will be used for all the language servers
-- -- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
-- lvim.lsp.on_attach_callback = function(client, bufnr)
--   local function buf_set_option(...)
--     vim.api.nvim_buf_set_option(bufnr, ...)
--   end
--   --Enable completion triggered by <c-x><c-o>
--   buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
-- end

-- -- set a formatter, this will override the language server formatting capabilities (if it exists)
-- local formatters = require "lvim.lsp.null-ls.formatters"
-- formatters.setup {
--   { command = "black", filetypes = { "python" } },
--   { command = "isort", filetypes = { "python" } },
--   {
--     -- each formatter accepts a list of options identical to https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#Configuration
--     command = "prettier",
--     ---@usage arguments to pass to the formatter
--     -- these cannot contain whitespaces, options such as `--line-width 80` become either `{'--line-width', '80'}` or `{'--line-width=80'}`
--     extra_args = { "--print-with", "100" },
--     ---@usage specify which filetypes to enable. By default a providers will attach to all the filetypes it supports.
--     filetypes = { "typescript", "typescriptreact" },
--   },
-- }

-- -- set additional linters
-- local linters = require "lvim.lsp.null-ls.linters"
-- linters.setup {
--   { command = "flake8", filetypes = { "python" } },
--   {
--     -- each linter accepts a list of options identical to https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#Configuration
--     command = "shellcheck",
--     ---@usage arguments to pass to the formatter
--     -- these cannot contain whitespaces, options such as `--line-width 80` become either `{'--line-width', '80'}` or `{'--line-width=80'}`
--     extra_args = { "--severity", "warning" },
--   },
--   {
--     command = "codespell",
--     ---@usage specify which filetypes to enable. By default a providers will attach to all the filetypes it supports.
--     filetypes = { "javascript", "python" },
--   },
-- }

-- Additional Plugins
-- lvim.plugins = {
--     {"folke/tokyonight.nvim"},
--     {
--       "folke/trouble.nvim",
--       cmd = "TroubleToggle",
--     },
-- }

-- Autocommands (https://neovim.io/doc/user/autocmd.html)
-- vim.api.nvim_create_autocmd("BufEnter", {
--   pattern = { "*.json", "*.jsonc" },
--   -- enable wrap mode for json files only
--   command = "setlocal wrap",
-- })
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "zsh",
--   callback = function()
--     -- let treesitter use bash highlight for zsh files as well
--     require("nvim-treesitter.highlight").attach(0, "bash")
--   end,
-- })


-- >>>>>>> custom settings start here <<<<<<<
-- no auto wrap
vim.opt.whichwrap = "b,s"
vim.opt.ignorecase = true
vim.opt.cmdheight = 0

lvim.builtin.bufferline.options.indicator_icon = nil
lvim.builtin.bufferline.options.indicator = { style = "icon", icon = "▎" }
lvim.builtin.bufferline.options.always_show_bufferline = true
lvim.builtin.lualine.style = "default"
lvim.builtin.lualine.options.theme = "horizon"
lvim.builtin.telescope.defaults.layout_config.prompt_position = "top"
lvim.builtin.telescope.defaults.sorting_strategy = "ascending"
lvim.builtin.telescope.pickers.find_files.hidden = true
lvim.builtin.telescope.defaults.path_display = { "smart" }
lvim.builtin.cmp.completion.completeopt = "menu,menuone,noinsert"

lvim.builtin.alpha.dashboard.section.buttons.entries = {
  { "SPC f p", "  Recent Projects", "<CMD>Telescope projects theme=dropdown layout_config={height=60,width=120}<CR>" },
  { "SPC f o", "  Recently Used Files", "<CMD>Telescope oldfiles<CR>" },
  { "e", "  New File  ", ":ene <BAR> startinsert <CR>" },
  { "SPC f f", "  Find File", "<cmd>Telescope find_files find_command=fd,--type,file,--hidden,--exclude,.git<CR>" },
  { "SPC s t", "  Live Grep", "<CMD>Telescope live_grep<CR>" },
  {
    "SPC L c",
    "  Configuration",
    "<CMD>edit " .. require("lvim.config"):get_user_config_path() .. " <CR>",
  }
}

lvim.builtin.nvimtree.setup.renderer.indent_markers.enable = true
lvim.builtin.nvimtree.setup.view.width = 50
lvim.builtin.nvimtree.setup.view.mappings.list = {
  { key = { "e", "<CR>", "o" }, action = "edit", mode = "n" },
  { key = "h", action = "close_node" },
  { key = "s", action = "split" },
  { key = "v", action = "vsplit" },
  { key = "C", action = "cd" },
}

-- disable signcolomn when opening terminal
vim.api.nvim_create_autocmd("TermEnter", {
  pattern = { "term://*toggleterm#*" },
  command = "setlocal signcolumn=no",
})

lvim.keys.normal_mode["tt"] = ":bwipeout <CR>"
lvim.keys.normal_mode["<space>"] = "yiw" -- yank word under cursor
lvim.keys.normal_mode["<space><space>"] = 'viw"+p' -- replace word under cursor
lvim.keys.normal_mode["<leader>r"] = ":%s/\\<<C-r><C-w>\\>//g<Left><Left>"
lvim.keys.normal_mode["H"] = "<cmd> :BufferLineCyclePrev<CR>"
lvim.keys.normal_mode["L"] = "<cmd> :BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<F3>"] = "<cmd> :NvimTreeToggle<CR>"
-- lvim.keys.normal_mode["<tab>"] = "<cmd> :lua vim.lsp.buf.code_action() <CR>"
-- lvim.keys.normal_mode["<leader>s"] = "<cmd> :lua require'popui.diagnostics-navigator'() <CR>"
lvim.keys.normal_mode["<leader>u"] = "<cmd> :PackerSync <CR>"
lvim.keys.insert_mode["jk"] = "<ESC>"
lvim.keys.insert_mode["JK"] = "<ESC>"

lvim.builtin.which_key.setup.triggers = { "<leader>" }
lvim.builtin.which_key.mappings["f"] = {
  name = "+Telescope",
  c = { "<cmd>Telescope<CR>", "Telescope" },
  r = { "<cmd>Telescope resume<CR>", "Telescope" },
  w = { "<cmd>Telescope live_grep<CR>", "Live Grep" },
  f = { "<cmd>Telescope find_files find_command=fd,--type,file,--hidden,--exclude,.git<CR>", "Find Files" },
  p = { "<cmd>Telescope projects theme=dropdown layout_config={height=60,width=120}<CR>", "Projects" },
  t = { "<cmd>Telescope colorscheme layout_config={height=60} enable_preview=true<CR>", "Colorschemes" },
  o = { "<cmd>Telescope oldfiles<CR>", "Recently Used Files" },
}

lvim.builtin.which_key.mappings["t"] = {
  name = "+ToggleTerm",
  a = { "<cmd>ToggleTerm direction=horizontal size=25<CR>", "Horizontal Terminal" },
  t = { "<cmd>ToggleTerm direction=float<CR>", "Floating Terminal" },
}

lvim.builtin.which_key.mappings["g"] = {
  name = "+Diffview",
  c = { ":DiffviewOpen HEAD", "Complare HEAD to specified <commit...>" },
  d = { "<cmd>DiffviewClose<CR>", "Close Diffview" },
  f = { "<cmd>DiffviewFileHistory<CR>", "View git history" },
  b = { "<cmd>ToggleBlameLine<CR>", "Blame" },
}

lvim.builtin.which_key.mappings["c"] = {
  name = "+Crates",
  i = { ":lua require('crates').show_crate_popup()<CR>", "Show crate information" },
  v = { ":lua require('crates').show_versions_popup()<CR>", "Show versions" },
  f = { ":lua require('crates').show_features_popup()<CR>", "Show features" },
  d = { ":lua require('crates').show_dependencies_popup()<CR>", "Show depedencies" },
}

lvim.builtin.dap.active = true
lvim.plugins = {
  { "lunarvim/colorschemes" },
  { "tiagovla/tokyodark.nvim" },
  { "sindrets/diffview.nvim" },
  { "williamboman/nvim-lsp-installer" },
  { "RishabhRD/popfix" },
  { "tveskag/nvim-blame-line" },
  {
    "saecki/crates.nvim",
    config = function()
      require("crates").setup({
        popup = {
          autofocus = true,
          show_version_date = true,
          copy_register = '"',
          style = "minimal",
          border = "rounded",
        }
      })

    end,
  },
  {
    "simrat39/rust-tools.nvim",
    config = function()
      local rt = require("rust-tools")

      rt.setup({
        server = {
          on_attach = function(_, bufnr)
            -- Hover actions
            vim.keymap.set("n", "<Leader>s", rt.hover_actions.hover_actions, { buffer = bufnr })
            -- Code action groups
            vim.keymap.set("n", "<TAB>", rt.code_action_group.code_action_group, { buffer = bufnr })
          end,
        },
        tools = {
          inlay_hints = {
            auto = true,
            only_current_line = false,
            show_parameter_hints = true,
            parameter_hints_prefix = " <- ",
            other_hints_prefix = " => ",
            max_len_align = false,
            max_len_align_padding = 1,
            right_align = false,
            right_align_padding = 7,
            highlight = "Comment",
          },
        },
      })
    end,
  },
}

vim.cmd [[
hi Comment guifg=#666666
let g:blameLineVirtualTextHighlight = 'Question'
let g:blameLineGitFormat = ' -> %h | %an | %ar | %s'
]]
-- >>>>>>> custom settings end here <<<<<<<
