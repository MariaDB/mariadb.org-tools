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

define get_lock_rec_for_page_heap_no_106
  set $p_id=$arg0
  set $heap_no=$arg1
  set $byte_index = (ulint)($heap_no/8)
  set $bit_index = (ulint)($heap_no%8)
  set $p_fold=(($p_id>>32)<<20)+($p_id>>32) + ($p_id & (0xffffffff))
  set $hash_ulint=(($p_fold^1653893711)%lock_sys.rec_hash.n_cells)
  set $pad=lock_sys.rec_hash.LATCH + lock_sys.rec_hash.LATCH * ($hash_ulint /lock_sys.rec_hash.ELEMENTS_PER_LATCH) + ($hash_ulint / lock_sys.rec_hash.ELEMENTS_PER_LATCH) * lock_sys.rec_hash.EMPTY_SLOTS_PER_LATCH + $hash_ulint
  set $lock = (ib_lock_t *)lock_sys.rec_hash->array[$pad].node
  while ($lock)
    set $heap_no_bit_set = 1 & ((*(((byte *)((ib_lock_t *)$lock + 1)) + $byte_index))>>$bit_index)
    if (($lock->un_member.rec_lock.page_id.m_id == $p_id) && $heap_no_bit_set)
      p $lock
      p *$lock
    end
    set $lock = $lock->hash
  end
end

document get_lock_rec_for_page_heap_no_106
Prints all record locks for the certain page and heap_no. Args: page id, heap_no
end


define get_lock_rec_for_cell_106
  set $p_id=$arg0
  set $p_fold=(($p_id>>32)<<20)+($p_id>>32) + ($p_id & (0xffffffff))
  set $hash_ulint=(($p_fold^1653893711)%lock_sys.rec_hash.n_cells)                                                                                     
  set $pad=lock_sys.rec_hash.LATCH + lock_sys.rec_hash.LATCH * ($hash_ulint /lock_sys.rec_hash.ELEMENTS_PER_LATCH) + ($hash_ulint / lock_sys.rec_hash.ELEMENTS_PER_LATCH) * lock_sys.rec_hash.EMPTY_SLOTS_PER_LATCH + $hash_ulint
  set $lock = (ib_lock_t *)lock_sys.rec_hash->array[$pad].node
  while ($lock)
    p $lock
    p *$lock
    set $lock = $lock->hash
  end
end

document get_lock_rec_for_cell_106
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

define undo_seg_1st_page_info
  set $page = (byte *)$arg0

  set $TRX_UNDO_PAGE_HDR= 38
  set $TRX_UNDO_PAGE_HDR_SIZE= 18
  set $TRX_UNDO_SEG_HDR= $TRX_UNDO_PAGE_HDR + $TRX_UNDO_PAGE_HDR_SIZE
  set $TRX_UNDO_SEG_HDR_SIZE= 30
  set $TRX_UNDO_PAGE_TYPE= 0
  set $TRX_UNDO_LAST_LOG= 2
  set $TRX_UNDO_STATE= 0
  set $TRX_UNDO_PAGE_NODE= 6
  set $FIL_ADDR_PAGE= 0
  set $FLST_NEXT= 6
  set $TRX_UNDO_TRX_ID= 0
  set $TRX_UNDO_TRX_NO= 8
  set $TRX_UNDO_NEXT_LOG= 30

  set $undo_page_hdr= $page + $TRX_UNDO_PAGE_HDR
  set $undo_seg_hdr= $page + $TRX_UNDO_SEG_HDR

  set $type = *(uint16_t *)($undo_page_hdr + $TRX_UNDO_PAGE_TYPE)
  set $type = (uint16_t)($type<<8)|($type >> 8)
  set $last_log_offset = *(uint16_t *)($undo_seg_hdr + $TRX_UNDO_LAST_LOG)
  set $last_log_offset = (uint16_t)($last_log_offset<<8)|($last_log_offset >> 8)
  set $state = *(uint16_t *)($undo_seg_hdr + $TRX_UNDO_STATE)
  set $state = (uint16_t)($state<<8)|($state >> 8)
  set $last_log_offset= *(uint16_t *)($undo_seg_hdr + $TRX_UNDO_LAST_LOG)
  set $last_log_offset = (uint16_t)($last_log_offset<<8)|($last_log_offset >> 8)
  set $next_page_ptr = *(int32_t *)($undo_page_hdr + $TRX_UNDO_PAGE_NODE + $FLST_NEXT + $FIL_ADDR_PAGE)
  printf "Page type: %d, undo segment state: %d, last log offset: %d, next page: ", $type, $state, $last_log_offset
  if $next_page_ptr == -1
    printf "no"
  end
  if $next_page_ptr != -1
    printf "yes"
  end
  printf "\nUndo logs:\n"

  set $undo_log_offset=$TRX_UNDO_SEG_HDR + $TRX_UNDO_SEG_HDR_SIZE
  set $i = 0
  while($undo_log_offset && $i < 200)
    set $undo_log_addr= (unsigned char *)($page) + $undo_log_offset
    set $trx_no_addr= ($undo_log_addr + $TRX_UNDO_TRX_NO)
    set $trx_no= (uint64_t)($trx_no_addr[0])<<56 | (uint64_t)($trx_no_addr[1])<<48 | (uint64_t)($trx_no_addr[2])<<40 | (uint64_t)($trx_no_addr[3])<<32 | (uint64_t)($trx_no_addr[4])<<24 | (uint64_t)($trx_no_addr[5])<<16 | (uint64_t)($trx_no_addr[6])<<8 | (uint64_t)$trx_no_addr[7]
    set $trx_id_addr= ($undo_log_addr + $TRX_UNDO_TRX_ID)
    set $trx_id= (uint64_t)($trx_id_addr[0])<<56 | (uint64_t)($trx_id_addr[1])<<48 | (uint64_t)($trx_id_addr[2])<<40 | (uint64_t)($trx_id_addr[3])<<32 | (uint64_t)($trx_id_addr[4])<<24 | (uint64_t)($trx_id_addr[5])<<16 | (uint64_t)($trx_id_addr[6])<<8 | (uint64_t)$trx_id_addr[7]
    set $current_offset = $undo_log_offset
    set $undo_log_offset= *(uint16_t *)($undo_log_addr + $TRX_UNDO_NEXT_LOG)
    set $undo_log_offset= (uint16_t)($undo_log_offset<<8)|($undo_log_offset >> 8)
    if ($current_offset == $last_log_offset)
      printf "vvvvv Last log from undo seg header vvvvv\n"
    end
    printf "%d - current offset: %d, trx_id: %d, trx_no: %d, next_undo_log_offset: %d\n", $i, $current_offset, $trx_id, $trx_no, $undo_log_offset
    set $i= $i+1
  end
end
document undo_seg_1st_page_info
Shows 1st undo page info. Args: undo segment first page address
end

