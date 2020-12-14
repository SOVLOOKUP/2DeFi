import strformat, strutils, times,json,os, streams, sequtils

import libp2p/daemon/daemonapi

import wNim ,chronos, nimcrypto
import winim/inc/windef
import wNim/private/winimx
import wHyperlink

import i18n

when not(compileOption("threads")):
  {.fatal: "Please, compile this program with the --threads:on option!".}

const
  ServerProtocols = @["/test-chat-stream"]

type
  CustomData = ref object
    api: DaemonAPI
    remotes: seq[StreamTransport]
    consoleFd: AsyncFD
    wfd: AsyncFD
    serveFut: Future[void]

type
  MenuID = enum
    idVertical, idHorizontal, idOpen, idExit,idenUS, idzhCN

let app = App()
let frame = Frame(title="2DeFi", size=(900, 600))

let win = Frame(frame, size=(400, 400))
let panel = Panel(win)

# panel.mForegroundColor = wWhite

let splitter = Splitter(frame, style = wSpHorizontal or wDoubleBuffered, size=(5, 5))
let statusBar = StatusBar(frame)
let menuBar = MenuBar(frame)

let console = TextCtrl(splitter.panel1, style= wTeRich or wTeMultiLine or wTeDontWrap or wVScroll or wTeReadOnly)
console.font = Font(12, faceName="Consolas", encoding=wFontEncodingCp1252)

var (rfd, wfd) = createAsyncPipe()
var writePipe = fromPipe(wfd)


let command = TextCtrl(splitter.panel2, style= wBorderSunken)
command.font = Font(12, faceName="Consolas", encoding=wFontEncodingCp1252)

var consoleString = ""

command.wEvent_TextEnter do (): 
    var line = command.getValue()
    let res = waitFor writePipe.write(line & "\r\n")
    consoleString = line & "\r\n"
    console.add consoleString
    command.clear


proc aliasDialog(owner: wWindow): string =
  var alias = ""

  let dialog = Frame(owner=owner, size=(320, 200), style=wCaption or wSystemMenu)
  let panel = Panel(dialog)

  let statictext = StaticText(panel, label= T"Please enter the alias:", pos=(10, 10))
  let textctrl = TextCtrl(panel, pos=(20, 50), size=(270, 30), style=wBorderSunken)
  let buttonOk = Button(panel, label= T"OK", size=(90, 30), pos=(100, 120))
  let buttonCancel = Button(panel, label= T"Cancel", size=(90, 30), pos=(200, 120))

  buttonOk.setDefault()

  dialog.wIdDelete do ():
    textctrl.clear()

  dialog.wEvent_Close do ():
    dialog.endModal()

  buttonOk.wEvent_Button do ():
    alias = textctrl.value
    dialog.close()

  buttonCancel.wEvent_Button do ():
    dialog.close()
    quit()

  dialog.shortcut(wAccelNormal, wKey_Esc) do ():
    buttonCancel.click()

  dialog.center()
  dialog.showModal()
  dialog.delete()

  result = alias


template dhtFindPeer() {.dirty.} =
    var peerId = PeerID.init(parts[1]).value
    consoleString = T"Searching for peer " & peerId.pretty() & "\r\n"
    console.add consoleString

    var id = await udata.api.dhtFindPeer(peerId)
    consoleString = T"Peer " & parts[1] & "found at addresses: " & "\r\n"
    console.add consoleString

    for item in id.addresses:
      consoleString = $item & "\r\n"
      console.add consoleString

proc serveThread(udata: CustomData) {.async.} =
 {.gcsafe.}:
  var transp = fromPipe(udata.consoleFd)

  proc remoteReader(transp: StreamTransport) {.async.} =
    {.gcsafe.}:
      while true:
        var line = await transp.readLine()
        if len(line) == 0:
          break
        consoleString = ">> " & line
        console.add consoleString

  while true:
    try:
      var line = await transp.readLine()
      if line.startsWith("/connect"):
        var parts = line.split(" ")
        if len(parts) == 2:
          dhtFindPeer()

          var address = MultiAddress.init(multiCodec("p2p-circuit")).value
          address = MultiAddress.init(multiCodec("p2p"), peerId).value
          consoleString = T"Connecting to peer " & $address & "\r\n"
          console.add consoleString
          echo consoleString

          await udata.api.connect(peerId, @[address], 30)
          consoleString = T"Opening stream to peer chat " & parts[1] & "\r\n"
          console.add consoleString
          echo consoleString

          var stream = await udata.api.openStream(peerId, ServerProtocols)
          udata.remotes.add(stream.transp)
          consoleString = T"Connected to peer chat " & parts[1] & "\r\n"
          console.add consoleString
          echo consoleString

          asyncCheck remoteReader(stream.transp)
      elif line.startsWith("/search"):
        var parts = line.split(" ")
        if len(parts) == 2:
          dhtFindPeer()

      elif line.startsWith("/consearch"):
        var parts = line.split(" ")
        if len(parts) == 2:
          var peerId = PeerID.init(parts[1]).value
          consoleString = &"Searching for peers connected to peer {parts[1]}\r\n"
          console.add consoleString
          var peers = await udata.api.dhtFindPeersConnectedToPeer(peerId) 
          consoleString = &"{len(peers)} connected to peer {parts[1]}\r\n"
          console.add consoleString
          for item in peers:
            var peer = item.peer
            var addresses = newSeq[string]()
            var relay = false
            for a in item.addresses:
              addresses.add($a)
              if a.protoName().value == "/p2p-circuit":
                relay = true
                break
            if relay:
              consoleString = &"""{peer.pretty()} * [{addresses.join(", ")}]"""
              console.add consoleString
            else:
              consoleString = &"""{peer.pretty()} [{addresses.join(", ")}]"""
              console.add consoleString
      elif line.startsWith("/get"):
        var parts = line.split(" ")
        if len(parts) == 2:
          var dag = parts[1]
          var value = await udata.api.dhtGetValue dag
          echo value
      elif line.startsWith("/exit"):
        break
      
      else:
        var msg = line & "\r\n"
        consoleString = "<< " & line
        var pending = newSeq[Future[int]]()
        for item in udata.remotes:
          pending.add(item.write(msg))
        if len(pending) > 0:
          var results = await all(pending)
    except:
      consoleString = getCurrentException().msg

var data = new CustomData

proc p2pdaemon() {.thread.} =
 {.gcsafe.}:
  data.remotes = newSeq[StreamTransport]()

  if rfd == asyncInvalidPipe or wfd == asyncInvalidPipe:
      raise newException(ValueError, T"Could not initialize pipe!")

  data.consoleFd = rfd

  data.serveFut = serveThread(data)

  consoleString = T"Starting P2P node" & "\r\n"
  console.add consoleString

  var alias = config["alias"].getStr
  if alias == "":
    alias = aliasDialog(frame)
    if alias != "":
      MessageDialog(frame, alias, "node alias:", wOk or wIconInformation).display()
      config["alias"] = %alias


  data.api = waitFor newDaemonApi({DHTFull, Bootstrap, PSGossipSub}, id="")
  var id = waitFor data.api.identity()
  config["id"] = % id.peer.pretty()
  writeFile("config.json", $config)
  proc streamHandler(api: DaemonAPI, stream: P2PStream) {.async.} =
      {.gcsafe.}:
          consoleString = "Peer " & stream.peer.pretty() & " joined chat\r\n"
          console.add consoleString
          data.remotes.add(stream.transp)
          while true:
              var line = await stream.transp.readLine()
              if len(line) == 0:
                  break
              consoleString = ">> " & line & "\r\n"
              console.add consoleString

  waitFor data.api.addHandler(ServerProtocols, streamHandler)
  var peers = waitFor data.api.listPeers()
  consoleString = $peers.len & T"nodes connected" & "\r\n"
  console.add consoleString

  for p in peers:
    consoleString = p.peer.pretty()
    console.add consoleString

  consoleString = T"Alias:" & alias & "\r\n" 
  console.add consoleString
  consoleString = T"ID:" & &"{id.peer.pretty()}\r\n"
  console.add consoleString

  waitFor data.serveFut

var p2pThread: Thread[void]
p2pThread.createThread p2pdaemon

proc switchSplitter(mode: int) =
  splitter.splitMode = mode
  statusBar.refresh()
  let size = frame.clientSize
  splitter.move(size.width div 2, size.height div 2)

let menuFile = Menu(menuBar, T"File")
menuFile.append(idOpen, T"Open", "Open a file")
menuFile.appendSeparator()
menuFile.append(idExit, T"Exit", "Exit the program")

let menuLayout = Menu(menuBar, T"Layout")
menuLayout.appendRadioItem(idHorizontal, T"Horizontal").check()
menuLayout.appendRadioItem(idVertical, T"Vertical")

let menuLang = Menu(menuBar, T"Language")
if currentLanguage == "enUS":
  menuLang.appendRadioItem(idenUS, "enUS").check()
  menuLang.appendRadioItem(idzhCN, "zhCN")
else:
  menuLang.appendRadioItem(idenUS, "enUS")
  menuLang.appendRadioItem(idzhCN, "zhCN").check()

frame.wEvent_Menu do (event: wEvent):
  case event.id
  of idExit:
    frame.close()

  of idVertical:
    if not splitter.isVertical:
      switchSplitter(wSpVertical)

  of idHorizontal:
    if splitter.isVertical:
      switchSplitter(wSpHorizontal)

  of idOpen:  
    var files = FileDialog(frame, style=wFdOpen or wFdFileMustExist).display()
    if files.len != 0:
      var alias = config["alias"].getStr
      var (path,name,ext) = splitFile(files[0])
      var label = alias & "/" & name & ext
      consoleString = &"[{now()}]:[{alias}]: "& T"shared" 
      console.add consoleString
      var bestSize = console.getBestSize()
      echo "getBestSize: ", bestSize
      var insertionPoint = console.getInsertionPoint()
      echo "getInsertionPoint: ", insertionPoint

      let hyperlink = Hyperlink(frame, label=label, url=files[0], pos=(bestSize.width, insertionPoint))
      hyperlink.wEvent_OpenUrl do (event: wEvent):
        echo "open"  
        # ShellExecute(0, "open", hyperlink.mUrl, nil, nil, SW_SHOW)
      console.add "\r\n"
      # panel.autolayout """
      # H:|-[console]-[hyperlink]-|
      # """
  of idenUS:
    if currentLanguage != "enUS":
      setCurrentLanguage "enUS"
  of idzhCN:
    if currentLanguage != "zhCN":
      setCurrentLanguage "zhCN"

  else:
    discard

splitter.panel1.wEvent_Size do ():
  splitter.panel1.autolayout "HV:|[console]|"

splitter.panel2.wEvent_Size do ():
  splitter.panel2.autolayout "HV:|[command]|"

switchSplitter(wSpHorizontal)
frame.center()
frame.show()

app.mainLoop()