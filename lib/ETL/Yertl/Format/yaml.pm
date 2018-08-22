package ETL::Yertl::Format::yaml;
our $VERSION = '0.038';
# ABSTRACT: YAML read/write support for Yertl

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

L<ETL::Yertl::FormatStream>

=cut

use ETL::Yertl;
use base 'ETL::Yertl::Format';

sub new {
    my ( $class, @args ) = @_;
    my $self = $class->SUPER::new( @args );
    no strict 'refs';
    $self->{_load} = \&{ $self->{formatter_class} . '::Load' };
    $self->{_dump} = \&{ $self->{formatter_class} . '::Dump' };
    return $self;
}

sub _formatter_classes {
    return (
        [ 'YAML::XS' => 0 ],
        [ 'YAML::Syck' => 0 ],
        # [ 'YAML' => 0 ], # Disabled: YAML::Old changes have broke something here...
        [ 'YAML::Tiny' => 0 ],
    );
}

sub read_buffer {
    my ( $self, $buffref, $eof ) = @_;
    if ( $$buffref =~ s/(.+(?:\n---[^\n]*\n|\Z))//s ) {
        my @docs = $self->{_load}->( $1 );
        return @docs;
    }
}

sub format {
    my ( $self, $doc ) = @_;
    return $self->{_dump}->( $doc );
}

1;
