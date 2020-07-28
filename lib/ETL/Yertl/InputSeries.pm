package ETL::Yertl::InputSeries;
our $VERSION = '0.045';
# ABSTRACT: Read a series of input streams

=head1 SYNOPSIS

    use ETL::Yertl;
    use ETL::Yertl::InputSeries;
    my $series = ETL::Yertl::InputSeries->new(
        streams => [ \*STDIN, "/path/to/file.yaml" ],
        on_doc => sub {
            my ( $self, $doc, $eof ) = @_;
            # ... do something with $doc
        },
        on_child_eof => sub {
            my ( $self ) = @_;
            say STDERR "Switching stream";
        },
        on_read_eof => sub {
            my ( $self ) = @_;
            # All streams have been exhausted
            $self->loop->stop;
        },
    );

    use IO::Async::Loop;
    my $loop = IO::Async::Loop->new;
    $loop->add( $series );
    $loop->run;

=head1 DESCRIPTION

This module reads a series of input streams in the default format
(determined by L<ETL::Yertl::Format/get_default>). Input streams can be
filehandles (like C<STDIN>) or paths to files.

=head1 SEE ALSO

L<ETL::Yertl::FormatStream>

=cut

use ETL::Yertl;
use base 'IO::Async::Notifier';
use Carp qw( croak );
use Scalar::Util qw( weaken );

sub configure {
    my ( $self, %args ) = @_;

    # Args to pass to streams as we create them
    # XXX: This is why I would prefer already having the streams
    # created!
    for my $arg ( qw( format ) ) {
        $self->{stream_args}{ $arg } = delete $args{ $arg } if $args{ $arg };
    }

    if ( my $streams = delete $args{streams} ) {
        # TODO: Support any kind of Yertl input stream. Stream must not
        # yet be added to a loop, otherwise it will start producing
        # events we're not ready to handle yet (I think)
        if ( grep { ref $_ && ref $_ ne 'GLOB' } @$streams ) {
            croak "InputSeries streams must be file paths or filehandles";
        }
        $self->{streams} = $streams;
    }
    for my $event ( qw( on_doc on_read_eof on_child_read_eof ) ) {
        $self->{ $event } = delete $args{ $event } if exists $args{ $event };
    }

    return $self->SUPER::configure( %args );
}

sub _add_to_loop {
    my ( $self ) = @_;
    $self->can_event( "on_doc" )
        or croak "Expected either an on_doc callback or to be able to ->on_doc";
    $self->_shift_stream;
}

sub _shift_stream {
    my ( $self ) = @_;
    weaken $self;
    my $stream = shift @{ $self->{streams} };
    my $fh;
    if ( !ref $stream ) {
        open $fh, '<', $stream or die "Could not open $stream for reading: $!";
    }
    elsif ( ref $stream eq 'GLOB' ) {
        $fh = $stream;
    }
    else {
        die "Unknown stream type '$stream': Should be path or filehandle";
    }

    my $current_stream = $self->{current_stream} = ETL::Yertl::FormatStream->new(
        %{ $self->{stream_args} },
        read_handle => $fh,
        on_doc => sub {
            my ( undef, $doc, $eof ) = @_;
            $self->invoke_event( on_doc => $doc, $eof );
        },
        on_read_eof => sub { $self->_on_child_read_eof },
    );
    $self->add_child( $current_stream );
}

sub _on_child_read_eof {
    my ( $self ) = @_;
    $self->remove_child( $self->{current_stream} );
    $self->maybe_invoke_event( 'on_child_read_eof' );
    if ( !@{ $self->{streams} } ) {
        $self->maybe_invoke_event( 'on_read_eof' );
        return;
    }
    $self->_shift_stream;
}

1;
