-- Strict JSON data, never executable Lua. UTF-8 and escaped surrogate pairs are supported.
local M={null={}}
function M.array(t)return setmetatable(t or{},{__json_array=true})end
local function utf8(n)
 if n<128 then return string.char(n)end
 if n<2048 then return string.char(192+math.floor(n/64),128+n%64)end
 if n<65536 then return string.char(224+math.floor(n/4096),128+math.floor(n/64)%64,128+n%64)end
 return string.char(240+math.floor(n/262144),128+math.floor(n/4096)%64,128+math.floor(n/64)%64,128+n%64)
end
function M.decode(s,max_bytes)
 assert(type(s)=='string'and #s<=(max_bytes or 16*1024*1024),'JSON exceeds its input size limit')
 s=s:gsub('^\239\187\191','');local i,n=1,#s
 local function fail(reason)error('JSON byte '..i..': '..reason,0)end
 local function space()local _,e=s:find('^[ \r\n\t]*',i);i=(e or i-1)+1 end
 local value
 local function str()
  if s:sub(i,i)~='"'then fail('expected a string')end
  i=i+1;local out={};local start=i
  while i<=n do
   local c=s:byte(i)
   if c==34 then out[#out+1]=s:sub(start,i-1);i=i+1;return table.concat(out)end
   if c<32 then fail('unescaped control character')end
   if c==92 then
    out[#out+1]=s:sub(start,i-1);i=i+1;local e=s:sub(i,i)
    local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
    if escapes[e]then out[#out+1]=escapes[e];i=i+1
    elseif e=='u'then
     local hex=s:sub(i+1,i+4);if not hex:match('^%x%x%x%x$')then fail('invalid Unicode escape')end
     local code=tonumber(hex,16);i=i+5
     if code>=0xD800 and code<=0xDBFF then
      if s:sub(i,i+1)~='\\u'then fail('missing low surrogate')end
      local low=tonumber(s:sub(i+2,i+5),16)
      if not low or low<0xDC00 or low>0xDFFF then fail('invalid low surrogate')end
      code=0x10000+(code-0xD800)*1024+low-0xDC00;i=i+6
     elseif code>=0xDC00 and code<=0xDFFF then fail('unexpected low surrogate')end
     out[#out+1]=utf8(code)
    else fail('invalid escape')end
    start=i
   else i=i+1 end
  end
  fail('unterminated string')
 end
 value=function(depth)
  if depth>64 then fail('nesting is too deep')end
  space();local c=s:sub(i,i)
  if c=='"'then return str()end
  if c=='{'or c=='['then
   local object=c=='{';local close=object and'}'or']';local out={};i=i+1;space()
   if s:sub(i,i)==close then i=i+1;return out end
   repeat
    local key
    if object then key=str();space();if s:sub(i,i)~=':'then fail('expected colon')end;i=i+1
     if out[key]~=nil then fail('duplicate object key '..key)end
    else key=#out+1 end
    out[key]=value(depth+1);space();c=s:sub(i,i);i=i+1
    if c==close then return out end
    if c~=','then fail('expected comma or '..close)end;space()
   until false
  end
  for literal,v in pairs({['true']=true,['false']=false,['null']=M.null})do
   if s:sub(i,i+#literal-1)==literal then i=i+#literal;return v end
  end
  local token=s:sub(i):match('^-?%d+%.%d+[eE][+-]?%d+')or s:sub(i):match('^-?%d+[eE][+-]?%d+')or s:sub(i):match('^-?%d+%.%d+')or s:sub(i):match('^-?%d+')
  if not token or token:match('^-?0%d')then fail('invalid value')end
  local number=tonumber(token);if not number or number==math.huge or number==-math.huge then fail('invalid number')end
  i=i+#token;return number
 end
 local out=value(0);space();if i<=n then fail('trailing data')end;return out
end
function M.encode(v,pretty,key_less)
 local function quote(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)
  local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
  return e[c]or string.format('\\u%04x',c:byte())
 end)..'"'end
 local function encode(x,depth)
  assert(depth<65,'JSON nesting is too deep')
  if x==M.null then return'null'end
  local t=type(x)
  if t=='string'then return quote(x)end
  if t=='boolean'then return x and'true'or'false'end
  if t=='number'then assert(x==x and math.abs(x)<math.huge);return string.format('%.17g',x)end
  assert(t=='table','unsupported JSON value')
  local keys,array={},true;for k in pairs(x)do keys[#keys+1]=k;if type(k)~='number'or k<1 or k%1~=0 then array=false end end
  if #keys==0 then return getmetatable(x)and getmetatable(x).__json_array and'[]'or'{}'end
  local out={}
  local function wrap(left,right)
   if not pretty then return left..table.concat(out,',')..right end
   local indent=string.rep('  ',depth+1)
   return left..'\n'..indent..table.concat(out,',\n'..indent)..'\n'..string.rep('  ',depth)..right
  end
  if array and #keys==#x then for i=1,#x do out[i]=encode(x[i],depth+1)end;return wrap('[',']')end
  table.sort(keys,key_less);for _,k in ipairs(keys)do assert(type(k)=='string');out[#out+1]=quote(k)..(pretty and': 'or':')..encode(x[k],depth+1)end
  return wrap('{','}')
 end
 return encode(v,0)..(pretty and'\n'or'')
end
return M
