package ETL::Yertl::Format::json;
our $VERSION = '0.038';
# ABSTRACT: JSON read/write support for Yertl

use ETL::Yertl;
use base 'ETL::Yertl::Format';
use Module::Runtime qw( use_module );
use ETL::Yertl::Util qw( pairs );

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

sub format_module {
    my ( $self ) = @_;
    return $self->{_format_module} if $self->{_format_module};
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
        . join( "",
            map { sprintf "\t%s (%s)", $_->[0], $_->[1] ? "version $_->[1]" : "Any version" }
            pairs @FORMAT_MODULES
        )
        . "\n";
}


# Hash of MODULE => formatter sub
my %FORMAT_SUB = (

    'JSON::XS' => {
        decode => sub {
            my ( $self, $msg ) = @_;
            state $json = JSON::XS->new->relaxed;
            return $json->decode( $msg );
        },
        write => sub {
            my $self = shift;
            state $json = JSON::XS->new->canonical->pretty->allow_nonref;
            return join( "", map { $json->encode( $_ ) } @_ );
        },
        read => sub {
            my $self = shift;
            state $json = JSON::XS->new->relaxed;
            return $json->incr_parse( do { local $/; readline $self->{input} } );
        },
    },

    'JSON::PP' => {
        decode => sub {
            my ( $self, $msg ) = @_;
            state $json = JSON::PP->new->relaxed;
            return $json->decode( $msg );
        },
        write => sub {
            my $self = shift;
            state $json = JSON::PP->new->canonical->pretty->indent_length(3)->allow_nonref;
            return join "", map { $json->encode( $_ ) } @_;
        },
        read => sub {
            my $self = shift;
            state $json = JSON::PP->new->relaxed;
            require Storable;
            local $Storable::canonical = 1;

            # Work around a bug in JSON::PP.
            # incr_parse() only returns the first item, see: https://github.com/makamaka/JSON-PP/pull/7
            my $text = do { local $/; readline $self->{input} };
            my @objs = $json->incr_parse( $text );
            if ( scalar @objs == 1 ) {
                my @more_objs = $json->incr_parse( $text );
                while ( Storable::freeze( $objs[0] ) ne Storable::freeze( $more_objs[0] ) ) {
                    push @objs, @more_objs;
                    @more_objs = $json->incr_parse( $text );
                    last if !@more_objs;
                }
            }

            return @objs;
        },
    },

);

=method write( DOCUMENTS )

Convert the given C<DOCUMENTS> to JSON. Returns a JSON string.

=cut

sub write {
    my $self = shift;
    return $FORMAT_SUB{ $self->format_module }{write}->( $self, @_ );
}

=method read()

Read a JSON string from L<input> and return all the documents

=cut

sub read {
    my $self = shift;
    return $FORMAT_SUB{ $self->format_module }{read}->( $self );
}

=method decode

    my $msg = $fmt->decode( $bytes );

Decode the given bytes into the given message. The bytes must contain
exactly one message to be decoded.

=cut

sub decode {
    my ( $self, $bytes ) = @_;
    return $FORMAT_SUB{ $self->format_module }{decode}->( $self, $bytes );
}

1;
__END__

=head1 SYNOPSIS

