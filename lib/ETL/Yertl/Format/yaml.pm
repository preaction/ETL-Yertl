package ETL::Yertl::Format::yaml;
# ABSTRACT: YAML read/write support for Yertl

use ETL::Yertl 'Class';
use Module::Runtime qw( use_module );
use List::Util qw( pairs pairkeys pairfirst );

=attr format_module

The module being used for this format. Possible modules, in order of importance:

=over 4

=item L<YAML::XS> (any version)

=item L<YAML::Syck> (any version)

=item L<YAML> (any version)

=back

=cut

# Pairs of module => supported version
our @FORMAT_MODULES = (
    'YAML::XS' => 0,
    'YAML::Syck' => 0,
    'YAML' => 0,
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
        die "Could not load a formatter for YAML. Please install one of the following modules:\n"
            . join "",
                map { sprintf "\t%s (%s)", $_->[0], $_->[1] ? "version $_->[1]" : "Any version" }
                pairs @FORMAT_MODULES;
    },
);


# Hash of MODULE => formatter sub
my %FORMAT_SUB = (

    'YAML::XS' => {
        to => sub {
            my $self = shift;
            return YAML::XS::Dump( @_ );
        },

        from => sub {
            my $self = shift;
            return YAML::XS::Load( @_ );
        },

    },

    'YAML::Syck' => {
        to => sub {
            my $self = shift;
            return YAML::Syck::Dump( @_ );
        },

        from => sub {
            my $self = shift;
            return YAML::Syck::Load( @_ );
        },

    },

    'YAML' => {
        to => sub {
            my $self = shift;
            return YAML::Dump( @_ );
        },

        from => sub {
            my $self = shift;
            return YAML::Load( @_ );
        },

    },
);

=method to( DOCUMENTS )

Convert the given C<DOCUMENTS> to YAML. Returns a YAML string.

=cut

sub to {
    my $self = shift;
    return $FORMAT_SUB{ $self->format_module }{to}->( $self, @_ );
}

=method from( YAML )

Convert the given C<YAML> string into documents. Returns the list of values extracted.

=cut

sub from {
    my $self = shift;
    return $FORMAT_SUB{ $self->format_module }{from}->( $self, @_ );
}

1;
__END__


