package Pastedance;
use Dancer qw(:syntax);
use MongoDB;
use DateTime;
use Data::Uniqid qw/uniqid/;
use Encode qw/decode encode/;
use Pastedance::Pygments;
use Dancer::Plugin::Mongo;

our $VERSION='0.007';

my %expires = %{ config->{expires} };

get '/' => sub {
        template 'index', {
            syntaxes => get_lexers(),
            expires => \%expires,
        };
};

before sub {
    var db => mongo->Pastedance->Pastedance;
};

get '/new_from/:id' => sub {
    my $doc = vars->{db}->find_one({id => params->{id}});
    $doc->{subject} ||= params->{id};
        template 'index', {
            syntaxes => get_lexers(),
            expires => \%expires, 
            code    => $doc->{code},
            subject => $doc->{subject} =~ /\Are:/i
                ? $doc->{subject}
                : "Re: ".$doc->{subject},
        };
};

post '/' => sub {
    chomp(my $code = request->params->{code});
    my $lang = request->params->{lang};
    my $subject = request->params->{subject};
    unless(length($code)) {
        return send_error("Don't paste no code!", 403);
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
    my $id = vars->{db}->insert($doc);
    redirect request->uri_for($doc->{id});
};

get '/:id' => sub {
    my $doc = vars->{db}->find_one({id => params->{id}});
    return send_error("Not found", 404) unless $doc;
    my $ln = request->params->{ln};
    $ln = defined($ln) ? $ln : 1;
    $doc->{url} = request->uri_for('/');
    $doc->{id}  = params->{id};
    $doc->{code} = pygments_highlight($doc, $ln);
    $doc->{'time'} = DateTime->from_epoch( epoch => $doc->{time} ),
    $doc->{expires} = DateTime::Duration->new( seconds => $doc->{expires} ),
    template 'show', $doc;
};

get '/plain/:id' => sub {
    my $doc = vars->{db}->find_one({id => params->{id}});
    return send_error("Not found", 404) unless $doc;
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

1;

# vim: sw=4 ai et
