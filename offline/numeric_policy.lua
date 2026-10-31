-- Storage limits shared by every view and writer. Game tuning ranges are not type limits.
local M={F32_MAX=3.4028234663852886e38}
local float=require('ffi').new('float[1]')
-- Display simple decimals within one float32 storage unit, without dropping
-- meaningful digits from less regular values or rounding tiny values to zero.
function M.display(value)
 if value==nil then return '?'end
 if value~=value or math.abs(value)==math.huge then return tostring(value)end
 if math.abs(value)==M.F32_MAX then return value<0 and'-FLT_MAX'or'FLT_MAX'end
 if value==0 then return'0'end
 if value%1==0 and math.abs(value)<=9007199254740992 then return string.format('%.0f',value)end
 local _,exponent=math.frexp(math.abs(value))
 local unit=math.max(2^-149,math.ldexp(1,exponent-24))
 for digits=1,9 do
  local text=string.format('%.'..digits..'g',value)
  if math.abs(tonumber(text)-value)<=unit then return text end
 end
 return string.format('%.9g',value)
end
-- For arithmetic, use the shortest decimal which reproduces the exact stored
-- float. Adding 0.1 twice to float32(200) must equal float32(200.2), rather than
-- carrying float32(200.1)'s binary residue into the next addition.
function M.increment(value,amount)
 float[0]=value
 if tonumber(float[0])==value then
  for digits=1,9 do
   local decimal=tonumber(string.format('%.'..digits..'g',value))
   float[0]=decimal
   if tonumber(float[0])==value then return decimal+amount end
  end
 end
 return value+amount
end
local R={u8={0,255},i8={-128,127},u16={0,65535},i16={-32768,32767},
 u32={0,4294967295},enum={0,4294967295},i32={-2147483648,2147483647},flag={0,1}}
local SELECTOR={gun=true,grenade=true,tier=true}
local SCALAR={[0]='i8',[1]='i16',[2]='i32',[4]='u8',[5]='u16',[6]='u32',[16]='u32'}
local widths={i8=1,u8=1,i16=2,u16=2,i32=4,u32=4,enum=4}
local function member_type(schemas,typ,at,depth)
 if depth>24 or not schemas[typ]then return end
 for _,m in ipairs(schemas[typ].members or{})do if at>=m.offset and at<m.offset+m.size then
  if m.storage==20 then
   local stride=m.atom==2 and m.count>0 and m.size/m.count or m.size
   return member_type(schemas,m.type,(at-m.offset)%stride,depth+1)
  end
  local s=SCALAR[m.storage]
  if s and m.atom~=3 and (at-m.offset)%widths[s]==0 then return s end
 end end
end
-- Resolve signedness from the installed type library before any view creates a shared field.
function M.storage(metadata,kind,offset,fallback)
 if not widths[fallback]or type(offset)~='number'then return fallback end
 local schemas=metadata and metadata.schemas;local root=schemas and schemas[kind]
 local array=root and root.members and root.members[2];local row=array and schemas[array.type]
 if not(row and row.size>0 and array.atom==2 and array.storage==20 and offset>=array.offset and offset<array.offset+array.size)then return fallback end
 if M.schemas~=schemas then M.schemas=schemas;M.cache={}end
 local cache=M.cache[kind];if not cache then cache={};M.cache[kind]=cache end
 local relative=(offset-array.offset)%row.size
 if cache[relative]==nil then cache[relative]=member_type(schemas,array.type,relative,0)or false end
 local s=cache[relative];return s and widths[s]==widths[fallback]and s or fallback
end
function M.bounds(field)
 if type(field)=='string'then field={storage=field}end
 if field.demolition then return 0,4294967295,true end
 local s=field.storage
 if s=='bits'then return 0,2^field.bit_width-1,true end
 local bit=s and s:match('^bit[0-7]$')
 if bit then return 0,1,true end
 local width=s and s:match('^bits[124]_%d+_(%d+)$')
 if width then return 0,2^tonumber(width)-1,true end
 local r=R[s];if r then return r[1],r[2],true end
 if s=='f32'or s=='virtual'then return -M.F32_MAX,M.F32_MAX,false end
end
function M.validate(field,value)
 if type(value)~='number'or value~=value or value<=-math.huge or value>=math.huge then return nil,'Enter a finite number.'end
 local lo,hi,integer=M.bounds(field)
 if not lo then return value end -- Structured selectors resolve their own record/byte representation.
 if integer then value=math.floor(value+.5)end
 if value<lo or value>hi then return nil,string.format('%s range: %s to %s.',field.storage,tostring(lo),tostring(hi))end
 if field.storage=='f32' then float[0]=value;value=tonumber(float[0])end
 return value
end
function M.valid(field,value)
 local normalized=M.validate(field,value);return normalized~=nil and normalized==value
end
function M.row(row)
 if row.hash64 or row.custom_edit or row.custom_change or row.choice=='holster'or row.choice=='pod_twin'
    or SELECTOR[row.storage]then return row.min,row.max end
 local lo,hi
 if row.mult or row.span or row.scale then lo,hi=M.bounds(row.storage)
 else
  for _,part in ipairs(row.parts or{})do
   local a,b=M.bounds(part.field)
   if a then lo=lo and math.max(lo,a)or a;hi=hi and math.min(hi,b)or b end
  end
  if not lo then lo,hi=M.bounds(row.storage)end
 end
 if lo then row.min,row.max,row.limit=lo,hi,nil end
 return row.min,row.max
end
function M.clamp(field,value)
 local lo,hi,integer=M.bounds(field)
 if not lo or not value or value~=value then return value end
 value=math.max(lo,math.min(hi,value));return integer and math.floor(value+.5)or value
end
function M.accept(row,c)
 if row and row.custom_edit then return not c:find('[%z\1-\31]')end
 if row and row.hash64 then return c:match('^[%da-fA-FxX]$')~=nil end
 return c:match('^[%da-fA-FxXeE%.,%+%-]$')~=nil
end
function M.input(row,value)
 if value~=nil and row.storage=='f32'and math.abs(value)~=M.F32_MAX then return M.display(value)end
 if value~=nil and M.bounds(row.storage)then return string.format('%.17g',value)end
end
return M
