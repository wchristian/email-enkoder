use strictures;

package Email::Enkoder;

use 5.010;
use Sub::Exporter::Simple qw' enkode enkode_mail ';
use utf8;

# VERSION

# ABSTRACT: obfuscate email or html with randomized javascript

# COPYRIGHT

my $default_enkoders = [
    {
        perl => sub { reverse @_ },
        js   => ";kode=kode.split('').reverse().join('')",
    },
    {
        perl => sub {
            my ( $string ) = @_;
            for my $i ( 0 .. ( length( $string ) / 2 - 1 ) ) {
                $i *= 2;
                my $left = substr $string, $i, 1;
                my $right = substr $string, $i + 1, 1;
                substr $string, $i, 1, $right;
                substr $string, $i + 1, 1, $left;
            }
            return $string;
        },
        js => (
                ";x='';for(i=0;i<(kode.length-1);i+=2){"
              . "x+=kode.charAt(i+1)+kode.charAt(i)"
              . "}kode=x+(i<kode.length?kode.charAt(kode.length-1):'');"
        )
    },
    {
        perl => sub {
            my ( $str ) = @_;
            my @chars = split //, $str;
            for ( @chars ) {
                my $ord = ord $_;
                $ord += 3;
                $_ = chr $ord;
            }
            my $result = join '', @chars;
            return $result;
        },
        js => (
            ";x='';for(i=0;i<kode.length;i++){"    #
              . "c=kode.charCodeAt(i)-3;x+=String.fromCharCode(c)"
              . "}kode=x"
        )
    },
];

sub enkoders { $default_enkoders }

sub enkode_mail {
    my ( $email, $link_text, $options ) = @_;

    $_ = defined $_ ? qq| $_|         : '' for $options->{link_attributes};
    $_ = defined $_ ? qq|?subject=$_| : '' for $options->{subject};

    $email = qq|<a href="mailto:$email$options->{subject}"$options->{link_attributes}>$link_text</a>|;
    my $link = enkode( $email, $options );

    return $link;
}

sub enkode {
    my ( $html, $options ) = @_;

    $options->{enkoders}   ||= enkoders();
    $options->{max_length} ||= 1024;

    my $js = js_dbl_quote( $html );
    $js = qq|document.write($js);|;

    $options->{max_length} = 1 + length $js if $options->{max_length} <= length $js;

    my $script_html;

    while ( $options->{max_length} > length $js ) {
        my $idx = $options->{enkoder_index} // int rand @{ $options->{enkoders} };
        $js = $options->{enkoders}[$idx]{perl}->( $js );
        $js = js_dbl_quote( $js );
        $js = qq|kode=$js$options->{enkoders}[$idx]{js}|;
        my $js_variable = js_wrap_quote( js_dbl_quote( $js ), 79 );

        $script_html = qq|
            <script type="text/javascript">
            /* <![CDATA[ */
            function perl_enkoder(){var kode=
            $js_variable
            ;var i,c,x;while(eval(kode));}perl_enkoder();
            /* ]]> */
            </script>
        |;
        $script_html =~ s/^ +//mg;
        last if length $script_html > $options->{max_length};
    }

    return $script_html;
}

sub js_wrap_quote {
    my ( $str, $max_line_length ) = @_;

    $max_line_length -= 3;
    my $inQ;
    my $esc     = 0;
    my $lineLen = 0;
    my $result  = '';
    my $chunk   = '';

    while ( length $str ) {
        my $chunk = '';
        if ( $str =~ /^\\[0-7]{3}/ ) {
            $chunk = substr $str, 0, 4;
            substr $str, 0, 4, '';
        }
        elsif ( $str =~ /^\\./ ) {
            $chunk = substr $str, 0, 2;
            substr $str, 0, 2, '';
        }
        else {
            $chunk = substr $str, 0, 1;
            substr $str, 0, 1, '';
        }

        if ( ( $lineLen + length $chunk ) >= $max_line_length ) {
            $result .= qq|"+\n"|;
            $lineLen = 1;
        }

        $lineLen += length $chunk;
        $result .= $chunk;
    }

    return $result;
}

sub js_dbl_quote {
    my ( $in ) = @_;
    $in =~ s/([\\"])/\\$1/g;
    return qq|"$in"|;
}

1;
