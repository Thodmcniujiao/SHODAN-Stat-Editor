-- Named fields verified against the installed type library. Scope: character subtitles and local fonts.
local V=require('component_view')
local D=require('demolition')
local R=V.R
local M={CHAR=0x7655097B,FONT=0x226555C8,FONT_LIST={},pages={}}
M.CHAR_SPEC=V.prepare({TYPE='CharacterNameComponentData',KEY='character_name',HASH=M.CHAR,SIZE=16,
 SLOT='CharacterNameFields',FLAG='character_name_component',COMPONENT={'Character name component','角色名称组件','角色名稱組件'},
 GROUPS={{'name','Subtitle name and random template','字幕名称与随机模板','字幕名稱與隨機範本'}},
 LAYOUT={{0,4},{4,4},{8,4},{12,1}},OPEN_ENUMS=true,
 ENUMS={race={[0]={'None','无','無'},[1]={'Super Earth','超级地球','超級地球'},[2]={'Bugs','虫族','蟲族'},
 [3]={'Cyborg','生化人','生化人'},[4]={'Illuminate','光能者','光能者'}}},
 FIELDS={
 {'race',0,'enum','name','Race (race)','种族（race）','種族（race）',R.enum,{id='race',enum='race',enum_type='RaceType'}},
 {'random_name_template',4,'u32','name','Random name template text ID','随机名称模板 ID','隨機名稱範本文字 ID',R.hash,{id='random_name_template'}},
 {'character_name',8,'u32','name','Character subtitle name text ID','角色字幕名称 ID','角色字幕名稱 ID',R.hash,{id='character_name'}},
 {'use_persistent_seed',12,'flag','name','Persistent name seed','固定名称随机种子','固定名稱隨機種子',R.flag,{id='use_persistent_seed'}},
 }})
M.FONT_TYPES={'Title','Header','Body','Subtitles','Runtime_Header','Runtime_Body','Runtime_Title','Special_Samples','Special_Automaton'}
M.HUD={'Title','TitleMediumDescription','HeaderBig','HeaderMedium','BodyBig','BodyMedium','SmallText','HeaderBigRuntime','BodyBigRuntime','BodyMediumRuntime','HeaderMediumRuntime','HeaderSmallRuntime','BodySmallRuntime'}
M.MENU={'Title','TitleMedium','TitleMediumDescription','HeaderBig','HeaderMedium','HeaderSmall','BodyBig','BodyMedium','BodySmall','HeaderBigRuntime','BodyBigRuntime','HeaderMediumRuntime','BodyMediumRuntime','HeaderSmallRuntime','BodySmallRuntime','TitleRuntime','TitleMediumRuntime'}
local function u32(b,o)
 if o<0 or o+4>#b then return end
 local a,c,d,e=b:byte(o+1,o+4);return a+c*256+d*65536+e*16777216
end
local function array(b,o,stride)
 local lo,hi,n,pad=u32(b,o),u32(b,o+4),u32(b,o+8),u32(b,o+12)
 if not(lo and hi and n and pad==0)or n>4096 then return end
 if n==0 then return 0,0 end
 if hi~=0 or lo<112 or lo+n*stride>#b then return end
 return lo,n
end
function M.font_parse(b)
 if #b<112 then return nil,'FontSettings header is truncated'end
 local index={styles={},floats={},languages={}}
 for _,group in ipairs({{80,'hud'},{96,'menu'}})do
  local at,n=array(b,group[1],16)
  if not at then return nil,'FontSettings style array is invalid'end
  for i=0,n-1 do
   local off=at+i*16;index.styles[#index.styles+1]={offset=off,group=group[2],index=i}
   index.floats[#index.floats+1]=off+8;index.floats[#index.floats+1]=off+12
  end
 end
 local at,n=array(b,8,8)
 if at then for i=0,n-1 do
  local ptr,hi=u32(b,at+i*8),u32(b,at+i*8+4)
  if ptr and hi==0 and ptr>=112 and ptr<#b then
   local text=b:sub(ptr+1):match('^([^%z]*)%z')
   if text and #text<=64 and not text:find('[%c]')then index.languages[#index.languages+1]=text end
  end
 end end
 return index,#index.styles
end
function M.font_layout(schemas)
 local function matches(hash,size,layout)
  local t=schemas and schemas[hash]
  if not t or t.size~=size or #t.members~=#layout then return nil end
  for i,x in ipairs(layout)do local a=t.members[i]
   if a.offset~=x[1]or a.size~=x[2]or a.storage~=x[3]or a.atom~=(x[4]or 0)or x[5]and a.type~=x[5]then return nil end
  end
  return true
 end
 return matches(M.FONT,112,{{0,8,7},{8,16,18,1},{24,8,7},{32,16,7,1},{48,16,7,1},
  {64,16,20,1,0xAB967758},{80,16,20,1,0x7E330F19},{96,16,20,1,0xA50E2E2D}})
  and matches(0x054D9678,12,{{0,4,16},{4,4,8},{8,4,8}})
  and matches(0x7E330F19,16,{{0,4,16},{4,12,20,0,0x054D9678}})
  and matches(0xA50E2E2D,16,{{0,4,16},{4,12,20,0,0x054D9678}})
end
function M.register(kinds)
 kinds[M.CHAR]={name='character name',stride=16,keyed=true}
 kinds[M.FONT]={name='font settings',stride=1,groups=true,list=M.FONT_LIST,parse=M.font_parse,
  group_key=function(b)return string.format('font settings %08X%08X',u32(b,4),u32(b,0))end}
end
function M.build(c)
 for _,list in pairs(M.pages)do for _,p in ipairs(list)do if c.by_hash[p.hash]==p then c.by_hash[p.hash]=nil end end end
 M.pages={CharacterNameFields={},FontStyleFields={},IdentityRpcInfo={}}
 local function tx(t)return V.pick(c.lang(),t)end
 if V.check_layout(M.CHAR_SPEC,c.schemas,M.CHAR)then
  local spec=setmetatable({NAMES={['4D1C334D294DFA97']='Helldiver / character subtitle'}},{__index=M.CHAR_SPEC})
  local view=V.build(spec,{table=c.tables[M.CHAR],kind=M.CHAR,weapons=c.weapons,by_hash=c.by_hash,
   field_at=c.field_at,read=c.read,add_row=c.add_row,default_of=c.default_of,schemas=c.schemas,names=c.names,lang=c.lang,log=c.log})
  M.pages.CharacterNameFields=view.pages
  for _,page in ipairs(view.pages)do page.note_of=function()return tx({'Scope: character subtitles and random name templates.',
   '作用范围：角色字幕名称与随机名字模板。','作用範圍：角色字幕名稱與隨機名字範本。'})..' · '..page.entity_hash end end
 elseif c.log then c.log('identity: character-name layout not matched; fields unavailable')end
 local function page(name,slot,key)
  local hash=D.hex(D.hash_resource('shodan/identity/'..slot..'/'..key))
  local p={name=name,slot=slot,hash=hash,rows={},by_id={},field_keys={},identity_parameters=true}
  c.by_hash[hash]=p;M.pages[slot][#M.pages[slot]+1]=p;return p
 end
 local function readonly(p,id,label,text)
  local row={id=id,label=label,storage='u32',parts={},empty=true,readonly_text=tostring(text),section='Metadata'}
  row.section_of=function()return tx({'Metadata (read-only)','元数据（只读）','中繼資料（唯讀）'})end
  row.tip_of=function()return{label..': '..tostring(text)}end
  p.rows[#p.rows+1]=row;return row
 end
 if M.font_layout(c.schemas)then for _,kind in ipairs(c.font_list)do
  local t=c.tables[kind];local b=c.bytes(kind);local idx=t.index
  local key=string.format('%08X%08X',u32(b,4),u32(b,0))
  local language=table.concat(idx.languages,', ')
  local p=page('FontSettings · '..(language~=''and language or key),'FontStyleFields',key)
  p.languages=idx.languages
  p.component_view='font_style'
  p.note_of=function()return tx({'Scope: local shared HUD/menu font styles.','作用范围：本机共用 HUD／菜单字体样式。','作用範圍：本機共用 HUD／選單字型樣式。'})end
  readonly(p,'name','name (resource hash)','0x'..key)
  readonly(p,'languages','languages',language~=''and language or key)
  readonly(p,'package','resource_package',D.hex(b:sub(25,32)))
  for _,entry in ipairs(idx.styles)do
   local off=entry.offset;local id=entry.group..'_'..entry.index..'_'
   local section=entry.group..':'..entry.index
   local style=u32(b,off);local labels=entry.group=='hud'and M.HUD or M.MENU
   local title=entry.group:upper()..' · '..(labels[style+1]or tostring(style))..' ['..entry.index..']'
   for _,field in ipairs({{'style',0,'u32',{'Style ID (style)','样式 ID（style）','樣式 ID（style）'},0,4294967295,1,1},
    {'font_type',4,'u32',{'Font type (settings.type)','字体类型（settings.type）','字型類型（settings.type）'},0,4294967295,1,1},
    {'font_size',8,'f32',{'Font size (font_size)','字号（font_size）','字號（font_size）'},0,1000,1,5},
    {'shadow_range',12,'f32',{'Shadow range (shadow_range)','阴影范围（shadow_range）','陰影範圍（shadow_range）'},0,100,0.05,0.2}})do
    local f=c.field_at(kind,off+field[2],field[3],field[3]=='f32'and 1e12 or 4294967295)
    local row=c.add_row(p,section,id..field[1],field[4][1],field[3],{{id=id..field[1],field=f}},field[5],field[6],field[7],field[8])
    row.label_of=function()return tx(field[4])end
    row.section_of=function()return title end
    row.component='FontSettings';row.component_of=function()return tx({'Font styles','字体样式','字型樣式'})end
    row.tip_of=function()return{field[1],string.format('FontSettings payload +0x%X · %s',off+field[2],field[3]),
     tx({'Shared local display style; affects every widget using it.','共用本机显示样式，影响所有使用它的界面元素。','共用本機顯示樣式，影響所有使用它的介面元素。'})}end
    p.field_keys[f.key]=true
   end
  end
 end elseif c.log then c.log('identity: font layout not matched; fields unavailable')end
 local preferred=c.lang()=='zh-Hans'and'cn'or c.lang()=='zh-Hant'and'tc'or c.lang()=='ru'and'ru'or'us'
 local function language_matches(p)for _,name in ipairs(p.languages)do if name==preferred then return true end end;return false end
 table.sort(M.pages.FontStyleFields,function(a,b)
  local aa,bb=language_matches(a),language_matches(b);if aa~=bb then return aa end;return a.name<b.name
 end)
 -- Confirmed operation names and descriptor metadata; no writable unidentified arguments.
 for _,r in ipairs({{'rpc_ingame_chat_message','9FDDB88E',2},{'rpc_set_player_info','E0294D95',2},{'rpc_sync_player_info','E36BFC38',2}})do
  local p=page(r[1],'IdentityRpcInfo',r[1])
  p.note_of=function()return tx({'2026-10-28 resource snapshot; argument member names unresolved, read-only.',
   '2026-10-28 资源快照；参数成员名尚未恢复，仅供查看。','2026-10-28 資源快照；參數成員名尚未恢復，僅供查看。'})end
  readonly(p,'operation','operation',r[1]);readonly(p,'hash','name_hash (thin)',r[2]);readonly(p,'count','argument_count',r[3])
 end
 return M.pages
end
function M.list(tab,query,tr)
 local source=M.pages[tab];if not source then return end
 if not query or query==''then return source end
 local out={};for _,p in ipairs(source)do
  local text=(p.name..' '..(tr and tr(p.name)or'')..' '..(p.entity_hash or'')):lower();local found=true
  for word in query:lower():gmatch('%S+')do if not text:find(word,1,true)then found=false;break end end
  if found then out[#out+1]=p end
 end;return out
end
return M
