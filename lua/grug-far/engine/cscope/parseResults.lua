local utils = require('grug-far.utils')
local engine = require('grug-far.engine')
local ResultHighlightType = engine.ResultHighlightType
local ResultLineGroup = engine.ResultLineGroup

local M = {}

---@type ResultHighlightSign
local change_sign = { icon = 'resultsChangeIndicator', hl = 'GrugFarResultsChangeIndicator' }
---@type ResultHighlightSign
local removed_sign = { icon = 'resultsRemovedIndicator', hl = 'GrugFarResultsRemoveIndicator' }
---@type ResultHighlightSign
local added_sign = { icon = 'resultsAddedIndicator', hl = 'GrugFarResultsAddIndicator' }
---@type ResultHighlightSign
local separator_sign = { icon = 'resultsDiffSeparatorIndicator', hl = 'GrugFarResultsDiffSeparatorIndicator' }

local HighlightByType = {
  [ResultHighlightType.LineNumber] = 'GrugFarResultsLineNo',
  [ResultHighlightType.ColumnNumber] = 'GrugFarResultsLineColumn',
  [ResultHighlightType.FilePath] = 'GrugFarResultsPath',
  [ResultHighlightType.Match] = 'GrugFarResultsMatch',
  [ResultHighlightType.MatchAdded] = 'GrugFarResultsMatchAdded',
  [ResultHighlightType.MatchRemoved] = 'GrugFarResultsMatchRemoved',
  [ResultHighlightType.DiffSeparator] = 'Normal',
}

local last_line_group_id = 0
local function get_next_line_group_id()
  last_line_group_id = last_line_group_id + 1
  return last_line_group_id
end

---@class CscopeMatch
---@field file string
---@field line_number integer
---@field function string
---@field text string

--- adds result lines
---@param resultLine string line to add
---@param line_number integer
---@param match_text string text to highlight
---@param lines string[] lines table to add to
---@param highlights ResultHighlight[] highlights table to add to
---@param line_group ResultLineGroup
---@param lineNumberSign? ResultHighlightSign
---@param matchHighlightType? ResultHighlightType
local function addResultLine(
  resultLine,
  line_number,
  match_text,
  lines,
  highlights,
  line_group,
  lineNumberSign,
  matchHighlightType
)
  local line_group_id = get_next_line_group_id()
  local current_line = #lines
  local line_no = tostring(line_number)
  local prefix = string.format('%-7s', line_no .. '-')

  -- Add line number highlight
  table.insert(highlights, {
    line_group = line_group,
    line_group_id = line_group_id,
    hl_type = ResultHighlightType.LineNumber,
    hl = HighlightByType[ResultHighlightType.LineNumber],
    start_line = current_line,
    start_col = 0,
    end_line = current_line,
    end_col = #line_no,
    sign = lineNumberSign,
  })

  resultLine = prefix .. resultLine

  -- Add match highlight if text provided
  if matchHighlightType and match_text then
    local match_start = resultLine:find(vim.pesc(match_text), #prefix + 1, true)
    if match_start then
      table.insert(highlights, {
        line_group = line_group,
        line_group_id = line_group_id,
        hl_type = matchHighlightType,
        hl = HighlightByType[matchHighlightType],
        start_line = current_line,
        start_col = match_start - 1,
        end_line = current_line,
        end_col = match_start + #match_text - 1,
      })
    end
  end

  table.insert(lines, utils.getLineWithoutCarriageReturn(resultLine))
end

--- parse results data and get info
---@param data string Raw cscope output
---@param operation string The cscope operation being performed
---@return ParsedResultsData
function M.parseResults(data, operation)
  local stats = { files = 0, matches = 0 }
  local lines = {}
  local highlights = {}
  local files_seen = {}

  -- Parse cscope output lines
  for line in vim.gsplit(data, '\n') do
    if #line > 0 then
      -- Parse cscope output format: file function line text
    --   local log_file = io.open("log.json", "a")
    --   log_file:write(line)
      local file, func, lnum, text = line:match("^([^ ]+) ([^ ]+) (%d+) (.*)$")
    --   log_file:write("file".. file)
    --   log_file:write("func".. func)
    --   log_file:write("lnum".. lnum)
    --   log_file:write("text".. text)
      if file and lnum and text then
        -- Add file header if new file
        if not files_seen[file] then
          stats.files = stats.files + 1
          files_seen[file] = true
          
          table.insert(highlights, {
            line_group = ResultLineGroup.FilePath,
            line_group_id = get_next_line_group_id(),
            hl_type = ResultHighlightType.FilePath,
            hl = HighlightByType[ResultHighlightType.FilePath],
            start_line = #lines,
            start_col = 0,
            end_line = #lines,
            end_col = #file,
          })
          table.insert(lines, file)
        end

        stats.matches = stats.matches + 1

        -- Add result line with appropriate highlighting based on operation
        local highlight_text = operation == 'f' and file or func
        addResultLine(
          text,
          tonumber(lnum),
          highlight_text,
          lines,
          highlights,
          ResultLineGroup.MatchLines,
          change_sign,
          ResultHighlightType.Match
        )
      end
    end
  end

  local results = {
    lines = lines,
    highlights = highlights,
    stats = stats,
  }
  
--   -- Convert results to JSON and append to log file
--   local json_str = vim.json.encode(results)
--   local log_file = io.open("log.json", "a")
--   if log_file then
--     log_file:write("\n ------------------------------\nCscope Search" ..json_str .. "\n ------------------------------\n")
--     log_file:close()
--   end

  return results

end

return M 