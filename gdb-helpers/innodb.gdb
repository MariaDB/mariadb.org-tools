define records_list_on_page_106
  set $page=(byte *)$arg0
  set $records_number=$arg1
  set $is_comp=$page[PAGE_HEADER + PAGE_N_HEAP] & 0x80
  if ($is_comp)
    set $inf_offs=PAGE_NEW_INFIMUM
    set $sup_offs=PAGE_NEW_SUPREMUM
  else
    set $inf_offs=PAGE_OLD_INFIMUM
    set $sup_offs=PAGE_OLD_SUPREMUM
  end
  set $next_offs = $inf_offs
  while ($next_offs != $sup_offs && $records_number)
    set $cur_rec=$page+$next_offs
    p/x $next_offs
    set $deleted=(bool)($cur_rec[-5]&0x20)
    p $cur_rec
    p $deleted
    set $field_value=(uint16_t)(((($cur_rec-REC_NEXT)[0])<<8)+($cur_rec-REC_NEXT)[1])
    if ($is_comp != 0)
      set $next_offs=$cur_rec-$page+(int16_t)$field_value
    else
      set $next_offs=$field_value
    end
    set $records_number=$records_number-1
  end
end

document records_list_on_page_106
Iterates records on page. Args: pointer to page, maximum records number to iterate
end

define get_lock_rec_cell_106
  set $p_id=$arg0
  set $p_fold=(($p_id>>32)<<20)+($p_id>>32) + ($p_id & (0xffffffff))
  set $hash_ulint=(($p_fold^1653893711)%lock_sys.rec_hash.n_cells)
  set $pad=lock_sys.rec_hash.LATCH + lock_sys.rec_hash.LATCH * ($hash_ulint /lock_sys.rec_hash.ELEMENTS_PER_LATCH) + ($hash_ulint / lock_sys.rec_hash.ELEMENTS_PER_LATCH) * lock_sys.rec_hash.EMPTY_SLOTS_PER_LATCH + $hash_ulint
  p lock_sys.rec_hash->array[$pad]
end

document get_lock_rec_cell_106
Prints record hash cell for the certain page id. Args: page id
end

define get_lock_rec_for_page_106
  set $p_id=$arg0
  set $p_fold=(($p_id>>32)<<20)+($p_id>>32) + ($p_id & (0xffffffff))
  set $hash_ulint=(($p_fold^1653893711)%lock_sys.rec_hash.n_cells)
  set $pad=lock_sys.rec_hash.LATCH + lock_sys.rec_hash.LATCH * ($hash_ulint /lock_sys.rec_hash.ELEMENTS_PER_LATCH) + ($hash_ulint / lock_sys.rec_hash.ELEMENTS_PER_LATCH) * lock_sys.rec_hash.EMPTY_SLOTS_PER_LATCH + $hash_ulint
  set $lock = (ib_lock_t *)lock_sys.rec_hash->array[$pad].node
  while ($lock)
    if ($lock->un_member.rec_lock.page_id.m_id == $p_id)
      p $lock
      p *$lock
    end
    set $lock = $lock->hash
  end
end

document get_lock_rec_for_page_106
Prints all record locks for the certain page. Args: page id
end

define get_lock_rec_for_page_all_106
  set $p_id=$arg0
  set $p_fold=(($p_id>>32)<<20)+($p_id>>32) + ($p_id & (0xffffffff))
  set $hash_ulint=(($p_fold^1653893711)%lock_sys.rec_hash.n_cells)                                                                                     set $pad=lock_sys.rec_hash.LATCH + lock_sys.rec_hash.LATCH * ($hash_ulint /lock_sys.rec_hash.ELEMENTS_PER_LATCH) + ($hash_ulint / lock_sys.rec_hash.ELEMENTS_PER_LATCH) * lock_sys.rec_hash.EMPTY_SLOTS_PER_LATCH + $hash_ulint
  set $lock = (ib_lock_t *)lock_sys.rec_hash->array[$pad].node
  while ($lock)
    p $lock
    p *$lock
    set $lock = $lock->hash
  end
end

document get_lock_rec_for_page_all_106
Prints all record locks for the hash cell of the certain page. Args: page id
end

define rw_trx_hash_106
  set $link=  *(unsigned long *)trx_sys.rw_trx_hash.hash.array->level[0]
  while ($link != 0)
    set $ptr= (LF_SLIST *)((unsigned long)$link & (~(unsigned long)1))
    if (($link&1))
      set $link = 0
      p "found deleted"
    else
      if ($ptr->hashnr & 1)
        p ((rw_trx_hash_element_t *)($ptr+1))->trx
      end
      set $link=$ptr->link
    end
  end
end

document rw_trx_hash_106
Iterates rw_trx_hash.
end

define space_list_show_opened_106
  set $i= fil_system.space_list.sentinel_.next
  while ($i != &fil_system.space_list.sentinel_)
    set $file_handle = (*(fil_node_t *)(((fil_space_t *)$i)->chain->start)).handle.m_file
    if ($file_handle != -1)
      p (*(fil_node_t *)(((fil_space_t *)$i)->chain)->start).name
      p $file_handle
    end
    set $i = $i->next
  end
end

document space_list_show_opened_106
Iterates fil_system.space_list.
end

define find_page_105
  set $id=((unsigned long long)$arg0)<<32|$arg1
  set $chunk=buf_pool.chunks
  set $i=buf_pool.n_chunks
  set $found=0
  while ($i-- && !$found)
    set $j = $chunk->size
    set $b = $chunk->blocks
    while ($j--)
      if ($b->page.id_.m_id==$id)
        print $b
        set $found=1
        loop_break
      end
      set $b++
    end
    set $chunk++
  end
end

document find_page_105
Buffer pool look-up: find_page_105 space_id page_no"
end

define find_page_102
  set $buf_pool=$arg0
  set $space=$arg1
  set $page=$arg2

  set $chunk=$buf_pool->chunks
  set $i=$buf_pool->n_chunks
  while ($i--)
    set $j = $chunk->size
    set $b = $chunk->blocks
    while ($j--)
      if ($b->page.id.m_space==$space && $b->page.id.m_page_no==$page)
        print $b
      end
      set $b++
    end
    set $chunk++
  end
end

document find_page_102
Buffer pool look-up: find_page_102 buf_pool_ptr space_id page_no"
end
