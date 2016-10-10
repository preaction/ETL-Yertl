package ETL::Yertl::Command::yq::Regex;
our $VERSION = "0.028";
# ABSTRACT: A regex-based parser for programs

use ETL::Yertl;
use boolean qw( :all );
use Regexp::Common;

sub empty() {
    bless {}, 'empty';
}

sub is_empty($) {
    return ref $_[0] eq 'empty';
}

*diag = *yertl::diag;

my $QUOTE_STRING = $RE{delimited}{-delim=>q{'"}};
my $EVAL_NUMS = qr{(?:0b$RE{num}{bin}|0$RE{num}{oct}|0x$RE{num}{hex})};

# Match a document path
my $FILTER = qr{
        [.] # entire document
        |
        (?:[.](?:\w+|\[\d*\]))+ # hash/array lookup
        |
        $QUOTE_STRING
        |
        $RE{num}{real}|$EVAL_NUMS
        |
        \w+ # Constant/bareword
    }x;
my $OP = qr{eq|ne|==|!=|>=?|<=?};
my $FUNC_NAME = qr{empty|select|grep|group_by|keys|length|sort};
my $EXPR = qr{
    \{(\s*$FILTER\s*:\s*(?0)\s*(?:,(?-1))*)\} # Hash constructor
    |
    \[(\s*(?0)\s*(?:,(?-1))*)\] # Array constructor
    |
    $FUNC_NAME(?:\(\s*(?0)\s*\))? # Function with optional argument
    |
    $FILTER\s+$OP\s+$FILTER # Binary operator
    |
    $FILTER
}x;
my $PIPE = qr{[|]};

# Filter MUST NOT mutate $doc!
sub filter {
    my ( $class, $filter, $doc, $scope ) = @_;

    # Pipes: LEFT | RIGHT pipes the output of LEFT to the input of RIGHT
    if ( $filter =~ $PIPE ) {
        my @exprs = split /\s*$PIPE\s*/, $filter;
        my @in = ( $doc );
        for my $expr ( @exprs ) {
            my @out = ();
            for my $doc ( @in ) {
                push @out, $class->filter( $expr, $doc, $scope );
            }
            @in = @out;
        }
        return @in;
    }
    # Hash constructor
    elsif ( $filter =~ /^{/ ) {
        my %out;
        my ( $inner ) = $filter =~ /^\{\s*([^\}]+?)\s*\}$/;
        for my $pair ( split /\s*,\s*/, $inner ) {
            my ( $key_filter, $value_expr ) = split /\s*:\s*/, $pair;
            my $key = $class->filter( $key_filter, $doc );
            $out{ $key } = $class->filter( $value_expr, $doc );
        }
        return \%out;
    }
    # Array constructor
    elsif ( $filter =~ /^\[/ ) {
        my @out;
        my ( $inner ) = $filter =~ /^\[\s*([^\]]+?)\s*\]$/;
        for my $value_expr ( split /\s*,\s*/, $inner ) {
            push @out, $class->filter( $value_expr, $doc );
        }
        return \@out;
    }
    # , does multiple filters, yielding multiple documents
    elsif ( $filter =~ /,/ ) {
        my @filters = split /\s*,\s*/, $filter;
        return map { $class->filter( $_, $doc ) } @filters;
    }
    # Function calls
    elsif ( $filter =~ /^($FUNC_NAME)(?:\(\s*($EXPR)\s*\))?$/ ) {
        my ( $func, $expr ) = ( $1, $2 );
        diag( 1, "F: $func, ARG: " . ( $expr || '' ) );
        if ( $func eq 'empty' ) {
            if ( $expr ) {
                warn "empty does not take arguments\n";
            }
            return empty;
        }
        elsif ( $func eq 'select' || $func eq 'grep' ) {
            if ( !$expr ) {
                warn "'$func' takes an expression argument";
                return empty;
            }
            return $class->filter( $expr, $doc ) ? $doc : empty;
        }
        elsif ( $func eq 'group_by' ) {
            my $grouping = $class->filter( $expr, $doc );
            push @{ $scope->{ group_by }{ $grouping } }, $doc;
            return;
        }
        elsif ( $func eq 'sort' ) {
            $expr ||= '.';
            my $value = $class->filter( $expr, $doc );
            push @{ $scope->{sort} }, [ "$value", $doc ];
            return;
        }
        elsif ( $func eq 'keys' ) {
            $expr ||= '.';
            my $value = $class->filter( $expr, $doc );
            if ( ref $value eq 'HASH' ) {
                return [ keys %$value ];
            }
            elsif ( ref $value eq 'ARRAY' ) {
                return [ 0..$#{ $value } ];
            }
            else {
                warn "keys() requires a hash or array";
                return empty;
            }
        }
        elsif ( $func eq 'length' ) {
            $expr ||= '.';
            my $value = $class->filter( $expr, $doc );
            if ( ref $value eq 'HASH' ) {
                return scalar keys %$value;
            }
            elsif ( ref $value eq 'ARRAY' ) {
                return scalar @$value;
            }
            elsif ( !ref $value ) {
                return length $value;
            }
            else {
                warn "length() requires a hash, array, string, or number";
                return empty;
            }
        }
    }
    # Hash and array keys to traverse the data structure
    elsif ( $filter =~ /^($FILTER)$/ ) {
        # Extract quoted strings
        if ( $filter =~ /^(['"])(.+)(\1)$/ ) {
            return $2;
        }
        # Eval numbers to allow bin, hex, and oct
        elsif ( $filter =~ /^$EVAL_NUMS$/ ) {
            ## no critic ( ProhibitStringyEval )
            return eval $filter;
        }
        # Constants/barewords do not begin with .
        elsif ( $filter !~ /^[.]/ ) {
            # If it's not a reserved word, it's a string
            # XXX: This is a very poor decision...
            return $filter;
        }

        if ( is_empty $doc ) {
            return empty;
        }

        my @keys = split /[.]/, $filter;
        my $subdoc = $doc;
        for my $key ( @keys[1..$#keys] ) {
            if ( $key =~ /^\[\]$/ ) {
                return @{ $subdoc };
            }
            elsif ( $key =~ /^\[(\d+)\]$/ ) {
                $subdoc = $subdoc->[ $1 ];
            }
            elsif ( $key =~ /^\w+$/ ) {
                $subdoc = $subdoc->{ $key };
            }
            else {
                die "Invalid filter key '$key'";
            }
        }
        return $subdoc;
    }
    # Binary operators
    elsif ( $filter =~ /^($FILTER)\s+($OP)\s+($FILTER)$/ ) {
        my ( $lhs_filter, $cond, $rhs_filter ) = ( $1, $2, $3 );
        my $lhs_value = $class->filter( $lhs_filter, $doc );
        my $rhs_value = $class->filter( $rhs_filter, $doc );
        diag( 1, join " ", "BINOP:", $lhs_value // '<undef>', $cond, $rhs_value // '<undef>' );
        # These operators suppress undef warnings, treating undef as just
        # another value. Undef will never be treated as '' or 0 here.
        if ( $cond eq 'eq' ) {
            return defined $lhs_value == defined $rhs_value 
                && $lhs_value eq $rhs_value ? true : false;
        }
        elsif ( $cond eq 'ne' ) {
            return defined $lhs_value != defined $rhs_value
                || $lhs_value ne $rhs_value ? true : false;
        }
        elsif ( $cond eq '==' ) {
            return defined $lhs_value == defined $rhs_value
                && $lhs_value == $rhs_value ? true : false;
        }
        elsif ( $cond eq '!=' ) {
            return defined $lhs_value != defined $rhs_value
                || $lhs_value != $rhs_value ? true : false;
        }
        # These operators allow undef warnings, since equating undef to 0 or ''
        # can be a cause of problems.
        elsif ( $cond eq '>' ) {
            return $lhs_value > $rhs_value ? true : false;
        }
        elsif ( $cond eq '>=' ) {
            return $lhs_value >= $rhs_value ? true : false;
        }
        elsif ( $cond eq '<' ) {
            return $lhs_value < $rhs_value ? true : false;
        }
        elsif ( $cond eq '<=' ) {
            return $lhs_value <= $rhs_value ? true : false;
        }
    }
    # Conditional (if/then/else)
    # NOTE: If we're capturing using $EXPR, then we _must_ use named captures,
    # because $EXPR has captures in itself
    elsif ( $filter =~ /^if\s+(?<expr>$EXPR)\s+then\s+(?<true>$FILTER)(?:\s+else\s+(?<false>$FILTER))?$/ ) {
        my ( $expr, $true_filter, $false_filter ) = @+{qw( expr true false )};
        my $expr_value = $class->filter( $expr, $doc );
        if ( $expr_value ) {
            return $class->filter( $true_filter, $doc );
        }
        else {
            return $false_filter ? $class->filter( $false_filter, $doc ) : ();
        }
    }
    else {
        die "Could not parse filter '$filter'\n";
    }
    return;
}

1;

