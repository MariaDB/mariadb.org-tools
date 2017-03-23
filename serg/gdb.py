import gdb.printing

# in python2 gdb.Value can only be converted to long(), python3 only has int()
try: a=long(1)
except: long=int

def PrettyPrinter(func):

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

    pp=PrettyPrinterWrapperWrapper(func.__name__, func)
    gdb.printing.register_pretty_printer(None, pp, True)
    return func

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
