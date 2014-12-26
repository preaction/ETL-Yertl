package ETL::Yertl::Format::json;
# ABSTRACT: JSON read/write support for Yertl

use ETL::Yertl 'Class';
use Module::Runtime qw( use_module );
use List::Util qw( pairs pairkeys pairfirst );

=attr format_module

The module being used for this format. Possible modules, in order of importance:

=over 4

=item L<JSON::XS> (any version)

=item L<JSON::PP> (any version)

=back

=cut

# Pairs of module => supported version
our @FORMAT_MODULES = (
    'JSON::XS' => 0,
    'JSON::PP' => 0,
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
        die "Could not load a formatter for JSON. Please install one of the following modules:\n"
            . join "",
                map { sprintf "\t%s (%s)", $_->[0], $_->[1] ? "version $_->[1]" : "Any version" }
                pairs @FORMAT_MODULES;
    },
);


# Hash of MODULE => formatter sub
my %FORMAT_SUB = (

    'JSON::XS' => {
        to => sub {
            my $self = shift;
            state $json = JSON::XS->new->canonical->pretty->allow_nonref;
            return join( "", map { $json->encode( $_ ) } @_ );
        },
        from => sub {
            my $self = shift;
            state $json = JSON::XS->new->relaxed;
            return $json->incr_parse( @_ );
        },
    },

    'JSON::PP' => {
        to => sub {
            my $self = shift;
            state $json = JSON::PP->new->canonical->pretty->indent_length(3)->allow_nonref;
            return join "", map { $json->encode( $_ ) } @_;
        },
        from => sub {
            my $self = shift;
            state $json = JSON::PP->new->relaxed;
            require Storable;
            local $Storable::canonical = 1;

            # Work around a bug in JSON::PP.
            # incr_parse() only returns the first item, see: https://github.com/makamaka/JSON-PP/pull/7
            my @objs = $json->incr_parse( @_ );
            if ( scalar @objs == 1 ) {
                my @more_objs = $json->incr_parse( @_ );
                while ( Storable::freeze( $objs[0] ) ne Storable::freeze( $more_objs[0] ) ) {
                    push @objs, @more_objs;
                    @more_objs = $json->incr_parse( @_ );
                    last if !@more_objs;
                }
            }

            return @objs;
        },
    },

);

=method to( DOCUMENTS )

Convert the given C<DOCUMENTS> to JSON. Returns a JSON string.

=cut

sub to {
    my $self = shift;
    return $FORMAT_SUB{ $self->format_module }{to}->( $self, @_ );
}

=method from( JSON )

Convert the given C<JSON> string into documents. Returns the list of values extracted.

=cut

sub from {
    my $self = shift;
    return $FORMAT_SUB{ $self->format_module }{from}->( $self, @_ );
}

1;
__END__

=head1 SYNOPSIS

