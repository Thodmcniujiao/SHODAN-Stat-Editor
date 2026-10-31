-- Display names only. Field paths, IDs, storage, ranges, offsets and owners stay intact.
local Data=require('reference_component_names')
local M={}
local cache=setmetatable({},{__mode='k'})
function M.signature(schemas,kind)
 local root=schemas and schemas[kind];local row=root and root.members[2]
 if not row or not schemas[row.type]then return nil end
 local known=cache[schemas];if not known then known={};cache[schemas]=known end
 if known[kind]then return known[kind]end
 local h,seen=5381,{}
 local function feed(s)for i=1,#s do h=(h*33+s:byte(i))%4294967296 end end
 local function visit(tid)
  if seen[tid]then return end;seen[tid]=true
  local t=schemas[tid];feed(string.format('%d:%d;',tid,t.size))
  local members={};for _,m in ipairs(t.members)do members[#members+1]=m end
  table.sort(members,function(a,b)if a.offset~=b.offset then return a.offset<b.offset end;return a.count<b.count end)
  for _,m in ipairs(members)do feed(string.format('%d:%d:%d:%d:%d:%d;',m.offset,m.size,m.atom,m.storage,m.count,m.type))end
  for _,m in ipairs(members)do if m.storage==20 and schemas[m.type]then visit(m.type)end end
 end
 visit(row.type);known[kind]=h;return h
end
function M.unknown(text)
 text=tostring(text or'')
 local s=text:lower()
 return s:find('unknown',1,true)or s:find('unk_',1,true)or text:find('未知',1,true)
  or s:match('^field %+')or text:match('^字段 %+')or text:match('^欄位 %+')or s:match('^0x%x+$')
end
function M.lookup(schemas,kind)
 local data=Data.TYPES[kind]
 if not data or M.signature(schemas,kind)~=data.signature then return nil end
 return data
end
function M.apply(spec,schemas,kind)
 local data=M.lookup(schemas,kind or spec.HASH)
 if not data or data.size~=spec.SIZE then return 0 end
 local changed=0;local groups={}
 for _,field in ipairs(spec.FIELDS)do
  local storage=field[3]=='flag'and'u8'or field[3]
  local entry=data.fields[tostring(field[2])..':'..storage]
  if entry then
   local index_only=tostring(field[5]):match('^#%d+$')and M.unknown(field[1])and entry.group
   if index_only or M.unknown(field[5])or M.unknown(field[6])or M.unknown(field[7])then
    if not index_only then for n=1,3 do field[n+4]=entry.labels[n]end end
    local x=field[9]or{};field[9]=x
    x.resolved_name,x.resolved_owner=entry.name,entry.owner
    x.resolved_evidence,x.resolved_desc=entry.evidence,entry.description
    x.resolved_commit=Data.COMMIT
    changed=changed+1
   end
   if entry.group and entry.group_key then
    local g=groups[field[4]]
    if not g then groups[field[4]]={key=entry.group_key,labels=entry.group}
    elseif g.key~=entry.group_key then g.conflict=true end
   end
  end
 end
 for key,g in pairs(groups)do
  local group=spec.GROUP and spec.GROUP[key]
  if group and not g.conflict and(M.unknown(group.name[1])or M.unknown(group.name[2])or M.unknown(group.name[3]))then
   group.name=g.labels
  end
 end
 return changed
end
function M.tip(x,lang)
 if not x.resolved_name then return{}end
 local function pick(t)return lang=='zh-Hans'and t[2]or lang=='zh-Hant'and t[3]or t[1]end
 local lines={pick({'Reference field: ','参考字段：','參考欄位：'})..x.resolved_owner..' · '..x.resolved_name}
 lines[#lines+1]=pick(x.resolved_evidence=='struct'and{
  'shalzuth reference: same struct hash, complete ordered member-type match; current record layout checked.',
  'shalzuth 参考：结构哈希一致，整个结构的成员类型与顺序一致；已核对当前记录布局。',
  'shalzuth 參考：結構雜湊一致，整個結構的成員類型與順序一致；已核對目前記錄配置。'}or{
  'shalzuth reference: unique named struct/enum hash in both schemas; current record layout checked.',
  'shalzuth 参考：两版结构中唯一对应的具名结构／枚举哈希；已核对当前记录布局。',
  'shalzuth 參考：兩版結構中唯一對應的具名結構／列舉雜湊；已核對目前記錄配置。'})
 if x.resolved_desc and x.resolved_desc~=''then lines[#lines+1]=x.resolved_desc end
 return lines
end
return M
