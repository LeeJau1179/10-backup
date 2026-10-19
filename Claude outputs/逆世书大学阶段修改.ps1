# 逆世书大学阶段修改：Obsidian CLI 步骤（新建、改名、移动、删除）
# 用法：Obsidian 保持打开，在 PowerShell 里运行：
#   powershell -ExecutionPolicy Bypass -File "D:\Obsidian-S\Claude outputs\逆世书大学阶段修改.ps1"
$ErrorActionPreference = "Stop"
$ob = if ($env:COPILOT_OBSIDIAN_CLI) { $env:COPILOT_OBSIDIAN_CLI } else { "obsidian" }
$vaultDir = Split-Path $PSScriptRoot -Parent
$scenes = "StoryLine/逆世书/今生/Scenes"
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Ob { & $ob 'vault=Obsidian-S' @args; if ($LASTEXITCODE -ne 0) { throw "obsidian $args 失败" } }
function Full($rel) { Join-Path $vaultDir ($rel -replace '/', '\') }
function MustExist($rel) { if (-not (Test-Path -LiteralPath (Full $rel))) { throw "没有找到：$rel" } }

Write-Host "== 0. 检查 Obsidian CLI" -ForegroundColor Cyan
& $ob version; if ($LASTEXITCODE -ne 0) { throw "Obsidian CLI 不可用：请打开 Obsidian 并启用 设置→通用→命令行界面" }

Write-Host "== 1. 同步场景文件名前缀（act/sequence 已改好）" -ForegroundColor Cyan
Ob command 'id=storyline-prefix-sync:sync-now'
Read-Host "如果 Obsidian 弹出「将改名 N 个场景文件」，点确认；改名完成后按回车继续"
MustExist "$scenes/Act 2/03-135 军训·隐藏体能.md"

Write-Host "== 2. 地点：苏晚住处 → 林硕租处" -ForegroundColor Cyan
if (Test-Path -LiteralPath (Full "StoryLine/逆世书/今生/Archive/林硕租处.md")) { Ob delete 'path=StoryLine/逆世书/今生/Archive/林硕租处.md' }
Ob rename 'path=StoryLine/逆世书/今生/Codex/Locations/苏晚住处.md' 'name=林硕租处'
MustExist "StoryLine/逆世书/今生/Codex/Locations/林硕租处.md"

Write-Host "== 3. 归档 金色生日礼物·分身卡（发卡移到 生日礼物·唯一的金卡）" -ForegroundColor Cyan
$old = Get-ChildItem -LiteralPath (Full "$scenes/Act 2") -Filter "*金色生日礼物·分身卡.md" | Select-Object -First 1
if ($old) {
  Ob move "path=$scenes/Act 2/$($old.Name)" "to=StoryLine/逆世书/今生/Archive/$($old.Name)"
  MustExist "StoryLine/逆世书/今生/Archive/$($old.Name)"
}
if (Test-Path -LiteralPath (Full "StoryLine/逆世书/今生/SceneNotes/金色生日礼物·分身卡 - Notes.md")) { Ob delete 'path=StoryLine/逆世书/今生/SceneNotes/金色生日礼物·分身卡 - Notes.md' }

Write-Host "== 4. 第三卷场景移入 Act 3 文件夹" -ForegroundColor Cyan
Get-ChildItem -LiteralPath (Full "$scenes/Act 2") -Filter "03-*.md" | ForEach-Object {
  Ob move "path=$scenes/Act 2/$($_.Name)" "to=$scenes/Act 3/$($_.Name)"
  MustExist "$scenes/Act 3/$($_.Name)"
}

Write-Host "== 5. 新建 idea 场景与场景笔记" -ForegroundColor Cyan
function NewNote($rel, $content) {
  if (Test-Path -LiteralPath (Full $rel)) { Write-Host "已存在，跳过：$rel"; return }
  Ob create "path=$rel" 'content=（新建）'
  MustExist $rel
  [System.IO.File]::WriteAllText((Full $rel), $content, $utf8)
}

NewNote 'StoryLine/逆世书/今生/Scenes/Act 2/02-101 包裹到了·第一次用自己的电脑.md' @'
---
type: scene
title: 包裹到了·第一次用自己的电脑
aliases:
  - 包裹到了·第一次用自己的电脑
act: 2
sequence: 101
storyDate: ""
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[许默]]"
location: "[[林硕租处]]"
status: idea
synopsis: 笔记本实物卡用后，系统安排的包裹寄到；主角第一次用自己的电脑完成一项具体的学习或摄影后期任务
conflict: 东西到手容易，用它把活干好得靠自己
tags:
  - 主-系统
  - 主-事业
setup_scenes:
  - "[[苏然突袭·落脚点危机]]"
payoff_scenes:
  - "[[两种生活·主动安排]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/包裹到了·第一次用自己的电脑 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/包裹到了·第一次用自己的电脑 - Notes.md' @'
## 节拍

- 系统安排的包裹寄到，里面是一台笔记本电脑。
- 主角用它完成一项具体的学习或摄影后期任务。（重点）

## 边界

- 电脑的资金经系统既有通道，[[林北川]]此时不知道收款人是谁；主角也不知道资助者。
- 电脑只改善条件，不替代技能和劳动。
- 成就名、收件地址与设备型号待定；按2005年的笔记本写，不写现代硬件。（待审）

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 2/02-104 人物试片·第一次交出一组照片.md' @'
---
type: scene
title: 人物试片·第一次交出一组照片
aliases:
  - 人物试片·第一次交出一组照片
act: 2
sequence: 104
storyDate: ""
chapter: ""
pov: "[[许默]]"
characters:
  - "[[许默]]"
location: ""
status: idea
synopsis: 主角自己找到普通的拍摄对象，沟通、完成第一组人物照委托，系统追认摄影技能卡；取得后主动使用，再拿试拍对照看到改变
conflict: 拍活动靠抓时机，拍人得先开口跟人商量
tags:
  - 主-事业
  - 主-系统
setup_scenes:
  - "[[真实工作·摄影试做]]"
  - "[[两种生活·主动安排]]"
payoff_scenes:
  - "[[摄影社返工·宣传页采用]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/人物试片·第一次交出一组照片 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/人物试片·第一次交出一组照片 - Notes.md' @'
## 节拍

- 主角自己找到一位普通的拍摄对象，沟通需求，完成第一组人物照委托。（重点）
- 系统追认，发摄影技能卡。
- 取得后主动使用，用试拍对照看到改变。

## 边界

- 首次活动摄影已靠原有能力完成，技能卡在本场才取得。
- 技能不代替经验、沟通和选片判断。
- 拍摄对象是普通人，与[[林北川]]无关。

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 2/02-128 生日礼物·唯一的金卡.md' @'
---
type: scene
title: 生日礼物·唯一的金卡
aliases:
  - 生日礼物·唯一的金卡
act: 2
sequence: 128
storyDate: 2006-05-15
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[一伶]]"
location: "[[沪州大学·校内]]"
status: idea
synopsis: 大一生日当晚，系统第一次以生日礼物的名义发下唯一一张金卡，还多了一句祝福；苏晚记下这个异常，收起卡没用
conflict: 系统从不多说一句，这回多说了
tags:
  - 主-系统
  - 支-一伶
setup_scenes:
  - "[[生日未提·床上的礼物]]"
payoff_scenes:
  - "[[两个家庭的邀请·使用分身卡]]"
  - "[[两份毕业答案]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/生日礼物·唯一的金卡 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/生日礼物·唯一的金卡 - Notes.md' @'
## 节拍

- 晚上回宿舍、上楼前，界面第一次亮起金色。（重点）
- 系统播报生日礼物，另有一句单独的祝福。
- 她看过卡背，收起来，不用。
- 收束回到当天的礼物：[[顾盼]]的小镜子、[[林硕]]的项链和这张卡。

## 边界

- 播报格式见[[本一卷二·系统任务设定#第二阶段开启与播报格式]]，不套成就追认。
- 卡背三项分列成三角，正文不解释数字。
- 她不追问系统，不新增任务。
- 分身卡的效果和时限见[[本一卷二·系统任务设定]]与[[本一·穿越与分身设定]]，本场不展示机制。
- 系统送礼不等于向主角揭示妹妹的身份。

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-134 军训前·又要领一套衣服.md' @'
---
type: scene
title: 军训前·又要领一套衣服
aliases:
  - 军训前·又要领一套衣服
act: 3
sequence: 134
storyDate: 2006-08-27
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[孟夏]]"
  - "[[顾盼]]"
  - "[[王倩]]"
location: "[[沪州大学·宿舍]]"
status: idea
synopsis: 大二返校，宿舍四人领军训服，裤腰裤长又不合身，四个人凑在一起解决
conflict: 同一套麻烦，这回是四个熟人一起对付
tags:
  - 主-感情
  - 支-室友
setup_scenes:
  - "[[开学前夜·屋里的东西]]"
payoff_scenes:
  - "[[军训·隐藏体能]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/军训前·又要领一套衣服 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/军训前·又要领一套衣服 - Notes.md' @'
## 节拍

- 大二返校，四人领军训服。
- 裤子腰围过大，换小一码裤腿又短，只能保留原码、用腰带收紧。（重点）
- 四人互相帮着改、试，聊暑假。

## 边界

- 四人已同住一年，不写初识，不重复开学自我介绍。

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-140 王蘅入学·提到那个姐姐.md' @'
---
type: scene
title: 王蘅入学·提到那个姐姐
aliases:
  - 王蘅入学·提到那个姐姐
act: 3
sequence: 140
storyDate: 2006-09-16
chapter: ""
pov: "[[苏珩]]"
characters:
  - "[[王蘅]]"
  - "[[苏珩]]"
location: "[[上沪大学·校内]]"
status: idea
synopsis: 王蘅进入上沪大学，在新环境的闲聊里提起卷一漫展上见过的苏晚；苏家由此得到一条可核实的线索
conflict: 一句闲话里的名字，对上了苏家找了七年的人
tags:
  - 主-亲情
  - 支-苏家
setup_scenes:
  - "[[公开舞台·苏晚开始走红]]"
payoff_scenes:
  - "[[赛后初谈·各自误会]]"
  - "[[初见核实·求助四哥]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/王蘅入学·提到那个姐姐 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/王蘅入学·提到那个姐姐 - Notes.md' @'
## 节拍

- [[王蘅]]入学，闲聊里提起在滨海漫展见过的[[苏晚]]。（重点）
- 消息里有能核实的姓名和滨海旧识的背景。

## 边界

- [[王蘅]]此前没往苏家想，入学后在新环境的自然聊天里提起这位旧识。
- 只凭一个常见名字不能确认亲缘，苏家只得到一条要核实的线索。
- 她向谁说、是否同场见到苏家兄弟待定。（待审）
- [[王蘅]]不知道双身份。

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-148 旧疤·终于打开的记忆.md' @'
---
type: scene
title: 旧疤·终于打开的记忆
aliases:
  - 旧疤·终于打开的记忆
act: 3
sequence: 148
storyDate: 2006-10-11
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[一伶]]"
location: ""
status: idea
synopsis: 大一就有的旧疤在苏家接触初期被触动，封存的记忆卡打开，她第一次面对一段不属于许默的童年
conflict: 疤是这具身体的，记忆却不是她的，她解释不了，也没人回答
tags:
  - 主-身份
  - 主-系统
  - 支-一伶
setup_scenes:
  - "[[更衣室·旧疤与记忆闪回]]"
payoff_scenes:
  - "[[视频之后·不属于自己的记忆]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/旧疤·终于打开的记忆 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/旧疤·终于打开的记忆 - Notes.md' @'
## 节拍

- 特定接触或物品触动旧疤，记忆卡触发。（重点）
- 闪回小时候被哥哥欺负、撞伤的画面。
- 她问系统，没有得到解释。

## 边界

- 闪回用小孩视角；童年的她不开口，哥哥只用动作欺负她。
- 不认出[[苏珩]]。
- 用卷二库存的记忆卡，不发新卡。
- 系统回应只用[[本一·系统设定#系统人格红线]]卷三起的格式。
- 触发物与可识别的信息范围待定。（待审）

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-165 苏母生日·隔着屏幕见一面.md' @'
---
type: scene
title: 苏母生日·隔着屏幕见一面
aliases:
  - 苏母生日·隔着屏幕见一面
act: 3
sequence: 165
storyDate: ""
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[沈如兰]]"
  - "[[苏珩]]"
  - "[[苏长青]]"
  - "[[孟夏]]"
location: "[[沪州大学·宿舍]]"
status: idea
synopsis: 沈如兰生日，苏珩替母亲请求视频，苏晚答应一次有限的见面；视频里沈如兰从她一抿唇认出了女儿，她仍不确定自己是谁
conflict: 对方只想隔着屏幕看看她，她却在屏幕前先露了底
tags:
  - 主-亲情
  - 主-身份
  - 支-苏家
setup_scenes:
  - "[[高端舞会·童年习惯露出]]"
payoff_scenes:
  - "[[公司探访·苏长青在等]]"
  - "[[商场远望·苏母一眼认出]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/苏母生日·隔着屏幕见一面 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/苏母生日·隔着屏幕见一面 - Notes.md' @'
## 节拍

- [[苏珩]]来电：今天是母亲生日，舞会照片传到她手里后，她只想隔着电脑看看这个女孩，不认亲。
- 她答应晚上视频，借[[孟夏]]的摄像头；[[苏长青]]扶[[沈如兰]]坐到电脑前。
- [[沈如兰]]说得平常，问吃住、冷暖。
- 她鼻子一酸，抿了一下唇，[[沈如兰]]认出了女儿。（重点）
- 视频结束。

## 边界

- 请求以[[沈如兰]]生日为由，不要求她叫妈妈，不问身世，不哭诉。
- 她不承认亲缘，也不恢复具体的童年画面。
- [[沈如兰]]的生日月日待定，定下后只写在[[沈如兰]]人物卡。（待审）

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-225 大三的普通周末.md' @'
---
type: scene
title: 大三的普通周末
aliases:
  - 大三的普通周末
act: 3
sequence: 225
storyDate: ""
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[周扬]]"
location: ""
status: idea
synopsis: 大三的一个普通周末，苏晚和周扬一起做一件两人都想做的事，也各有学习和工作；两人既投契，也开始需要商量时间
conflict: 两个人都忙，一个周末得两个人一起安排
tags:
  - 主-感情
  - 支-周扬
setup_scenes:
  - "[[试相处·她主动约他]]"
payoff_scenes:
  - "[[约好的事·一次谈成的分歧]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/大三的普通周末 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/大三的普通周末 - Notes.md' @'
## 节拍

- 两人一起做一件双方都主动投入的事。（重点）
- 各自的学习和工作挤进同一个周末，两人商量着排开。

## 边界

- 交往已稳定，在大三前中段。
- 活动待定，不预设重大事件。（待审）

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-226 约好的事·一次谈成的分歧.md' @'
---
type: scene
title: 约好的事·一次谈成的分歧
aliases:
  - 约好的事·一次谈成的分歧
act: 3
sequence: 226
storyDate: ""
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[周扬]]"
location: ""
status: idea
synopsis: 两人对一件安排有不同需要，这一次谈开并解决了；另一个关键问题仍然没谈
conflict: 他们能把一件事谈成，却还绕着最难的那件
tags:
  - 主-感情
  - 支-周扬
setup_scenes:
  - "[[约定落空·没有谈完的分歧]]"
  - "[[大三的普通周末]]"
payoff_scenes:
  - "[[家人邀约·被规划好的以后]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/约好的事·一次谈成的分歧 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/约好的事·一次谈成的分歧 - Notes.md' @'
## 节拍

- 两人对一件安排的需要不同。
- 这一次通过协商谈成。（重点）
- 另一个关键问题仍然没谈。

## 边界

- 在大三中段，晚于约定落空·没有谈完的分歧。
- 具体事件待定。（待审）

## 正文待改

'@

NewNote 'StoryLine/逆世书/今生/Scenes/Act 3/03-227 家里知道了·她还不知道.md' @'
---
type: scene
title: 家里知道了·她还不知道
aliases:
  - 家里知道了·她还不知道
act: 3
sequence: 227
storyDate: ""
chapter: ""
pov: "[[许默]]"
characters:
  - "[[苏晚]]"
  - "[[周扬]]"
location: ""
status: idea
synopsis: 周扬按自己的理解把交往告诉了家里，他认为家人不是外人，没意识到违反了两人的约定；苏晚还不知道
conflict: 他觉得是让关系名正言顺，她连这件事发生了都不知道
tags:
  - 主-感情
  - 支-周扬
setup_scenes:
  - "[[试相处·她主动约他]]"
payoff_scenes:
  - "[[家人邀约·被规划好的以后]]"
notesFile: StoryLine/逆世书/今生/SceneNotes/家里知道了·她还不知道 - Notes.md
wordcount: 0
charcount: 0
created: 2026-10-19
modified: 2026-10-19
---

'@

NewNote 'StoryLine/逆世书/今生/SceneNotes/家里知道了·她还不知道 - Notes.md' @'
## 节拍

- [[周扬]]把交往告诉了家里。（重点）
- [[苏晚]]此时不知道。

## 边界

- 在大三后段、家人邀约之前。
- 可以只通过[[苏晚]]后来发现的事实体现，不强制增加[[周扬]]视角。
- 家人没有恶意安排。

## 正文待改

'@


Write-Host "== 6. 核对文件名前缀（只看不改）" -ForegroundColor Cyan
Ob command 'id=storyline-prefix-sync:check'
Remove-Item -LiteralPath (Join-Path $PSScriptRoot "specs.tgz"), (Join-Path $PSScriptRoot "outline3.tmp") -ErrorAction SilentlyContinue
Write-Host "完成。请在 StoryLine 里打开今生，确认顺序；新建的 idea 场景已带好序号，无需再拖。" -ForegroundColor Green
