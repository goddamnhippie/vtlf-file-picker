{$, View, EditorView} = require 'atom'

filePickerCSS = """
  .btn-group.btn-group-vtlf {width: 120px}
    .btn-group.btn-group-vtlf .btn {width: 45%}
  .vtlf-container { display: -webkit-flex; -webkit-flex-direction: row; }
    .vtlf-container .btn-group { margin-left: 12px; }
    .vtlf-container .editor-container { position: relative; -webkit-flex: 1}
      .vtlf-container .editor { width: 100%; }
    .vtlf-container .file-picker-side {position:relative; top:-10px; 
        margin-right:15px}
      .vtlf-container .recent-picks {
          background-color:rgba(128, 128, 128, 0.2);
          margin:left:15px; width:280px; overflow:auto; border:solid 1px gray}
        .vtlf-container .recent-picks-inner {width:275px}
        .vtlf-container .recent-picks-inner .list-group {
          font-size:14px; margin-left:8px}
"""

module.exports =
class FilePickerView extends View
  
	@remove = -> 
    if ($picker = atom.workspaceView.find '.vtlf-file-picker').length > 0
      $picker.view().destroy()
      true
      
  @content: ->
    @div class:'vtlf-file-picker overlay from-top', \
         style: 'position:absolute; margin:0', tabindex:"-1", =>
           
      @style filePickerCSS
           
      @div class: 'block', =>
        @span class: 'description', 'View-Tail-Large-Files: Open Any File'

      @div class: "file-path vtlf-container block", =>
        @div class: "editor-container", =>
          @subview "filePath", new EditorView
            tabindex:"1"
            mini: true
            placeholderText: "Absolute path to file"

        @div class: 'btn-group-vtlf btn-group', =>
          @button outlet: 'openButton',   tabindex:"3", \
                   class: 'inline-block btn', 'Open'
          @button outlet: 'cancelButton', tabindex:"2", \
                   class: 'inline-block btn', 'Cancel'
                     
      @div class:"file-picker-bottom vtlf-container block", =>
        
        @div class:"file-picker-side inline-block ui-colors", =>
          @span class: 'description', 'Recent Files'
          @div class: 'recent-picks', =>
            @div class: 'recent-picks-inner', =>
              @ul class: 'list-group', =>
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item highlight', 'Normal item'       
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item', 'Normal item'
                         
        @div class:"file-picker-side inline-block", =>
          @span class: 'description', 'Recent Files'
          @div class: 'recent-picks', =>
            @div class: 'recent-picks-inner', =>
              @ul class: 'list-group', =>
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item', 'Normal item'       
                @li class: 'list-item', 'Normal item'       
                           
  initialize: (@state, @FilePicker) ->
    @handleEvents()
    wsv    = atom.workspaceView
    ww     = wsv.width()
    wh     = wsv.height()
    width  = 600
    height = Math.max 200, wh - 200
    left   = (ww - width)/2
    top    = 80
    @css {left, top, width, height}
    @find('.recent-picks').height height - 100
    wsv.append @
    @find('.editor').focus()
    
  handleEvents: ->
    atom.workspaceView.on 'core:cancel core:close', => @destroy()
    @cancelButton.on 'click', => @destroy()
    @openButton.on   'click', => @open()
      
  open: ->
    @destroy()
    @FilePicker.open 'c:\\apps\\insteon\\data\\hvac.log'   # debug

    
  destroy: -> @detach()

    
