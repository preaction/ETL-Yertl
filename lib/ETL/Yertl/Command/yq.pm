package ETL::Yertl::Command::yq;
our $VERSION = '0.038';
# ABSTRACT: Filter and construct documents using a mini-language

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use boolean qw( :all );
use Module::Runtime qw( use_module );
our $VERBOSE = $ENV{YERTL_VERBOSE} // 0;
use IO::Async::Loop;
use ETL::Yertl::Format;
use ETL::Yertl::FormatStream;

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

    my $loop = IO::Async::Loop->new;

    push @files, "-" unless @files;
    for my $file ( @files ) {

        # We're doing a similar behavior to <>, but manually for easier testing.
        my $scope = {};
        my %args = (
            on_doc => sub {
                my ( $self, $doc, $eof ) = @_;
                #; say STDERR "Got doc: " . $doc;
                return unless $doc; # XXX: This shouldn't be happening, but it is
                my @output = $class->filter( $filter, $doc, $scope );
                $class->write( \@output, \%opt );
            },
            on_read_eof => sub {
                # Finish the scope, cleaning up any collections
                $class->write( [ $class->finish( $scope ) ], \%opt );
                $loop->stop;
            },
        );
        my $in;
        if ( $file eq '-' ) {
            $in = ETL::Yertl::FormatStream->new_for_stdin( %args );
        }
        else {
            open my $fh, '<', $file or do {
                warn "Could not open file '$file' for reading: $!\n";
                next;
            };
            $in = ETL::Yertl::FormatStream->new(
                read_handle => $fh,
                %args,
            );
        }
        $loop->add( $in );
        $loop->run;

    }
}

sub write {
    my ( $class, $docs, $opt ) = @_;

    if ( $opt->{xargs} ) {
        print "$_\n" for grep { defined } @$docs;
        return;
    }

    my $format = ETL::Yertl::Format->get_default;
    for my $doc ( @$docs ) {
        next if is_empty( $doc );
        if ( isTrue( $doc ) ) {
            print $format->format( "true" );
        }
        elsif ( isFalse( $doc ) ) {
            print $format->format( "false" );
        }
        else {
            print $format->format( $doc );
        }
    }
}

$ENV{YQ_CLASS} ||= 'ETL::Yertl::Command::yq::Regex';
use_module( $ENV{YQ_CLASS} );
{
    no strict 'refs';
    no warnings 'once';
    *filter = *{ $ENV{YQ_CLASS} . "::filter" };
}

sub finish {
    my ( $class, $scope ) = @_;
    if ( $scope->{sort} ) {
        return map { $_->[1] } sort { $a->[0] cmp $b->[0] } @{ $scope->{sort} };
    }
    elsif ( $scope->{group_by} ) {
        return $scope->{group_by};
    }
    return;
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

