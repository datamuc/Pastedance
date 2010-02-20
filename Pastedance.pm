package Pastedance;
use Dancer;
use Data::Dumper;
use KiokuDB;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
use highlight;

my $k = KiokuDB->connect(
  #"dbi:SQLite:dbname=pastedance.db",
  'bdb:dir=pastebindb',
  transactions=>0,
  create => 1,
);

# XXX Not sure about this: KiokuDB needs a scope object
#     so this does create at least one per request... but
#     not sure about its scope. :p
before sub { var scope => $k->new_scope; };

get '/' => sub {
    template 'index', { syntaxes => config->{Syntaxmap} };
};

post '/' => sub {
    my $code = request->params->{code};
    my $lang = request->params->{lang} || 'txt';
    ($lang) = grep { $_ eq $lang } map { $_->{value} } @{ config->{Syntaxmap} };
    $lang ||= 'txt';

    my $doc = {
       code   => $code,
       lang   => $lang,
       'time' => time,
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
  my $ln = shift;
  my $lang = $doc->{lang} || 'txt';
  my $gen = highlightc::CodeGenerator_getInstance($highlightc::HTML);
  $gen->initTheme('/opt/highlight/share/highlight/themes/ide-codewarrior.style');
  $gen->loadLanguage("/opt/highlight/share/highlight/langDefs/${lang}.lang");
  $gen->setEncoding('UTF-8');
  $gen->setFragmentCode(1);
  $gen->setHTMLInlineCSS(1);
  $gen->setHTMLAttachAnchors(1);
  $gen->setPrintLineNumbers($ln);
  #$gen->setHTMLOrderedList(1);
  my $output = $gen->generateString($doc->{code});
  highlightc::CodeGenerator_deleteInstance($gen);
  return $output;
}

true;
