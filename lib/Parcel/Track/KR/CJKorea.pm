package Parcel::Track::KR::CJKorea;
# ABSTRACT: Parcel::Track driver for the CJ Korea Express (CJ 대한통운)

use utf8;

use Moo;

our $VERSION = '0.001';

with 'Parcel::Track::Role::Base';

use Capture::Tiny;
use File::Which;
use HTML::Selector::XPath;
use HTML::TreeBuilder::XPath;
use HTTP::Tiny;

#
# to support HTTPS
#
use IO::Socket::SSL;
use Mozilla::CA;
use Net::SSLeay;

our $URI =
    'https://www.doortodoor.co.kr/parcel/doortodoor.do?fsp_action=PARC_ACT_002&fsp_cmd=retrieveInvNoACT&invc_no=%s';

our $AGENT = 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)';

sub BUILDARGS {
    my ( $class, @args ) = @_;

    my %params;
    if ( ref $args[0] eq 'HASH' ) {
        %params = %{ $args[0] };
    }
    else {
        %params = @args;
    }
    $params{id} =~ s/\D//g;

    return \%params;
}

sub uri { sprintf( $URI, $_[0]->id ) }

sub track {
    my $self = shift;

    my %result = (
        from   => q{},
        to     => q{},
        result => q{},
        htmls  => [],
        descs  => [],
    );

    my $content;
    if ( exists &Net::SSLeay::CTX_v2_new ) {
        my $http = HTTP::Tiny->new(
            agent       => $AGENT,
            SSL_options => { SSL_version => 'SSLv2', }
        );

        my $res = $http->get( $self->uri );
        print $res->{content};
        unless ( $res->{success} ) {
            $result{result} = 'failed to get parcel tracking info from the site';
            return \%result;
        }

        $content = $res->{content};
    }
    elsif ( my $wget = File::Which::which('wget') ) {
        my ( $stdout, $stderr, $exit ) = Capture::Tiny::capture {
            system( $wget, qw( -O - ), $self->uri );
        };

        $content = $stdout;
    }
    else {
        $result{result} =
            'This version of OpenSSL has been compiled without SSLv2 support and there is no wget';
        return \%result;
    }

    unless ($content) {
        $result{result} = 'failed to tracking parcel info';
        return \%result;
    }

    #
    # http://stackoverflow.com/questions/19703341/disabling-html-entities-expanding-in-htmltreebuilder-perl-module
    #
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->ignore_unknown(0);
    $tree->no_expand_entities(1);
    $tree->attr_encoded(1);
    $tree->parse($content);
    $tree->eof;

    my $prefix = '/html/body/div/div[2]/div/div[2]/ul/li[1]/div';

    $result{from}  = $tree->findvalue("$prefix/div[1]/div/table/tr[2]/td[2]");
    $result{to}    = $tree->findvalue("$prefix/div[1]/div/table/tr[2]/td[3]");
    $result{htmls} = [
        ( $tree->findnodes("$prefix/div[1]/div/table") )[0]->as_HTML,
        ( $tree->findnodes("$prefix/div[2]/div/table") )[0]->as_HTML,
    ];

    my @elements  = $tree->findnodes("$prefix/div[2]/div/table/tr");
    my $row_index = 0;
    for my $e (@elements) {
        next if $row_index++ == 0;

        my @tds = $e->look_down( '_tag', 'td' );
        push @{ $result{descs} }, join( q{ }, map $_->as_text, @tds[ 1, 0, 3, 2 ] );

        $result{result} = join( q{ }, map $_->as_text, @tds[ 1, 0 ] );
    }

    return \%result;
}

1;

# COPYRIGHT

__END__

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    use Parcel::Track;

    # Create a tracker
    my $tracker = Parcel::Track->new( 'KR::CJKorea', '808-123-4567' );

    # ID & URI
    print $tracker->id . "\n";
    print $tracker->uri . "\n";
    
    # Track the information
    my $result = $tracker->track;
    
    # Get the information what you want.
    if ( $result ) {
        print "Message sent ok\n";
        print "$result->{from}\n";
        print "$result->{to}\n";
        print "$result->{result}\n";
        print "$_\n" for @{ $result->{descs} };
        print "$_\n" for @{ $result->{htmls} };
    }
    else {
        print "Failed to track information\n";
    }


=attr id

=method track

=method uri


=head1 SEE ALSO

=for :list
* L<Parcel::Track>
* L<CJ Korea Express (CJ 대한통운)|https://www.doortodoor.co.kr>
