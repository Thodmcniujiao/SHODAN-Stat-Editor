local J=require('json_data')
local decoded=J.decode(' { "name": "\\u963f\\u5c14\\u6cd5", "emoji":"\\ud83d\\ude80", "a":[true,false,null,-1.25e2] } ')
assert(decoded.name=='阿尔法'and decoded.emoji=='🚀'and decoded.a[1]and decoded.a[2]==false and decoded.a[3]==J.null and decoded.a[4]==-125)
assert(J.decode(J.encode(decoded)).emoji=='🚀')
assert(J.encode(J.array())=='[]')
for _,s in ipairs({'{"a":1,"a":2}','[1,]','01','1.e2','NaN','return os.execute("x")','"\\ud800"','{"a":false} trailing'})do
 assert(not pcall(J.decode,s),'accepted invalid JSON: '..s)
end
print('PASS: strict JSON, UTF-8, Unicode surrogate pairs, booleans/null, round-trip, duplicate/invalid rejection and data-only parsing')
