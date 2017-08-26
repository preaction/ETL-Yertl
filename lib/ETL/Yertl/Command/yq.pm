package ETL::Yertl::Command::yq;
our $VERSION = '0.032';
# ABSTRACT: Filter and construct documents using a mini-language

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use boolean qw( :all );
use Module::Runtime qw( use_module );
our $VERBOSE = $ENV{YERTL_VERBOSE} // 0;

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

    push @files, "-" unless @files;
    for my $file ( @files ) {
        # We're doing a similar behavior to <>, but manually for easier testing.
        my $fh;
        if ( $file eq '-' ) {
            # Use the existing STDIN so tests can fake it
            $fh = \*STDIN;
        }
        else {
            unless ( open $fh, '<', $file ) {
                warn "Could not open file '$file' for reading: $!\n";
                next;
            }
        }

        my $in_fmt = load_module( format => 'default' )->new( input => $fh );
        my $scope = {};
        for my $doc ( $in_fmt->read ) {
            my @output = $class->filter( $filter, $doc, $scope );
            $class->write( \@output, \%opt );
        }

        # Finish the scope, cleaning up any collections
        $class->write( [ $class->finish( $scope ) ], \%opt );
    }
}

sub write {
    my ( $class, $docs, $opt ) = @_;

    if ( $opt->{xargs} ) {
        print "$_\n" for grep { defined } @$docs;
        return;
    }

    my $out_fmt = load_module( format => 'default' )->new;
    for my $doc ( @$docs ) {
        next if is_empty( $doc );
        if ( isTrue( $doc ) ) {
            print $out_fmt->write( "true" );
        }
        elsif ( isFalse( $doc ) ) {
            print $out_fmt->write( "false" );
        }
        else {
            print $out_fmt->write( $doc );
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

