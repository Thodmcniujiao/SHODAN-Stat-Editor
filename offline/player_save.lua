-- Local testament_new.sav: bounded chunk codec, staged field edits and transactional save writes.
-- Nothing is written until commit(). Opaque bytes and unchanged compressed chunks are preserved.
local bit=require('bit')
local D=require('demolition')
local J=require('json_data')
local M={}
local MAX=4294967295
local function check(ok,s)if not ok then error('Player save: '..s,0)end end
local function u32(s,o)return D.u32(s,o)end
local function p32(v)return D.p32(v)end
local function put(s,o,v)return s:sub(1,o)..v..s:sub(o+#v+1)end
local crc_table={}
for i=0,255 do local v=i;for _=1,8 do v=bit.bxor(bit.rshift(v,1),bit.band(v,1)~=0 and 0xEDB88320 or 0)end;crc_table[i]=v end
function M.crc32(s)
 local v=-1;for i=1,#s do v=bit.bxor(bit.rshift(v,8),crc_table[bit.band(bit.bxor(v,s:byte(i)),255)])end
 v=bit.bnot(v);return v<0 and v+4294967296 or v
end
function M.inflate(s,limit)
 limit=limit or 65536;local src,n,out,at=1,#s,{},0
 local function length(v)
  if v==15 then repeat check(src<=n,'truncated LZ4 length');local x=s:byte(src);src=src+1;v=v+x;if x~=255 then break end until false end
  check(v<=limit,'LZ4 length exceeds block');return v
 end
 while src<=n do
  local token=s:byte(src);src=src+1;local literal=length(math.floor(token/16))
  check(src+literal-1<=n and at+literal<=limit,'LZ4 literals outside block')
  for i=src,src+literal-1 do at=at+1;out[at]=s:byte(i)end;src=src+literal
  if src>n then break end
  check(src+1<=n,'truncated LZ4 offset');local distance=s:byte(src)+s:byte(src+1)*256;src=src+2
  check(distance>0 and distance<=at,'invalid LZ4 back reference');local count=length(token%16)+4
  check(at+count<=limit,'LZ4 output exceeds block')
  for _=1,count do at=at+1;out[at]=out[at-distance]end
 end
 local strings={};for i=1,at,2048 do strings[#strings+1]=string.char(unpack(out,i,math.min(at,i+2047)))end
 return table.concat(strings)
end
-- Standard raw LZ4. Five trailing literals and a twelve-byte match-start margin
-- keep output compatible with native LZ4 decoders, including overlapping matches.
function M.deflate(s)
 local n=#s;local out,dict={},{};local anchor,pos=1,1
 local function extra(n)while n>=255 do out[#out+1]=string.char(255);n=n-255 end;out[#out+1]=string.char(n)end
 local function emit(last,ref,count)
  local literals=last-anchor;local match=count and count-4 or 0
  out[#out+1]=string.char(math.min(literals,15)*16+math.min(match,15))
  if literals>=15 then extra(literals-15)end
  out[#out+1]=s:sub(anchor,last-1)
  if ref then local distance=last-ref;out[#out+1]=string.char(distance%256,math.floor(distance/256));if match>=15 then extra(match-15)end end
 end
 while pos<=n-12 do
  local key=s:sub(pos,pos+3);local ref=dict[key];dict[key]=pos
  if ref and pos-ref<=65535 then
   local count=4;while pos+count<=n-5 and s:byte(ref+count)==s:byte(pos+count)do count=count+1 end
   emit(pos,ref,count);local stop=pos+count;for i=pos+1,stop-1 do if i<=n-3 then dict[s:sub(i,i+3)]=i end end
   pos=stop;anchor=pos
  else pos=pos+1 end
 end
 emit(n+1);return table.concat(out)
end
local MAGIC=string.char(0xD4,0xFD,0x1C,0x6B,0x5F,0x7B,0x23,0xCC)
function M.decode(raw)
 check(type(raw)=='string'and #raw>=40 and #raw<=32*1024*1024,'invalid container size')
 check(raw:sub(1,8)==MAGIC and u32(raw,8)==1,'unsupported container signature/version')
 check(u32(raw,12)==M.crc32(raw:sub(17)),'CRC32 mismatch')
 check(u32(raw,16)==#raw-28 and u32(raw,24)==0xF0000001 and u32(raw,32)==0,'unsupported chunk header')
 local declared=u32(raw,20);check(declared==u32(raw,28)and declared>0 and declared<=16*1024*1024,'invalid decoded length')
 local chunks,decoded={},{};local pos=36
 while pos<#raw do
  check(pos+4<=#raw,'truncated chunk header');local size=u32(raw,pos);pos=pos+4
  check(size>0 and size<=#raw-pos,'truncated compressed block')
  local compressed=raw:sub(pos+1,pos+size);local plain=M.inflate(compressed)
  check(#plain==65536,'unsupported block output size');chunks[#chunks+1]={compressed=compressed,plain=plain}
  decoded[#decoded+1]=plain;check(#chunks<=256,'too many chunks');pos=pos+size
 end
 local data=table.concat(decoded);check(#chunks==math.ceil(declared/65536),'unexpected block count')
 check(not data:sub(declared+1):find('[^%z]'),'nonzero final padding')
 data=data:sub(1,declared);check(#data>=0x151 and u32(data,0)==0x107,'unsupported save data version')
 return {raw=raw,header=raw:sub(1,36),data=data,chunks=chunks}
end
function M.encode(save,data)
 check(#data==#save.data,'save length changed');if data==save.data then return save.raw end
 local padded=data..string.rep('\0',#save.chunks*65536-#data);local out={}
 for i,chunk in ipairs(save.chunks)do
  local plain=padded:sub((i-1)*65536+1,i*65536);local compressed=plain==chunk.plain and chunk.compressed or M.deflate(plain)
  check(M.inflate(compressed)==plain,'compressed block verification failed');out[#out+1]=p32(#compressed)..compressed
 end
 local raw=save.header..table.concat(out);raw=put(raw,16,p32(#raw-28));raw=put(raw,12,p32(M.crc32(raw:sub(17))))
 check(M.decode(raw).data==data,'container verification failed');return raw
end
M.FIELDS={
 {key='helmet',offset=0x121,category='helmet',label={'Helmet','当前头盔','當前頭盔'}},
 {key='armor',offset=0x129,category='armor',label={'Armor','当前护甲','當前護甲'}},
 {key='cape',offset=0x125,category='cape',label={'Cape','当前披风','當前披風'}},
 {key='primary',offset=0x11,category='primary',label={'Primary weapon','当前主武器','當前主武器'}},
 {key='secondary',offset=0x15,category='secondary',label={'Secondary weapon','当前副武器','當前副武器'}},
 {key='grenade',offset=0x19,category='grenade',label={'Grenade','当前手雷','當前手雷'}},
 {key='victory',offset=0x135,label={'Victory pose','胜利姿势 ID','勝利姿勢 ID'},evidence='old CT +0x124; relative layout matched'},
 {key='card',offset=0x139,label={'Player card background','玩家卡片背景 ID','玩家卡片背景 ID'},evidence='old CT +0x128; relative layout matched'},
}
-- These are intentionally NOT named title/body/voice. They are editable raw u32s
-- next to the validated cosmetic slots; their gameplay meanings are unresolved.
for _,o in ipairs({0x11D,0x12D,0x131,0x13D,0x141,0x145,0x149,0x14D})do
 M.FIELDS[#M.FIELDS+1]={key=string.format('unknown_%x',o),offset=o,unknown=true,
  label={string.format('Unknown loadout +0x%X',o),string.format('未命名配装字段 +0x%X',o),string.format('未命名配裝欄位 +0x%X',o)}}
end
M.BY_KEY={};for _,f in ipairs(M.FIELDS)do M.BY_KEY[f.key]=f end
function M.integer(text)
 text=tostring(text):match('^%s*(.-)%s*$');local h=text:match('^0[xX](%x+)$')
 local v=h and tonumber(h,16)or text:match('^%d+$')and tonumber(text)
 if not v or v%1~=0 or v<0 or v>MAX then return nil,'请输入 0–4294967295 的整数或 0x 十六进制 ID。'end;return v
end
function M.catalog(entities,kits,schemas,names)
 local categories={primary={},secondary={},grenade={},helmet={},armor={},cape={}};local by_id={}
 local _,blocks=D.entity_blocks(entities);local b=assert(blocks[0x4F2CF417],'LoadoutEntryComponentData missing')
 local schema=assert(schemas[0x4F2CF417]);local map,array=schema.members[1],schema.members[2]
 check(map.count*16==map.size and schemas[array.type].size==32 and array.offset+array.size<=b.size,'loadout schema mismatch')
 local types={[1]='primary',[3]='secondary',[4]='grenade'}
 for i=0,map.count-1 do
  local at=b.payload+map.offset+i*16;local key=entities:sub(at+1,at+8)
  if key~=string.rep('\0',8)then
   local index=u32(entities,at+8);check(index<array.count,'loadout record bounds')
   local pos=b.payload+array.offset+index*32;local id,category=u32(entities,pos),types[u32(entities,pos+4)]
   if category and id~=0 then
    local hash=D.hex(key);local entry={id=id,category=category,entity=hash,name=names and names[hash]or hash}
    categories[category][id]=entry;by_id[id]=entry
   end
  end
 end
 local G=require('gamedata');local ffi=require('ffi');local ptr=ffi.cast('const uint8_t *',kits)
 for _,h in ipairs(G.headers(ptr,#kits))do if h.type==0xD9A55AA0 then
  check(h.size>=64,'customization record too short');local at=h.at+24;local category=({[0]='armor',[1]='helmet',[2]='cape'})[u32(kits,at+40)]
  if category then
   local id=u32(kits,at);local entry={id=id,category=category,name='ID '..id,loc=u32(kits,at+16)}
   categories[category][id]=entry;by_id[id]=entry
  end
 end end
 return {categories=categories,by_id=by_id}
end
local Model={};Model.__index=Model
function M.new(o)
 local self=setmetatable({io=o.io,catalog=o.catalog,changed=o.changed or function()end,
  selected=nil,save=nil,values={},paths=o.paths or{},presets={},preset_path=o.preset_path,version=0,
  status='请在“存档与备份”选择存档，或输入完整路径。',error=nil},Model)
 if o.preset_path then
  local raw=self.io.read(o.preset_path);if raw then local ok,t=pcall(J.decode,raw,1024*1024);if ok and type(t)=='table'then self.presets=t end end
 end
 if #self.paths==1 then local ok,why=self:load(self.paths[1]);if not ok then self.error=why end end
 return self
end
function Model:touch()self.version=self.version+1;self.changed()end
function Model:load(path)
 local raw=self.io.read(path);if not raw then return nil,'无法读取存档：'..path end
 local ok,save=pcall(M.decode,raw);if not ok then return nil,tostring(save)end
 self.selected=path;self.save=save;self.values={};self.error=nil
 self.backup=self.io.latest_backup and self.io.latest_backup(path)or nil
 self.status='已读取本地存档，修改暂存在编辑器中。';self:touch();return true
end
function Model:read(key,original)
 local f=M.BY_KEY[key];if not self.save or not f then return end
 return not original and self.values[key]or u32(self.save.data,f.offset)
end
function Model:set(key,value)
 local f=M.BY_KEY[key];if not self.save or not f then return nil,'请先选择并读取存档。'end
 if type(value)~='number'or value%1~=0 or value<0 or value>MAX then return nil,'物品 ID 必须是 u32 整数。'end
 if f.category then local item=self.catalog.categories[f.category][value]
  if not item and value~=self:read(key,true)then return nil,'此 ID 不属于当前版本的这个装备槽。'end
 end
 self.values[key]=value~=self:read(key,true)and value or nil;self:touch();return true
end
function Model:reset(key)if key then self.values[key]=nil else self.values={}end;self:touch();return true end
function Model:count()local n=0;for _ in pairs(self.values)do n=n+1 end;return n end
function Model:prepare()
 check(self.save and self.selected,'no save selected');local data=self.save.data
 for key,value in pairs(self.values)do data=put(data,M.BY_KEY[key].offset,p32(value))end
 return M.encode(self.save,data)
end
function Model:commit()
 if not self.save then return nil,'请先读取存档。'end
 if self.io.running()then return nil,'请先关闭 Helldivers 2，再写入存档。'end
 if self:count()==0 then self.status='存档没有待写入的修改。';self:touch();return true end
 if self.io.read(self.selected)~=self.save.raw then return nil,'存档已被游戏或 Steam 更新；请重新读取后再修改。'end
 local ok,raw=pcall(self.prepare,self);if not ok then return nil,tostring(raw)end
 local backup=self.selected..'.shodan-backup-'..os.date('%Y%m%d-%H%M%S');local n=0
 while self.io.read(backup)do n=n+1;backup=self.selected..'.shodan-backup-'..os.date('%Y%m%d-%H%M%S')..'-'..n end
 local done,why=self.io.write(backup,self.save.raw);if not done then return nil,'备份失败：'..tostring(why)end
 local temporary=self.selected..'.shodan-tmp'
 done,why=self.io.write(temporary,raw);if not done then return nil,'临时文件验证失败：'..tostring(why)end
 if self.io.running()or self.io.read(self.selected)~=self.save.raw then self.io.remove(temporary);return nil,'存档状态已变化，未替换原文件。'end
 done,why=self.io.move(temporary,self.selected);if not done then self.io.remove(temporary);return nil,'存档替换失败：'..tostring(why)end
 if self.io.read(self.selected)~=raw then return nil,'写回校验失败；原始内容已保存在 '..backup end
 self.backup=backup;self.last_written=raw;self.save=M.decode(raw);self.values={}
 self.status='已写入存档并保留备份；重启游戏检查配装。';self:touch();return true
end
function Model:restore()
 if self.io.running()then return nil,'请先关闭 Helldivers 2，再恢复存档。'end
 local path=self.backup
 if not path then return nil,'没有选定备份，请在存档管理中输入备份路径。'end
 local raw=self.io.read(path);if not raw then return nil,'备份文件不存在。'end
 local ok,decoded=pcall(M.decode,raw);if not ok then return nil,tostring(decoded)end
 local current=self.io.read(self.selected)
 if current~=self.save.raw then return nil,'存档已由其他程序更新；请重新读取后再恢复。'end
 -- Restore is also a write transaction: preserve what is currently on disk.
 local before=self.selected..'.shodan-before-restore-'..os.date('%Y%m%d-%H%M%S')
 if self.io.read(before)then return nil,'恢复备份文件名冲突，请稍后重试。'end
 local done,why=self.io.write(before,current);if not done then return nil,why end
 local tmp=self.selected..'.shodan-tmp';done,why=self.io.write(tmp,raw)
 if not done then return nil,why end
 if self.io.running()or self.io.read(self.selected)~=current then self.io.remove(tmp);return nil,'恢复前存档状态发生变化。'end
 done,why=self.io.move(tmp,self.selected);if not done then self.io.remove(tmp);return nil,why end
 if self.io.read(self.selected)~=raw then return nil,'恢复写回校验失败；恢复前的副本保存在 '..before end
 self.save=decoded;self.values={};self.last_written=raw;self.status='已恢复存档备份；恢复前的存档也已保留。';self:touch();return true
end
function Model:preset(what,n)
 n=tostring(n)
 if not self.save then return nil,'请先读取存档。'end
 if what=='save'then local t={};for _,f in ipairs(M.FIELDS)do if not f.unknown then t[f.key]=self:read(f.key)end end;self.presets[n]=t
 elseif what=='clear'then self.presets[n]=nil
 elseif what=='load'then
  local t=self.presets[n];if type(t)~='table'then return nil,'此存档配装预设为空或无效。'end
  local before={};for k,v in pairs(self.values)do before[k]=v end
  for key,value in pairs(t)do local ok,why=self:set(key,value);if not ok then self.values=before;return nil,why end end
 end
 if self.preset_path and(what=='save'or what=='clear')then
  local ok,why=self.io.write(self.preset_path,J.encode(self.presets));if not ok then return nil,why end
 end
 self:touch();return true
end
function Model:snapshot()
 if not self.save then return nil,'请先读取存档。'end
 local values={};for _,f in ipairs(M.FIELDS)do values[f.key]=self:read(f.key)end
 return {version=0x107,values=values}
end
function Model:apply_snapshot(snapshot)
 if type(snapshot)~='table'or snapshot.version~=0x107 or type(snapshot.values)~='table'then return nil,'不支持的配装预设。'end
 if not self.save then return nil,'请先读取存档。'end
 local before={};for k,v in pairs(self.values)do before[k]=v end
 self.values={}
 for key,value in pairs(snapshot.values)do
  local ok,why=self:set(key,value)
  if not ok then self.values=before;self:touch();return nil,why end
 end
 self:touch();return true
end
return M
