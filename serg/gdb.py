import gdb.printing

class ppString:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        return '_' + self.val['str_charset']['name'].string() + \
               ' "' + self.val['Ptr'].string('ascii', 'strict',
                        self.val['str_length']) + '"'

class ppMY_BITMAP:
    def __init__(self, val):
        self.val = val

    def to_string(self):
        s=''
        for i in range((self.val['n_bits']+7)//8):
            s = format(int(self.val['bitmap'][i]), '032b') + s
        return "b'" + s[-int(self.val['n_bits']):] + "'"

pp = gdb.printing.RegexpCollectionPrettyPrinter(".gdb.py")
pp.add_printer('String', '^String$', ppString)
pp.add_printer('st_bitmap', '^st_bitmap$', ppMY_BITMAP)
gdb.printing.register_pretty_printer(None, pp, True)
