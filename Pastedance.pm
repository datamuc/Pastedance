package Pastedance;
use Dancer;
use Data::Dumper;
use MongoDB;
use DateTime;
use URI::Escape;
use Data::Uniqid qw/uniqid/;
use Encode qw/decode encode/;
use Pastedance::Pygments;
use Data::Dumper::Concise;
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
      template 'index', {
        syntaxes => get_lexers(),
        expires => \%expires,
    });
};

get '/new_from/:id' => sub {
    my $doc = $collection->find_one({id => params->{id}});
    $doc->{subject} ||= params->{id};
    encode('utf-8',
        template 'index', {
            syntaxes => get_lexers(),
            expires => \%expires, 
            code    => $doc->{code},
            subject => $doc->{subject} =~ /\Are:/i
                ? $doc->{subject}
                : "Re: ".$doc->{subject},
        }
    );
};

post '/' => sub {
    chomp(my $code = request->params->{code});
    my $lang = request->params->{lang};
    my $subject = request->params->{subject};
    unless(length($code)) {
      return "don't paste no code"
    }

    my %rlex = reverse %{ get_lexers() };

    if ( ! defined $rlex{$lang} ) {
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
  return join("\n", sort keys %{ get_lexers() });
};

get '/json/lexers' => sub {
    my $term = params->{term} || "";
    my $lexers = get_lexers(); 
    my @return;
    while(my ($k,$v) = each %$lexers) {
        push @return, {
            id => $k,
            label => $k,
            value => $v,
        };
    }

    # search for matching lexers
    @return = grep { $_->{label} =~ /\Q$term/i } @return;

    # sort lexers
    # if lexer begins with $term it is sorted in first
    @return =
        map  { $_->[1] }
        sort { $a->[0] cmp $b->[0] }
        map  { [($_->{label} =~ /\A\Q$term/i ? 0 : 1).$_->{label}, $_] } @return
    ;

    to_json(\@return);
};

sub pygments_highlight {
   my $doc = shift;
   my $ln  = shift;
   return highlight($doc->{code}, $doc->{lang});
}

sub e404 {
  status '404';
  content_type 'text/plain';
  return "Not found";
}

1;

# vim: sw=4 ai et
