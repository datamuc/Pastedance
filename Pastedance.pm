# vim: sw=4 ai si et
package Pastedance;
use Dancer;
use Data::Dumper;
use MongoDB;
use DateTime;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
#use lib '/opt/sh';
use Encode qw/decode encode/;
#use SourceHighlight;
#use Syntax::Highlight::Perl::Improved;
#use KiokuDB::Backend::MongoDB;
use MongoDB;

#
# Database setup
#
my $mongo = MongoDB::Connection->new(
    host => config->{mongo}->{host},
    port => config->{mongo}->{port},
);
if(config->{mongo}->{auth}) {
    my $return = $mongo->authenticate(
        config->{mongo}->{database},
        config->{mongo}->{auth}->{user},
        config->{mongo}->{auth}->{password},
    );
    die("authentication failed") unless(ref $return && $return->{ok});
}
my $database   = $mongo->get_database(config->{mongo}->{database});
my $collection = $database->get_collection('Pastedance');

my %expires = %{ config->{expires} };

get '/' => sub {
    encode('utf-8',
      template 'index', { syntaxes => get_lexers(), expires => \%expires });
};

post '/' => sub {
    chomp(my $code = request->params->{code});
    my $lang = request->params->{lang};
    my $subject = request->params->{subject};
    unless(length($code)) {
      return "don't paste no code"
    }
    my %rlex = reverse %{ get_lexers() };
    if ( ! exists $rlex{$lang} ) {
       $lang = "txt";
    }

    my $doc = {
       id      => uniqid,
       code    => decode('UTF-8', $code),
       lang    => $lang,
       subject => $subject,
       'time'  => time,
       expires => $expires{request->params->{expires}} // $expires{'1 week'},
    };
    my $id = $collection->insert($doc);
    redirect request->uri_for($doc->{id});
};

get '/:id' => sub {
    my $doc = $collection->find_one({id => params->{id}});
    return e404() unless $doc;
    my $ln = request->params->{ln};
    $ln = defined($ln) ? $ln : 1;
    $doc->{url} = request->uri_for('/');
    $doc->{id}  = params->{id};
    $doc->{code} = pygments_highlight($doc, $ln);
    $doc->{'time'} = DateTime->from_epoch( epoch => $doc->{time} ),
    $doc->{expires} = DateTime::Duration->new( seconds => $doc->{expires} ),
    encode('UTF-8', template 'show', $doc);
};

get '/plain/:id' => sub {
  my $doc = $collection->find_one({id => params->{id}});
  return e404() unless $doc;
  content_type 'text/plain; charset=UTF-8';
  return encode('UTF-8', $doc->{code});
};

get '/lexers/' => sub {
  content_type 'text/plain; charset=UTF-8';
  return join("\n", keys %{ get_lexers() });
};

sub pygments_highlight {
   my $doc = shift;
   my $ln  = shift;
   return py_highlight($doc->{code}, $doc->{lang});
}

sub e404 {
  status '404';
  content_type 'text/plain';
  return "Not found";
}

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
    lexer = get_lexer_by_name('txt')

  formatter = HtmlFormatter(linenos=True)
  return highlight(code, lexer, formatter)

EOP

true;

# vim: sw=2 ai et
