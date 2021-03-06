{$, View, EditorView} = require 'atom'

fs        = require 'fs-plus'
path      = require 'path'
_         = require "underscore"
_.mixin require('underscore.string').exports()

rootDrives = null
winDrives  = 'cdefghijklmnopqrstuvwxyz'

filePickerCSS = """
  .vtlf-file-picker {position:absolute; margin:0; -webkit-user-select:none}
    .btn-group.left {width: 50px; margin-left: 5px}
      .btn-group .btn.left {width: 80%; tabindex:7}
    .btn-group.right {width: 120px; margin-left: 8px}
      .btn-group .btn.right {width: 45%}
    .vtlf-container {display: -webkit-flex; -webkit-flex-direction: row;}  	
      .vtlf-container .editor-container {position: relative; -webkit-flex: 1}
        .vtlf-container .editor {width: 100%}
        .vtlf-cover {position:absolute; width:100%; height:100%; background-color:red; opacity:0.2}
      .vtlf-container .column-vertical {position:relative; top:-10px;
          margin-left:3px; margin-right:15px}
        .vtlf-container .column {
            background-color:rgba(128, 128, 128, 0.2); position:relative;
            width:180px; overflow:auto;}
          .vtlf-container .column-inner {width:160px; position:relative;}
          .vtlf-container .column-inner .list-group {
            font-size:14px; margin-left:8px; }
            
  .vtlf-file-picker .focused {border:2px solid gray}
"""

module.exports =
class FilePickerView extends View
  
  @content: ->
    @div class:'vtlf-file-picker vtlf-form overlay from-top', tabindex:"-1", =>
           
      @style filePickerCSS
           
      @div class: 'block', =>
        @span class: 'description', 'View-Tail-Large-Files: Open Any File'

      @div class: "file-path vtlf-container block", =>
        
        @div class: 'btn-group-vtlf btn-group left', =>
          @button outlet: 'bsButton', \
                   class: 'inline-block btn left', 'Up'
                     
        @div class: "editor-container", =>
          @subview "pathEditor", new EditorView
            mini: true, placeholderText: "Absolute path to file"
            
        @div class: 'btn-group-vtlf btn-group right', =>
          @button outlet: 'openButton', \
                   class: 'inline-block btn right', 'Open'
          @button outlet: 'cancelButton', \
                   class: 'inline-block btn right', 'Cancel'
                     
      @div class:"file-picker-bottom vtlf-container block", =>
        
        @div class:"column-vertical inline-block", =>
          @span class: 'description', 'Directories  (Ctrl-Enter for Parent)'
          @div outlet: 'dirs', class: 'column focusable focused', =>
            @div class: 'column-inner', =>
              @ul outlet: 'dirsUl', class: 'list-group dirs', =>
                # @li class: 'list-item highlight', 'Normal item'       
                         
        @div class:"column-vertical inline-block", =>
          @span class: 'description', 'Files'
          @div outlet: 'files', class: 'column focusable', =>
            @div class: 'column-inner', =>
              @ul outlet: 'filesUl', class: 'list-group files', =>
                  
        @div class:"column-vertical inline-block", =>
          @span class: 'description', 'Recent Files'
          @div outlet: 'recent', class: 'column focusable', =>
            @div class: 'column-inner', =>
              @ul outlet: 'recentUl', class: 'list-group recent', =>
                           
  @getViewFromDOM: -> 
    if ($picker = atom.workspaceView.find '.vtlf-file-picker').length > 0
      $picker.view()
      
  initialize: (@state, @filePicker) ->
    # for x of @state then delete @state[x]
    # console.log 'initial state', @state
    
    wsv   = atom.workspaceView
    ww    = wsv.width();     wh     = wsv.height()
    width = 600;             height = Math.max 200, wh - 170
    left  = (ww - width)/2;  top    = 80
    $col  = @find '.column'
    @css {left, top, width, height}
    $col.height height - 100
    wsv.append @
    
    @$editor     = @find '.editor.mini'
    @$focusable  = @find '.focusable'
    
    @handleEvents()
    
    @state.inputText    ?= ''
    @state.prevSelDirs  ?= {}
    @state.prevSelFiles ?= {}
    @state.recentSel    ?= []
    
    @colFocused   = 'dirs'
    @recentSelIdx = 0
    
    @focusCol @colFocused
    
    if process.platform isnt 'win32'
      rootDrives = ['/']
    else
      if not rootDrives
        rootDrives = []
        for driveLetter in winDrives
          drive = driveLetter + ':\\'
          if fs.isDirectorySync drive
            rootDrives.push drive
      rootDrives[0]  ?= 'c:\\'
            
    @pathEditor.setText @state.inputText
    @setAllFromPath()
    
    setTimeout (=> @focus()), 100	          
      
  setLIs: ($ul, list) ->
    $ul.empty()
    for str in list
      $('<li/>').text(str).appendTo $ul

  showTempPath: (tempPath = '') ->
    @stashedPath ?= @pathEditor.getText()
    @pathEditor.setText tempPath
    @dirsUl.empty()
    @filesUl.empty()
    
  setAllFromPath: ->
    # console.log 'setAllFromPath enter @dir',  @dir
    oldDir = @dir
    
    if @stashedPath then @pathEditor.setText @stashedPath; @stashedPath = null
    @state.inputText = @pathEditor.getText()
    
    if /^\.+$/.test @state.inputText
      @pathEditor     .setText (@state.inputText = '')

    curPath = _.trim @state.inputText
    if process.platform is 'win32' 
      curPath = curPath.toLowerCase()
      curPath.replace /\//g, '\\'
    else 
      curPath = curPath.replace /\\/g, '/'
      
    @dir  = ''
    dirs  = []
    files = []
    
    if curPath is '' 
      @dir = ''
      dirs = rootDrives
    else
      if fs.isFileSync curPath then @dir= path.dirname curPath
      else if fs.isDirectorySync curPath then @dir = curPath
      else
        lastPath = null
        parentPath = curPath
        while parentPath isnt lastPath and not fs.isDirectorySync parentPath
          lastPath = parentPath
          parentPath = path.normalize parentPath + '/..'
        @dir = parentPath
        
    if not (hasPath = /\\|\//.test @dir)
      @dir = ''
      dirs = rootDrives
    else
      for dirOrFile in fs.listSync @dir
        basename = path.basename dirOrFile
        if fs.isDirectorySync dirOrFile then dirs.push basename else files.push basename
        
    # if @dir isnt oldDir then @focusCol 'dirs'
    
    $under = @.find '.highlights.underlayer'
    if not ($vtlfCover = $under.next()).hasClass 'vtlf-cover'
      $under.after ($vtlfCover = $ '<div class="vtlf-cover"/>')
        
    if hasPath and (fs.isFileSync(curPath) or fs.isDirectorySync(curPath))
      $vtlfCover.hide()
    else
      $editorText = @.find 'span.text'
      if @dir
        $editorText.after ($textClone = $editorText.clone().css(visibility:'none').text @dir)
        dirWidth = $textClone.width()
        $textClone.remove()
      else 
        dirWidth = 0
      editWid = (if curPath then $editorText.width() else 0)
      $vtlfCover.css display:'block', left: dirWidth, width: editWid - dirWidth
    
    @setLIs @dirsUl,  dirs
    if not((dir = @state.prevSelDirs[@dir.length]) and @setHighlight @dirsUl, dir)
      @setHighlight @dirsUl, 0
      
    @setLIs @filesUl, files
    if not((file = @state.prevSelFiles[@dir.length]) and @setHighlight @filesUl, file)
      @setHighlight @filesUl, 0
      
    @setLIs @recentUl, _.map @state.recentSel, (file) -> path.basename file	   
    @setHighlight @recentUl, @recentSelIdx
      
    # @$editor.focus()
    
  setPath: (path) ->
    # console.log 'setPath', path
    @pathEditor.setText path
    @setAllFromPath()
    
  goToParent: ->
    @focusCol 'dirs'
    if @dir.length is 0 then return
    if @state.inputText.length <= @dir.length  
      oldDir = @dir
      @dir = path.normalize @dir + '/..'
      if @dir is oldDir then @dir = ''
      # console.log 'goToParent @dir',  @dir
    @setPath @dir
    
  openDir: (dir) -> 
    @setPath (if /^[c-z]:\\$/.test dir then dir else path.join @dir, dir)
    @focusCol 'dirs'	 
    
  colClick: (e) ->
    if ($tgt = $(e.target).closest 'li').length is 0 
      $ul = $(e.currentTarget).find 'ul'
      if $ul.hasClass 'dirs'   then @focusCol 'dirs'
      if $ul.hasClass 'files'  then @focusCol 'files'
      if $ul.hasClass 'recent' then @focusCol 'recent'
    else
      $ul = $tgt.closest 'ul'
      switch
        when $ul.hasClass 'dirs'   then @openDir  $tgt.text()
        when $ul.hasClass 'files'  then @openFile $tgt.text()
        when $ul.hasClass 'recent'
          tgtIdx = $tgt.index()
          if @colFocused is 'recent' and $tgt.hasClass 'highlight'
            @openFile @state.recentSel[tgtIdx], yes
          else
            @focusCol 'recent'
            @showTempPath @state.recentSel[tgtIdx]
            @setHighlight $ul, tgtIdx
            
  liMetrics: ($li) ->
    $inner      = $li.closest '.column-inner'
    $outer      = $inner.parent()
    outerHeight = $outer.height()
    scrollTop   = $outer.scrollTop()
    scrollBot   = scrollTop + outerHeight - 15
    liTop       = $li.position().top
    liBot       = liTop + $li.height()
    {$inner, $outer, outerHeight, liTop, liBot, scrollTop, scrollBot}

  ensureLiVisible: ($li) ->
    {$outer, outerHeight, liTop, liBot, scrollTop, scrollBot} = @liMetrics $li
    $outer.scrollTop scrollTop = switch
      when liTop < scrollTop then liTop	
      when liBot > scrollBot then 2 * liBot - liTop - outerHeight
      else scrollTop
  
  getUl: ->
    switch @colFocused
      when 'dirs'   then @dirsUl
      when 'files'  then @filesUl
      when 'recent' then @recentUl
      
  setHighlight: ($ul, name) ->
    if not $ul or name is '' or ($lis = $ul.children()).length is 0 then return false
    if typeof name is 'number'
      if ($matchedLi = $lis.eq name).length is 0 then return
    else
      $matchedLi = null
      $lis.each ->
        $li = $ @
        if name is $li.text()
          $matchedLi = $li
          return false
          
    if $matchedLi
      # console.log '$matchedLi', $matchedLi, $matchedLi.index()
      $lis.removeClass 'highlight'
      $matchedLi.addClass 'highlight'
      @ensureLiVisible $matchedLi
      name =  $matchedLi.text()
      if $ul.hasClass 'dirs'   then @state.prevSelDirs[ @dir.length] = name
      if $ul.hasClass 'files'  then @state.prevSelFiles[@dir.length] = name
      return true
    false
    
  moveHighlight: (code) ->
    if not ($ul = @getUl()) then focusCol 'dirs'; return
    $hilite = $ul.find '.highlight'
    if (hiliteIdx = $hilite.index()) is -1 then code = 'down'
    hiliteIdx += switch code
      when 'up'   then -1
      when 'down' then +1
      when 'pgup' 
        {outerHeight, liTop, liBot} = @liMetrics $hilite
        - Math.floor outerHeight / (liBot - liTop)
      when 'pgdown' 
        {outerHeight, liTop, liBot} = @liMetrics $hilite
        Math.floor outerHeight / (liBot - liTop)
    $lis = $ul.children()
    hiliteIdx = Math.max 0, Math.min hiliteIdx, $lis.length - 1
    if $ul.hasClass 'recent' then @showTempPath @state.recentSel[@recentSelIdx = hiliteIdx]
    @setHighlight $ul, hiliteIdx
    
  keypress: (e) ->
    if e.which in [9, 40, 38, 33, 34, 17, 13] then return
    if @colFocused is 'recent' then @focusCol 'dirs'
    @lastKeyAction ?= 0
    now = Date.now()
    if @keypressTO then clearTimeout @keypressTO; @keypressTO = null
    if e then @keypressTO = setTimeout (=> @keypress no), 260
    else if now > @lastKeyAction + 250 then @setAllFromPath()
    @lastKeyAction = now
    
  focusCol: (col) ->
    if col is @colFocused then return
    if @colFocused is 'recent' then @setAllFromPath()
    @$focusable.removeClass 'focused'   
    switch col
      when 'editor' then process.nextTick => @pathEditor.focus()
      when 'dirs'   then @dirs.addClass   'focused'
      when 'files'  then @files.addClass  'focused'
      when 'recent' 
        @recent.addClass 'focused'
        @showTempPath @state.recentSel[@recentSelIdx]
        @setHighlight @getUl(), @recentSelIdx
    if col isnt 'editor' 
      process.nextTick => @bsButton.focus()  # just to unfocus editor
    @colFocused = col
           
  focusNext: (fwd) -> 
    switch @colFocused
      when 'editor' then (if fwd then @focusCol('dirs')   else @focusCol('recent'))
      when 'dirs'   then (if fwd then @focusCol('files')  else @focusCol('editor'))
      when 'files'  then (if fwd then @focusCol('recent') else @focusCol('dirs'))
      when 'recent' then (if fwd then @focusCol('editor') else @focusCol('files'))
      
  openFile: (text, isFullPath) ->
    if isFullPath then file = text
    else	   
      if not @dir or not text then return
      file = path.join @dir, text
    file = if process.platform is 'win32' then file.replace /\//g, '\\'  \
                                          else file.replace /\\/g, '/'
    if not fs.existsSync file
      atom.confirm
        message: 'View-Tail-Large-Files Error:\n\n'
        detailedMessage: 'File ' + file + ' doesn\'t exist.'
        buttons: ['Close']
      return
    @destroy()
    @filePicker.fileSelected file

  confirm: (e) ->
    if ($ul = @getUl()) 
      if ($hi = $ul.find '.highlight').length is 0 then return
      text = $hi.text() 
    switch @colFocused
      when 'editor' 
        file = @pathEditor.getText()
        if fs.existsSync file then @openFile file, yes
      when 'dirs'   then @openDir  text
      when 'files'  then @openFile text
      when 'recent' then @openFile @state.recentSel[@recentSelIdx], yes
    e.preventDefault()
    e.stopImmediatePropagation()
    
  openFromButton: ->    
    if @colFocused is 'recent'
      @openFile @state.recentSel[@recentSelIdx], yes          
    else if ($tgt = @filesUl.find '.highlight').length > 0
      @openFile $tgt.text()
    
  handleEvents: ->
    @subscribe atom.workspaceView, 'core:cancel core:close',  => @destroy()
    @subscribe atom.workspaceView, 'core:confirm',        (e) => @confirm e
    @subscribe @, 'view-tail-large-files:focus-next',         => @focusNext yes
    @subscribe @, 'view-tail-large-files:focus-previous',     => @focusNext no
    @subscribe @, 'view-tail-large-files:up',                 => @moveHighlight 'up'
    @subscribe @, 'view-tail-large-files:down',               => @moveHighlight 'down'
    @subscribe @, 'view-tail-large-files:pgup',               => @moveHighlight 'pgup'
    @subscribe @, 'view-tail-large-files:pgdown',             => @moveHighlight 'pgdown'
    @subscribe @, 'view-tail-large-files:parent',             => @goToParent()
    @subscribe @pathEditor,   'keydown',                  (e) => @keypress e
    @subscribe @pathEditor,   'click',                        => @focusCol 'editor'
    @subscribe @cancelButton, 'click',                        => @destroy()
    @subscribe @openButton,   'click',                        => @openFromButton()
    @subscribe @bsButton,     'click',                        => @goToParent()
    @subscribe @dirs,         'click',                    (e) => @colClick e
    @subscribe @files,        'click',                    (e) => @colClick e
    @subscribe @recent,       'click',                    (e) => @colClick e
    
  destroy: -> 
    @detach()
    @unsubscribe()
