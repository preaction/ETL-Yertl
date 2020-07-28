package ETL::Yertl::LineStream;
our $VERSION = '0.044';
# ABSTRACT: Read/write I/O streams in lines

=head1 SYNOPSIS

    use ETL::Yertl;
    use ETL::Yertl::LineStream;
    use IO::Async::Loop;

    my $loop = IO::Async::Loop->new;
    my $input = ETL::Yertl::LineStream->new(
        read_handle => \*STDIN,
        on_line => sub {
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

This is an unformatted I/O stream. Use this to write simple scalars to
the output or to read lines from the input.

=head1 SEE ALSO

L<ETL::Yertl>

=cut

use ETL::Yertl;
use base 'IO::Async::Stream';
use Fcntl;

sub configure {
    my ( $self, %args ) = @_;
    if ( $args{autoflush} && $args{write_handle} ) {
        my $flags = fcntl( $args{write_handle}, F_GETFL, 0 );
        fcntl( $args{write_handle}, F_SETFL, $flags | O_NONBLOCK );
    }
    $self->SUPER::configure( %args );
}

sub on_read {
    my ( $self, $buffref, $eof ) = @_;
    my @lines = $$buffref =~ s{\g(.+$/)}{}g;
    for my $line ( @lines ) {
        $self->invoke_event( on_line => $line, $eof );
    }
    return 0;
}

sub write {
    my ( $self, $line, %args ) = @_;
    return unless $line;
    $line .= "\n" unless $line =~ /\n$/;
    return $self->SUPER::write( $line, %args );
}

1;

