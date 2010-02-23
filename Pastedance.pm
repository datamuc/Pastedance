package Pastedance;
use Dancer;
use Data::Dumper;
use KiokuDB;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
use lib '/opt/sh';
use SourceHighlight;

my $k = KiokuDB->connect(
  #"dbi:SQLite:dbname=pastedance.db",
  'bdb:dir=pastebindb',
  transactions=>0,
  create => 1,
);

my %expires = (
  '1week'  => 604800,
  '1day'   => 86400,
  '1month' => 2678400,
  never    => undef, 
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
    template 'index', { syntaxes => config->{langs} };
};

post '/' => sub {
    my $code = request->params->{code};
    my $lang = request->params->{lang};
    if ( ! exists config->{langs}->{$lang} ) {
       $lang = "txt";
    }

    my $doc = {
       code    => $code,
       lang    => $lang,
       'time'  => time,
       expires => $expires{request->params->{expires}} // $expires{'1week'},
    };
    my $id = $k->store(uniqid, $doc);
    redirect request->uri_for($id);
};

get '/:id' => sub {
    my $doc = $k->lookup(params->{id});
    my $ln = request->params->{ln};
    $ln = defined($ln) ? $ln : 1;
    $doc->{url} = request->uri_for('/');
    $doc->{id}  = params->{id};
    $doc->{code} = highlight($doc, $ln);
    template 'show', $doc;
};

get '/plain/:id' => sub {
  my $doc = $k->lookup(params->{id});
  content_type 'text/plain; charset=UTF-8';
  return $doc->{code};
};


sub highlight {
  my $doc = shift;
  my $ln  = shift;
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

true;
