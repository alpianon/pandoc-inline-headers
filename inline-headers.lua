local doc
local secHeaderDelim
local numberSections
local sectionsDepth
local chapDelim
local inlineHeaderLevel
local opts = {}

-- {option_name = default}
local opt_defaults = {
  inlineHeaderLevel = 0, -- values below 2 do not have any effect
  inlineHeaderDelim = '.',
  inlineHeaderStyle = 'emph',
  inlineHeaderNumStyle = 'plain',
  inlineHeaderParStyle = 'Customlist',
  inlineHeaderParStyleStart = 'start'
}
-- option inlineHeaders can be set only as header attribute

local style_classes = {
  plain = pandoc.Span, normal = pandoc.Span, standard = pandoc.Span,
  emph = pandoc.Emph, emphasis = pandoc.Emph, italic = pandoc.Emph,
  bold = pandoc.Strong, strong = pandoc.Strong,
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

local function update_opts(header)
  --[[get options in the following order:
  1) header attribute, f.e.: # My Header {#sec:mine inlineHeaderDelim=":"}
  2) (grand(grand)..)parent header attribute
  3) document metadata (YAML), f.e.: inlineHeaderDelim: ":"
  4) default (see opt_defaults)
  ]]
  level = header.level
  opts[level] = {}
  for key, default_value in pairs(opt_defaults) do    
    if header.attributes and header.attributes[key] then
      -- 1) header attribute
      opts[level][key] = header.attributes[key]
    end
    if not opts[level][key] then
      --2) (grand(grand)..)parent header attribute
      local parentlevel = level - 1
      while parentlevel > 0 do
        if opts[parentlevel] and opts[parentlevel][key] then
          opts[level][key] = opts[parentlevel][key]
          break
        end
        parentlevel = parentlevel - 1
      end
    end
    if not opts[level][key] then
      if doc.meta[key] then
      -- 3) document metadata
        opts[level][key] = get_meta(key)
      end
    end
    if not opts[level][key] then
      -- 4) default
      opts[level][key] = default_value
    end
  end
  opts[level].inlineHeaderLevel = 
    tonumber(opts[level].inlineHeaderLevel)
end
    
local function get_style_class(style)
  if style_classes[style] then
    return style_classes[style]
  else
    return pandoc.Span
    -- default: plain
  end
end

local function create_elem(text, style)
  local style_class = get_style_class(style)
  local content = {}
  text = string.gsub(text, "\t", "&#x09;") --necessary to preserve possible tabs
  local p = pandoc.read(text, "html").blocks -- set html format otherwise it may
                                             -- detect "false" markdown syntax
  if p[1] and p[1].content then
    content =  p[1].content
  end
  return style_class(content)
end

local function create_inlineheader(header, delim)
  --[[transform the header to an inline header, applying the emphasis
  (italic) or strong (bold) style, depending on the options]]
  local level = header.level
  local inlineHeaderStyle = opts[level].inlineHeaderStyle
  local inlineHeaderNumStyle = opts[level].inlineHeaderNumStyle
  local inlineHeaderDelim = opts[level].inlineHeaderDelim

  local header_str = stringify(header)
  local inline_header = {}
  if numberSections and secHeaderDelim and
    secHeaderDelim ~= chapDelim and
    string.find(header_str, secHeaderDelim)
  then
    -- apply different styles for section number and for section title
    local startpos, endpos  = string.find(header_str,secHeaderDelim)
    local sec_number = string.sub(header_str, 1, endpos)
    local sec_title = string.sub(header_str, endpos + 1)

    if sec_title ~= "" and delim then
      sec_title = sec_title..inlineHeaderDelim
    end
    local sec_number_elem_class = get_style_class(inlineHeaderNumStyle)
    local sec_number_elem = sec_number_elem_class(pandoc.Str(sec_number))
    local sec_title_elem = create_elem(sec_title, inlineHeaderStyle)
    table.insert(inline_header, sec_number_elem)
    
    if next(sec_title_elem.content) then --content table is not empty
      table.insert(inline_header, sec_title_elem)
      table.insert(inline_header, pandoc.Space())
    end
    return pandoc.Span(inline_header)
  else
    -- apply one style for the entire header text
    for i, e in ipairs(header.content) do
      table.insert(inline_header, e)
    end
    if inline_header.content and next(inline_header.content) then --content table is not empty 
      if sectionsDepth == -1 or header.level <= sectionsDepth then
        table.insert(inline_header, pandoc.Str(inlineHeaderDelim))
        table.insert(inline_header, pandoc.Space())
      else
        table.insert(inline_header, pandoc.Str(secHeaderDelim))
      end
    end
    local inline_header_class = get_style_class(inlineHeaderStyle)
    return inline_header_class(inline_header)
  end 
end

local function skip_comments(n)
  local skip = 0
  local nn, nextblock
  repeat
    nn, nextblock = next(doc.blocks, n + skip)
    skip = skip + 1   
  until nextblock.t ~= 'RawBlock'
  return nn, nextblock
end  

function iterate(document)
  doc = document
  secHeaderDelim = get_meta("secHeaderDelim")
  numberSections = get_meta("numberSections")
  sectionsDepth = tonumber(get_meta("sectionsDepth"))
  chapDelim = get_meta("chapDelim")
  inlineHeaderLevel = tonumber(get_meta("inlineHeaderLevel"))
  if chapDelim and secHeaderDelim and chapDelim == secHeaderDelim then
       io.stderr.write(
           "[inline-headers]: secHeaderDelim "..secHeaderDelim..
           " is equal to chapDelim, cannot apply a separate numbering style"..
           "for inline headers\n" 
       )
  end
  if inlineHeaderLevel == nil or tonumber(inlineHeaderLevel) < 1 then
    return nil -- do nothing
  end
  local i, n = nil, nil
  local curlevel = 0
  local inlineheader
  local attr = {}
  
  while next(doc.blocks, i) do
    n, block = next(doc.blocks,i)
    if block.t == 'Header' then
      curlevel = block.level
      update_opts(block)
      if curlevel >= opts[curlevel].inlineHeaderLevel then
        attr["custom-style"] = 
          opts[curlevel].inlineHeaderParStyle.." "..
          tostring(curlevel-opts[curlevel].inlineHeaderLevel+1).." "..
          opts[curlevel].inlineHeaderParStyleStart
        nn, nextblock = skip_comments(n)
        if nextblock.t == 'Para' then
          inlineheader = create_inlineheader(block, true)
          table.insert(nextblock.content, 1, inlineheader)
          doc.blocks[nn] = pandoc.Div(
            {nextblock}, pandoc.Attr(block.identifier,{},attr)
          )
          table.remove(doc.blocks, n)
          i = nn - 2 --one block has been removed above...
          if i < 1 then i = nil end
        else
          inlineheader = create_inlineheader(block, false)
          doc.blocks[n] = pandoc.Div(
            pandoc.Para({inlineheader}), pandoc.Attr(block.identifier,{},attr)
          )
        end
      end
    elseif block.t == 'Para' then
      local srclevel = curlevel
      while srclevel > 0 do
        if opts[scrlevel] then
          inlineHeaderLevel = opts[scrlevel].inlineHeaderLevel
          break
        end
        srclevel = srclevel - 1
      end
      if curlevel >= inlineHeaderLevel then
        attr["custom-style"] = 
          opts[curlevel].inlineHeaderParStyle.." "..
          tostring(curlevel - inlineHeaderLevel+1)
        doc.blocks[n] = pandoc.Div(block, pandoc.Attr('',{},attr))
      end
    end
    if i == nil then i = 1 else i = i + 1 end -- damn those petroleum engineers! 
  end
  return pandoc.Pandoc(doc.blocks, doc.meta)
end

return {{Pandoc = iterate}}