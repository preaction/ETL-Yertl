package ETL::Yertl::Format::csv;
# ABSTRACT: CSV read/write support for Yertl

use ETL::Yertl 'Class';
use Module::Runtime qw( use_module );
use List::Util qw( pairs pairkeys pairfirst );
use Text::Trim qw( ltrim );

=attr trim

If true, trim off leading whitespace from the cells. Defaults to true.

Some CSV documents are formatted to line up the commas for easy visual
scanning. This removes that whitespace.

=cut

has trim => (
    is => 'ro',
    isa => Bool,
    default => sub { 1 },
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
        die "format_module must be one of: " . join " ", pairkeys @FORMAT_MODULES
            unless pairfirst { $a eq $format_module } @FORMAT_MODULES;
        eval {
            use_module( $format_module );
        };
        if ( $@ ) {
            die "Could not load format module '$format_module'";
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
            . join "",
                map { sprintf "\t%s (%s)", $_->[0], $_->[1] ? "version $_->[1]" : "Any version" }
                pairs @FORMAT_MODULES;
    },
);


sub format_sub {
    # Since we use state variables to keep the headers, we need to build new subs
    # for every instance. This is not a good way to do this and we need to come
    # up with another one (caching on the object perhaps?)

    my ( $self ) = @_;

    # Hash of MODULE => formatter sub
    my %subs = (

        'Text::CSV_XS' => {
            to => sub {
                my $self = shift;
                state $csv = Text::CSV_XS->new;
                state @names;
                my $str;

                if ( !@names ) {
                    @names = sort keys %{ $_[0] };
                    $csv->combine( @names );
                    $str .= $csv->string . $/;
                }

                for my $doc ( @_ ) {
                    $csv->combine( map { $doc->{ $_ } } @names );
                    $str .= $csv->string . $/;
                }

                return $str;
            },

            from => sub {
                my $self = shift;
                state $csv = Text::CSV_XS->new;
                state @names;

                if ( !@names ) {
                    $csv->parse( shift );
                    @names = $csv->fields;
                }

                my @docs;
                for my $line ( @_ ) {
                    $csv->parse( $line );
                    my @values = $csv->fields;
                    my $doc = { map {; $names[ $_ ] => $values[ $_ ] } 0..$#values };

                    if ( $self->trim ) {
                        ltrim for values %$doc;
                    }

                    push @docs, $doc;
                }

                return @docs;
            },
        },

        'Text::CSV' => {
            to => sub {
                my $self = shift;
                state $csv = Text::CSV->new;
                state @names;
                my $str;

                if ( !@names ) {
                    @names = sort keys %{ $_[0] };
                    $csv->combine( @names );
                    $str .= $csv->string . $/;
                }

                for my $doc ( @_ ) {
                    $csv->combine( map { $doc->{ $_ } } @names );
                    $str .= $csv->string . $/;
                }

                return $str;
            },

            from => sub {
                my $self = shift;
                state $csv = Text::CSV->new;
                state @names;

                if ( !@names ) {
                    $csv->parse( shift );
                    @names = $csv->fields;
                }

                my @docs;
                for my $line ( @_ ) {
                    $csv->parse( $line );
                    my @values = $csv->fields;
                    my $doc = { map {; $names[ $_ ] => $values[ $_ ] } 0..$#values };

                    if ( $self->trim ) {
                        ltrim for values %$doc;
                    }

                    push @docs, $doc;
                }

                return @docs;
            },

        },
    );

    return $subs{ $self->format_module };
}

=method to( DOCUMENTS )

Convert the given C<DOCUMENTS> to CSV. Returns a CSV string.

=cut

sub to {
    my $self = shift;
    return $self->format_sub->{to}->( $self, @_ );
}

=method from( CSV )

Convert the given C<CSV> string into documents. Returns the list of values extracted.

=cut

sub from {
    my $self = shift;
    return $self->format_sub->{from}->( $self, @_ );
}

1;
__END__

