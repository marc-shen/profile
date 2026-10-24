require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map("n", "]t", function()
  require("todo-comments").jump_next({keywords = { "ERROR", "WARNING" }})
end, { desc = "Next todo comment" })

map("n", "[t", function()
  require("todo-comments").jump_prev({keywords = { "ERROR", "WARNING" }})
end, { desc = "Previous todo comment" })

map("n", "：", ":", { noremap = true })
map("n", "；", ":", { noremap = true })
