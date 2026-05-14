-- TorrentOS — Neovim default config
-- Sensible defaults with TorrentOS colour hints.
-- For a full plugin setup, see: https://github.com/nvim-lua/kickstart.nvim

-- ── Leader key ───────────────────────────────────────────────────────────────
vim.g.mapleader      = ' '
vim.g.maplocalleader = ' '

-- ── Options ──────────────────────────────────────────────────────────────────
local o = vim.opt

-- Appearance
o.number         = true
o.relativenumber = true
o.signcolumn     = 'yes'
o.cursorline     = true
o.termguicolors  = true
o.laststatus     = 3        -- global statusline
o.showmode       = false    -- mode shown in statusline
o.showcmd        = false
o.ruler          = false
o.wrap           = false
o.linebreak      = true
o.list           = true
o.listchars      = { tab = '▸ ', trail = '·', nbsp = '␣', extends = '›', precedes = '‹' }
o.colorcolumn    = '100'
o.fillchars      = { eob = ' ', fold = ' ', foldopen = '', foldclose = '', foldsep = '│' }

-- Indentation
o.expandtab      = true
o.tabstop        = 4
o.softtabstop    = 4
o.shiftwidth     = 4
o.shiftround     = true
o.smartindent    = true
o.autoindent     = true

-- Search
o.ignorecase     = true
o.smartcase      = true
o.hlsearch       = true
o.incsearch      = true

-- Completion
o.completeopt    = { 'menuone', 'noselect', 'noinsert' }
o.pumheight      = 10

-- Files
o.backup         = false
o.writebackup    = false
o.swapfile       = false
o.undofile       = true
o.undodir        = vim.fn.stdpath('data') .. '/undodir'

-- Performance
o.updatetime     = 250
o.timeoutlen     = 400
-- Note: lazyredraw was removed in Neovim 0.10 — do not set it

-- Split direction
o.splitright     = true
o.splitbelow     = true

-- Scrolling
o.scrolloff      = 8
o.sidescrolloff  = 8

-- Folding
o.foldmethod     = 'indent'
o.foldlevel      = 99

-- Mouse
o.mouse          = 'a'
o.mousemoveevent = true

-- Clipboard — use system clipboard (Wayland: wl-clipboard)
o.clipboard      = 'unnamedplus'

-- ── Keymaps ───────────────────────────────────────────────────────────────────
local map = function(mode, lhs, rhs, opts)
    opts = vim.tbl_extend('force', { noremap = true, silent = true }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
end

-- Clear search highlight
map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Better window navigation
map('n', '<C-h>', '<C-w>h')
map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k')
map('n', '<C-l>', '<C-w>l')

-- Resize splits
map('n', '<C-Up>',    '<cmd>resize +2<CR>')
map('n', '<C-Down>',  '<cmd>resize -2<CR>')
map('n', '<C-Left>',  '<cmd>vertical resize -2<CR>')
map('n', '<C-Right>', '<cmd>vertical resize +2<CR>')

-- Move lines in visual mode
map('v', 'J', ":m '>+1<CR>gv=gv")
map('v', 'K', ":m '<-2<CR>gv=gv")

-- Better indenting
map('v', '<', '<gv')
map('v', '>', '>gv')

-- Keep cursor centred on search
map('n', 'n', 'nzzzv')
map('n', 'N', 'Nzzzv')
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')

-- Save with Ctrl+S
map({ 'n', 'i', 'v' }, '<C-s>', '<cmd>w<CR><Esc>')

-- Quit
map('n', '<leader>q', '<cmd>q<CR>')
map('n', '<leader>Q', '<cmd>qa!<CR>')

-- New splits
map('n', '<leader>|', '<cmd>vsplit<CR>')
map('n', '<leader>-', '<cmd>split<CR>')

-- Buffer navigation
map('n', '<S-l>', '<cmd>bnext<CR>')
map('n', '<S-h>', '<cmd>bprevious<CR>')
map('n', '<leader>x', '<cmd>bdelete<CR>')

-- File explorer (netrw)
map('n', '<leader>e', '<cmd>Lexplore 28<CR>')

-- Diagnostic navigation
map('n', '[d', vim.diagnostic.goto_prev)
map('n', ']d', vim.diagnostic.goto_next)
map('n', '<leader>d', vim.diagnostic.open_float)

-- ── Autocommands ─────────────────────────────────────────────────────────────
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd('TextYankPost', {
    group   = augroup('YankHighlight', { clear = true }),
    pattern = '*',
    callback = function() vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 180 }) end,
})

-- Remove trailing whitespace on save
autocmd('BufWritePre', {
    group    = augroup('TrimWhitespace', { clear = true }),
    pattern  = '*',
    callback = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[%s/\s\+$//e]])
        vim.api.nvim_win_set_cursor(0, pos)
    end,
})

-- Auto-reload files changed outside Neovim
autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
    group    = augroup('AutoReload', { clear = true }),
    pattern  = '*',
    callback = function()
        if vim.fn.mode() ~= 'c' then
            vim.cmd('checktime')
        end
    end,
})

-- Close certain filetypes with q
autocmd('FileType', {
    group   = augroup('QuickClose', { clear = true }),
    pattern = { 'help', 'man', 'qf', 'lspinfo', 'checkhealth', 'startuptime' },
    callback = function()
        vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = true })
    end,
})

-- Set 2-space indent for web languages
autocmd('FileType', {
    group   = augroup('WebIndent', { clear = true }),
    pattern = { 'html', 'css', 'scss', 'javascript', 'typescript', 'json', 'yaml', 'lua', 'vim' },
    callback = function()
        vim.opt_local.tabstop     = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.shiftwidth  = 2
    end,
})

-- ── Colour scheme ─────────────────────────────────────────────────────────────
-- Use built-in habamax as a reasonable dark fallback.
-- Install nvim-treesitter + a theme like 'tokyonight' or 'catppuccin' for better colours.
vim.cmd.colorscheme('habamax')

-- ── Status line (minimal built-in) ────────────────────────────────────────────
-- Replace with lualine or mini.statusline for something nicer.
o.statusline = ' %f %m%r%=%l:%c  %p%%  %{&filetype} '

-- ── Netrw settings ────────────────────────────────────────────────────────────
vim.g.netrw_banner    = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_winsize   = 28

-- ── Plugin manager hint ───────────────────────────────────────────────────────
-- To bootstrap lazy.nvim (recommended plugin manager):
--   git clone https://github.com/folke/lazy.nvim \
--     ~/.local/share/nvim/lazy/lazy.nvim
-- Then add to this file:
--   require('lazy').setup({ ... })
--
-- Starter config: https://github.com/nvim-lua/kickstart.nvim
