package ETL::Yertl::Format::csv;
our $VERSION = '0.041';
# ABSTRACT: CSV read/write support for Yertl

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

L<ETL::Yertl::FormatStream>

=cut

use ETL::Yertl;
use base 'ETL::Yertl::Format';

sub new {
    my ( $class, %opt ) = @_;
    $opt{delimiter} ||= ',';
    return $class->SUPER::new( %opt );
}

sub _formatter_classes {
    return (
        [ 'Text::CSV_XS' => 0 ],
        [ 'Text::CSV' => 0 ],
    );
}

sub _formatter {
    my ( $self ) = @_;
    return $self->{formatter_class}->new( { sep_char => $self->{delimiter} } );
}

sub read_buffer {
    my ( $self, $buffref, $eof ) = @_;
    my $csv = $self->_formatter;
    my $names = $self->{_field_names} ||= [];
    my @docs;
    while ( $$buffref =~ s/^(.*\n)// ) {
        my $line = $1;
        if ( !@$names ) {
            $csv->parse( $line );
            @$names = $csv->fields;
            next;
        }

        my $status = $csv->parse( $line );
        my @fields = $csv->fields;
        my $doc = {
            map {; $names->[ $_ ] => $fields[ $_ ] }
            0..$#fields
        };
        push @docs, $doc;
    }
    return @docs;
}

sub format {
    my ( $self, $doc ) = @_;
    my $csv = $self->_formatter;

    my $names = $self->{_field_names} ||= [];
    if ( !@$names ) {
        @$names = sort keys %$doc;
    }

    my $str = '';
    if ( !$self->{_wrote_header} ) {
        $csv->combine( @$names );
        $str .= $csv->string . $/;
        $self->{_wrote_header} = 1;
    }

    $csv->combine( map { $doc->{ $_ } } @$names );
    $str .= $csv->string . $/;

    return $str;
}

1;
