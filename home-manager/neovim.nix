# Neovim — user-level config managed by home-manager.
# Colorscheme mirrors the Blade Runner 2049 palette from kitty.nix exactly.

{ ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;   # sets $EDITOR=nvim
    vimAlias      = true;   # `vim` → `nvim`

    extraLuaConfig = ''
      -- ============================================================
      --  Blade Runner 2049 — mirrors kitty terminal palette
      -- ============================================================
      vim.opt.termguicolors = true
      vim.opt.cursorline    = true
      vim.opt.number        = true
      vim.opt.signcolumn    = "yes"

      vim.cmd("highlight clear")
      vim.g.colors_name = "br2049"

      local hi = function(g, o) vim.api.nvim_set_hl(0, g, o) end

      -- Palette (lifted verbatim from kitty settings)
      local bg       = "#0d0d0d"
      local bg1      = "#111111"
      local bg2      = "#1a1a1a"
      local bg3      = "#2a2a2a"
      local fg       = "#e0c0a0"
      local fg_dim   = "#c0a080"
      local muted    = "#595959"
      local gray     = "#404040"
      local orange   = "#ff6b00"
      local orange2  = "#ff8533"
      local amber    = "#d4a040"
      local yellow   = "#ffcc66"
      local green    = "#7a9955"
      local green2   = "#a0c070"
      local blue     = "#5577aa"
      local blue2    = "#6699cc"
      local magenta  = "#aa6688"
      local magenta2 = "#cc88aa"
      local cyan     = "#4499aa"
      local cyan2    = "#66bbcc"
      local red      = "#cc4444"
      local red2     = "#ff5555"

      -- ---- Base UI ------------------------------------------------
      hi("Normal",         { fg = fg,      bg = bg })
      hi("NormalFloat",    { fg = fg,      bg = bg1 })
      hi("FloatBorder",    { fg = gray })
      hi("NormalNC",       { fg = fg_dim,  bg = bg })
      hi("SignColumn",     { bg = bg })
      hi("ColorColumn",    { bg = bg2 })
      hi("CursorLine",     { bg = bg1 })
      hi("CursorLineNr",   { fg = orange,  bold = true })
      hi("LineNr",         { fg = gray })
      hi("EndOfBuffer",    { fg = bg2 })
      hi("NonText",        { fg = bg2 })
      hi("SpecialKey",     { fg = gray })
      hi("MatchParen",     { fg = orange2, bg = bg3, bold = true })
      hi("Visual",         { bg = bg3 })
      hi("Folded",         { fg = muted,   bg = bg2 })
      hi("FoldColumn",     { fg = gray,    bg = bg })
      hi("VertSplit",      { fg = bg2 })
      hi("WinSeparator",   { fg = bg2 })

      -- ---- Search -------------------------------------------------
      hi("Search",         { fg = yellow,  bg = bg3 })
      hi("IncSearch",      { fg = bg,      bg = orange, bold = true })
      hi("Substitute",     { fg = bg,      bg = orange2 })

      -- ---- Status / tab line --------------------------------------
      hi("StatusLine",     { fg = fg,      bg = bg2 })
      hi("StatusLineNC",   { fg = muted,   bg = bg1 })
      hi("TabLine",        { fg = muted,   bg = bg1 })
      hi("TabLineSel",     { fg = orange2, bg = bg2, bold = true })
      hi("TabLineFill",    { bg = bg })
      hi("WinBar",         { fg = fg_dim,  bg = bg })
      hi("WinBarNC",       { fg = muted,   bg = bg })

      -- ---- Popup menu ---------------------------------------------
      hi("Pmenu",          { fg = fg,      bg = bg1 })
      hi("PmenuSel",       { fg = bg,      bg = orange, bold = true })
      hi("PmenuSbar",      { bg = bg2 })
      hi("PmenuThumb",     { bg = gray })
      hi("WildMenu",       { fg = bg,      bg = orange2 })

      -- ---- Messages / titles --------------------------------------
      hi("ErrorMsg",       { fg = red2 })
      hi("WarningMsg",     { fg = amber })
      hi("MoreMsg",        { fg = green2 })
      hi("ModeMsg",        { fg = fg,      bold = true })
      hi("Question",       { fg = green2 })
      hi("Title",          { fg = orange2, bold = true })
      hi("Directory",      { fg = blue2 })

      -- ---- Diff ---------------------------------------------------
      hi("DiffAdd",        { fg = green2,  bg = "#0d1a0d" })
      hi("DiffChange",     { fg = blue2,   bg = "#0d0d1a" })
      hi("DiffDelete",     { fg = red,     bg = "#1a0d0d" })
      hi("DiffText",       { fg = yellow,  bg = "#0d0d1a", bold = true })
      hi("Added",          { fg = green2 })
      hi("Changed",        { fg = blue2 })
      hi("Removed",        { fg = red })

      -- ---- Diagnostics --------------------------------------------
      hi("DiagnosticError",            { fg = red2 })
      hi("DiagnosticWarn",             { fg = amber })
      hi("DiagnosticInfo",             { fg = blue2 })
      hi("DiagnosticHint",             { fg = cyan2 })
      hi("DiagnosticOk",               { fg = green2 })
      hi("DiagnosticUnderlineError",   { undercurl = true, sp = red2 })
      hi("DiagnosticUnderlineWarn",    { undercurl = true, sp = amber })
      hi("DiagnosticUnderlineInfo",    { undercurl = true, sp = blue2 })
      hi("DiagnosticUnderlineHint",    { undercurl = true, sp = cyan2 })
      hi("DiagnosticVirtualTextError", { fg = red,    italic = true })
      hi("DiagnosticVirtualTextWarn",  { fg = amber,  italic = true })
      hi("DiagnosticVirtualTextInfo",  { fg = blue,   italic = true })
      hi("DiagnosticVirtualTextHint",  { fg = cyan,   italic = true })

      -- ---- Spell --------------------------------------------------
      hi("SpellBad",       { undercurl = true, sp = red2 })
      hi("SpellCap",       { undercurl = true, sp = yellow })
      hi("SpellRare",      { undercurl = true, sp = magenta2 })
      hi("SpellLocal",     { undercurl = true, sp = cyan2 })

      -- ============================================================
      --  Syntax groups
      -- ============================================================
      hi("Comment",        { fg = muted,    italic = true })

      hi("Constant",       { fg = yellow })
      hi("String",         { fg = green2 })
      hi("Character",      { fg = green2 })
      hi("Number",         { fg = yellow })
      hi("Boolean",        { fg = orange2 })
      hi("Float",          { fg = yellow })

      hi("Identifier",     { fg = fg })
      hi("Function",       { fg = orange2 })

      hi("Statement",      { fg = orange,   bold = true })
      hi("Conditional",    { fg = orange })
      hi("Repeat",         { fg = orange })
      hi("Label",          { fg = orange })
      hi("Operator",       { fg = fg_dim })
      hi("Keyword",        { fg = orange })
      hi("Exception",      { fg = red2 })

      hi("PreProc",        { fg = magenta2 })
      hi("Include",        { fg = magenta2 })
      hi("Define",         { fg = magenta2 })
      hi("Macro",          { fg = magenta2 })
      hi("PreCondit",      { fg = magenta2 })

      hi("Type",           { fg = blue2 })
      hi("StorageClass",   { fg = blue2 })
      hi("Structure",      { fg = blue2 })
      hi("Typedef",        { fg = blue2 })

      hi("Special",        { fg = orange2 })
      hi("SpecialChar",    { fg = orange2 })
      hi("Tag",            { fg = orange2 })
      hi("Delimiter",      { fg = fg_dim })
      hi("SpecialComment", { fg = muted,    italic = true })

      hi("Underlined",     { underline = true })
      hi("Error",          { fg = red2 })
      hi("Todo",           { fg = bg,       bg = amber, bold = true })

      -- ============================================================
      --  Treesitter tokens
      -- ============================================================
      hi("@comment",              { link = "Comment" })
      hi("@variable",             { fg = fg })
      hi("@variable.builtin",     { fg = orange2 })
      hi("@constant",             { fg = yellow })
      hi("@constant.builtin",     { fg = orange2 })
      hi("@string",               { link = "String" })
      hi("@string.escape",        { fg = cyan2 })
      hi("@number",               { link = "Number" })
      hi("@boolean",              { link = "Boolean" })
      hi("@float",                { link = "Float" })
      hi("@function",             { link = "Function" })
      hi("@function.builtin",     { fg = cyan2 })
      hi("@function.macro",       { fg = magenta2 })
      hi("@method",               { link = "Function" })
      hi("@parameter",            { fg = amber })
      hi("@field",                { fg = fg_dim })
      hi("@property",             { fg = fg_dim })
      hi("@constructor",          { fg = blue2 })
      hi("@keyword",              { link = "Keyword" })
      hi("@keyword.function",     { fg = orange,  bold = true })
      hi("@keyword.operator",     { fg = orange })
      hi("@keyword.return",       { fg = orange })
      hi("@conditional",          { link = "Conditional" })
      hi("@repeat",               { link = "Repeat" })
      hi("@operator",             { fg = fg_dim })
      hi("@type",                 { link = "Type" })
      hi("@type.builtin",         { fg = blue,    italic = true })
      hi("@include",              { link = "Include" })
      hi("@exception",            { link = "Exception" })
      hi("@namespace",            { fg = blue2 })
      hi("@tag",                  { fg = orange2 })
      hi("@tag.attribute",        { fg = amber })
      hi("@tag.delimiter",        { fg = fg_dim })
      hi("@punctuation.bracket",  { fg = fg_dim })
      hi("@punctuation.special",  { fg = orange2 })
      hi("@text",                 { fg = fg })
      hi("@text.strong",          { bold = true })
      hi("@text.emphasis",        { italic = true })
      hi("@text.uri",             { fg = orange2, underline = true })
      hi("@text.title",           { fg = orange2, bold = true })
      hi("@text.literal",         { fg = green2 })
      hi("@text.reference",       { fg = blue2 })
    '';
  };
}
