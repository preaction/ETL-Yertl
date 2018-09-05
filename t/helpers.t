
=head1 DESCRIPTION

This tests the helper functions from L<ETL::Yertl> module, including
C<stdin>, C<stdout>, C<file>, C<transform>, and C<loop>.

=cut

use ETL::Yertl 'Test', 'loop';
use ETL::Yertl::Transform;
use Test::Lib;
my $SHARE_DIR = path( __DIR__, 'share' );

my $loop;
subtest 'loop' => sub {
    $loop = loop();
    isa_ok $loop, 'IO::Async::Loop', 'loop() returns loop';
    is loop(), $loop, 'loop() returns same loop';
};

subtest 'transform' => sub {

    subtest 'transform class' => sub {
        my $xform = transform( 'Local::AddHello' => foo => 3 );
        isa_ok $xform, 'Local::AddHello', 'transform helper loads class';
        is $xform->{foo}, 3, 'configure args are correct';
        is $xform->loop, $loop, 'Transform has loop singleton';
    };

    subtest 'transform sub' => sub {
        my $sub = sub { $_ };
        my $xform = transform( $sub );
        isa_ok $xform, 'ETL::Yertl::Transform', 'transform helper';
        is $xform->{transform_doc}, $sub, 'transform subref is correct';
        is $xform->loop, $loop, 'Transform has loop singleton';
    };

};

subtest 'stdin' => sub {
    my $stdin = stdin();
    isa_ok $stdin, 'ETL::Yertl::FormatStream', 'helper returns';
    is $stdin->{read_handle}, \*STDIN, 'read_handle is STDIN';
    isa_ok $stdin->{format}, 'ETL::Yertl::Format::yaml', 'format object';
    is $stdin->loop, $loop, 'stream has loop singleton';

    subtest 'with format' => sub {
        my $stdin = stdin( format => 'json' );
        isa_ok $stdin, 'ETL::Yertl::FormatStream', 'helper returns';
        is $stdin->{read_handle}, \*STDIN, 'read_handle is STDIN';
        isa_ok $stdin->{format}, 'ETL::Yertl::Format::json', 'format object';
        is $stdin->loop, $loop, 'stream has loop singleton';
    };
};

subtest 'stdout' => sub {
    my $stdout = stdout();
    isa_ok $stdout, 'ETL::Yertl::FormatStream', 'helper returns';
    is $stdout->{write_handle}, \*STDOUT, 'write_handle is STDOUT';
    isa_ok $stdout->{format}, 'ETL::Yertl::Format::yaml', 'format object';
    is $stdout->loop, $loop, 'stream has loop singleton';

    subtest 'with format' => sub {
        my $stdout = stdout( format => 'json' );
        isa_ok $stdout, 'ETL::Yertl::FormatStream', 'helper returns';
        is $stdout->{write_handle}, \*STDOUT, 'write_handle is STDOUT';
        isa_ok $stdout->{format}, 'ETL::Yertl::Format::json', 'format object';
        is $stdout->loop, $loop, 'stream has loop singleton';
    };
};

subtest 'file' => sub {
    subtest 'read file' => sub {
        my $input = $SHARE_DIR->child( yaml => 'test.yaml' );
        my $file = file( '<', "$input" );
        isa_ok $file, 'ETL::Yertl::FormatStream', 'helper returns';
        ok $file->{read_handle}, 'read_handle exists';
        isa_ok $file->{format}, 'ETL::Yertl::Format::yaml', 'format object';
        is $file->loop, $loop, 'stream has loop singleton';

        subtest 'with format' => sub {
            my $file = file( '<', "$input", format => 'json' );
            isa_ok $file, 'ETL::Yertl::FormatStream', 'helper returns';
            ok $file->{read_handle}, 'read_handle exists';
            isa_ok $file->{format}, 'ETL::Yertl::Format::json', 'format object';
            is $file->loop, $loop, 'stream has loop singleton';
        };
    };

    subtest 'write file' => sub {
        my $tempfile = tempfile();
        my $file = file( '>', "$tempfile" );
        isa_ok $file, 'ETL::Yertl::FormatStream', 'helper returns';
        ok $file->{write_handle}, 'write_handle exists';
        isa_ok $file->{format}, 'ETL::Yertl::Format::yaml', 'format object';
        is $file->loop, $loop, 'stream has loop singleton';

        subtest 'with format' => sub {
            my $tempfile = tempfile();
            my $file = file( '>', "$tempfile", format => 'json' );
            isa_ok $file, 'ETL::Yertl::FormatStream', 'helper returns';
            ok $file->{write_handle}, 'write_handle exists';
            isa_ok $file->{format}, 'ETL::Yertl::Format::json', 'format object';
            is $file->loop, $loop, 'stream has loop singleton';
        };
    };
};

subtest 'yq' => sub {
    my $xform = yq( '.foo' );
    isa_ok $xform, 'ETL::Yertl::Transform::Yq';
    is $xform->{filter}, '.foo', 'filter is correct';
    is $xform->loop, $loop, 'xform has loop singleton';
};

done_testing;
