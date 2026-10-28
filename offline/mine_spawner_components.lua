-- MineSpawnerComponentData (地雷生成器, 32 bytes): how an enemy minefield lays its mines out (a grid of
-- mines wide x deep over width x depth, with scatter). Not in the RawData dump: layout from the game's type library,
-- values checked against the game's data; the editor already had +8 / +12 width / depth, +16 / +20 mines wide /
-- deep and +24 scatter (the minefield pages). +0 (the same 64-bit value in every record) and +28 are unnamed.
local V=require('component_view')
local R,f=V.R,V.field
local S={TYPE='MineSpawnerComponentData',KEY='mine_spawner',SIZE=32,SLOT='MineSpawnerComponents',FLAG='mine_spawner_component',
 COMPONENT={'Mine spawner component','地雷生成器组件（MineSpawner）','地雷生成器組件（MineSpawner）'}}
S.GROUPS={
 {'layout','Layout','布雷范围','佈雷範圍'},
 {'unknown','Unknown fields','未知字段','未知欄位'},
}
local L={}
f(L,'mines_wide',16,'u32','layout','Mines wide','横向地雷数','橫向地雷數',R.count,{verified=true,id='mine_wide'})
f(L,'mines_deep',20,'u32','layout','Mines deep','纵向地雷数','縱向地雷數',R.count,{verified=true,id='mine_deep'})
f(L,'field_width',8,'f32','layout','Field width (m)','雷区宽度（米）','雷區寬度（米）',R.m,{verified=true,id='mine_width'})
f(L,'field_depth',12,'f32','layout','Field depth (m)','雷区深度（米）','雷區深度（米）',R.m,{verified=true,id='mine_depth'})
f(L,'position_scatter',24,'f32','layout','Position scatter (m)','位置随机偏移（米）','位置隨機偏移（米）',R.m,{verified=true,id='mine_scatter'})
f(L,'unk_uint64_0x0000',0,'u64','unknown','Unknown 64-bit value +0x00','未知64位值 +0x00','未知64位值 +0x00',R.hash,
 {note={'The same value in every record; likely a resource hash.','所有记录中都是同一个值，可能是资源哈希。','所有記錄中都是同一個值，可能是資源雜湊。'}})
f(L,'unk_bool_0x001C',28,'flag','unknown','Unknown switch +0x1C','未知开关 +0x1C','未知開關 +0x1C',R.flag)
S.FIELDS=L
S.LAYOUT={{0,8},{8,4},{12,4},{16,4},{20,4},{24,4},{28,1}}
return V.prepare(S)
