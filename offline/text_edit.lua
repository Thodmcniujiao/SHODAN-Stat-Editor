-- UTF-8 byte-boundary caret and selection, shared by every text input.
local M={CHAR='[%z\1-\127\194-\244][\128-\191]*',BLINK=0.53}
local function clock_now(now)return tonumber(now)or os.clock()end
function M.touch(e,now)if e then e.touched=clock_now(now)end end
function M.caret_on(e,now)
 if not e then return false end
 local t=clock_now(now)
 if not e.touched or t<e.touched then e.touched=t end
 return math.floor((t-e.touched)/M.BLINK)%2==0
end
function M.signature(e,now)
 if not e then return'-'end
 local a,b=M.range(e)
 return table.concat({e.text or'',M.pos(e),a,b,e.fresh and'1'or'0',M.caret_on(e,now)and'1'or'0'},':')
end
local function boundary(s,p)
 p=math.max(0,math.min(#s,p))
 while p>0 and s:byte(p+1)and s:byte(p+1)>=128 and s:byte(p+1)<192 do p=p-1 end
 return p
end
function M.pos(e)return boundary(e.text,e.at or #e.text)end
local function prev(s,p)return boundary(s,p-1)end
local function nextpos(s,p)
 local q=math.min(#s,p+1)
 while q<#s and s:byte(q+1)>=128 and s:byte(q+1)<192 do q=q+1 end
 return q
end
function M.range(e)
 if e.fresh then return 0,#e.text end
 local at=M.pos(e);local anchor=boundary(e.text,e.anchor or at)
 return math.min(at,anchor),math.max(at,anchor)
end
function M.selected(e)
 local a,b=M.range(e);return a~=b and e.text:sub(a+1,b)or e.text
end
function M.all(e,now)e.fresh=true;e.at=#e.text;e.anchor=nil;M.touch(e,now)end
local function replace(e,a,b,text,now)
 e.text=e.text:sub(1,a)..text..e.text:sub(b+1);e.at=a+#text;e.fresh=false;e.anchor=nil;e.visual=nil;M.touch(e,now)
end
function M.insert(e,text,limit,now)
 local a,b=M.range(e)
 if #e.text-(b-a)+#text>(limit or math.huge)then return false end
 replace(e,a,b,text,now);return true
end
local function word(s,p,direction)
 if direction<0 then
  while p>0 and s:sub(prev(s,p)+1,p):match('^%s$')do p=prev(s,p)end
  while p>0 and not s:sub(prev(s,p)+1,p):match('^[%s%p]$')do p=prev(s,p)end
  return p
 end
 while p<#s and not s:sub(p+1,nextpos(s,p)):match('^[%s%p]$')do p=nextpos(s,p)end
 while p<#s and s:sub(p+1,nextpos(s,p)):match('^[%s%p]$')do p=nextpos(s,p)end
 return p
end
function M.erase(e,forward,whole,now)
 local a,b=M.range(e)
 if a==b then
  if forward then b=whole and word(e.text,b,1)or nextpos(e.text,b)
  else a=whole and word(e.text,a,-1)or prev(e.text,a)end
  if a==b then if forward then b=nextpos(e.text,b)else a=prev(e.text,a)end end
 end
 replace(e,a,b,'',now)
end
function M.move(e,key,control,shift,now)
 local p=M.pos(e);local a,b=M.range(e);local q=p
 if e.fresh and not shift and(key=='Left'or key=='Right')then q=key=='Left'and 0 or #e.text
 elseif not shift and a~=b and(key=='Left'or key=='Right')then q=key=='Left'and a or b
 elseif key=='Left'then q=control and word(e.text,p,-1)or prev(e.text,p);if q==p and p>0 then q=prev(e.text,p)end
 elseif key=='Right'then q=control and word(e.text,p,1)or nextpos(e.text,p);if q==p and p<#e.text then q=nextpos(e.text,p)end
 elseif key=='Home'then q=control and 0 or (e.text:sub(1,p):match('.*\n()')or 1)-1
 elseif key=='End'then q=control and #e.text or (e.text:find('\n',p+1,true)or(#e.text+1))-1
 elseif key=='Up'or key=='Down'then
  local starts={0};for at in e.text:gmatch('\n()')do starts[#starts+1]=at-1 end
  if e.visual and e.visual.text==e.text then starts=e.visual.starts end
  local row=1;for i,at in ipairs(starts)do if at<=p then row=i end end
  local column=0;for _ in e.text:sub(starts[row]+1,p):gmatch(M.CHAR)do column=column+1 end
  local target=math.max(1,math.min(#starts,row+(key=='Up'and-1 or 1)));q=starts[target]
  local finish=target<#starts and starts[target+1]-1 or#e.text
  for _=1,column do if q>=finish then break end;q=nextpos(e.text,q)end
 end
 if shift then e.anchor=e.anchor or(e.fresh and 0 or p)else e.anchor=nil end
 e.at=boundary(e.text,q);e.fresh=false;M.touch(e,now)
end
function M.click_at(e,byte_pos,shift,now)
 local p=M.pos(e)
 if shift then e.anchor=e.anchor or(e.fresh and 0 or p)else e.anchor=nil end
 e.at=boundary(e.text,byte_pos or #e.text);e.fresh=false;M.touch(e,now)
end
function M.view(e,limit)
 local s=e.text or''
 local at=M.pos(e);local sel_a,sel_b=M.range(e)
 local starts,chars={0},{}
 local pos,caret_idx=0,0
 for c in s:gmatch(M.CHAR)do
  chars[#chars+1]=c;pos=pos+#c;starts[#chars+1]=pos
  if pos<=at then caret_idx=#chars end
 end
 local from,to=1,#chars
 if limit and #chars>limit then
  from=math.max(1,caret_idx-limit+1)
  to=math.min(#chars,from+limit-1)
  from=math.max(1,to-limit+1)
 end
 local vis_a=starts[from]or 0
 local vis_b=(to>=#chars and #s)or starts[to+1]or #s
 local shown=s:sub(vis_a+1,vis_b)
 local caret_off=math.max(0,math.min(#shown,at-vis_a))
 local sa=math.max(0,math.min(#shown,sel_a-vis_a))
 local sb=math.max(0,math.min(#shown,sel_b-vis_a))
 return{
  text=shown,caret=caret_off,sel_a=sa,sel_b=sb,
  prefix=shown:sub(1,sa),selected=shown:sub(sa+1,sb),suffix=shown:sub(sb+1),
  before_caret=shown:sub(1,caret_off),vis_a=vis_a,vis_b=vis_b,
 }
end
function M.show(e,limit)
 local at=M.pos(e);local before,after=e.text:sub(1,at),e.text:sub(at+1)
 if limit then
  local chars={};for c in before:gmatch(M.CHAR)do chars[#chars+1]=c end
  local from=math.max(1,#chars-limit+1);before=table.concat(chars,'',from)
  local out={};for c in after:gmatch(M.CHAR)do out[#out+1]=c;if #out>=limit-#chars+from-1 then break end end;after=table.concat(out)
 end
 return before..'_'..after
end
function M.wrap(e,width,size)
 local rows,starts={},{};local line,at,units='',0,0;starts[1]=0
 for c in e.text:gmatch(M.CHAR)do
  local n=c:byte()<128 and .55 or 1
  if c=='\n'or units+n>width/size then
   rows[#rows+1]=line;line='';units=0;starts[#rows+1]=c=='\n'and at+#c or at
  end
  if c~='\n' then line=line..c;units=units+n end;at=at+#c
 end
 rows[#rows+1]=line;e.visual={text=e.text,starts=starts}
 local row=1;local p=M.pos(e);for i,from in ipairs(starts)do if from<=p then row=i end end
 local offset=math.max(0,math.min(#rows[row],p-starts[row]))
 local sel_a,sel_b=M.range(e)
 local meta={}
 for i,r in ipairs(rows)do
  local ls=starts[i]
  local sa=math.max(0,math.min(#r,sel_a-ls))
  local sb=math.max(0,math.min(#r,sel_b-ls))
  meta[i]={start=ls,sel_a=sa,sel_b=sb,prefix=r:sub(1,sa),selected=r:sub(sa+1,sb),suffix=r:sub(sb+1)}
 end
 return rows,row,offset,meta
end
function M.lines(e,width,size)
 local rows,row,offset=M.wrap(e,width,size)
 local copy={};for i,r in ipairs(rows)do copy[i]=r end
 copy[row]=copy[row]:sub(1,offset)..'_'..copy[row]:sub(offset+1)
 return copy,row
end
function M.keys(e,o)
 if o.commit_down or o.cancel_down then return false end
 local hit=o.pressed;local now=o.now
 if o.ctrl then
  if hit('T65')then M.all(e,now);return true end
  if hit('T67')then o.copy(M.selected(e));return true end
  if hit('T88')then o.copy(M.selected(e));local a,b=M.range(e);if a==b then M.all(e,now)end;M.erase(e,false,false,now);return true end
  if hit('T86')then
   local raw=tostring(o.paste()or''):gsub('\r\n','\n'):gsub('\r','\n')
   if not o.multiline then raw=raw:gsub('\n',' ')end
   if o.compact then raw=raw:gsub('%s+','')end
   for c in raw:gmatch(M.CHAR)do if not o.accept or o.accept(c)then M.insert(e,c,o.limit,now)end end
   M.touch(e,now)
   return true
  end
 end
 for _,key in ipairs({'Left','Right','Home','End','Up','Down'})do
  if hit(key,.3,.04)then M.move(e,key,o.ctrl,o.shift,now);return true end
 end
 if hit('Backspace',o.delay or .3,o.rate or .015)then M.erase(e,false,o.ctrl,now);return true end
 if hit('Delete',o.delay or .3,o.rate or .015)then M.erase(e,true,o.ctrl,now);return true end
 if o.multiline and o.shift and hit('Enter')then M.insert(e,'\n',o.limit,now);return true end
 if not o.ctrl then
  local consumed=false
  for _,c in ipairs(o.typed or{})do consumed=true;if not o.accept or o.accept(c)then M.insert(e,c,o.limit,now)end end
  if consumed then M.touch(e,now);return true end
 end
 return false
end
return M
