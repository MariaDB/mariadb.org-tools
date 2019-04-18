set breakpoint pending on
set height 100
set history remove-duplicates unlimited
set history save
set history size 2048
set print object
set print static-members off
set print vtbl
#set print array
#set print pretty
handle SIGPIPE nostop
handle SIGUSR1 nostop noprint
handle SIGUSR2 nostop noprint
source gdbinit

define pp
  printf "----------\n%s\n----------\n", $arg0
end
document pp
Print a string verbatim (no C escapes, no truncation).
Use: pp dbug_print(cond)
end

define ber
  if $argc == 0
    b my_message_sql
  else
    b my_message_sql if error == $arg0
  end
  r
end
document ber
Breakpoint on Error and Run.
Put a breakpoint on my_message_sql, optionally only for a specific error code,
and run.
Use: ./mtr --gdb='ber 1160'
end

define bir
  b $arg0
  if $argc > 1
    ign 1 $arg1
  end
  r
end
document bir
Breakpint with Ignore and Run.
Put a breakpoint, optionally with an ignore count, and run.
Use: ./mtr --gdb='bir mysql_parse 15'
end

define bq
  b mysql_parse if $_streq(rawbuf,$arg0)
  r
end
document bq
Breakpoint on a Query (and Run).
Use: ./mtr --gdb='bq "select 1 from t1"'
end

define qq
  if $_thread == 0
    quit
  end
end
document qq
Safe quit. Quits only if the program isn't running.
Use: ./mtr --gdb='r;qq'
end

source ~/.gdb.py
