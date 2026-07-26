-- Minimal init used to run the plenary busted test suite.
-- Run with: make test   (or see the command in the Makefile)

local plugin_root = vim.fn.getcwd()
local deps = plugin_root .. "/.test/site/pack/deps/start"

-- Locate plenary: prefer an existing install (e.g. lazy.nvim) to avoid a
-- network clone; otherwise fetch a shallow copy into .test/ (gitignored).
local function ensure_plenary()
  local lazy_install = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
  if vim.fn.isdirectory(lazy_install) == 1 then
    return lazy_install
  end

  local target = deps .. "/plenary.nvim"
  if vim.fn.isdirectory(target) == 0 then
    vim.fn.mkdir(deps, "p")
    io.stdout:write("Cloning plenary.nvim...\n")
    vim.fn.system({
      "git", "clone", "--depth", "1",
      "https://github.com/nvim-lua/plenary.nvim", target,
    })
  end
  return target
end

vim.opt.runtimepath:prepend(plugin_root)
vim.opt.runtimepath:prepend(ensure_plenary())

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")
