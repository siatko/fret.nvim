if exists("b:current_syntax")
  finish
endif

" Time signature on the ruler line (e.g. 4/4)
syn match fretTimeSig /\v^\d+\/\d+/
" Measure bars
syn match fretBar /|/
" Fret numbers
syn match fretNote /\v\d+/
" Beat numbers in ruler (single digits after |)
syn match fretBeat /\v(^[^ |]+\s+\|[\s|]*)@<= *\d/
" String names at line start
syn match fretString /\v^[eBGDAE]\s/

hi def link fretTimeSig  Title
hi def link fretBar      Comment
hi def link fretNote     Number
hi def link fretString   Identifier
hi def link fretBeat     Special

let b:current_syntax = "fret"
