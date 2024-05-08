local utils = require('grug-far/utils')
local uv = vim.loop

local function fetchWithRg(params)
  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = params.on_finish
  local args = params.args
  local isAborted = false
  local errorMessage = ''

  if not args then
    on_finish(nil)
    return
  end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle, pid
  handle, pid = uv.spawn("rg", {
    stdio = { nil, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args
  }, function(code, signal)
    stdout:close()
    stderr:close()
    handle:close()

    if code > 0 and #errorMessage == 0 then
      errorMessage = 'no matches'
    end
    local isSuccess = code == 0 and #errorMessage == 0
    on_finish(isSuccess and 'success' or 'error', errorMessage);
  end)

  local on_abort = function()
    isAborted = true
    stdout:close()
    stderr:close()
    handle:close()
    uv.kill(pid, 'sigkill')
  end

  local lastLine = ''
  uv.read_start(stdout, function(err, data)
    if isAborted then
      return
    end

    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stdout!'
      return
    end

    if data then
      -- large outputs can cause the last line to be truncated
      -- save it and prepend to next chunk
      local chunkData = lastLine .. data
      local i = utils.strFindLast(chunkData, "\n")
      if i then
        chunkData = string.sub(chunkData, 1, i)
        lastLine = string.sub(chunkData, i + 1, -1)
        on_fetch_chunk(chunkData)
      else
        lastLine = chunkData
      end
    else
      if #lastLine > 0 then
        on_fetch_chunk(lastLine)
      end
    end
  end)

  uv.read_start(stderr, function(err, data)
    if isAborted then
      return
    end

    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stderr!'
      return
    end

    if data then
      errorMessage = errorMessage .. data
    end
  end)

  return on_abort
end

return fetchWithRg
