import streams, critbits, parseopt2, strutils, os
import 
  core/parser, 
  core/interpreter, 
  core/utils,
  vendor/linenoise
import 
  lib/min_lang, 
  lib/min_stack, 
  lib/min_num,
  lib/min_str,
  lib/min_logic,
  lib/min_time, 
  lib/min_io,
  lib/min_sys,
  lib/min_net

const version* = "1.0.0-dev"
var REPL = false
const prelude = "lib/prelude.min".slurp.strip

const
  USE_LINENOISE = true


let usage* = "  MiNiM v" & version & " - a tiny concatenative programming language" & """

  (c) 2014-2016 Fabio Cevasco
  
  Usage:
    minim [options] [filename]

  Arguments:
    filename  A minim file to interpret (default: STDIN).
  Options:
    -e, --evaluate    Evaluate a minim program inline
    -h, --help        Print this help
    -v, --version     Print the program version
    -i, --interactive Start MiNiM's Read Eval Print Loop"""

proc completionCallback*(str: cstring, completions: ptr linenoiseCompletions) {.cdecl.}= 
  var words = ($str).split(" ")
  var w = if words.len > 0: words.pop else: ""
  var sep = ""
  if words.len > 0:
    sep = " "
  for s in ROOT.symbols.keys:
    if startsWith(s, w):
      linenoiseAddCompletion completions, words.join(" ") & sep & s
proc prompt(s: string): string = 
  var res = linenoise(s)
  discard $linenoiseHistoryAdd(res)
  return $res

proc minimStream(s: Stream, filename: string) =
  var i = INTERPRETER
  i.pwd = filename.parentDir
  i.eval prelude
  i.open(s, filename)
  discard i.parser.getToken() 
  i.interpret()
  i.close()

proc minimString*(buffer: string) =
  minimStream(newStringStream(buffer), "input")

proc minimFile*(filename: string) =
  var stream = newFileStream(filename, fmRead)
  if stream == nil:
    stderr.writeLine("Error - Cannot read from file: "& filename)
    stderr.flushFile()
  minimStream(stream, filename)

proc minimFile*(file: File, filename="stdin") =
  var stream = newFileStream(stdin)
  if stream == nil:
    stderr.writeLine("Error - Cannot read from "& filename)
    stderr.flushFile()
  minimStream(stream, filename)

proc minimRepl*() = 
  var i = INTERPRETER
  var s = newStringStream("")
  i.open(s, "")
  echo "MiNiM v"&version&" - REPL initialized."
  i.eval prelude
  echo "-> Type 'exit' or 'quit' to exit."
  when USE_LINENOISE:
    linenoiseSetCompletionCallback completionCallback
  var line: string
  while true:
    line = prompt(": ")
    i.parser.buf = $i.parser.buf & $line
    i.parser.bufLen = i.parser.buf.len
    discard i.parser.getToken() 
    try:
      i.interpret()
    except:
      warn getCurrentExceptionMsg()
    finally:
      stdout.write "-> "
      echo i.dump
    
###

var file, s: string = ""

for kind, key, val in getopt():
  case kind:
    of cmdArgument:
      file = key
    of cmdLongOption, cmdShortOption:
      case key:
        of "debug", "d":
          INTERPRETER.debugging = true
        of "evaluate", "e":
          s = val
        of "help", "h":
          echo usage
          quit(0)
        of "version", "v":
          echo version
          quit(0)
        of "interactive", "i":
          REPL = true
        else:
          discard
    else:
      discard

if s != "":
  minimString(s)
elif file != "":
  minimFile file
elif REPL:
  minimRepl()
  quit(0)
else:
  minimFile stdin

