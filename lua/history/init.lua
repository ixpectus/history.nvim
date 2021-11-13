local fileOpenHistoryFile = "/home/ixpectus/.vim/fileHistory/"
local projectHistoryFile = "/home/ixpectus/.vim/projectHistoryFile"
local position = 1
local result = {}


local function filter(lines, line, fn)
  local a = {}
  local i = 1
  for _, v in pairs(lines) do
    if fn(v,line) then
      a[i] = v
      i = i+1
    end
  end
  return a
end


local function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    local formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))
    else
      print(formatting .. v)
    end
  end
end

local function tableToString(t)
  return table.concat(t, "\n")
end

local function file_exists(name)
   local f = io.open(name, "r")
   return f ~= nil and io.close(f)
end

local function readLines(f)
  local ll = {}
  for line in f:lines() do
    table.insert(ll,line)
  end
  return ll
end

local function addHistoryFile(historyFilename, filename)
  local f
  if file_exists(historyFilename) then
    f = io.open(historyFilename, "r")
  else
    f = io.open(historyFilename, "w+")
  end
  local ll = readLines(f)
  local cmp = function(a,b)
    return a ~= b
  end
  local filteredLines = filter(ll, filename, cmp)
  table.insert(filteredLines,1,filename)
  local fw = io.open(historyFilename, "w+")
  fw:write(tableToString(filteredLines))
  fw:close()
end


local function getParentPath(path)
    local pattern1 = "^(.+)/([^/]+)"
    return string.match(path,pattern1)
end

local function innerfindRoot(dir, mask)
  local maskPath = dir .. "/" .. mask
  -- print("mask " .. maskPath)
  if file_exists(maskPath) then
    return dir
  end
  -- print("dir " .. dir)
  local parentPath = getParentPath(dir)
  if parentPath == nil  then
    return ""
  end
  -- print("parent " .. parentPath)
  local root = innerfindRoot(parentPath, mask)
  if root ~= "" then
    return root
  end
  return nil
end

local function findRoot(dir, mask)
  if not file_exists(dir) then
    return nil
  end
  local res = innerfindRoot(dir,mask)
  if res ~= nil then
    return res
  end
  return dir
end


--------------------------------------------------

local function findRootForOpenedFile(mask)
  local f = vim.fn["expand"]("%:p:h")
  local root = findRoot(f,mask)
  return root
end
local function world()
    print "history world"
end

local function planet()
    print "history planets"
end

local function width()
  print(vim.fn.nvim_win_get_width(0))
  print(vim.g.mapleader)
end

local function projectFileHistoryName()
  local root = findRootForOpenedFile(".git")
  if root == nil then
    if vim.g.lastProject ~= nil then
      root = vim.g.lastProject
    else
      return nil
    end
  end
  local pp = vim.split(root, "/")
  local projectName = pp[#pp]
  local f = vim.fn["expand"]("%")
  return fileOpenHistoryFile .. projectName
end

local function saveCurrrentFileToHistory()
  local fileName = projectFileHistoryName()
  if fileName == nil then
    return
  end
  local f = vim.fn["expand"]("%")
  addHistoryFile(fileName, f)
end


local function register()
  local f = io.open("yank_history.txt", "a+")
  f:write(vim.fn["getreg"]("0"))
  f:write("\n")
  f:close()
end


local api = vim.api
local buf, win

local function open_window()
  print(vim.inspect(vim.g.lastProject))
  buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

  -- wipe - delete buffer on close
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- get dimensions
  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  -- calculate our floating window size
  local win_height = math.ceil(table.getn(result)+1)
  local win_width = math.ceil(width * 0.8)

  -- and its starting position
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  -- set some options
  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  -- and finally create it with buffer attached
  win = api.nvim_open_win(buf, true, opts)
end



local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end


-- Our file list start at line 4, so we can prevent reaching above it
-- from bottm the end of the buffer will limit movment
local function move_cursor()
  api.nvim_win_set_cursor(win, {position+1, 1})
end

local function loadResult()
  if table.getn(result) > 0 then
    return
  end
  local fileName = projectFileHistoryName()
  if fileName == nil then
    return
  end
  position = 1
  -- we will use vim systemlist function which run shell
  -- command and return result as list
  result = vim.fn.systemlist('cat '..fileName)

  -- with small indentation results will look better
  for k,v in pairs(result) do
    result[k] = ' '..result[k]
  end
end

local function updateView(direction)
  loadResult()
  api.nvim_buf_set_option(buf, 'modifiable', true)
  position = position + direction
  if position > table.getn(result) then
    position = 1
  end

  if position == 0 then position = table.getn(result) end
  if position == 0 then position = 1 end

  api.nvim_buf_set_lines(buf, 0, -1, false, {
      center('Last files'),
  })
  api.nvim_buf_set_lines(buf, 3, -1, false, result)

  api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  api.nvim_buf_add_highlight(buf, -1, 'WhidHeader', 0, 0, -1)
  api.nvim_buf_add_highlight(buf, -1, 'whidSubHeader', position, 0, -1)

  move_cursor()
  api.nvim_buf_set_option(buf, 'modifiable', false)
end


local function close_window()
  api.nvim_win_close(win, true)
end


-- Open file under cursor
local function open_file()
  local str = api.nvim_get_current_line()
  close_window()
  api.nvim_command('edit '..str)
end

local function set_mappings()
  local mappings = {
    ['<cr>'] = 'open_file()',
    k = 'updateView(-1)',
    j = 'updateView(1)',
    q = 'close_window()',
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"history".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
  -- local other_chars = {
  --   'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  -- }
  -- for k,v in ipairs(other_chars) do
  --   api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
  --   api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
  --   api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  -- end
end


local function saveCurrrentProjectToHistory()
  local root = findRootForOpenedFile(".git")
  if root == nil then
    return
  end
  vim.g.lastProject = root
  local f = vim.fn["expand"]("%:p")
  if root == f then
    return
  end
  addHistoryFile(projectHistoryFile , root)
end



local function pluginWindow()
  loadResult()
  open_window()
  set_mappings()
  updateView(0)
end

return {
    world = world,
    planet = planet,
    width = width,
    openWindow = open_window,
    pluginWindow = pluginWindow,
    updateView = updateView,
    saveCurrrentFileToHistory = saveCurrrentFileToHistory,
    register = register,
    findRoot = findRoot,
    findRootForOpenedFile = findRootForOpenedFile,
    saveCurrrentProjectToHistory = saveCurrrentProjectToHistory,
    move_cursor = move_cursor,
    open_file = open_file,
    close_window = close_window,
    projectFileHistoryName = projectFileHistoryName,
}
