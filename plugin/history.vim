hi def link WhidHeader      Number
hi def link WhidSubHeader   Identifier

fun! RegisterHistory()
  lua for k in pairs(package.loaded) do if k == "history" then package.loaded[k] = nil end end
  lua history = require("history")
  :lua history.register()
endfun

fun! FileHistory()
  lua for k in pairs(package.loaded) do if k == "history" then package.loaded[k] = nil end end
  lua history = require("history")
  :lua history.saveCurrrentFileToHistory()
endfun

fun! ProjectHistory()
  lua for k in pairs(package.loaded) do if k == "history" then package.loaded[k] = nil end end
  lua history = require("history")
  :lua history.saveCurrrentProjectToHistory()
endfun

fun! FindRoot()
  lua for k in pairs(package.loaded) do if k == "history" then package.loaded[k] = nil end end
  lua history = require("history")
  let g:fileProjectPath = v:lua.history.findRootForOpenedFile(".git")
  let g:projectPath = v:lua.history.findRootForOpenedFile(".git")
endfun

fun! HistoryPlugin()
  lua for k in pairs(package.loaded) do if k == "history" then package.loaded[k] = nil end end
  lua history = require("history")
  :lua history.world()
  :lua history.width()
  :lua history.register()
endfun


augroup HistoryPlugin
  autocmd!
augroup END


augroup HistoryRegisterHistory
  autocmd!
  autocmd TextYankPost * call RegisterHistory()
augroup END

augroup HeloFileHistory
  echom "sadfasdf"
  lua history = require("history")
  autocmd!
  autocmd BufRead * call FileHistory()
  autocmd BufRead * call ProjectHistory()
  autocmd BufEnter * call FindRoot()
augroup END
