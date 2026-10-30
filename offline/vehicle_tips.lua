-- Vehicle handling tips derived from upstream 4794aee, plus local centre-of-mass axes.
local M={}
local T={
 mass={
  ["en"]={"Heavier: speeds up and stops more slowly, shoves enemies and wrecks aside, and is harder to flip.","Lighter: quicker off the line, but bounces over bumps and gets thrown around by explosions."},
  ["zh-Hans"]={"越重：加速和制动越慢，推撞更有力，也更难翻车。","越轻：起步更快，但更容易被路面颠簸和爆炸抛起。"},
  ["zh-Hant"]={"越重：加速和煞車越慢，推撞更有力，也更難翻車。","越輕：起步更快，但更容易被路面顛簸和爆炸拋起。"},
  ["ru"]={"Тяжелее: медленнее разгон и торможение, сильнее толчки, труднее опрокинуть.","Легче: быстрее разгон, но неровности и взрывы сильнее подбрасывают машину."},
 },
 com={
  ["en"]={"How high the balance point sits. Lower (even below 0): stays flat in hard turns and over rocks.","Higher: leans more and tips over in sharp turns."},
  ["zh-Hans"]={"降低重心（可低于零）能改善急转弯和越障时的稳定性。","提高重心会增加车身侧倾，更容易翻车。"},
  ["zh-Hant"]={"降低重心（可低於零）能改善急轉彎和越障時的穩定性。","提高重心會增加車身側傾，更容易翻車。"},
  ["ru"]={"Ниже центр масс, даже ниже нуля: устойчивее в поворотах и на камнях.","Выше: сильнее крен и больше риск опрокидывания."},
 },
 torque={
  ["en"]={"How hard the engine pushes. Higher: faster acceleration and steeper hills, but more wheelspin.","It does not raise the top speed by itself: that comes from the engine speed and the gears."},
  ["zh-Hans"]={"扭矩越高：加速和爬坡越有力，但车轮也更容易空转。","极速还取决于最高转速与传动比，单独增加扭矩不会直接提高极速。"},
  ["zh-Hant"]={"扭矩越高：加速和爬坡越有力，但車輪也更容易空轉。","極速還取決於最高轉速與傳動比，單獨增加扭矩不會直接提高極速。"},
  ["ru"]={"Больше момент: лучше разгон и подъём, но больше пробуксовки.","Максимальная скорость зависит также от оборотов и передаточных чисел."},
 },
 rpm={
  ["en"]={"How fast the engine may spin before it stops pulling. Higher: a higher top speed in every gear,","as long as the engine torque is enough to get there."},
  ["zh-Hans"]={"提高最高转速，可以提高各挡位允许达到的最高速度。","引擎仍需要足够扭矩，才能实际达到该速度。"},
  ["zh-Hant"]={"提高最高轉速，可以提高各擋位允許達到的最高速度。","引擎仍需要足夠扭矩，才能實際達到該速度。"},
  ["ru"]={"Больше максимальные обороты: выше возможная скорость на каждой передаче.","Для её достижения двигателю нужен достаточный крутящий момент."},
 },
 gear={
  ["en"]={"How much this gear multiplies the engine. Higher: stronger pull, but it tops out sooner.","Lower: faster in this gear, weaker on hills and from a stop."},
  ["zh-Hans"]={"传动比越高：牵引力越强，但该挡位的最高速度越低。","传动比越低：允许速度更高，但起步和爬坡更无力。"},
  ["zh-Hant"]={"傳動比越高：牽引力越強，但該擋位的最高速度越低。","傳動比越低：允許速度更高，但起步和爬坡更無力。"},
  ["ru"]={"Больше передаточное число: сильнее тяга, но ниже скорость на передаче.","Меньше: выше скорость, но слабее разгон и подъём."},
 },
 brake={
  ["en"]={"Higher: stops in a shorter distance. Too high locks the wheels, and it skids instead of stopping.","0: these wheels do not brake at all."},
  ["zh-Hans"]={"制动力越高，制动距离通常越短；过高会抱死车轮，导致滑行。","设为零表示这组车轮不提供制动力。"},
  ["zh-Hant"]={"煞車力越高，煞車距離通常越短；過高會鎖死車輪，導致滑行。","設為零表示這組車輪不提供煞車力。"},
  ["ru"]={"Больше тормозное усилие: короче путь; избыток блокирует колёса и вызывает скольжение.","Ноль означает отсутствие тормозного усилия у этих колёс."},
 },
 grip={
  ["en"]={"How well the tyres hold the ground. Higher: sharper turns, less sliding and wheelspin.","Front grip lower than the rear: it turns wide. Rear lower than the front: the back slides out."},
  ["zh-Hans"]={"抓地越强：转向更直接，侧滑和空转更少。","前轮抓地弱于后轮时容易推头；后轮弱于前轮时更容易甩尾。"},
  ["zh-Hant"]={"抓地越強：轉向更直接，側滑和空轉更少。","前輪抓地弱於後輪時容易推頭；後輪弱於前輪時更容易甩尾。"},
  ["ru"]={"Больше сцепление: точнее повороты, меньше скольжения и пробуксовки.","Слабее передние: снос наружу. Слабее задние: занос кормы."},
 },
 radius={
  ["en"]={"Bigger wheels: a higher top speed and more room under the body, but a weaker pull.","Smaller: quicker to speed up, slower at the top, and it scrapes over rocks."},
  ["zh-Hans"]={"轮胎越大：允许速度和离地间隙更高，但牵引力更弱。","轮胎越小：加速更快，极速更低，也更容易在岩石上托底。"},
  ["zh-Hant"]={"輪胎越大：允許速度和離地間隙更高，但牽引力更弱。","輪胎越小：加速更快，極速更低，也更容易在岩石上觸底。"},
  ["ru"]={"Больше колёса: выше возможная скорость и клиренс, но слабее тяга.","Меньше: быстрее разгон, ниже скорость и легче задеть камни днищем."},
 },
 spring={
  ["en"]={"Higher: a stiffer ride, less lean in turns, bumps kick harder.","Lower: a softer ride, the body leans in turns and sags."},
  ["zh-Hans"]={"弹簧越硬：转弯时车身侧倾越小，但颠簸冲击更强。","弹簧越软：车身更容易侧倾，并在自重下下沉。"},
  ["zh-Hant"]={"彈簧越硬：轉彎時車身側傾越小，但顛簸衝擊更強。","彈簧越軟：車身更容易側傾，並在自重下下沉。"},
  ["ru"]={"Жёстче пружины: меньше крен, но сильнее удары от неровностей.","Мягче: больше крен и проседание под весом машины."},
 },
 damping={
  ["en"]={"How fast the springs settle after a bump. Higher: settles at once, a firmer ride.","Lower: keeps bouncing after every bump."},
  ["zh-Hans"]={"阻尼越高：越快抑制颠簸后的弹簧振动，乘坐感更硬。","阻尼越低：颠簸后车身会持续弹跳更久。"},
  ["zh-Hant"]={"阻尼越高：越快抑制顛簸後的彈簧振動，乘坐感更硬。","阻尼越低：顛簸後車身會持續彈跳更久。"},
  ["ru"]={"Больше демпфирование: колебания быстрее затухают, ход жёстче.","Меньше: машина дольше продолжает раскачиваться."},
 },
 travel={
  ["en"]={"More: soaks up big bumps and keeps the wheels on the ground on rough terrain.","Less: bumps go straight into the body and it wobbles."},
  ["zh-Hans"]={"悬挂行程越大，越能吸收大幅颠簸，并让车轮在崎岖地面保持接触。","行程越小，路面冲击越容易直接传到车身。"},
  ["zh-Hant"]={"懸吊行程越大，越能吸收大幅顛簸，並讓車輪在崎嶇地面保持接觸。","行程越小，路面衝擊越容易直接傳到車身。"},
  ["ru"]={"Больше ход подвески: лучше поглощает неровности и удерживает колёса на земле.","Меньше ход: больше ударов передаётся прямо кузову."},
 },
 com_y={
  ["en"]={"Moves the centre of mass forward or backward; negative Y is the front.","Changes how weight is distributed between the front and rear wheels."},
  ["zh-Hans"]={"前后移动重心；Y 轴负方向是车头。","改变前后车轮承受的重量分配。"},
  ["zh-Hant"]={"前後移動重心；Y 軸負方向是車頭。","改變前後車輪承受的重量分配。"},
  ["ru"]={"Смещает центр масс вперёд или назад; отрицательная Y направлена к носу.","Меняет нагрузку на передние и задние колёса."},
 },
 com_x={
  ["en"]={"Moves the centre of mass sideways.","A larger offset gives the two sides unequal loading and can affect balance in turns."},
  ["zh-Hans"]={"左右移动重心。","偏移越大，两侧承重差异越大，可能影响转弯平衡。"},
  ["zh-Hant"]={"左右移動重心。","偏移越大，兩側承重差異越大，可能影響轉彎平衡。"},
  ["ru"]={"Смещает центр масс вбок.","Большое смещение неравномерно нагружает стороны и влияет на баланс."},
 },
}
function M.get(id,lang)
 id=id:gsub('^phys_',''):gsub('^front_',''):gsub('^rear_',''):gsub('^gear%d+$','gear')
 if id=='handbrake'then id='brake'end
 local tip=T[id];return tip and(tip[lang]or tip.en)
end
return M
