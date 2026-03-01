--%%offline:true 
ER = ER or { _tools = {} }

local keywords = {
  ["&"] = {type='op',value='and'},
  ["|"] = {type='op',value='or'},
  ["!"] = {type='op',value='not'},
  ["=>"] = {type='rule',value='rule'},
  ["="] = {type='assign',value='assign'},
  [">"] = {type='op',value='greater_than'},
  ["<"] = {type='op',value='less_than'},
  [">="] = {type='op',value='greater_equal'},
  ["<="] = {type='op',value='less_equal'},
  ["=="] = {type='op',value='equal'},
  ["~="] = {type='op',value='not_equal'},
  ["+"] = {type='op',value='plus'},
  ["-"] = {type='op',value='minus'},
  ["*"] = {type='op',value='multiply'},
  ["/"] = {type='op',value='divide'},
  ["{"] = {type='lbra',value='table_start'},
  ["}"] = {type='rbra',value='table_end'},
  [":"] = {type='colon',value='colon'},
  [";"] = {type='semicolon',value='semicolon'},
  [","] = {type='comma',value='comma'},
  ["."] = {type='dot',value='dot'},
  ["("] = {type='lpar',value='paren_open'},
  [")"] = {type='rpar',value='paren_close'},
  ["["] = {type='lsqb',value='bracket_open'},
  ["]"] = {type='rsqb',value='bracket_close'},
  ['local'] = {type='local',value='local'},
  ['function'] = {type='function',value='function'},
  ['end'] = {type='end',value='end'},
  ['if'] = {type='if',value='if'},
  ['then'] = {type='then',value='then'},
  ['else'] = {type='else',value='else'},
  ['elseif'] = {type='elseif',value='elseif'},
  ['while'] = {type='while',value='while'},
  ['do'] = {type='do',value='do'},
  ['loop'] = {type='loop',value='loop'},
  ['repeat'] = {type='repeat',value='repeat'},
  ['until'] = {type='until',value='until'},
  ['return'] = {type='return',value='return'},
  ['break'] = {type='break',value='break'},
  ['nil'] = {type='nil',value=false},
  ['true'] = {type='true',value=true},
  ['false'] = {type='false',value=false},
  ['for'] = {type='for',value='for'},
  ['in'] = {type='in',value='in'},
  ['not'] = {type='op',value='not'},
  ['and'] = {type='op',value='and'},
  ['or'] = {type='op',value='or'},
}

local function lookupTkType(t)
  for k,v in pairs(keywords) do
    if v.type == t then return k end
  end
  return nil
end

local identifierChars = "abcdefghijklmnopqrstuvwxyzåäöøABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖØ"

local tknsStrs = {
  {"0123456789","%d+%.?%d*",function(n) 
    return {type='number',value=tonumber(n)} 
  end
},
{"><!=~","[><!=~][>=]", function(t) 
  local k = keywords[t]
  if not k then error("Bad token:"..t) end
  return {type=k.type, value=k.value, tk=t}
end
},
{"+-*/(){}&|!:;,.<>=[]",".",function(t) 
  local k = keywords[t]
  if not k then error("Bad token:"..t) end
  return {type=k.type, value=k.value, tk=t}
end
},
{" \t\n","%s+",function(t) 
  return nil end
},
{'"\n"','"(.-)"',function(s) 
  return {type='string', value=s:sub(2,-2)} end
},
{"'\n'","'(.-)'",function(s) 
  return {type='string', value=s:sub(2,-2)} end
},
{identifierChars,"["..identifierChars.."]["..identifierChars.."_%d]*",function(id) 
  local k = keywords[id]
  if k then
    return {type=k.type, value=k.value, tk=id}
  end
  return {type='identifier', value=id} end
},
}

local tokenLookup = {}
for _,v in ipairs(tknsStrs) do
  local prefixes = v[1]
  local pattern = v[2]
  local handler = v[3]
  for i = 1, #prefixes do
    local c = prefixes:sub(i,i)
    if not tokenLookup[c] then
      tokenLookup[c] = {}
    end
    table.insert(tokenLookup[c], {pattern="^"..pattern, handler=handler})
  end
end

local tokenMT = {
  __tostring = function(self)
    return string.format("[%s:%s]", self.type, tostring(self.value))
  end
}

local function tokenizer(str)
  local pos = 1
  local function tkns()
    if pos > #str then return nil end
    local c = str:sub(pos,pos)
    local candidates = tokenLookup[c]
    if not candidates then
      error("Unexpected character at position "..pos..": "..c)
    end
    for _,cand in ipairs(candidates) do
      local s, e = str:find(cand.pattern, pos)
      if s == pos then
        local tokenStr = str:sub(s, e)
        local start,len = pos, e - pos + 1
        pos = e + 1
        local tokenVal = cand.handler(tokenStr)
        if tokenVal ~= nil then
          tokenVal.pos, tokenVal.len = start, len
          return setmetatable(tokenVal,tokenMT)
        else
          return tkns() -- Skip token (e.g. whitespace)
        end
      end
    end
    error("No matching token at position "..pos..": "..c)
  end
  return tkns
end

local function tokenStream(str)
  local tkns = tokenizer(str)
  local buffer = {}
  local function peek(n)
    n = n or 1
    while #buffer < n do
      local t = tkns()
      if t == nil then return nil end
      table.insert(buffer, t)
    end
    return buffer[n]
  end
  local function next()
    local t = peek(1)
    table.remove(buffer,1)
    return t
  end
  local function match(expectedType)
    local t = peek(1)
    if t and t.type == expectedType then
      next()
      return t
    else
      return nil
    end
  end
  local function expect(expectedType)
    local t = peek(1)
    if t and t.type == expectedType then
      next()
      return t
    else
      local exp = lookupTkType(expectedType) or expectedType
      local got = t and ("'"..t.tk.."'") or "end of input"
      error("Expected '"..exp.."', got "..got, 2)
    end
  end
  return {
    peek = peek,
    next = next,
    match = match,
    expect = expect,
  }
end

ER._tools.tokenizer = tokenizer
ER._tools.tokenStream = tokenStream
