set trace-commands on
set pagination off
set print pretty on
set print array on
set print array-indexes on
set print elements 15000
set print sevenbit on
set print static-members off
handle SIGUSR1 nostop noprint
handle SIGUSR2 nostop noprint
handle SIGWAITING nostop noprint
handle SIGLWP nostop noprint
handle SIGPIPE nostop
handle SIGALRM nostop
handle SIGHUP nostop
handle SIGTERM nostop noprint
handle SIG32 nostop noprint
handle SIG33 nostop noprint

define find_page_in_pool
  set $buf_pool=$arg0
  set $space=$arg1
  set $page=$arg2

  set $chunk=$buf_pool->chunks
  set $i=$buf_pool->n_chunks
  set $found=0
  while ($i-- && !$found)
    set $j = $chunk->size
    set $b = $chunk->blocks
    while ($j--)
      if ($b->page.id.m_space==$space && $b->page.id.m_page_no==$page)
        print $b
        set $found=1
        loop_break
      end
      set $b++
    end
    set $chunk++
  end
end

document find_page_in_pool
Buffer pool look-up: find_page_in_pool &buf_pool_ptr[0] space_id page_no"
end
