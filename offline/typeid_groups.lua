-- Presentation only: no ID remapping, offsets, field objects or config keys change.
local M={}
-- Sort only this component's newly emitted range; nested/inline damage owners stay separate.
function M.sort(schema,rows,first,last)
 first,last=first or 1,last or #rows
 local rank={};for i,id in ipairs(schema.GROUP_ORDER)do
  assert(schema.GROUPS[id],'unknown TypeID parameter group: '..id);rank[id]=i
 end
 local ordered={}
 for i=first,last do
  local row=rows[i];local group=assert(row.section and row.section:match('([^:]+)$'))
  assert(rank[group],'unclassified TypeID row: '..tostring(row.id)..' / '..group)
  row.section_level='group'
  ordered[#ordered+1]={row=row,rank=rank[group],index=i}
 end
 table.sort(ordered,function(a,b)return a.rank~=b.rank and a.rank<b.rank or a.rank==b.rank and a.index<b.index end)
 for i,item in ipairs(ordered)do rows[first+i-1]=item.row end
 return rows
end
return M
