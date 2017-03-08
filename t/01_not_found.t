use strict;
use warnings;
use Test::More tests => 3;

use_ok 'Parcel::Track';

my ( $tracker, $result );
$tracker = Parcel::Track->new( 'KR::CJKorea', '697569448283' );
$result = $tracker->track;
ok( $result->{result}, 'exists' );

$tracker = Parcel::Track->new( 'KR::CJKorea', '697569448283xxxxx' );
$result = $tracker->track;
ok( $result->{result}, 'not found' );
