
=head1 DESCRIPTION

This tests the L<ETL::Yertl::InputSeries> module. This module is used to
loop over all of C<@ARGV>, one after the other.

=cut

use ETL::Yertl 'Test';
use ETL::Yertl::InputSeries;
use ETL::Yertl::Format;
use ETL::Yertl::FormatStream;
use IO::Async::Test;
use IO::Async::Loop;
my $SHARE_DIR = path( __DIR__, 'share' );

my $loop = IO::Async::Loop->new;
testing_loop( $loop );

my $yaml_path = "".$SHARE_DIR->child( yaml => 'test.yaml' );
my $yaml_fh = $SHARE_DIR->child( yaml => 'foo.yaml' )->openr;

my $on_read_eof_called = 0;
my $on_child_read_eof_called = 0;
my @got = ();
my $series = ETL::Yertl::InputSeries->new(
    streams => [ $yaml_path, $yaml_fh ],
    on_doc => sub {
        my ( $self, $doc ) = @_;
        push @got, $doc;
    },
    on_child_read_eof => sub { $on_child_read_eof_called++ },
    on_read_eof => sub { $on_read_eof_called++ },
);
$loop->add( $series );

wait_for { @got == 4 };

is_deeply \@got,
    [
        # t/share/yaml/test.yaml
        { baz => 'buzz', foo => 'bar' },
        { flip => [qw( flop blip )] },
        [qw( foo bar baz )],
        # t/share/yaml/foo.yaml
        { foo => 'bar', baz => 'fuzz' },
    ],
    'Got test.yaml and foo.yaml documents';

is $on_child_read_eof_called, 2, 'on_child_read_eof called twice';
is $on_read_eof_called, 1, 'on_read_eof called once';

done_testing;

