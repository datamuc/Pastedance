package Pastedance::Pygments;

# I've been called "Ugly," "Pug Ugly," "Fugly," "Pug Fugly." But never "Ugly-Ugly!"

use Inline Python => << 'EOP';
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name, get_all_lexers

def get_lexers():
    r = {}
    lexers = get_all_lexers()
    for l in lexers:
        r[l[0]] = l[1][0]

    return r

def py_highlight(code, lang):
    try:
        lexer = get_lexer_by_name(lang)
    except:
        lexer = get_lexer_by_name('text')

    formatter = HtmlFormatter(linenos=True, lineanchors='l', anchorlinenos=True)
    return highlight(code, lexer, formatter)

EOP

use Data::Dumper::Concise;
sub import {
    my $caller = caller;
    *{"${caller}::get_lexers"} = sub { return get_lexers(@_) };
    *{"${caller}::highlight"}  = sub { return py_highlight(@_) };
}

1;
