local M = {}

--- Replace is not supported in cscope
---@param params EngineReplaceParams
---@return fun()? abort
function M.replace(params)
  params.on_finish('error', 'Replace not supported in cscope engine')
  return nil
end

return M 