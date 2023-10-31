-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

lvim.log.level = "warn"
lvim.colorscheme = "tokyodark"
lvim.leader = ","

vim.opt.whichwrap = "b,s"
vim.opt.ignorecase = true
vim.opt.cmdheight = 0

lvim.builtin.bufferline.options.indicator_icon = nil
lvim.builtin.bufferline.options.indicator = { style = "icon", icon = "▎" }
lvim.builtin.bufferline.options.always_show_bufferline = true lvim.builtin.lualine.style = "default"
lvim.builtin.lualine.options.theme = "horizon"
lvim.builtin.cmp.completion.completeopt = "menu,menuone,noinsert"
lvim.builtin.telescope.defaults.layout_config.prompt_position = "top"
lvim.builtin.telescope.defaults.sorting_strategy = "ascending"
lvim.builtin.telescope.defaults.path_display = { "smart" }
lvim.builtin.cmp.completion.completeopt = "menu,menuone,noinsert"

lvim.builtin.telescope.pickers = {
  find_files = {
    layout_config = {
      width = 0.80,
    },
    hidden = true,
  },
  live_grep = {
    layout_config = {
      width = 0.80,
    },
  },
}

lvim.builtin.alpha.dashboard.section.buttons.entries = {
  { "SPC f p", "  Recent Projects", "<CMD>Telescope projects theme=dropdown layout_config={height=60,width=120}<CR>" },
  { "SPC f o", "  Recently Used Files", "<CMD>Telescope oldfiles<CR>" },
  { "e", "  New File  ", ":ene <BAR> startinsert <CR>" },
  { "SPC f f", "  Find File", "<cmd>Telescope find_files layout_strategy=horizontal layout_config={height=0.8,width=0.8,preview_width=0.6} find_command=fd,--type,file,--hidden,--exclude,.git<CR>" },
  { "SPC f w", "  Live Grep", "<CMD>Telescope live_grep layout_strategy=horizontal layout_config={height=0.8,width=0.8,preview_width=0.6}<CR>" },
  {
    "SPC L c",
    "  Configuration",
    "<CMD>edit " .. require("lvim.config"):get_user_config_path() .. " <CR>",
  }
}

lvim.builtin.nvimtree.setup.renderer.indent_markers.enable = true
lvim.builtin.nvimtree.setup.view.width = 50
-- lvim.builtin.nvimtree.setup.config.mappings.list = {
--   { key = { "e", "<CR>", "o" }, action = "edit", mode = "n" },
--   { key = "h", action = "close_node" },
--   { key = "s", action = "split" },
--   { key = "v", action = "vsplit" },
--   { key = "C", action = "cd" },
-- }

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

lvim.autocommands = {
  {
    { "ColorScheme" },
    {
      pattern = "*",
      callback = function()
        -- change `Normal` to the group you want to change
        -- and `#ffffff` to the color you want
        -- see `:h nvim_set_hl` for more options
        vim.api.nvim_set_hl(0, "Normal", { bg = "#000000", underline = false, bold = true })
        vim.api.nvim_set_hl(0, "NormalNC", { bg = "#000000", underline = false, bold = false })
        vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "#000000", fg = "#000000", underline = false, bold = false })
        vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "#000000", underline = false, bold = false })
        vim.api.nvim_set_hl(0, "TelescopeBorder", { bg = "#000000", underline = false, bold = false })
        vim.api.nvim_set_hl(0, "SignColumn", { bg = "#000000", underline = false, bold = false })
        vim.api.nvim_set_hl(0, "MsgArea", { bg = "#000000", underline = false, bold = false })
        vim.api.nvim_set_hl(0, "CursorLine", { bg = "#121212", underline = false, bold = true })
        vim.api.nvim_set_hl(0, "Cursor", { bg = "#cccccc", underline = false, bold = true })
      end,
    },
  },
  {
    -- ref: https://github.com/nvim-tree/nvim-tree.lua/issues/1368#issuecomment-1512248492
    -- Quit Nvimtree on closing last buffer
    { "QuitPre" },
    {
      callback = function()
        local invalid_win = {}
        local wins = vim.api.nvim_list_wins()
        for _, w in ipairs(wins) do
          local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
          if bufname:match("NvimTree_") ~= nil then
            table.insert(invalid_win, w)
          end
        end
        if #invalid_win == #wins - 1 then
          -- Should quit, so we close all invalid windows.
          for _, w in ipairs(invalid_win) do vim.api.nvim_win_close(w, true) end
        end
      end
    },
  },
}

lvim.format_on_save = {
  enabled = true,
  pattern = "*.rs,*.lua",
  timeout = 1000,
}
