import languages
import tables, strutils,os,json

var config* = when fileExists("config.json"): parseFile("config.json") else: %* {"alias":"","id":"","language":"zhCN"}

var currentLanguage* = config["language"].getStr

proc setCurrentLanguage*(newLanguage: string) =
  currentLanguage = newLanguage
  config["language"] = %newLanguage
  writeFile("config.json", $config)

proc getCurrentLanguage*(): string = currentLanguage
type Translation* = Table[string, string]


var translations: Table[string, Translation] = initTable[string, Translation]()

proc registerTranslation*(lang: string; t: Translation) = translations[lang] = t

proc addT*(lang: string; key, val: string) =
  if translations.hasKey lang:
      translations[lang][key] = val
  else: 
    translations[lang] = initTable[string,string]()

proc T*(x: string): string =  
  let y = translations[currentLanguage]
  if y.hasKey(x):
    result = y[x]
  else:
    result = x

proc raiseInvalidFormat(errmsg: string) =
  raise newException(ValueError, errmsg)

proc parseChoice(f: string; i, choice: int, r: var seq[char]) =
  var i = i
  while i < f.len:
    var n = 0
    let oldI = i
    var toAdd = false
    while i < f.len and f[i] >= '0' and f[i] <= '9':
      n = n * 10 + ord(f[i]) - ord('0')
      inc i
    if oldI != i:
      if f[i] == ':':
        inc i
      else:
        raiseInvalidFormat"':' after number expected"
      toAdd = choice == n
    else:
      # an else section does not start with a number:
      toAdd = true
    while i < f.len and f[i] != ']' and f[i] != '|':
      if toAdd: r.add f[i]
      inc i
    if toAdd: break
    inc i

proc `%`*(formatString: string; args: openArray[string]): string =
  let f = string(formatString)
  var i = 0
  var num = 0
  var r = newSeq[char]()
  while i < f.len:
    if f[i] == '$' and i+1 < f.len:
      inc i
      case f[i]
      of '#':
        r.add args[num]
        inc i
        inc num
      of '1'..'9', '-':
        var j = 0
        var negative = f[i] == '-'
        if negative: inc i
        while f[i] >= '0' and f[i] <= '9':
          j = j * 10 + ord(f[i]) - ord('0')
          inc i
        let idx = if not negative: j-1 else: args.len-j
        r.add args[idx]
      of '$':
        inc(i)
        r.add '$'
      of '[':
        let start = i+1
        while i < f.len and f[i] != ']': inc i
        inc i
        if i >= f.len: raiseInvalidFormat"']' expected"
        case f[i]
        of '#':
          parseChoice(f, start, parseInt args[num], r)
          inc i
          inc num
        of '1'..'9', '-':
          var j = 0
          var negative = f[i] == '-'
          if negative: inc i
          while f[i] >= '0' and f[i] <= '9':
            j = j * 10 + ord(f[i]) - ord('0')
            inc i
          let idx = if not negative: j-1 else: args.len-j
          parseChoice(f, start, parseInt args[idx], r)
        else: raiseInvalidFormat"argument index expected after ']'"
      else:
        raiseInvalidFormat("'#', '$', or number expected")
      if i < f.len and f[i] == '$': inc i
    else:
      r.add f[i]
      inc i
  result = join(r)

addT("enUS", "Please enter the alias: ", "Please enter the alias: ")
addT("enUS", "Starting P2P node", "Starting P2P node")
addT("enUS", "OK", "OK")
addT("enUS", "Cancel", "Cancel")
addT("enUS", "File", "File")
addT("enUS", "Open", "Open")
addT("enUS", "Exit", "Exit")
addT("enUS", "Layout", "Layout")
addT("enUS", "Horizontal", "Horizontal")
addT("enUS", "Vertical", "Vertical")
addT("enUS", "Language", "Language")
addT("enUS", "nodes connected", "nodes connected")
addT("enUS", "shared", "shared")
addT("enUS", "Alias: ", "Alias: ")
addT("enUS", "Searching for peer ", "Searching for peer ")
addT("enUS", "Connecting to peer ", "Connecting to peer ")



addT("zhCN", "Please enter the alias: ", "请输入节点昵称: ")
addT("zhCN", "Starting P2P node", "启动点对点节点")
addT("zhCN", "OK", "确认")
addT("zhCN", "Cancel", "取消")
addT("zhCN", "File", "文件")
addT("zhCN", "Open", "打开")
addT("zhCN", "Exit", "退出")
addT("zhCN", "Layout", "布局")
addT("zhCN", "Horizontal", "水平")
addT("zhCN", "Vertical", "垂直")
addT("zhCN", "Language", "语言")
addT("zhCN", "nodes connected", "个节点已连接")
addT("zhCN", "shared", "分享了")
addT("zhCN", "Alias: ", "昵称: ")
addT("zhCN", "Searching for peer ", "搜索节点")
addT("zhCN", "Connecting to peer ", "连接节点")

