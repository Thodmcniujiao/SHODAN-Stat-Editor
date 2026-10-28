-- Attachment lists, separate from Modifier definitions and the entity deltas' effect values.
-- The two GalacticPresence arrays are deliberately named by offset: their add/remove semantics are unverified.
local D=require('demolition')
local DATA=require('planet_data')
local MD=require('modifier_data')
local V=require('component_view')
local M={PLANET=146979202,labels={
 PlanetModifierLists={'Planet environment entities','星球环境实体','星球環境實體'},
 GalacticModifierLists={'Event entity lists (experimental)','事件实体列表（实验）','事件實體列表（實驗）'}}}
for h,t in pairs(DATA.schemas)do if t.name=='GalacticPresenceSettings'then M.GALACTIC=h end end
local OFFSETS={[M.PLANET]={[424]=true},[M.GALACTIC]={[504]=true,[704]=true}}
function M.check_array(s,schemas)
 if s.domain~='modifier_entity'or not(OFFSETS[s.root]and OFFSETS[s.root][s.offset])then return false end
 local file=s.root==M.PLANET and'generated_planet_data.dl_bin'or'generated_galactic_presence_settings.dl_bin'
 if s.file~=file or type(s.ordinal)~='number'or s.ordinal<1 or s.ordinal%1~=0 then return false end
 if not require('planet_components').check_layout(s.root,schemas)then return false end
 for _,m in ipairs(schemas[s.root].members)do
  if m.offset==s.offset then return m.atom==1 and m.storage==7 and m.size==16 end
 end
 return false
end
local function u32(b,o)return D.u32(b,o)end
local function pointer(b,o,address)
 local lo,hi=u32(b,o),u32(b,o+4);local v=lo+hi*4294967296
 if v>=#b and address then v=v-address end
 if v<0 or v>#b then return end;return v
end
function M.values(b,offset,address)
 assert(offset+16<=#b,'attachment descriptor outside record')
 local n=u32(b,offset+8);assert(n<=100000,'invalid attachment count')
 local at=pointer(b,offset,address);assert(n==0 or at and at+n*8<=#b,'attachment data outside record')
 local out={};for i=0,n-1 do out[#out+1]=D.hex(b:sub(at+i*8+1,at+i*8+8))end;return out,at
end
function M.build(c,page,txt,PC)
 local model=rawget(_G,'SHODAN_PRELOAD_MODEL')
 local function display(h)
  local n=MD.ENTITIES[h];return n and V.pick(c.lang(),{n[1],n[2],n[2]})or(c.names or{})[h]or h
 end
 if model then
  model.modifier_entities={}
  for kind,t in pairs(c.tables)do if kind~=0x683E604F then
   for key in pairs(t.index or{})do if type(key)=='string'and #key==8 then model.modifier_entities[D.hex(key)]=true end end
  end end
 end
 local function row(p,id,label,section)
  local r={id=id,label=id,label_of=label,storage='u32',parts={},min=0,max=1,small=1,big=1,section=section or'attachment'}
  r.section_of=function()return txt('Local entity references','本地实体引用','本機實體引用')end
  r.component='ModifierAttachments';r.component_of=function()return txt('Local entity lists (not eight effect-ID slots)','本地实体列表（非八槽效果 ID）','本機實體列表（非八槽效果 ID）')end
  p.rows[#p.rows+1]=r;return r
 end
 local aliases,ranks={},{}
 local function alias(s,h,rank)
  s=s:lower()
  if not ranks[s]or rank>ranks[s]then aliases[s],ranks[s]=h,rank
  elseif rank==ranks[s]and aliases[s]~=h then aliases[s]=false end
 end
 for h,n in pairs(MD.ENTITIES)do
  local environment=n[2]and n[2]:find('（环境）',1,true)
  for _,s in ipairs(n)do
   alias(s,h,2);local short=s:gsub('%s*%(.+$',''):gsub('（.*$','')
   alias(short,h,environment and 3 or 1)
  end
 end
 local function resolve(input)
  input=input:match('^%s*(.-)%s*$');local known=aliases[input:lower()]
  if known then return known end
  assert(known~=false,'ambiguous entity name; enter the full name or 64-bit hash')
  local path=(c.names or{})
  for h,n in pairs(path)do if n==input then return h end end
  return require('preload_store').input_hash(input)
 end
 for _,root in ipairs({M.PLANET,M.GALACTIC})do
  if require('planet_components').check_layout(root,c.schemas)then
   local file=root==M.PLANET and'generated_planet_data.dl_bin'or'generated_galactic_presence_settings.dl_bin'
   for _,kind in ipairs(c.kinds[root]and c.kinds[root].list or{})do
    local t=c.tables[kind];local b=c.bytes(kind);local addr=t.copies[1]+24
    local location=PC.location(t.copies[1]);local ordinal=tonumber(location and location:match(':(%d+)$'))
    if ordinal then
     local identity=require('planet_components').identity(b,root,addr)
     if identity==''then identity='#'..ordinal end
     local planet=root==M.PLANET and DATA.planets[identity]
     local name=(root==M.PLANET and'PlanetEffectList'or'EventEffectList')..' · '..identity..' [#'..ordinal..']'
     local p=page(root==M.PLANET and'PlanetModifierLists'or'GalacticModifierLists',name,'attachments/'..root..'/'..ordinal)
     p.attachment_planet=planet;p.attachment_identity=identity
     if planet then p.search=p.search..' '..planet.en..' '..planet.zhs..' '..planet.zht..' '..planet.sector end
     p.note_of=function()
      return root==M.PLANET and txt('64-bit environment entities for local generation; not the eight 32-bit effect-ID slots.',
       '本地星球生成配置中的 64 位环境实体；不是内存中八个 32 位效果 ID 槽位。','本機星球產生設定中的 64 位環境實體；不是記憶體中八個 32 位效果 ID 槽位。')or
       txt('Local 64-bit entity lists, not eight effect-ID slots. A/B behavior is unverified; file ordinal is not event ID.',
        '本地 64 位实体列表，非八槽效果 ID。A/B 用途待验证；文件序号不等于事件 ID。','本機 64 位實體列表，非八槽效果 ID。A/B 用途待驗證；檔案序號不等於事件 ID。')
     end
     local arrays={}
     for _,off in ipairs(root==M.PLANET and{424}or{504,704})do
      local values,target=M.values(b,off,addr)
      local spec={file=file,root=root,ordinal=ordinal,offset=off,domain='modifier_entity'}
      local key=file..'/'..root..'/'..ordinal..'/'..off
      if model then
       for _,h in ipairs(values)do model.modifier_entities[h]=true end
       model:register_array(key,spec,values)
      end
      arrays[#arrays+1]={key=key,spec=spec,values=values,target=target}
     end
     p.modifier_arrays=arrays
     local base_search=p.search
     local function update_search()
      local terms={base_search}
      for _,a in ipairs(arrays)do for _,h in ipairs(model and model:array_values(a.key)or a.values)do
       terms[#terms+1]=h;local n=MD.ENTITIES[h]
       if n then terms[#terms+1]=n[1];terms[#terms+1]=n[2]end
      end end
      p.search=table.concat(terms,' ')
     end
     update_search()
     local refresh
     refresh=function()
      update_search()
      p.rows={};p.by_id={}
      local source=row(p,'source',function()return txt('File / record ordinal','文件／记录序号','檔案／記錄序號')end);source.empty=true;source.readonly_text=file..' # '..ordinal
      for ai,a in ipairs(arrays)do
       local values=model and model:array_values(a.key)or a.values
       local section='attachment'..ai
       local function heading()
        return root==M.PLANET and'gameplay_modifiers (+0x1A8)'or(ai==1 and txt('Local entity list A (+0x1F8)','本地实体列表 A（+0x1F8）','本機實體列表 A（+0x1F8）')or txt('Local entity list B (+0x2C0)','本地实体列表 B（+0x2C0）','本機實體列表 B（+0x2C0）'))
       end
       local count=row(p,'count_'..ai,function()return heading()end,section);count.empty=true;count.readonly_text=tostring(#values)
       if model then
        local function edit(id,label,value,set)
         local r=row(p,id,label,section);r.custom_value=function()return 0 end;r.input_text=value
         r.custom_text=function()local s=value();return s~=''and s or txt('Click to enter...','点击输入…','點擊輸入…')end
         r.custom_edit=function(input)
          local ok,a,b=pcall(function()return set(input)end);if not ok then return nil,tostring(a)end
          if a then refresh()end;return a,b
         end
         r.tip_of=function()return{file..string.format(' # %d +0x%X',ordinal,a.spec.offset),
          txt('Writes a 64-bit entity reference into this local array. This does not edit any of the eight 32-bit planet effect-ID slots.',
           '把 64 位实体引用写入当前本地数组；不会改写星球的八个 32 位效果 ID 槽位。','把 64 位實體引用寫入目前本機陣列；不會改寫星球的八個 32 位效果 ID 槽位。'),
          txt('Entity name, resource path or 64-bit hash. Enter - to delete an existing item.',
           '输入实体名称、资源路径或 64 位哈希；已有项输入 - 删除。','輸入實體名稱、資源路徑或 64 位雜湊；已有項輸入 - 刪除。'),
          txt('The list is rebuilt inside its original DL block; pointers and count are updated together.',
           '列表在原 DL 块内重建，指针与数量一并更新。','列表在原 DL 區塊內重建，指標與數量一併更新。')}
         end;return r
        end
        edit('append_'..ai,function()return txt('Add local entity reference (name / hash)','添加本地实体引用（名称／哈希）','新增本機實體引用（名稱／雜湊）')end,function()return''end,function(input)
         assert(input:find('%S'),'enter an entity');local list=model:array_values(a.key);list[#list+1]=resolve(input);return model:set_array(a.key,list)
        end)
        for i,h in ipairs(values)do
         local r=edit('effect_'..ai..'_'..i,function()return'#'..i..' '..display(h)end,function()return'0x'..h end,function(input)
          local list=model:array_values(a.key)
          if input:match('^%s*%-%s*$')then table.remove(list,i)else list[i]=resolve(input)end
          return model:set_array(a.key,list)
         end)
         r.search=display(h)..' '..h
         r.custom_reset=function()
          local list=model:array_values(a.key)
          if a.values[i]then list[i]=a.values[i]else table.remove(list,i)end
          local ok,why=model:set_array(a.key,list);if ok then refresh()end;return ok,why
         end
        end
       else
        -- Headless/no authoring store: existing references still have ordinary editable scalar backing fields.
        for i,h in ipairs(values)do
         local id='effect_'..ai..'_'..i;local off=a.target+(i-1)*8
         local lo,hi=c.field_at(kind,off,'u32',4294967295),c.field_at(kind,off+4,'u32',4294967295)
         local r=c.add_row(p,section,id,id,'u64',{{id=id..'_lo',field=lo},{id=id..'_hi',field=hi}},0,4294967295,1,1)
         r.hash64,r.lead=true,true;r.label_of=function()return'#'..i..' '..display(h)end
         p.field_keys[lo.key],p.field_keys[hi.key]=true,true
        end
       end
      end
     end
     if model then
      p.custom_modified=function()for _,a in ipairs(arrays)do if model.cfg.arrays[a.key]then return true end end;return false end
      p.custom_reset=function()
       local ok,why=model:mutate(function()for _,a in ipairs(arrays)do model.cfg.arrays[a.key]=nil end end)
       if ok then refresh()end;return ok,why
      end
      p.custom_preset=function(action,n)
       local id='modifier-attachments/'..p.hash..'/'..n
       local ok,why=model:mutate(function()
        if action=='save'then
         local saved={};for _,a in ipairs(arrays)do saved[a.key]=model.cfg.arrays[a.key]or false end;model.cfg.presets[id]=saved
        elseif action=='clear'then model.cfg.presets[id]=nil
        else local saved=assert(model.cfg.presets[id],'No saved modifier attachment preset')
         for _,a in ipairs(arrays)do model.cfg.arrays[a.key]=saved[a.key]or nil end
        end
       end)
       if ok then refresh()end;return ok,why
      end
     end
     p.ensure_rows=function()
      if p.rows_built and(not model or p.model_version==model.version)then return end
      refresh();p.rows_built=true;p.model_version=model and model.version
     end
    end
   end
  end
 end
end
function M.translate_name(name,lang)
 local root,tail=name:match('^(%w+EffectList) · (.*)$');if not root then return end
 tail=tail:gsub('%[#(%d+)%]',function(n)return V.pick(lang,{'[file record '..n..']','[文件序号 '..n..']','[檔案序號 '..n..']'})end)
 if root=='PlanetEffectList'then
  local id=tail:match('^(%S+)');local planet=DATA.planets[id]
  if planet then return V.pick(lang,{planet.en,planet.zhs,planet.zht})..' · '..tail end
 end
 return V.pick(lang,root=='PlanetEffectList'and{'Environment entities','环境实体','環境實體'}or{'Event entities','事件实体','事件實體'})..' · '..tail
end
return M
