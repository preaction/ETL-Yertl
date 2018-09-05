
=head1 DESCRIPTION

This simple transform adds a C<__HELLO__> key to any document hash that passes
through it. This is used by tests.

=cut

package Local::AddHello;
use ETL::Yertl;
use base 'ETL::Yertl::Transform';

sub configure {
    my ( $self, %args ) = @_;
    $self->{foo} = delete $args{foo} if $args{foo};
    return $self->SUPER::configure( %args );
}

sub transform_doc {
    my ( $self, $doc ) = @_;
    if ( ref $doc eq 'HASH' ) {
        $doc->{__HELLO__} = "World";
    }
    $self->write( $doc );
}

1;
