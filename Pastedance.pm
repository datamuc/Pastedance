package Pastedance;
use Dancer;
use Data::Dumper;
use MongoDB;
use DateTime;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
use lib '/opt/sh';
use Encode qw/decode encode/;
use SourceHighlight;

my $mongo = MongoDB::Connection->new(host => 'localhost', port => 27017);
my $database   = $mongo->get_database('Pastedance');
my $collection = $database->get_collection('Pastedance');


my %expires = (
  '1 week'  => 604800,
  '1 day'   => 86400,
  '1 month' => 2678400,
  never    => -1,
);


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
    $doc->{code} = highlight($doc, $ln);
    $doc->{'time'} = DateTime->from_epoch( epoch => $doc->{time} ),
    $doc->{expires} = DateTime::Duration->new( seconds => $doc->{expires} ),
    template 'show', $doc;
};

get '/plain/:id' => sub {
  my $doc = $collection->find_one({id => params->{id}});
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

sub e404 {
  status '404';
  content_type 'text/plain';
  return "Not found";
}

true;
