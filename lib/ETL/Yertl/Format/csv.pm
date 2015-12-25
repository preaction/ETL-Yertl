package ETL::Yertl::Format::csv;
# ABSTRACT: CSV read/write support for Yertl

use ETL::Yertl 'Class';
use Module::Runtime qw( use_module );
use List::Util qw( pairs pairkeys pairfirst );

=attr input

The filehandle to read from for input.

=cut

has input => (
    is => 'ro',
    isa => FileHandle,
);

=attr format_module

The module being used for this format. Possible modules, in order of importance:

=over 4

=item L<Text::CSV_XS> (any version)

=item L<Text::CSV> (any version)

=back

=cut

# Pairs of module => supported version
our @FORMAT_MODULES = (
    'Text::CSV_XS' => 0,
    'Text::CSV' => 0,
);

has format_module => (
    is => 'rw',
    isa => sub {
        my ( $format_module ) = @_;
        die "format_module must be one of: " . join( " ", pairkeys @FORMAT_MODULES ) . "\n"
            unless pairfirst { $a eq $format_module } @FORMAT_MODULES;
        eval {
            use_module( $format_module );
        };
        if ( $@ ) {
            die "Could not load format module '$format_module': $@";
        }
    },
    lazy => 1,
    default => sub {
        for my $format_module ( pairs @FORMAT_MODULES ) {
            eval {
                # Prototypes on use_module() make @$format_module not work correctly
                use_module( $format_module->[0], $format_module->[1] );
            };
            if ( !$@ ) {
                return $format_module->[0];
            }
        }
        die "Could not load a formatter for CSV. Please install one of the following modules:\n"
            . join( "",
                map { sprintf "\t%s (%s)", $_->[0], $_->[1] ? "version $_->[1]" : "Any version" }
                pairs @FORMAT_MODULES
            )
            . "\n";
    },
);

has _field_names => (
    is => 'rw',
    isa => ArrayRef[Str],
    default => sub { [] },
);

has _csv => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        $self->format_module->new({ binary => 1, eol => $\ });
    },
);

=method write( DOCUMENTS )

Convert the given C<DOCUMENTS> to CSV. Returns a CSV string.

=cut

sub write {
    my ( $self, @docs ) = @_;
    my $csv = $self->_csv;
    my $str = '';
    my @names = @{ $self->_field_names };

    if ( !@names ) {
        @names = sort keys %{ $docs[0] };
        $csv->combine( @names );
        $str .= $csv->string . $/;
        $self->_field_names( \@names );
    }

    for my $doc ( @docs ) {
        $csv->combine( map { $doc->{ $_ } } @names );
        $str .= $csv->string . $/;
    }

    return $str;
}

=method read()

Read a CSV string from L<input> and return all the documents.

=cut

sub read {
    my ( $self ) = @_;
    my $fh = $self->input || die "No input filehandle";
    my $csv = $self->_csv;
    my @names = @{ $self->_field_names };

    if ( !@names ) {
        @names = @{ $csv->getline( $fh ) };
        $self->_field_names( \@names );
    }

    my @docs;
    while ( my $row = $csv->getline( $fh ) ) {
        push @docs, { map {; $names[ $_ ] => $row->[ $_ ] } 0..$#{ $row } };
    }

    return @docs;
}

1;
__END__

