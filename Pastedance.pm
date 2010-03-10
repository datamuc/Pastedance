package Pastedance;
use Dancer;
use Data::Dumper;
use KiokuDB;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
use lib '/opt/sh';
use Encode qw/decode encode/;
use SourceHighlight;
use Syntax::Highlight::Perl::Improved;
use KiokuDB::Backend::MongoDB;
use MongoDB;

# my $conn = MongoDB::Connection->new(host => 'localhost');
# my $mongodb    = $conn->get_database('Pastedance');
# my $collection = $mongodb->get_collection('Pastedance');
# my $mongo = KiokuDB::Backend::MongoDB->new('collection' => $collection);
# 
# my $k = KiokuDB->new(
#   backend => $mongo
# );
# 

my $k = KiokuDB->connect(
  #"dbi:SQLite:dbname=pastedance.db",
  'bdb:dir=pastebindb',
  transactions=>0,
  create => 1,
);

my %expires = (
  '1 week'  => 604800,
  '1 day'   => 86400,
  '1 month' => 2678400,
  never    => -1,
);


# XXX Not sure about this: KiokuDB needs a scope object
#     so this does create at least one per request... but
#     not sure about its scope. :p
before sub {
  var scope => $k->new_scope;
  my $langs = config->{langs};
  set revlangs => { reverse %{$langs} } unless exists config->{revlangs};
};

get '/' => sub {
    template 'index', { syntaxes => config->{langs}, expires => \%expires };
};

post '/' => sub {
    chomp(my $code = request->params->{code});
    my $lang = request->params->{lang};
    my $subject = request->params->{subject};
    unless(length($code)) {
      return "don't paste no code" unless length($code);
    }
    if ( ! exists config->{langs}->{$lang} ) {
       $lang = "txt";
    }

    my $doc = {
       code    => decode('UTF-8', $code),
       lang    => $lang,
       subject => $subject,
       'time'  => time,
       expires => $expires{request->params->{expires}} // $expires{'1 week'},
    };
    my $id = $k->store(uniqid, $doc);
    redirect request->uri_for($id);
};

get '/:id' => sub {
    my $doc = $k->lookup(params->{id});
    return e404() unless $doc;
    my $ln = request->params->{ln};
    $ln = defined($ln) ? $ln : 1;
    $doc->{url} = request->uri_for('/');
    $doc->{id}  = params->{id};
    $doc->{code} = highlight($doc, $ln);
    template 'show', $doc;
};

get '/plain/:id' => sub {
  my $doc = $k->lookup(params->{id});
  return e404() unless $doc;
  content_type 'text/plain; charset=UTF-8';
  return $doc->{code};
};

#print Dumper(config);
#if(config->{environment} eq "development") {
#  get '/dump/:id' => sub {
#    content_type 'text/plain; charset=UTF-8';
#    my $doc = $k->lookup(params->{id});
#    return Dumper($doc)."\n".Dumper(config);
#  };
#}


sub highlight {
  my $doc = shift;
  my $ln  = shift;
  warn "xxx " .$doc->{code};
  if($doc->{lang} eq "Perl") {
    return perl_highlight($doc, $ln);
  }
  my $lang = config->{langs}->{$doc->{lang}} // 'nohilite.lang';
  $doc->{code} =~ s/\t/        /g;
  my $hl = SourceHighlight::SourceHighlight->new('html.outlang');
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
          'Label'             => 'color:#993399;font-style:italic;',
          'Quote'             => 'color:#0000aa;',
          'String'            => 'color:#0000aa;',
          'Subroutine'        => 'color:#998800;',
          'Variable_Scalar'   => 'color:#008800;',
          'Variable_Array'    => 'color:#ff7700;',
          'Variable_Hash'     => 'color:#8800ff;',
          'Variable_Typeglob' => 'color:#ff0033;',
          'Whitespace'        => '',
          'Character'         => 'color:#880000;',
          'Keyword'           => 'color:#000000;',
          'Builtin_Operator'  => 'color:#330000;',
          'Builtin_Function'  => 'color:#000011;',
          'Operator'          => 'color:#000000;',
          'Bareword'          => 'color:#33AA33;',
          'Package'           => 'color:#990000;',
          'Number'            => 'color:#ff00ff;',
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

  my @lines = $formatter->format_string($doc->{code});
  return '<pre>'.join("",@lines).'</pre>';
}

sub e404 {
  status '404';
  content_type 'text/plain';
  return "Not found";
}

true;

# vim: sw=2 ai et
