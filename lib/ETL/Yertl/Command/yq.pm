package ETL::Yertl::Command::yq;
our $VERSION = '0.041';
# ABSTRACT: Filter and construct documents using a mini-language

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use boolean qw( :all );
use Module::Runtime qw( use_module );
our $VERBOSE = $ENV{YERTL_VERBOSE} // 0;
use IO::Async::Loop;
use ETL::Yertl::Format;
use ETL::Yertl::FormatStream;
use ETL::Yertl::LineStream;
use ETL::Yertl::Transform::Yq;

sub is_empty {
    return !$_[0] || ref $_[0] eq 'empty';
}

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my ( $filter, @files ) = @_;

    die "Must give a filter\n" unless $filter;

    my $output = $opt{xargs} 
               ? ETL::Yertl::LineStream->new_for_stdout( autoflush => 1 )
               : stdout();

    my $xform = ETL::Yertl::Transform::Yq->new(
        filter => $filter,
        destination => $output,
    );

    my $loop = IO::Async::Loop->new;
    $loop->add( $xform );

    push @files, "-" unless @files;
    for my $file ( @files ) {

        # We're doing a similar behavior to <>, but manually for easier testing.
        my $in;
        if ( $file eq '-' ) {
            $in = ETL::Yertl::FormatStream->new_for_stdin;
        }
        else {
            open my $fh, '<', $file or do {
                warn "Could not open file '$file' for reading: $!\n";
                next;
            };
            $in = ETL::Yertl::FormatStream->new( read_handle => $fh );
        }
        $loop->add( $in );

        $xform->configure( source => $in );
        $xform->run;
    }
}

1;
__END__

=head1 SYNOPSIS

    ### On a shell...
    $ yq [-v] <script> [<file>...]
    $ yq [-h|--help|--version]

    ### In Perl...
    use ETL::Yertl;
    yq( '<script>', '<filename>', { verbose => 1 } );

=head1 DESCRIPTION

=head1 ARGUMENTS

=head1 OPTIONS

