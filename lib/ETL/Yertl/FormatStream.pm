package ETL::Yertl::FormatStream;
our $VERSION = '0.039';
# ABSTRACT: Read/write I/O stream with Yertl formatters

=head1 SYNOPSIS

    use ETL::Yertl;
    use ETL::Yertl::FormatStream;
    use ETL::Yertl::Format;
    use IO::Async::Loop;

    my $loop = IO::Async::Loop->new;
    my $format = ETL::Yertl::Format->get( "json" );

    my $input = ETL::Yertl::FormatStream->new(
        read_handle => \*STDIN,
        format => $format,
        on_doc => sub {
            my ( $self, $doc, $eof ) = @_;

            # ... do something with $doc

            if ( $eof ) {
                $loop->stop;
            }
        },
    );

    $loop->add( $input );
    $loop->run;

=head1 DESCRIPTION

=head1 SEE ALSO

L<ETL::Yertl::Format>

=cut

use ETL::Yertl;
use base 'IO::Async::Stream';
use ETL::Yertl::Format;
use Carp qw( croak );

sub configure {
    my ( $self, %args ) = @_;

    $self->{format} = delete $args{format} || ETL::Yertl::Format->get_default;

    for my $event ( qw( on_doc ) ) {
        $self->{ $event } = delete $args{ $event } if exists $args{ $event };
    }
    if ( $self->read_handle ) {
        $self->can_event( "on_doc" )
            or croak "Expected either an on_doc callback or to be able to ->on_doc";
    }

    $self->SUPER::configure( %args );
}

sub on_read {
    my ( $self, $buffref, $eof ) = @_;
    my @docs = $self->{format}->read_buffer( $buffref, $eof );
    for my $doc ( @docs ) {
        $self->invoke_event( on_doc => $doc, $eof );
    }
    return 0;
}

sub write {
    my ( $self, $doc, @args ) = @_;
    my $str = $self->{format}->format( $doc );
    return $self->SUPER::write( $str, @args );
}

1;
