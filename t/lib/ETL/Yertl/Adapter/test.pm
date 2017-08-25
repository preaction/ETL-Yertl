package ETL::Yertl::Adapter::test;
# ABSTRACT: A test adapter for testing

our @READ;
our @READ_TS;
our @WRITE;
our @WRITE_TS;

sub new {
    my ( $class, @args ) = @_;
    return bless { args => \@args }, $class;
}

sub read {
    my ( $self, @args ) = @_;
    return @READ;
}

sub read_ts {
    my ( $self, @args ) = @_;
    return @READ_TS;
}

sub write {
    my ( $self, @args ) = @_;
    push @WRITE, @args;
}

sub write_ts {
    my ( $self, @args ) = @_;
    push @WRITE_TS, @args;
}

1;
