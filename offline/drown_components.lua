-- A component-first view of DrownableComponentData (淹没): every entity that has the component, field by field.
-- The record (64 bytes), in the component's own field order:
--   +0 drown_enter_node (node name hash)  +4 drown_enter_offset  +8 drown_float_surface_offset  +12 drown_time
--   +16 drown_recovery_multiplier  +20 drown_callout_delay  +24 slow_while_submerged  +25 slow_while_drowning
--   +26 should_die  (+27 padding)  +28 slow_strength  +32 buoyancy_loss  +36 slow_depth_start  +40 slow_depth_max
--   +44 slow_base_nodes[4] (node name hashes)  +60 should_float  (+61..63 padding)
-- +4 / +8 / +12 are the helldiver's water stats the editor had (SHODAN Offline Integration). The rest is taken from
-- the component's field list and only opened when the game's type library lays the record out exactly so (offsets
-- and sizes, M.LAYOUT); otherwise only those three are shown and the reason is logged.
-- Same field objects as the original pages (no duplicate value store): a field the helldiver page already has keeps
-- saving under that page's config entry (health_owner, as on the Health page).
local D=require('demolition')
local M={}
--  id, label, offset, storage, limit (plausible read), smallest, largest, small step, big step, field name, verified
local HASH=4294967295
M.FIELDS={
 {'drown_enter_node','drown_enter_node',0,'u32',HASH,0,HASH,1,1,'drown_enter_node'},
 {'drown_depth','Drowning depth offset (m)',4,'f32',3600,-100,100,.1,.5,'drown_enter_offset',true},
 {'float_depth','Floating depth offset (m)',8,'f32',3600,-100,100,.1,.5,'drown_float_surface_offset',true},
 {'drown_time','Time before drowning (s)',12,'f32',3600,0,3600,.1,5,'drown_time',true},
 {'drown_recovery','drown_recovery_multiplier',16,'f32',3600,0,100,.1,1,'drown_recovery_multiplier'},
 {'drown_callout','drown_callout_delay',20,'f32',3600,0,3600,.1,1,'drown_callout_delay'},
 {'slow_submerged','slow_while_submerged',24,'flag',1,0,1,1,1,'slow_while_submerged'},
 {'slow_drowning','slow_while_drowning',25,'flag',1,0,1,1,1,'slow_while_drowning'},
 {'should_die','should_die',26,'flag',1,0,1,1,1,'should_die'},
 {'slow_strength','slow_strength',28,'f32',3600,0,100,.1,.5,'slow_strength'},
 {'buoyancy_loss','buoyancy_loss',32,'f32',3600,0,100,.05,.25,'buoyancy_loss'},
 {'slow_depth_start','slow_depth_start',36,'f32',3600,-100,100,.05,.25,'slow_depth_start'},
 {'slow_depth_max','slow_depth_max',40,'f32',3600,-100,100,.05,.25,'slow_depth_max'},
 {'slow_node1','slow_base_nodes[0]',44,'u32',HASH,0,HASH,1,1,'slow_base_nodes[0]'},
 {'slow_node2','slow_base_nodes[1]',48,'u32',HASH,0,HASH,1,1,'slow_base_nodes[1]'},
 {'slow_node3','slow_base_nodes[2]',52,'u32',HASH,0,HASH,1,1,'slow_base_nodes[2]'},
 {'slow_node4','slow_base_nodes[3]',56,'u32',HASH,0,HASH,1,1,'slow_base_nodes[3]'},
 {'should_float','should_float',60,'flag',1,0,1,1,1,'should_float'},
}
-- the record's fields in the type library: offset, size (slow_base_nodes: 4 x 4 bytes)
M.LAYOUT={{0,4},{4,4},{8,4},{12,4},{16,4},{20,4},{24,1},{25,1},{26,1},{28,4},{32,4},{36,4},{40,4},{44,16},{60,1}}
M.SIZE=64
M.NAME={en='Drownable',zh='淹没'}
-- the names in Chinese (简体, 繁體) of the fields the editor had no name for; English shows the field's own name
M.ZH={
 drown_enter_node={'入水判定节点（哈希）','入水判定節點（雜湊）'},
 drown_recovery={'溺水恢复倍率','溺水恢復倍率'},
 drown_callout={'溺水语音提示延迟','溺水語音提示延遲'},
 slow_submerged={'没入水中时减速','沒入水中時減速'},
 slow_drowning={'溺水时减速','溺水時減速'},
 should_die={'溺水会致死','溺水會致死'},
 slow_strength={'减速强度','減速強度'},
 buoyancy_loss={'浮力损失','浮力損失'},
 slow_depth_start={'减速起始深度','減速起始深度'},
 slow_depth_max={'减速最大深度','減速最大深度'},
 slow_node1={'减速基准节点 1（哈希）','減速基準節點 1（雜湊）'},
 slow_node2={'减速基准节点 2（哈希）','減速基準節點 2（雜湊）'},
 slow_node3={'减速基准节点 3（哈希）','減速基準節點 3（雜湊）'},
 slow_node4={'减速基准节点 4（哈希）','減速基準節點 4（雜湊）'},
 should_float={'会漂浮','會漂浮'},
}
M.NOTE={'lower (more negative): you go deeper before drowning starts'}
-- true when the type library (schemas: type hash -> { size, members = { offset, size, type, ... } }) lays the
-- component's record out as M.LAYOUT; else nil, why
function M.check_layout(schemas,kind)
 if type(schemas)~='table'then return nil,'no type library'end
 local t=schemas[kind]
 if not t or #t.members~=2 then return nil,'DrownableComponentData is not a keyed table in the type library'end
 local row=schemas[t.members[2].type]
 if not row then return nil,'no record type'end
 if row.size~=M.SIZE then return nil,'record is '..tostring(row.size)..' bytes, not '..M.SIZE end
 local members={}
 for _,m in ipairs(row.members)do members[#members+1]=m end
 table.sort(members,function(a,b)return a.offset<b.offset end)
 local got={}
 for _,m in ipairs(members)do got[#got+1]='+'..m.offset..':'..m.size end
 if #members~=#M.LAYOUT then return nil,'record has '..#members..' fields, not '..#M.LAYOUT..' ('..table.concat(got,' ')..')'end
 for i,m in ipairs(members)do
  if m.offset~=M.LAYOUT[i][1]or m.size~=M.LAYOUT[i][2]then return nil,'record fields differ ('..table.concat(got,' ')..')'end
 end
 return true
end
function M.build(c)
 local out={pages={},by_entity={}}
 if not c.table then return out end
 local function lang()return c.lang and c.lang()or'en'end
 local function zh()local l=lang();return l=='zh-Hans'or l=='zh-Hant'end
 local full,why=M.check_layout(c.schemas,c.kind)
 out.full,out.why=full,why
 if c.log then c.log('drownable: '..(full and'all '..#M.FIELDS..' fields (type library layout matches)'or('the 3 known fields only: '..tostring(why))))end
 local names,owners,users={},{},{}
 for _,w in ipairs(c.weapons)do
  if w.key then names[w.key]=names[w.key]or w.name end
  if w.enemy and w.enemy.members then
   for i,m in ipairs(w.enemy.members)do names[m.key]=w.name..(#w.enemy.members>1 and(' · '..i)or'')end
  end
  for _,row in ipairs(w.rows)do for _,p in ipairs(row.parts)do
   if p.field.kind==c.kind and not owners[p.field.key]then owners[p.field.key]={weapon=w,part=p}end
  end end
 end
 local keys={}
 for key,at in pairs(c.table.index)do keys[#keys+1]=key;users[at]=(users[at]or 0)+1 end
 table.sort(keys,function(a,b)return D.hex(a)<D.hex(b)end)
 for _,key in ipairs(keys)do
  local at=c.table.index[key];local entity=D.hex(key)
  local path=(c.names or{})[entity]or''
  local name=names[key]or(path~=''and path:match('([^/]+)$'))or entity
  local hash=D.hex(D.hash_resource('shodan/components/drown/'..entity:lower()))
  assert(not c.by_hash[hash],'Drownable component view hash collision')
  local page={name=name,hash=hash,key=key,slot='DrownComponents',drown_component=true,
   entity_hash=entity,path=path,drown_offset=at,shared_count=users[at],rows={},by_id={},field_keys={}}
  page.note='DrownableComponentData · '..entity..' · '..users[at]..' entity reference(s) to this record'
  page.note_of=function()
   if zh()then
    return 'DrownableComponentData · '..entity..' · '..(users[at]>1 and('共用记录：'..users[at]..' 个实体，修改会一起生效')or'此实体的淹没组件')
   end
   return page.note
  end
  for _,s in ipairs(M.FIELDS)do
   if full or s[11]then
    local f=c.field_at(c.kind,at+s[3],s[4],s[5])
    if s[6]<0 then f.signed=true end   -- (before the first read: negative values are refused otherwise)
    local value=c.read(f)
    if value~=nil then
     local id=s[1];local p={id=id,field=f,health_owner=owners[f.key]}
     local row=c.add_row(page,'Drownable',id,s[2],s[4],{p},math.min(s[6],value),math.max(s[7],value),s[8],s[9])
     row.section_level='component'
     row.section_of=function()
      local l=lang()
      return l=='zh-Hans'and'淹没组件（Drownable）'or l=='zh-Hant'and'淹沒組件（Drownable）'or M.NAME.en
     end
     local zh_name=M.ZH[id]
     if zh_name then   -- (the editor's own names are translated as everywhere else)
      row.label_of=function()local l=lang();return l=='zh-Hans'and zh_name[1]or l=='zh-Hant'and zh_name[2]or s[2]end
     end
     -- the component's field name in every row's tip (and the depth's note there)
     local field,note=s[10],id=='drown_depth'and M.NOTE[1]or nil
     row.tip_of=function()return{(zh()and'对应字段：'or'Field: ')..field,note}end
     page.field_keys[f.key]=true
    end
   end
  end
  c.by_hash[hash]=page;out.pages[#out.pages+1]=page;out.by_entity[entity]=page
 end
 table.sort(out.pages,function(a,b)
  local an,bn=a.name~=a.entity_hash,b.name~=b.entity_hash
  if an~=bn then return an end
  if a.name==b.name then return a.entity_hash<b.entity_hash end
  return a.name:lower()<b.name:lower()
 end)
 return out
end
return M
