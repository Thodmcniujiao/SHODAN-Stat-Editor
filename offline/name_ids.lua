-- Exact textual IDs. Never round a 64-bit entity hash through a Lua number.
local U=require('stratagem_components')
local M={}
function M.hex(text)
 local s=tostring(text or''):match('^%s*(.-)%s*$'):upper()
 if s:match('^[EU]%x+$')and #s==17 then s=s:sub(2)end
 local h=s:match('^0X(%x+)$')or(#s==16 and s:match('^%x+$'))
 if h then if #h>16 then return nil end;return string.rep('0',16-#h)..h end
 local lo,hi=U.parse_u64(s);if lo then return string.format('%08X%08X',hi,lo)end
end
function M.decimal(hex)
 local h=M.hex(hex);if h then return U.u64_text(tonumber(h:sub(9),16),tonumber(h:sub(1,8),16))end
end
function M.hashes(text)
 local s=tostring(text or''):gsub('%s+',''):upper();local out={}
 if s:match('^%d+$')then
  local lo,hi=U.parse_u64(s);if lo then out[#out+1]=string.format('%08X%08X',hi,lo)end
 end
 local h=s:match('^0X(%x+)$')or s:match('^%x+$')
 if h and #h<=16 then out[#out+1]=string.rep('0',16-#h)..h end
 return out
end
-- In JSON hash values, digit-only strings are decimal; hexadecimal values use 0x.
function M.entity(text)
 if type(text)=='string'and text:match('^%d+$')then
  local lo,hi=U.parse_u64(text);if lo then return string.format('%08X%08X',hi,lo)end
  return nil
 end
 return M.hex(text)
end
function M.index(text)
 local s=tostring(text or''):gsub('%s+','')
 local h=s:match('^0[xX](%x+)$')or(s:find('[a-fA-F]')and s:match('^%x+$'))
 local n=h and #h<=8 and tonumber(h,16)or(not h and s:match('^%d+$')and #s<=10 and tonumber(s))
 if n and n>=0 and n<=4294967295 then return string.format('%.0f',n)end
end
return M
