import gdb.printing

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
            typename = val.type.unqualified().strip_typedefs().name
            if typename == self.name:
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
