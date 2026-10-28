-- Shared bottom actions. Coordinates are physical pixels; all four actions share a row.
local M={}
function M.layout(width,height)
 local sx,sy=width/1060,height/1080
 local gap,left,span=10*sx,30*sx,(width-60*sx)-30*sx
 local buttons={};local weights={.28,.28,.22,.22}
 for i,entry in ipairs({{'install','Install into the game'},{'restore',"Restore the game's files"},{'presets','Presets'},{'settings','Settings'}})do
  local size=span*weights[i]
  buttons[#buttons+1]={key=entry[1],label=entry[2],x0=left,x1=left+size,y0=1038*sy,y1=1072*sy}
  left=left+size+gap
 end
 return buttons
end
return M
