import gdb.printing

# in python2 gdb.Value can only be converted to long(), python3 only has int()
try: a=long(1)
except: long=int

def PrettyPrinter(arg):

    class PrettyPrinterWrapperWrapper:

        class PrettyPrinterWrapper:
            def __init__(self, prefix, val, cb):
                self.prefix = prefix
                self.val = val
                self.cb = cb
            def to_string(self):
                return self.prefix + self.cb(self.val)

        def __init__(self, name, cb):
            self.name = name
            self.enabled = True
            self.cb = cb

        def __call__(self, val):
            prefix = ''
            if val.type.code == gdb.TYPE_CODE_PTR:
                prefix = '({}) {:#08x} '.format(str(val.type), long(val))
                try: val = val.dereference()
                except: return None
            valtype=val.type.unqualified()
            if valtype.name == self.name:
                return self.PrettyPrinterWrapper(prefix, val, self.cb)
            if valtype.strip_typedefs().name == self.name:
                return self.PrettyPrinterWrapper(prefix, val, self.cb)
            return None

    name = getattr(arg, '__name__', arg)

    def PrettyPrinterWrapperWrapperWrapper(func):
        pp=PrettyPrinterWrapperWrapper(name, func)
        gdb.printing.register_pretty_printer(None, pp, True)
        return func

    if callable(arg):
        return PrettyPrinterWrapperWrapperWrapper(arg)

    return PrettyPrinterWrapperWrapperWrapper

@PrettyPrinter
def String(val):
    return '_' + val['str_charset']['name'].string() + \
           ' "' + val['Ptr'].string('ascii', 'strict',
                    val['str_length']) + '"'

@PrettyPrinter
def st_bitmap(val):
    s=''
    for i in range((val['n_bits']+7)//8):
        s = format(int(val['bitmap'][i]), '032b') + s
    return "b'" + s[-int(val['n_bits']):] + "'"

@PrettyPrinter
def sql_mode_t(val):
    s=''
    modes=['REAL_AS_FLOAT', 'PIPES_AS_CONCAT', 'ANSI_QUOTES', 'IGNORE_SPACE',
           'IGNORE_BAD_TABLE_OPTIONS', 'ONLY_FULL_GROUP_BY',
           'NO_UNSIGNED_SUBTRACTION', 'NO_DIR_IN_CREATE', 'POSTGRESQL',
           'ORACLE', 'MSSQL', 'DB2', 'MAXDB', 'NO_KEY_OPTIONS',
           'NO_TABLE_OPTIONS', 'NO_FIELD_OPTIONS', 'MYSQL323', 'MYSQL40',
           'ANSI', 'NO_AUTO_VALUE_ON_ZERO', 'NO_BACKSLASH_ESCAPES',
           'STRICT_TRANS_TABLES', 'STRICT_ALL_TABLES', 'NO_ZERO_IN_DATE',
           'NO_ZERO_DATE', 'INVALID_DATES', 'ERROR_FOR_DIVISION_BY_ZERO',
           'TRADITIONAL', 'NO_AUTO_CREATE_USER', 'HIGH_NOT_PRECEDENCE',
           'NO_ENGINE_SUBSTITUTION', 'PAD_CHAR_TO_FULL_LENGTH']
    for i in range(0,len(modes)):
        if val & (1 << i): s += ',' + modes[i]
    return s[1:]

@PrettyPrinter('Alter_inplace_info::HA_ALTER_FLAGS')
def HA_ALTER_FLAGS(val):
    s=''
    modes=[ 'ADD_INDEX', 'DROP_INDEX', 'ADD_UNIQUE_INDEX', 'DROP_UNIQUE_INDEX',
            'ADD_PK_INDEX', 'DROP_PK_INDEX', 'ADD_VIRTUAL_COLUMN',
            'ADD_STORED_BASE_COLUMN', 'ADD_STORED_GENERATED_COLUMN',
            'DROP_VIRTUAL_COLUMN', 'DROP_STORED_COLUMN', 'ALTER_COLUMN_NAME',
            'ALTER_VIRTUAL_COLUMN_TYPE', 'ALTER_STORED_COLUMN_TYPE',
            'ALTER_COLUMN_EQUAL_PACK_LENGTH', 'ALTER_STORED_COLUMN_ORDER',
            'ALTER_VIRTUAL_COLUMN_ORDER', 'ALTER_COLUMN_NULLABLE',
            'ALTER_COLUMN_NOT_NULLABLE', 'ALTER_COLUMN_DEFAULT',
            'ALTER_VIRTUAL_GCOL_EXPR', 'ALTER_STORED_GCOL_EXPR',
            'ADD_FOREIGN_KEY', 'DROP_FOREIGN_KEY', 'CHANGE_CREATE_OPTION',
            'ALTER_RENAME', 'ALTER_COLUMN_OPTION',
            'ALTER_COLUMN_COLUMN_FORMAT', 'ADD_PARTITION', 'DROP_PARTITION',
            'ALTER_PARTITION', 'COALESCE_PARTITION', 'REORGANIZE_PARTITION',
            'ALTER_TABLE_REORG', 'ALTER_REMOVE_PARTITIONING',
            'ALTER_ALL_PARTITION', 'RECREATE_TABLE', 'ALTER_COLUMN_VCOL',
            'ALTER_PARTITIONED', 'ALTER_ADD_CHECK_CONSTRAINT',
            'ALTER_DROP_CHECK_CONSTRAINT']
    for i in range(0,len(modes)):
        if val & (1 << i): s += ',' + modes[i]
    return s[1:]
