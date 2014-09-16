#!/usr/bin/env perl
use 5.008005;
use strict;
use warnings;
our $VERSION = "0.01";

use Cache::FileCache;
use XML::LibXML::Simple;
use URI;
use LWP::UserAgent;
use Lingua::EN::PluralToSingular 'to_singular';

my $lwp           = LWP::UserAgent->new( timeout => 10, agent => join '/', __PACKAGE__, $VERSION );
my $cache_version = 0.01;
my $cache         = Cache::FileCache->new({ namespace => __PACKAGE__ . $cache_version , default_expires_in => 12000 });
my $excluded_terms = qr/^(we|at|here|can|find|list|which|what|be|set|size|if|it|0|of|not|with|and|a|an|is|to|in|into|the|that|this|may|by|should|there|are|for|were|was|but|these|on|out|have|has|open)$/i;

sub search {
    my ($dic,$term) = @_;

    $cache->get($term) // do { 
        my $uri = URI->new('http://public.dejizo.jp/NetDicV09.asmx/SearchDicItemLite');
        $uri->query_form(
            Dic  => $dic,
            Scope => 'HEADWORD',
            Match => 'EXACT',
            Merge => 'AND',
            Prof  => 'XHTML',
            PageSize => 1,
            PageIndex => 0,
            word => $term,
        );

        my $res = $lwp->get($uri->as_string);
        my $ref = XML::LibXML::Simple->new->XMLin($res->decoded_content);

        if ( $ref->{TotalHitCount} ) {
            my $term_id = $ref->{TitleList}->{DicItemTitle}->{ItemID};
            $cache->set($term,$term_id);
            return $term_id;
        }
        else {
            return;
        }
    };
}

sub get_info {
    my ($dic,$item_id) = @_;

    $cache->get($item_id) // do { 
        my $uri = URI->new('http://public.dejizo.jp/NetDicV09.asmx/GetDicItemLite');
        $uri->query_form(
            Dic  => $dic,
            Prof  => 'XHTML',
            Loc   => '',
            Item  => $item_id,
        );

        my $res = $lwp->get($uri->as_string);
        my $ref = XML::LibXML::Simple->new->XMLin($res->decoded_content);

        $cache->set($item_id,$ref);

        return $ref;
    };
}


sub get_word {
    my ($dic,$term) = @_;

    die "dic: $dic" unless $dic =~ /^EJdict|wpedia$/;

    my $item_id = search($dic => $term) or return;

    my $info = get_info($dic => $item_id);                    
    if( $dic eq 'EJdict' ) {
        return $info->{Body}->{div}->{div} 
            ? $info->{Body}->{div}->{div}
            : undef;
    }
    elsif( $dic eq 'wpedia' ) {
        if( ref($info->{Body}->{div}->{div}) eq 'HASH' && ( my $doc = $info->{Body}->{div}->{div}->{span}->{content} ) ) {
            return $doc;
        }
        elsif( ref($info->{Body}->{div}->{div}) eq 'ARRAY' ) {
            my @content;
            for my $span ( @{$info->{Body}->{div}->{div}} ) {
                if( ref($span) eq 'ARRAY' ) {
                    for my $row ( @{$span} ) {
                        push @content, $row->{content};
                    }
                }
                elsif( ref($span->{ul}) eq 'HASH' && ref($span->{ul}->{li}) eq 'ARRAY' ) {
                    for my $row ( @{$span->{ul}->{li}} ) {
                        push @content, ( ref($row) eq 'HASH' ) 
                            ? ( ( ref($row->{span}) eq 'HAHS' ) ? $row->{span}->{content} : $row )
                            : $row; 
                    }
                }
            }
            return join ',', @content;
        }
        else {
            return;
        }

    }
}


sub run {

    my %terms;
    my @results;
    my @lines;
    while( my $line = <> ) {
        chomp $line;
        push @lines, $line;
        for my $term ( split /\s+/, $line ) {
            $term =~ s/[,.()"'`;:]//g;
            next if $term =~ $excluded_terms;
            next if $term =~ /^\d+$/;

            $term = to_singular($term);

            unless( $terms{$term}++ ) {
                push @results,{
                    word => $term,
                    doc  => get_word('EJdict' => $term) || get_word('wpedia' => $term) || 'Not Found.',
                };
            }
        }
    }

    print "<html lang='jp'>\n";
    print qq{<meta http-equiv="Content-Type" content="text/html; charset=utf-8">\n};
    print "<body>\n";
    printf qq{<div>%s</div>\n}, join("", @lines);
    print "<table style='border: 1px solid gray;'>\n";
    for my $row ( @results ) {
        print Encode::encode('utf8',sprintf("<tr><td style='border: 1px solid gray;'>%s</td><td style='border: 1px solid gray;'>%s</td></tr>\n", $row->{word}, $row->{doc}) );    
    }
    print "</table></body></html>\n";
}


&run() && exit();

1;
