--[[
SPDX-License-Identifier: GPL-3.0-only
SPDX-FileCopyrightText: 2020 Alberto Pianon <pianon@array.eu>
]]

local doc

local function int(number)
  return number - (number % 1)
end

local function is_key_in(key, table)
  r = false
  for k, v in pairs(table) do
    if k == key then
      r = true
      break
    end
  end
  return r
end

local function upperRoman(number)
  local roman_digit_map = {
    {1000, 'M'}, {900, 'CM'}, {500, 'D'}, {400, 'CD'},
    {100, 'C'},  {90, 'XC'},  {50, 'L'},  {40, 'XL'},
    {10, 'X'},   {9, 'IX'},   {5, 'V'},   {4, 'IV'},
    {1, 'I'}
  }
  local roman_number = ''
  local i = 1
  local x, count
  while  number > 0 do
    x = 0
    count = int(number / roman_digit_map[i][1])
    while x < count do
      roman_number = roman_number..roman_digit_map[i][2]
      number = number - roman_digit_map[i][1]
      x = x + 1
    end
    i = i + 1
  end
  return roman_number
end

local function lowerRoman(number)
  local r = upperRoman(number)
  return r:lower()
end

local function lowerAlpha(number)
  return string.sub('abcdefghijklmnopqrstuvwxyz',number, number)
end

local function upperAlpha(number)
  return string.sub('ABCDEFGHIJKLMNOPQRSTUVWXYZ',number, number)
end

local number_formats = {
    Decimal = str,
    LowerAlpha = lowerAlpha,
    UpperAlpha = upperAlpha,
    LowerRoman = lowerRoman,
    UpperRoman = upperRoman
}

local function stringify(el)
  if el == nil then
    return el
  else
    return pandoc.utils.stringify(el)
  end
end

local function get_meta(key)
  return stringify(doc.meta[key])
end

local function get_boolean_meta(key)
  r = get_meta(key)
  if r == nil then
    return nil
  elseif r == "1" or r == "true" or r == "True" then
    return true 
  else 
    return false 
  end
end

local function get_number_meta(key)
  r = get_meta(key)
  if r then return tonumber(r) else return 0 end
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read "*a"
  file:close()
  return content
end

function get_crossrefYaml(meta)
  local crossrefYaml = stringify(meta['crossrefYaml'])
  local crossrefYaml_content
  local crossrefYaml_meta
  if crossrefYaml then
    crossrefYaml_content = read_file(crossrefYaml)
  end
  if crossrefYaml_content then
    crossrefYaml_content = "---\n"..crossrefYaml_content.."\n---\n"
    crossrefYaml_meta = pandoc.read(crossrefYaml_content).meta
    -- a little bit hacky, but it works; otherwise we would need to use
    -- a yaml library for lua
    for k, v in pairs(crossrefYaml_meta) do
      if not meta[k] then --do not override doc metadata
        meta[k] = v
      end
    end
  end
  return meta
end

function iterate(document)
  doc = document
  local numberSections = get_boolean_meta('numberSections')
  local sectionsDepth = get_number_meta('sectionsDepth')
  local secHeaderDelim = get_meta('secHeaderDelim')
  local inlineHeaderLevel = get_number_meta('inlineHeaderLevel')
  local crossrefOrderedList = get_boolean_meta('crossrefOrderedList')
  if not numberSections then return nil end
  if inlineHeaderLevel < 1 and not crossrefOrderedList then return nil end
  local curlevel = 0
  local curid = ''
  local i, n, block, number
  local metadata_end_el_idx, metadata_start_el_idx, content, header, para
  while next(doc.blocks, i) do
    n, block = next(doc.blocks,i)
    if block.t == 'Header' then
      curlevel = block.level
      curid = block.identifier
      i = n --> we do not put i=i+1 here because i could be nil
    elseif block.t == 'OrderedList' then
      local ordered_list = block
      if not is_key_in(ordered_list.style, number_formats) then
        return nil
      end
      local format_number = number_formats[ordered_list.style]
      i = n --> we do not put i=i+1 here because i could be nil
      for idx, list_item in ipairs(ordered_list.content) do
        number = format_number(idx)
        metadata_start_el_idx = nil
        metadata_end_el_idx = nil
        content = nil
        if list_item[1] and list_item[1].content then
          -- search for metadata within curly brackets:
          content = list_item[1].content
          for el_idx, el in ipairs(content) do
            if el.t == 'Str' then
              if string.sub(el.text, 1, 1) == '{' then
                metadata_start_el_idx = el_idx
              end
              if string.sub(el.text, -1, -1) == '}' then
                metadata_end_el_idx = el_idx
              end
            end
          end
        end      
        if metadata_start_el_idx ~= nil 
          and metadata_end_el_idx ~= nil
          and metadata_start_el_idx <= metadata_end_el_idx
        then
          -- metadata found!
          -- create Header object
          local header_content = {}
          for m = 1,metadata_end_el_idx do
            table.insert(header_content, content[m])
          end
          header_content = stringify(pandoc.Span(header_content))
          local number_str = ''
          if curlevel >= sectionsDepth and sectionsDepth ~=-1 then
            number_str = tostring(number)
            number_str = number_str..secHeaderDelim
          end
          local hashes = string.rep('#', curlevel + 1)
          local header_str = hashes..' '..number_str..' '..header_content
          header_str = string.gsub(header_str, "\t", "&#x09;")
          local metadata = string.match(header_str, '{.*}')
          metadata = string.sub(metadata, 2, -2) --remove curly brackets
          identifier_set_by_user = nil
          for i in string.gmatch(metadata, "%S+") do
            if string.sub(i,1,1) == "#" then
              identifier_set_by_user = i
              break
            end
          end
          header = pandoc.read(header_str).blocks[1]
          header.attributes['label'] = number
          if not identifier_set_by_user then
            -- avoid possible duplicate auto-generated identifiers
            header.identifier = curid..":"..number
          end
          -- create Para object
          para = {}
          if #content > metadata_end_el_idx then
            for p = metadata_end_el_idx+1, #content do
              table.insert(para, list_item[1].content[p])
            end
          end
          para = pandoc.Para(para)
        
        else
          -- metadata NOT found!
          -- create Header object
          local header_content
          if curlevel >= sectionsDepth and sectionsDepth ~=-1 then
            header_content = pandoc.Str(number..secHeaderDelim)
          else
            header_content = pandoc.Str("")
          end
          header = pandoc.Header(
            curlevel+1,
            {header_content},
            pandoc.Attr(curid..":"..number, {}, {label = number})
          )
          -- create Para object
          para = {}
          if list_item[1] and list_item[1].content then
            for k, el in ipairs(list_item[1].content) do
              table.insert(para, el)
            end
          end
          para = pandoc.Para(para)
        end
        -- create item in new "orderedlist" (-> sections)
        i = i + 1
        table.insert(doc.blocks, i, header)
        if para.content then
          i = i + 1
          table.insert(doc.blocks, i, para)
        end
      end
      table.remove(doc.blocks, n) -- remove old orderedlist
      i = i - 1
    else -- nothing to do, go to the next element
      i = n
    end
  end
  return pandoc.Pandoc(doc.blocks, doc.meta)
end

return {{Meta = get_crossrefYaml, Pandoc = iterate}}
