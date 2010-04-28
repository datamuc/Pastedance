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
use Syntax::SourceHighlight;
use Syntax::Highlight::Perl::Improved;
use KiokuDB::Backend::MongoDB;
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
    template 'index', { syntaxes => get_lexers(), expires => \%expires };
};

post '/' => sub {
    chomp(my $code = request->params->{code});
    my $lang = request->params->{lang};
    my $subject = request->params->{subject};
    unless(length($code)) {
      return "don't paste no code"
    }
    if ( ! exists get_lexers()->{$lang} ) {
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

#print Dumper(config);
#if(config->{environment} eq "development") {
#  get '/dump/:id' => sub {
#    content_type 'text/plain; charset=UTF-8';
#    my $doc = $k->lookup(params->{id});
#    return Dumper($doc)."\n".Dumper(config);
#  };
#}

sub pygments_highlight {
   my $doc = shift;
   my $ln  = shift;
   return py_highlight($doc->{code}, get_lexers()->{$doc->{lang}});
}


sub highlight {
  my $doc = shift;
  my $ln  = shift;
  warn "xxx " .$doc->{code};
  if($doc->{lang} eq "Perl") {
    return perl_highlight($doc, $ln);
  }
  my $lang = config->{langs}->{$doc->{lang}} // 'nohilite.lang';
  $doc->{code} =~ s/\t/        /g;
  my $hl = Syntax::SourceHighlight::SourceHighlight->new('html.outlang');
  if($ln) {
    $hl->setGenerateLineNumbers(1);
    $hl->setLineNumberPad(' ');
    $hl->setGenerateLineNumberRefs(1);
    $hl->setLineNumberAnchorPrefix('l');
  }
  return $hl->highlightString($doc->{code}, $lang);
}

sub perl_highlight {
  my $doc = shift;
  my $ln  = shift;
  
  warn "xxx " .$doc->{code};
  my %default_styles = (
          'Comment_Normal'    => 'color:#006699;font-style:italic;',
          'Comment_POD'       => 'color:#001144;font-style:italic;',
          'Directive'         => 'color:#339999;font-style:italic;',
          'Label'             => 'color:#772277;font-style:italic;',
          'Quote'             => 'color:#0000aa;',
          'String'            => 'color:#0000aa;',
          'Subroutine'        => 'color:#554400;',
          'Variable_Scalar'   => 'color:#008800;',
          'Variable_Array'    => 'color:#CC7700;',
          'Variable_Hash'     => 'color:#8800CC;',
          'Variable_Typeglob' => 'color:#CC0033;',
          'Whitespace'        => '',
          'Character'         => 'color:#880000;',
          'Keyword'           => 'color:#000000;',
          'Builtin_Operator'  => 'color:#330000;',
          'Builtin_Function'  => 'color:#000011;',
          'Operator'          => 'color:#000000;',
          'Bareword'          => 'color:#338833;',
          'Package'           => 'color:#990000;',
          'Number'            => 'color:#BB00BB;',
          'Symbol'            => 'color:#000000;',
          'CodeTerm'          => 'color:#000000;',
          'DATA'              => 'color:#000000;',
          'LineNumber'        => 'color:#CCCCCC;'
  );

  my $formatter = new Syntax::Highlight::Perl::Improved;
  $formatter->define_substitution(
    '<' => '&lt;', '>' => '&gt;', '&' => '&amp;'
  ); 

  while ( my($type,$style) = each %default_styles ) {
    $formatter->set_format($type, [ "<span style=\"$style\">",'</span>' ] );
    #$str = '<PRE style="font-size:10pt;color:#333366;">';
  }

  my @formatted = $formatter->format_string($doc->{code});
  my ($code) = @formatted;
  my $line_num = ($code =~ tr/\n//) + 1;
  my $lines = join( "\n",
    map { sprintf( "\%@{[length($line_num)]}d:", $_ ) } 1 .. $line_num );
  return qq{
    <table>
     <tr>
      <td style="padding-right: 10px">
      <pre>$lines</pre>
      </td>
       <td><pre>$code</pre>
      </td>
     </table>
  };
}

sub e404 {
  status '404';
  content_type 'text/plain';
  return "Not found";
}

use Inline Python => << 'EOP';
from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_all_lexers

#code = 'print "Hello World"'
#print highlight(code, PythonLexer(), HtmlFormatter())

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
