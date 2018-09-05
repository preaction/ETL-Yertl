
=head1 DESCRIPTION

This tests the L<ETL::Yertl::Transform> module, including specifying a transform
subroutine and creating a custom transform class.

=cut

use ETL::Yertl 'Test';
use ETL::Yertl::FormatStream;
use ETL::Yertl::Format;
use ETL::Yertl::Transform;
use Test::Lib;
use Local::AddHello;
use IO::Async::Test;
use IO::Async::Loop;
my $SHARE_DIR = path( __DIR__, 'share' );

my $loop = IO::Async::Loop->new;
testing_loop( $loop );
my $input = $SHARE_DIR->child( yaml => 'test.yaml' );

subtest 'transform_doc callback' => sub {
    my $in_stream = ETL::Yertl::FormatStream->new(
        read_handle => $input->openr,
        format => ETL::Yertl::Format->get( 'yaml' ),
    );
    $loop->add( $in_stream );

    my $called = 0;
    my $xform = ETL::Yertl::Transform->new(
        source => $in_stream,
        transform_doc => sub {
            my ( $self, $doc ) = @_;
            $called++;
        },
    );
    $loop->add( $xform );
    $xform->run;

    is $called, 3, 'transform callback called 1 time per document';
};

subtest 'transform as input' => sub {
    my $in_stream = ETL::Yertl::FormatStream->new(
        read_handle => $input->openr,
        format => ETL::Yertl::Format->get( 'yaml' ),
    );
    $loop->add( $in_stream );

    my $xform_src = Local::AddHello->new(
        source => $in_stream,
    );
    $loop->add( $xform_src );

    my $called = 0;
    my $xform = ETL::Yertl::Transform->new(
        source => $xform_src,
        transform_doc => sub {
            my ( $self, $doc ) = @_;
            $called++;
        },
    );
    $loop->add( $xform );
    $xform->run;

    is $called, 3, 'transform callback called 1 time per document';
};

subtest 'transform with output' => sub {
    my $in_stream = ETL::Yertl::FormatStream->new(
        read_handle => $input->openr,
        format => ETL::Yertl::Format->get( 'yaml' ),
    );
    $loop->add( $in_stream );

    my $tempfile = tempfile();
    my $out_stream = ETL::Yertl::FormatStream->new(
        write_handle => $tempfile->openw,
        autoflush => 1,
    );
    $loop->add( $out_stream );

    my $called = 0;
    my $xform = ETL::Yertl::Transform->new(
        source => $in_stream,
        destination => $out_stream,
        transform_doc => sub {
            my ( $self, $doc ) = @_;
            $called++;
            return $doc;
        },
    );
    $loop->add( $xform );
    $xform->run;

    is $called, 3, 'transform callback called 1 time per document';

    my @docs = docs_from_string( $tempfile->slurp );
    is_deeply \@docs, [
        { foo => 'bar', baz => 'buzz' },
        { flip => [qw( flop blip )] },
        [qw( foo bar baz )],
    ], 'transformed docs are correct';
};

subtest 'transform subclass - Local::AddHello' => sub {
    my $in_stream = ETL::Yertl::FormatStream->new(
        read_handle => $input->openr,
        format => ETL::Yertl::Format->get( 'yaml' ),
    );
    $loop->add( $in_stream );

    my $tempfile = tempfile();
    my $out_stream = ETL::Yertl::FormatStream->new(
        write_handle => $tempfile->openw,
        autoflush => 1,
    );
    $loop->add( $out_stream );

    my $xform = Local::AddHello->new(
        source => $in_stream,
        destination => $out_stream,
    );
    $loop->add( $xform );
    $xform->run;

    my @docs = docs_from_string( $tempfile->slurp );
    is_deeply \@docs, [
        { __HELLO__ => 'World', foo => 'bar', baz => 'buzz' },
        { __HELLO__ => 'World', flip => [qw( flop blip )] },
        [qw( foo bar baz )],
    ], 'transformed docs are correct';
};

subtest 'overloaded operators' => sub {
    subtest 'configure source - <<' => sub {
        my $in_stream = ETL::Yertl::FormatStream->new(
            read_handle => $input->openr,
            format => ETL::Yertl::Format->get( 'yaml' ),
        );
        my $xform = ETL::Yertl::Transform->new(
            transform_doc => sub { $_ },
        );

        my $result = $xform << $in_stream;
        is $result, $xform, 'result of << is transform';
        is $xform->{source}, $in_stream, 'source is configured';
    };

    subtest 'configure destination - >>' => sub {
        my $tempfile = tempfile();
        my $out_stream = ETL::Yertl::FormatStream->new(
            write_handle => $tempfile->openw,
            autoflush => 1,
        );
        my $xform = ETL::Yertl::Transform->new(
            transform_doc => sub { $_ },
        );

        my $result = $xform >> $out_stream;
        is $result, $xform, 'result of >> is transform';
        is $xform->{destination}, $out_stream, 'destination is configured';
    };

    subtest 'combine transforms - |' => sub {
        my $xform_src = ETL::Yertl::Transform->new(
            transform_doc => sub { $_ },
        );
        my $xform = ETL::Yertl::Transform->new(
            transform_doc => sub { $_ },
        );

        my $result = $xform_src | $xform;
        is $result, $xform, 'result of | is right-side transform';
        is $xform->{source}, $xform_src, 'source is configured';
    };

    subtest 'source | transform' => sub {
        my $in_stream = ETL::Yertl::FormatStream->new(
            read_handle => $input->openr,
            format => ETL::Yertl::Format->get( 'yaml' ),
        );
        my $xform = ETL::Yertl::Transform->new(
            transform_doc => sub { $_ },
        );

        my $result = $in_stream | $xform;
        is $result, $xform, 'result of | is right-side transform';
        is $xform->{source}, $in_stream, 'source is configured';
    };
};

done_testing;
