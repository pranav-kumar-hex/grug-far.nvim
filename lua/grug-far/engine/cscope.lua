local search = require('grug-far.engine.cscope.search')
local replace = require('grug-far.engine.cscope.replace')

---@type GrugFarEngine
local CscopeEngine = {
  type = 'cscope',

  isSearchWithReplacement = function(inputs, options)
    -- Cscope doesn't support replacement
    return false
  end,

  showsReplaceDiff = function(options)
    -- Cscope doesn't support showing replace diff
    return false
  end,

  search = search.search,

  replace = replace.replace,

  isSyncSupported = function()
    -- Cscope doesn't support sync
    return false
  end,

  sync = function()
    -- not supported
  end,

  getInputPrefillsForVisualSelection = function(visual_selection, initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)
    prefills.search = table.concat(visual_selection, '\n')
    return prefills
  end,
}

return CscopeEngine 