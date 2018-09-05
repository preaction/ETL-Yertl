
=head1 DESCRIPTION

This tests the L<ETL::Yertl::FormatStream> module.

=cut

use ETL::Yertl 'Test';
use ETL::Yertl::FormatStream;
use ETL::Yertl::Format;
use IO::Async::Test;
use IO::Async::Loop;
my $SHARE_DIR = path( __DIR__, 'share' );

my $loop = IO::Async::Loop->new;
testing_loop( $loop );

sub test_format_stream {
    my ( $path, $expect_output, $format ) = @_;

    subtest 'read_handle and on_doc' => sub {
        my @docs;

        my $fh = $path->openr;
        my $stream = ETL::Yertl::FormatStream->new(
            read_handle => $fh,
            on_doc => sub {
                my ( $self, $doc ) = @_;
                push @docs, $doc;
            },
            ( $format ? ( format => $format ) : () ),
        );
        $loop->add( $stream );

        wait_for { @docs == 3 };
        is_deeply \@docs, [
            { foo => 'bar', baz => 'buzz' },
            { flip => [qw( flop blip )] },
            [qw( foo bar baz )],
        ], 'documents read are correct';
    };

    subtest 'write_handle and write()' => sub {
        my $tmp = tempfile();
        my $stream = ETL::Yertl::FormatStream->new(
            write_handle => $tmp->openw,
            autoflush => 1,
            ( $format ? ( format => $format ) : () ),
        );
        $loop->add( $stream );
        $stream->write( { foo => 'bar' } );

        my $output = $tmp->slurp;
        is $output, $expect_output, 'output is correct';
    };
}

subtest 'default format' => \&test_format_stream,
    $SHARE_DIR->child( yaml => 'test.yaml' ),
    "---\nfoo: bar\n",
    ;

subtest 'format object (ETL::Yertl::Format::json)' => \&test_format_stream,
    $SHARE_DIR->child( json => 'test.json' ),
    qq{{\n   "foo" : "bar"\n}\n},
    ETL::Yertl::Format->get( 'json' ),
    ;

subtest 'new_for_stdin' => sub {
    my $stream = ETL::Yertl::FormatStream->new_for_stdin;
    is $stream->read_handle, \*STDIN, 'read_handle is STDIN';
};

subtest 'new_for_stdout' => sub {
    my $stream = ETL::Yertl::FormatStream->new_for_stdout;
    is $stream->write_handle, \*STDOUT, 'write_handle is STDOUT';
};

done_testing;
