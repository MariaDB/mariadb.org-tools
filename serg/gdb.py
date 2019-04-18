import duel
from pretty_printer import PrettyPrinter

def print_string(val, length):
    if length <= 0:
        return '""'
    return str(val.dereference().cast(gdb.lookup_type('char').array(length - 1)))

@PrettyPrinter
def String(val):
    try:    cs=val['m_charset']   # 10.4+
    except: cs=val['str_charset'] # 10.3-
    return '_' + cs['name'].string() + ' ' + \
            print_string(val['Ptr'], val['str_length'])

@PrettyPrinter
def st_bitmap(val):
    s=''.join(reversed([format(int(val['bitmap'][i]),'032b')
                          for i in range(int(val['n_bits']+31)//32)]))
    return "b'" + s[-int(val['n_bits']):] + "'"

@PrettyPrinter('Bitmap<64u>')
def keymap64(val):
    return "b'" + format(long(val['map']),'b') + "'"


def print_flags(val, bits):
    return ','.join([s for n,s in enumerate(bits) if val & (1 << n)])

@PrettyPrinter
def sql_mode_t(val):
    return print_flags(val, ['REAL_AS_FLOAT', 'PIPES_AS_CONCAT', 'ANSI_QUOTES',
        'IGNORE_SPACE', 'IGNORE_BAD_TABLE_OPTIONS', 'ONLY_FULL_GROUP_BY',
        'NO_UNSIGNED_SUBTRACTION', 'NO_DIR_IN_CREATE', 'POSTGRESQL', 'ORACLE',
        'MSSQL', 'DB2', 'MAXDB', 'NO_KEY_OPTIONS', 'NO_TABLE_OPTIONS',
        'NO_FIELD_OPTIONS', 'MYSQL323', 'MYSQL40', 'ANSI',
        'NO_AUTO_VALUE_ON_ZERO', 'NO_BACKSLASH_ESCAPES', 'STRICT_TRANS_TABLES',
        'STRICT_ALL_TABLES', 'NO_ZERO_IN_DATE', 'NO_ZERO_DATE',
        'INVALID_DATES', 'ERROR_FOR_DIVISION_BY_ZERO', 'TRADITIONAL',
        'NO_AUTO_CREATE_USER', 'HIGH_NOT_PRECEDENCE', 'NO_ENGINE_SUBSTITUTION',
        'PAD_CHAR_TO_FULL_LENGTH'])

@PrettyPrinter('Alter_inplace_info::HA_ALTER_FLAGS')
def HA_ALTER_FLAGS(val):
    return print_flags(val, ['ADD_INDEX', 'DROP_INDEX', 'ADD_UNIQUE_INDEX',
        'DROP_UNIQUE_INDEX', 'ADD_PK_INDEX', 'DROP_PK_INDEX',
        'ADD_VIRTUAL_COLUMN', 'ADD_STORED_BASE_COLUMN',
        'ADD_STORED_GENERATED_COLUMN', 'DROP_VIRTUAL_COLUMN',
        'DROP_STORED_COLUMN', 'ALTER_COLUMN_NAME', 'ALTER_VIRTUAL_COLUMN_TYPE',
        'ALTER_STORED_COLUMN_TYPE', 'ALTER_COLUMN_EQUAL_PACK_LENGTH',
        'ALTER_STORED_COLUMN_ORDER', 'ALTER_VIRTUAL_COLUMN_ORDER',
        'ALTER_COLUMN_NULLABLE', 'ALTER_COLUMN_NOT_NULLABLE',
        'ALTER_COLUMN_DEFAULT', 'ALTER_VIRTUAL_GCOL_EXPR',
        'ALTER_STORED_GCOL_EXPR', 'ADD_FOREIGN_KEY', 'DROP_FOREIGN_KEY',
        'CHANGE_CREATE_OPTION', 'ALTER_RENAME', 'ALTER_COLUMN_OPTION',
        'ALTER_COLUMN_COLUMN_FORMAT', 'ADD_PARTITION', 'DROP_PARTITION',
        'ALTER_PARTITION', 'COALESCE_PARTITION', 'REORGANIZE_PARTITION',
        'ALTER_TABLE_REORG', 'ALTER_REMOVE_PARTITIONING',
        'ALTER_ALL_PARTITION', 'RECREATE_TABLE', 'ALTER_COLUMN_VCOL',
        'ALTER_PARTITIONED', 'ALTER_ADD_CHECK_CONSTRAINT',
        'ALTER_DROP_CHECK_CONSTRAINT'])

def byte(val):
    return int(val.cast(gdb.lookup_type('unsigned char')))

@PrettyPrinter
def sockaddr_storage(val):
    if val['ss_family'] == 0: return 'AF_UNSPEC'
    if val['ss_family'] == 1: return 'AF_UNIX ???'
    if val['ss_family'] == 2:
        s = val['__ss_padding']
        return 'AF_INET://{}.{}.{}.{}:{}'.format(
                byte(s[2]), byte(s[3]), byte(s[4]), byte(s[5]),
                byte(s[0])*256+byte(s[1])
                )
    if val['ss_family'] == 10: return 'AF_INET6 ???'
    return 'AF_???'

@PrettyPrinter
def mysql_prlock_t(val):
    return '=mysql_prlock_t'

@PrettyPrinter
def mysql_mutex_t(val):
    return '=mysql_mutex_t'

@PrettyPrinter
def mysql_cond_t(val):
    return '=mysql_cond_t'
