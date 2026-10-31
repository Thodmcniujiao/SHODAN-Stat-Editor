-- P1 convenience rows on the real desktop host and game data (Windows only; no game writes):
-- pickup slot / auto drop, no bolt pull, second ammo switch, beam rows, stomp / shield bash,
-- enemy side / rear sight, body part bleed-out time and vehicle Copy to....
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
local found={}
local function body()
 assert(tonumber(ffi.C.GetTickCount64())-began<420000,'P1 rows host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready'then
   local e=assert(TEST_PARAMETERS)
   -- every row of a page: component-first pages keep theirs in (lazily loaded) component groups
   local function rows(w)
    if w.ensure_rows then w.ensure_rows()end
    if not w.component_groups then return w.rows or{}end
    local out={}
    for _,g in ipairs(w.component_groups)do if g.load then g.load()end;for _,r in ipairs(g.rows or{})do out[#out+1]=r end end
    return out
   end
   local function each(test)for _,w in ipairs(e.weapons)do for n,r in ipairs(rows(w))do local hit=test(w,r,n);if hit then return w,r,n end end end end
   local function set(w,r,v)e.select(w);e.change(r,0,false,v)end
   -- armory: every armor has its own page in the Armor editing list, and looking at pages never resets a combination
   local armor_pages={};for _,w in ipairs(e.weapons_in('Armors'))do if w.armor then armor_pages[#armor_pages+1]=w end end
   assert(#armor_pages>=50,'armor pages missing from the Armor editing list: '..#armor_pages)
   for _,w in ipairs(e.weapons_in('Armors'))do assert(not w.passive and w.hash~='FFFFFFF900000001','护甲 tab lists only armors')end
   local passive_tab=e.weapons_in('ArmorPassives');assert(#passive_tab>=20,'护甲词条 tab missing passives');for _,w in ipairs(passive_tab)do assert(w.passive)end
   do local wr;for _,r in ipairs(armor_pages[1].rows)do if r.id=='weight'then wr=r end end
    assert(wr,'armor page has no weight row');local w0=e.row_value(wr);e.select(armor_pages[1]);e.change(wr,0,false,w0==2 and 1 or 2)
    local weight_page=e.by_hash['FFFFFFF900000001'];local same;for _,r in ipairs(weight_page.rows)do if r.parts[1].field==wr.parts[1].field then same=r end end
    assert(same and e.row_value(same)==e.row_value(wr)and e.row_value(wr)~=w0,'weight row not shared with the weight page')
    e.reset_row(armor_pages[1],wr);assert(e.row_value(wr)==w0)
   end
   local ap=armor_pages[1];local other
   for _,w in ipairs(e.weapons)do if w.passive then local id=tonumber(w.hash:sub(9),16)
    local taken=false;for _,v in ipairs(e.MOD.kits.list_of(ap))do if v==id then taken=true end end
    if not taken then other=id;break end
   end end
   e.select(ap);local before=#e.MOD.kits.list_of(ap);e.click('stack_add:'..other)
   assert(#e.MOD.kits.list_of(ap)==before+1,'add passive did not stick')
   for _,w in ipairs(e.weapons_in('Armors'))do e.MOD.page_changed(w)end
   assert(#e.MOD.kits.list_of(ap)==before+1,'checking pages reset the armor passives')
   assert(e.MOD.page_changed(ap),'an armor with its own passives does not show as changed')
   e.click('reset_weapon');assert(#e.MOD.kits.list_of(ap)==before and not e.settings.armor_passives[ap.armor],'Reset this page kept the combination')
   found.armor=#armor_pages..' armor pages'
   -- pickup: out of the support slot the EAT / Commando drop ability is cleared, back at 3 it is the game's again
   local w,r=each(function(_,r)return r.id=='pickup_slot'and r.parts[1].field.auto_drop end)
   if w then
    local drop=r.parts[1].field.auto_drop;local own=e.default_of(drop);assert(own and own~=0)
    set(w,r,1);assert(e.read(drop)==0,'auto drop not cleared');set(w,r,3);assert(e.read(drop)==own,'auto drop not restored')
    e.reset_row(w,r);found.pickup=w.name
   end
   -- no bolt pull: the switch writes the Diligence's ids into all three u32s and puts the game's back
   w,r=each(function(_,r)return r.id=='no_bolt'end)
   if w then
    assert(e.row_value(r)==0);set(w,r,1);assert(e.row_value(r)==1)
    for _,p in ipairs(r.parts)do assert(e.read(p.field)==1 and p.field.bolt_on~=p.field.bolt_off)end
    e.reset_row(w,r);assert(e.row_value(r)==0);found.bolt=w.name
   end
   -- second ammo: a choice takes the free weapon function (8); none gives it back
   w,r=each(function(_,r)return r.id=='projectile_2'and r.parts[1].field.switch end)
   if w then
    local sw=r.parts[1].field.switch;local own=e.default_of(sw)
    e.select(w);e.change(r,1,false);assert((e.read(r.parts[1].field)or 0)>0 and e.read(sw)==8,'second ammo switch not set')
    e.reset_row(w,r);assert(e.read(sw)==own);found.second=w.name
   end
   for _,id in ipairs({'beam_range','beam_count','beam_stay','sight_side','sight_rear'})do
    local pw=each(function(_,r)return r.id==id end);if pw then found[id]=pw.name end
   end
   local sw=each(function(_,r)return type(r.id)=='string'and r.id:match('^stomp_')end);found.stomp=sw and sw.name
   local bw=each(function(_,r)return type(r.id)=='string'and r.id:match('^bash_')end);found.bash=bw and bw.name
   -- bleed-out time: the same bytes as the bleed-out health, in seconds over the enemy's part drain
   w,r=each(function(_,r)return type(r.id)=='string'and r.id:match('_bleed_time$')end)
   if w then
    local rate=e.read(r.drain.parts[1].field);local health=e.read(r.parts[1].field)
    assert(rate>0 and math.abs(e.row_value(r)-health/rate)<1e-3)
    set(w,r,e.row_value(r)+2);assert(math.abs(e.read(r.parts[1].field)-(health+2*rate))<=1,'time does not set the bleed-out health')
    e.reset_row(w,r);assert(e.read(r.parts[1].field)==health);found.bleed=w.name
   end
   -- vehicle Copy to...: components pair by type (entity hash left out), kinds with their own kind, body parts by
   -- zone name; a copied value lands and resets
   local V=e.MOD.vcopy;local v,comp
   for _,w in ipairs(e.weapons)do if V.kind(w)=='vehicle'then
    for _,c in ipairs(V.comps(w))do if c:match('^HealthComponentData')and V.can(w,c)then v,comp=w,c;break end end
    if v then break end
   end end
   if not v then
    local info={}
    for _,w in ipairs(e.weapons)do if V.kind(w)=='vehicle'then
     local list={};for _,c in ipairs(V.comps(w))do list[#list+1]=V.norm(c)..'='..#V.rows(w,c)..'/'..#V.targets(w,c)end
     info[#info+1]=w.name..': '..table.concat(list,' ')
    end end
    error('no vehicle health component offers Copy to (rows/targets):\n  '..table.concat(info,'\n  '))
   end
   local targets=V.targets(v,comp);assert(#targets>0)
   for _,t in ipairs(targets)do assert(V.kind(t)=='vehicle'and t~=v)end
   local tg=assert(V.group_of(targets[1],comp))
   local tk={};for _,r in ipairs(V.rows(targets[1],comp))do tk[V.key(r,tg.type)]=r end
   local hr,th;for _,r in ipairs(V.rows(v,comp))do local t=tk[V.key(r,comp)]
    if t and t.parts[1].field~=r.parts[1].field and r.storage=='u32'and e.row_value(r)then hr,th=r,t;break end end
   assert(hr,'no paired u32 row in '..comp)
   local own,town=e.row_value(hr),e.row_value(th);set(v,hr,own+7);local want=e.row_value(hr)
   local plan=V.plan(v,comp,targets[1]);local listed=false
   for _,c in ipairs(plan.changes)do if c.row==th then listed=true end end;assert(listed or want==town,'changed row missing from the preview')
   assert(V.apply(v,comp,{targets[1]})>=1);assert(e.row_value(th)==want,'copied value did not land')
   for _,c in ipairs(plan.changes)do e.select(targets[1]);e.reset_row(targets[1],c.row)end
   e.select(v);e.reset_row(v,hr);assert(e.row_value(hr)==own and e.row_value(th)==town,'reset did not restore')
   local zones=0
   for _,w in ipairs(e.weapons)do if V.kind(w)=='vehicle'then for _,c in ipairs(V.comps(w))do if c:match('^HealthComponentData')then
    for _,t in ipairs(V.targets(w,c))do local tgc=V.group_of(t,c).type
     for _,ch in ipairs(V.plan(w,c,t).changes)do
      assert(V.key(ch.from,c)==V.key(ch.row,tgc)and ch.from.parts[1].field~=ch.row.parts[1].field)
      if V.key(ch.from,c):find('|zone:',1,true)then zones=zones+1 end
     end
    end
   end end end end
   for _,w in ipairs(e.weapons)do local kind=V.kind(w)
    if kind and kind:find('^mount:')then for _,c in ipairs(V.comps(w))do
     for _,t in ipairs(V.targets(w,c))do assert(V.kind(t)==kind,'a mount paired with another kind')end
    end end
   end
   found.copy=v.name..' '..V.norm(comp)..' -> '..#targets..' (zone pairs '..zones..')'
   local missing={}
   for _,k in ipairs({'armor','pickup','bolt','second','beam_range','beam_count','sight_side','sight_rear','stomp','bash','bleed','copy'})do
    if not found[k]then missing[#missing+1]=k end
   end
   if #missing>0 then
    local got={};for k,v in pairs(found)do got[#got+1]=k..'='..tostring(v)end;table.sort(got)
    error('rows not found in this game build: '..table.concat(missing,', ')..'\n  found: '..table.concat(got,'; '))
   end
   phase=1
  end
 end
 return phase<1
end
-- an error must end the run (printed), not wait in the host's hidden error box
S.pump=function()
 local ok,res=xpcall(body,debug.traceback)
 if not ok then io.stderr:write('FAIL: '..tostring(res)..'\n');io.stderr:flush();os.exit(1)end
 return res
end
S.present=function()end
arg={[1]=panel};assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
assert(phase==1);gdi.DeleteDC(S.dc)
local list={};for k,v in pairs(found)do list[#list+1]=k..'='..tostring(v)end;table.sort(list)
print('PASS: P1 rows on real data, written and reset without game writes: '..table.concat(list,'; '))
]==]
assert(loadstring(prefix..checks,'@p1_rows_host'))()
