-- InventoryComponentData (背包 / 物品栏, 144 bytes): an entity's default equipment (+0 primary, +8 sidearm,
-- +16 support, +24 throwable, +32 backpack, +40 melee weapon: entity hashes), its stims (+48 start, +52 refill,
-- +56 max), +60 can drop equipment, and an unnamed list of 10 entities (+64; the helldiver's first is the Cricket
-- pistol). Layout from the type-library dump of game 1.007.200 (Darctor/Helldivers2_RawData,
-- InventoryComponentData.json, 2026-10-20), checked against the game's type library and data (86 entities).
-- The SEAF pages' "Weapons carried" rows are the same fields (+0 / +8 / +16, chosen from SEAF's weapon list).
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='InventoryComponentData',KEY='inventory',SIZE=144,SLOT='InventoryComponents',FLAG='inventory_component',
 COMPONENT={'Inventory component','物品栏组件（Inventory）','物品欄組件（Inventory）'}}
S.GROUPS={
 {'loadout','Default equipment','默认装备','預設裝備'},
 {'stims','Stims','治疗针','治療針'},
 {'other','Other','其他','其他'},
 {'extra','Unnamed equipment list','未命名装备列表','未命名裝備列表'},
}
local CHANGE={'Equipment the game does not load for this entity shows as a missing model, and an enemy\'s gun in SEAF hands has crashed the game.',
 '换成游戏没为该实体加载的装备会显示为缺失模型；把敌人的枪给 SEAF 曾使游戏崩溃。','換成遊戲沒為該實體載入的裝備會顯示為缺失模型；把敵人的槍給 SEAF 曾使遊戲崩潰。'}
local L={}
for i,s in ipairs({{'default_primary','Primary','主武器','主武器'},{'default_sidearm','Sidearm','副武器','副武器'},
 {'default_support','Support weapon','支援武器','支援武器'},{'default_throwable','Throwable','投掷物','投擲物'},
 {'default_backpack','Backpack','背包','背包'},{'default_melee_weapon','Melee weapon','近战武器','近戰武器'}})do
 f(L,s[1],(i-1)*8,'u64','loadout',s[2],s[3],s[4],R.hash,{entity=true,note=CHANGE})
end
f(L,'start_amount_stims',48,'u32','stims','Starting stims','初始治疗针','初始治療針',R.count)
f(L,'refill_amount_stims',52,'u32','stims','Stims from resupply','补给治疗针','補給治療針',R.count)
f(L,'max_amount_stims',56,'u32','stims','Max stims','最大治疗针','最大治療針',R.count)
f(L,'can_drop_equipment',60,'flag','other','Can drop equipment','可丢弃装备','可丟棄裝備',R.flag)
for k=0,9 do
 f(L,'unk_array_0x0040['..k..']',64+k*8,'u64','extra','Unnamed entity '..(k+1),'未命名实体 '..(k+1),'未命名實體 '..(k+1),R.hash,
  {id='unk_entity'..(k+1),entity=true})
end
S.FIELDS=L
S.LAYOUT={{0,8},{8,8},{16,8},{24,8},{32,8},{40,8},{48,4},{52,4},{56,4},{60,1},{64,80}}
return V.prepare(S)
