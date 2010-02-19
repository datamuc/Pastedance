package Pastedance;
use Dancer;
use Data::Dumper;
use KiokuDB;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
use highlight;

my $k = KiokuDB->connect(
  'bdb:dir=pastebindb',
  create => 1,
);

# XXX Not sure about this: KiokuDB needs a scope object
#     so this does create at least one per request... but
#     not sure about its scope. :p
before sub { var scope => $k->new_scope; };

get '/' => sub {
    template 'index';
};

post '/' => sub {
    my $code = request->params->{code};
    my $doc = {
       code   => $code,
       lang   =>'txt',
       'time' => time,
    };
    my $id = $k->store(uniqid, $doc);
    redirect request->uri_for($id);
};

get '/:id' => sub {
    my $doc = $k->lookup(params->{id});
    $doc->{url} = request->uri_for('/');
    $doc->{id}  = params->{id};
    $doc->{code} = highlight($doc->{code});
    template 'show', $doc;
};

get '/plain/:id' => sub {
  my $doc = $k->lookup(params->{id});
  content_type 'text/plain; charset=UTF-8';
  return $doc->{code};
};

sub highlight {
  my $code = shift;
  my $gen = highlightc::CodeGenerator_getInstance($highlightc::HTML);
  $gen->initTheme('/opt/highlight/share/highlight/themes/ide-codewarrior.style');
  $gen->loadLanguage('/opt/highlight/share/highlight/langDefs/pl.lang');
  #$gen->loadLanguage('/opt/highlight/share/highlight/langDefs/txt.lang');
  $gen->setEncoding('UTF-8');
  $gen->setFragmentCode(1);
  $gen->setHTMLInlineCSS(1);
  $gen->setHTMLAttachAnchors(1);
  #$gen->setPrintLineNumbers(1);
  $gen->setHTMLOrderedList(1);
  my $output = $gen->generateString($code);
  highlightc::CodeGenerator_deleteInstance($gen);
  return $output;
}

true;
