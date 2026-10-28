-- DamageSettings -> DamageInfo: all 19 scalar fields of the current 76-byte record.
local M={TYPE=0xE0A72CF0,SIZE=76}
-- Legacy stat id, INI field name, offset, storage, min, max, small step, big step.
M.FIELDS={
 {'damage','Damage',4,'i32',-1000000,1000000,1,10},
 {'durable','ArmorDamage',8,'i32',-1000000,1000000,1,10},
 {'ap_direct','PenetrationAngle25',12,'u32',0,100,1,1},
 {'ap_slight','PenetrationAngle60',16,'u32',0,100,1,1},
 {'ap_large','PenetrationAngle80',20,'u32',0,100,1,1},
 {'ap_extreme','PenetrationAngle90',24,'u32',0,100,1,1},
 {'demolition','Demolition',28,'u32',0,1000000,1,10},
 {'stagger','ForceStrength',32,'u32',0,1000000,1,10},
 {'push','ForceImpulse',36,'u32',0,1000000,1,10},
 {'element_type','ElementType',40,'u32',0,5,1,1},
}
M.NAMES={
 DamageTypeID={'Damage ID','伤害 ID','傷害 ID'},
 Damage={'Damage','伤害','傷害'},ArmorDamage={'Durable damage','耐久伤害','耐久傷害'},
 PenetrationAngle25={'Armor pen. (direct, 25°)','穿甲等级（正面命中，25°）','穿甲等級（正面命中，25°）'},
 PenetrationAngle60={'Armor pen. (slight angle, 60°)','穿甲等级（小角度，60°）','穿甲等級（小角度，60°）'},
 PenetrationAngle80={'Armor pen. (large angle, 80°)','穿甲等级（大角度，80°）','穿甲等級（大角度，80°）'},
 PenetrationAngle90={'Armor pen. (extreme angle, 90°)','穿甲等级（极端角度，90°）','穿甲等級（極端角度，90°）'},
 Demolition={'Demolition force','破坏力','破壞力'},
 ForceStrength={'Stagger force','硬直力','硬直力'},ForceImpulse={'Push force','击退力','擊退力'},
 ElementType={'Element type','元素类型','元素類型'},
}
M.ELEMENTS={
 {'None','无','無'},{'Fire','火焰','火焰'},{'Electricity','电击','電擊'},
 {'Acid','酸液','酸液'},{'Bleed','流血','流血'},{'Gas','毒气','毒氣'},
}
function M.names(field)
 if M.NAMES[field]then return M.NAMES[field]end
 local n=field:match('^StatusEffectType(%d+)$')
 if n then return{'Status effect '..n..' ID','状态效果 '..n..' ID','狀態效果 '..n..' ID'}end
 n=field:match('^StatusEffectFactor(%d+)$')
 if n then return{'Status effect '..n..' strength per hit','状态效果 '..n..'：每次命中强度','狀態效果 '..n..'：每次命中強度'}end
 return{field,field,field}
end
function M.check_layout(schemas)
 local table_type=schemas and schemas[M.TYPE]
 local array=table_type and table_type.members and table_type.members[1]
 local row=array and schemas[array.type]
 if not array or array.atom~=1 or array.storage~=20 or not row or row.size~=M.SIZE or #row.members~=8 then return nil end
 local expected={{0,4,16,0,0},{4,8,2,2,2},{12,16,6,2,4},{28,4,6,0,0},
  {32,4,6,0,0},{36,4,6,0,0},{40,4,16,0,0},{44,32,20,2,4}}
 for i,e in ipairs(expected)do
  local m=row.members[i]
  if not m or m.offset~=e[1]or m.size~=e[2]or m.storage~=e[3]or m.atom~=e[4]or m.count~=e[5]then return nil end
 end
 local status=schemas[row.members[8].type]
 return status and status.size==8 and #status.members==2
  and status.members[1].offset==0 and status.members[1].size==4 and status.members[1].storage==12
  and status.members[2].offset==4 and status.members[2].size==4 and status.members[2].storage==8
end
return M
