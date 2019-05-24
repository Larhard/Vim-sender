let s:sender = {}

function s:sender.out_callback(channel, msg)
    echomsg a:msg
endfunction

function s:sender.exit_callback(job, status)
    echomsg "Job ended with exit code: " . a:status

    while ! empty(self.lines)
        let line = remove(self.lines, -1)
        call matchdelete(line.match)
    endwhile

    unmap <buffer> <F2>
    unmap <buffer> <F3>
endfunction

function s:sender.create(cmd)
    let new = copy(self)

    let new.location = 0
    let new.lines = []

    echomsg "Starting cmd: " . a:cmd
    let new.job = job_start(a:cmd,
                \ {
                \   'mode': 'raw',
                \   'out_cb': new.out_callback,
                \   'exit_cb': new.exit_callback,
                \ })
    let new.channel = job_getchannel(new.job)

    return new
endfunction

function s:sender.send_next()
    let line = {}

    try
        let line.content = getbufline(bufnr("%"), self.location + 1)[0]
    catch /.*out of range.*/
        echomsg "EOF"
        return
    endtry

    let line.previous = self.location
    let self.location = self.location + 1

    let line.match = matchadd('SenderSent', '\%' . self.location . 'l')

    call ch_sendraw(self.channel, "+" . line.content . "\n")

    call add(self.lines, line)
endfunction

function s:sender.send_undo()
    if empty(self.lines)
        return
    endif

    let line = remove(self.lines, -1)
    let self.location = line.previous
    call ch_sendraw(self.channel, "-" . line.content . "\n")
    call matchdelete(line.match)
endfunction

function! sender#Start (cmd)
    hi default SenderSent ctermbg=darkblue

    let b:sender = s:sender.create(a:cmd)

    command! -buffer SenderNext :call b:sender.send_next()
    command! -buffer SenderUndo :call b:sender.send_undo()

    nnoremap <buffer> <F2> :SenderUndo<CR>
    nnoremap <buffer> <F3> :SenderNext<CR>
endfunction

" autocmd BufNewFile,BufRead *.rubiks setf rubiks
" autocmd FileType rubiks call sender#Start("tee /home/secmoto/moves.log")
