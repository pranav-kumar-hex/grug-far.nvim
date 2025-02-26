local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local utils = require('grug-far.utils')
local parseResults = require('grug-far.engine.cscope.parseResults')

local M = {}

-- Map cscope operations to descriptions
local sym_map = {
  s = "Find this symbol",
  g = "Find this function definition",
  d = "Find functions called by this function",
  c = "Find functions calling this function",
  t = "Find this text string",
  r = "Change this text string",
  e = "Find this egrep pattern",
  f = "Find this file",
  i = "Find files #including this file",
}


-- Map operations to their cscope L-number format
local op_index_map = {
  s = "0", -- symbol
  g = "1", -- function definition
  d = "2", -- functions called by this function
  c = "3", -- functions calling this function
  t = "4", -- text string
  r = "5", -- replace text string
  e = "6", -- egrep pattern
  f = "7", -- file
  i = "8", -- files #including this file
}

-- Default symbols for each operation
local default_sym = {
  s = vim.fn.expand('<cword>'),
  g = vim.fn.expand('<cword>'),
  c = vim.fn.expand('<cword>'),
  t = vim.fn.expand('<cword>'),
  e = vim.fn.expand('<cword>'),
  f = vim.fn.expand('%:t'), -- current file name
  i = vim.fn.expand('%:t'), -- current file name
  d = vim.fn.expand('<cword>'),
  a = vim.fn.expand('<cword>')
}

--- Get search args for cscope
---@param inputs GrugFarInputs
---@param options GrugFarOptions 
---@return string[]?, string? operation
function M.getSearchArgs(inputs, options)
  if #inputs.search < (options.minSearchChars or 1) then
    return nil
  end

  local args = {'-d','-q', '-R'}
  
  -- Default to text search if no operation specified
  local op = 't'
  
  -- Check flags for operation
  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, '%S+') do
      if sym_map[flag] then
        op = flag
        break
      end
    end
  end

  -- Get search term or default symbol based on operation
  local search_term = #inputs.search > 0 and inputs.search or default_sym[op]

  table.insert(args, '-L' .. op_index_map[op])
  table.insert(args, search_term)

  return args, op
end

-- --- Parse cscope output into results format
-- ---@param data string Raw cscope output
-- ---@param operation string The cscope operation being performed
-- ---@return ParsedResultsData
-- local function parseResults(data, operation)
--   local lines = {}
--   local highlights = {}
--   local stats = {matches = 0, files = 0}
--   local files_seen = {}

--   for line in vim.gsplit(data, '\n') do
--     if #line > 0 then
--       vim.notify("Processing line: " .. line, vim.log.levels.DEBUG)
      
--       -- Parse cscope output format: file line function text
--       local file, func, lnum,  text = line:match("^([^ ]+) ([^ ]+) (%d+) (.*)$")
--       -- local file, lnum, func, text = line:match("([^%s]+)%s+(%d+)%s+([^%s]+)%s+(.*)")
      
--       if file and lnum and text then
--         vim.notify(string.format("Parsed: file=%s, lnum=%s, func=%s, text=%s", 
--           file, lnum, func or "nil", text), vim.log.levels.DEBUG)
        
--         -- Add file header if new file
--         if not files_seen[file] then
--           table.insert(lines, file)
--           table.insert(highlights, {
--             type = 'FilePath',
--             line = #lines,
--             col_start = 0,
--             col_end = #file
--           })
--           files_seen[file] = true
--           stats.files = stats.files + 1
--         end

--         -- Add result line with line number prefix
--         local prefix = string.format("%-7s", lnum .. ":")
--         local full_line = prefix .. text
--         table.insert(lines, full_line)

--         -- Add line number highlight
--         table.insert(highlights, {
--           type = 'LineNumber',
--           line = #lines,
--           col_start = 0,
--           col_end = #prefix - 1
--         })

--         -- Add match highlight based on operation
--         if operation == 'f' or operation == 'i' then
--           -- For file operations, highlight the whole path
--           table.insert(highlights, {
--             type = 'Match',
--             line = #lines,
--             col_start = #prefix,
--             col_end = #full_line
--           })
--         else
--           -- For other operations, try to highlight the matched symbol/text
--           local match_start = text:find(vim.pesc(func), 1, true)
--           if match_start then
--             table.insert(highlights, {
--               type = 'Match',
--               line = #lines,
--               col_start = #prefix + match_start - 1,
--               col_end = #prefix + match_start + #func - 1
--             })
--           end
--         end

--         stats.matches = stats.matches + 1
--       end
--     end
--   end

--   local results = {
--     lines = lines,
--     highlights = highlights,
--     stats = stats,
--   }
  
--   -- Convert results to JSON and append to log file
--   local json_str = vim.json.encode(results)
--   local log_file = io.open("log.json", "a")
--   if log_file then
--     log_file:write("\n ------------------------------\nCscope Search" ..json_str .. "\n ------------------------------\n")
--     log_file:close()
--   end

--   return results
-- end

--- Run cscope search
---@param params EngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
function M.search(params)
  local args, operation = M.getSearchArgs(params.inputs, params.options)
  if not args then
    params.on_finish('error', 'Invalid search parameters')
    return nil, nil
  end

  local abort = fetchCommandOutput({
    cmd_path = params.options.engines.cscope.path or 'cscope',
    args = args,
    on_fetch_chunk = function(data)
      local results = parseResults.parseResults(data, operation)
      params.on_fetch_chunk(results)
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      params.on_finish(status, errorMessage)
    end
  })

  return abort, args
end

return M 